import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'music_ducking_controller.dart';

/// Call-session audio (MODE_IN_COMMUNICATION / SCO / FGS) plus local music ducking.
///
/// Music ducking is **local-only**: Android AudioFocus TRANSIENT_MAY_DUCK affects
/// this device's external players (Spotify, Yandex, Telegram, …). Peers are never
/// told about music state.
class AudioService extends ChangeNotifier {
  static const _channel = MethodChannel('com.example.mototalk/audio');

  AudioSession? _audioSession;
  late final MusicDuckingController _ducking;

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  double _volume = 1.0;
  bool _isBluetoothConnected = false;
  bool _callActive = false;

  /// Fired when a full audio interruption begins (e.g. GSM call).
  /// WebRTCService should stop TX so we do not send over the phone call.
  VoidCallback? onExternalInterruptionBegin;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  double get volume => _volume;
  bool get isBluetoothConnected => _isBluetoothConnected;
  bool get callActive => _callActive;
  bool get isMusicDucked => _ducking.duckActive;

  AudioService() {
    _ducking = MusicDuckingController(
      onDuckRequested: requestMusicDuck,
      onResumeRequested: releaseMusicDuck,
    );
    _initAudio();
  }

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod(method);
    } catch (e) {
      debugPrint('AudioService: native $method skipped: $e');
    }
  }

  Future<void> requestMusicDuck() => _invoke('requestDuckFocus');

  Future<void> releaseMusicDuck() => _invoke('abandonDuckFocus');

  Future<void> _initAudio() async {
    try {
      _audioSession = await AudioSession.instance;
      // Attributes for WebRTC voice path. Focus for external music is owned by
      // MusicDuckingController → native TRANSIENT_MAY_DUCK (not permanent GAIN).
      await _audioSession!.configure(const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
          flags: AndroidAudioFlags.audibilityEnforced,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ));

      _audioSession!.interruptionEventStream.listen((event) {
        debugPrint(
          'AudioService: interruption begin=${event.begin} type=${event.type}',
        );
        // GSM / higher-priority session: stop PTT TX. Pure duck interruptions
        // from other apps do not require stopping our mic path.
        if (event.begin &&
            (event.type == AudioInterruptionType.pause ||
                event.type == AudioInterruptionType.unknown)) {
          onExternalInterruptionBegin?.call();
        }
      });

      _audioSession!.devicesChangedEventStream.listen((event) {
        final hasBt = event.devicesAdded.any(
          (d) =>
              d.type == AudioDeviceType.bluetoothSco ||
              d.type == AudioDeviceType.bluetoothA2dp,
        );
        if (hasBt) {
          _isBluetoothConnected = true;
          notifyListeners();
          if (_callActive) {
            unawaitedEnableSco();
          }
        }
        final removedBt = event.devicesRemoved.any(
          (d) =>
              d.type == AudioDeviceType.bluetoothSco ||
              d.type == AudioDeviceType.bluetoothA2dp,
        );
        if (removedBt) {
          _isBluetoothConnected = false;
          notifyListeners();
        }
        // VAF ducking uses AudioFocus and does not depend on output device.
      });

      notifyListeners();
    } catch (e, st) {
      debugPrint('AudioService: init error: $e\n$st');
    }
  }

  void unawaitedEnableSco() {
    enableBluetoothSco();
  }

  /// Voice activity on this device (local TX or remote partner speaking).
  /// Triggers local music duck / 5s resume — never signals the peer.
  void onVoiceActivityChanged(bool active) {
    if (!_callActive && !active) {
      // Outside a call, ensure we are not holding duck focus.
      _ducking.forceResumeNow();
      return;
    }
    _ducking.onVoiceActivityChanged(active);
  }

  Future<void> prepareForCall() async {
    try {
      _callActive = true;
      // Do NOT request permanent AudioFocus here — that would pause Spotify
      // for the entire call. Call session = mode/SCO/FGS/wake only.
      await _invoke('setCommunicationMode');
      await _invoke('enableBluetoothSco');
      await _invoke('startForegroundService');
      await _invoke('acquireWakeLock');
      debugPrint('AudioService: call audio ready (MODE_IN_COMMUNICATION)');
      notifyListeners();
    } catch (e, st) {
      debugPrint('AudioService: prepareForCall failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> prepareForPlayback() async {
    try {
      await _invoke('setCommunicationMode');
      _isPlaying = true;
      notifyListeners();
    } catch (e, st) {
      debugPrint('AudioService: prepareForPlayback failed: $e\n$st');
    }
  }

  Future<void> endCall() async {
    try {
      _callActive = false;
      _isPlaying = false;
      _isRecording = false;
      // Immediate music resume — do not wait for the 5s grace period.
      _ducking.forceResumeNow();
      await releaseMusicDuck();
      await _invoke('disableBluetoothSco');
      await _invoke('resetAudioMode');
      await _invoke('stopForegroundService');
      await _invoke('releaseWakeLock');
      notifyListeners();
    } catch (e, st) {
      debugPrint('AudioService: endCall failed: $e\n$st');
    }
  }

  Future<bool> startRecording() async {
    try {
      await _invoke('setCommunicationMode');
      _isRecording = true;
      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('AudioService: startRecording error: $e\n$st');
      return false;
    }
  }

  Future<bool> stopRecording() async {
    try {
      _isRecording = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('AudioService: stopRecording error: $e\n$st');
      return false;
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    notifyListeners();
  }

  Future<void> mute() async {
    _isMuted = true;
    notifyListeners();
  }

  Future<void> unmute() async {
    _isMuted = false;
    notifyListeners();
  }

  Future<void> enableBluetoothSco() async {
    await _invoke('enableBluetoothSco');
    _isBluetoothConnected = true;
    notifyListeners();
  }

  Future<void> disableBluetoothSco() async {
    await _invoke('disableBluetoothSco');
    notifyListeners();
  }

  @override
  void dispose() {
    _ducking.dispose();
    onExternalInterruptionBegin = null;
    super.dispose();
  }
}
