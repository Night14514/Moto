import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

/// Android audio focus + native MODE_IN_COMMUNICATION / Bluetooth SCO.
class AudioService extends ChangeNotifier {
  static const _channel = MethodChannel('com.example.mototalk/audio');

  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioSession? _audioSession;

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  double _volume = 1.0;
  bool _isBluetoothConnected = false;
  bool _isMusicPaused = false;
  bool _callActive = false;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  double get volume => _volume;
  bool get isBluetoothConnected => _isBluetoothConnected;
  bool get isMusicPaused => _isMusicPaused;
  bool get callActive => _callActive;

  AudioService() {
    _initAudio();
  }

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod(method);
    } catch (e) {
      debugPrint('AudioService: native $method skipped: $e');
    }
  }

  Future<void> _initAudio() async {
    try {
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
          flags: AndroidAudioFlags.audibilityEnforced,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      _audioSession!.interruptionEventStream.listen((event) {
        debugPrint(
          'AudioService: interruption begin=${event.begin} type=${event.type}',
        );
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
      });

      notifyListeners();
    } catch (e, st) {
      debugPrint('AudioService: init error: $e\n$st');
    }
  }

  void unawaitedEnableSco() {
    enableBluetoothSco();
  }

  Future<void> prepareForCall() async {
    try {
      _callActive = true;
      await _audioSession?.setActive(true);
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
      await _audioSession?.setActive(true);
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
      await _invoke('disableBluetoothSco');
      await _invoke('resetAudioMode');
      await _invoke('stopForegroundService');
      await _invoke('releaseWakeLock');
      await _audioSession?.setActive(false);
      notifyListeners();
    } catch (e, st) {
      debugPrint('AudioService: endCall failed: $e\n$st');
    }
  }

  Future<bool> startRecording() async {
    try {
      await _audioSession?.setActive(true);
      await _invoke('setCommunicationMode');

      if (_audioPlayer.playing) {
        _isMusicPaused = true;
        await _audioPlayer.pause();
      }

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

      if (_isMusicPaused) {
        await _audioPlayer.play();
        _isMusicPaused = false;
      }

      // Keep communication mode / session while call is up (remote RX).
      if (!_callActive) {
        await _audioSession?.setActive(false);
      }

      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('AudioService: stopRecording error: $e\n$st');
      return false;
    }
  }

  Future<bool> startPlaying() async {
    await prepareForPlayback();
    return true;
  }

  Future<bool> stopPlaying() async {
    try {
      _isPlaying = false;
      if (!_callActive) {
        await _audioSession?.setActive(false);
      }
      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('AudioService: stopPlaying error: $e\n$st');
      return false;
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
    notifyListeners();
  }

  Future<void> mute() async {
    _isMuted = true;
    await _audioPlayer.setVolume(0.0);
    notifyListeners();
  }

  Future<void> unmute() async {
    _isMuted = false;
    await _audioPlayer.setVolume(_volume);
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

  Future<void> pauseMusic() async {
    if (_audioPlayer.playing) {
      _isMusicPaused = true;
      await _audioPlayer.pause();
      notifyListeners();
    }
  }

  Future<void> resumeMusic() async {
    if (_isMusicPaused) {
      await _audioPlayer.play();
      _isMusicPaused = false;
      notifyListeners();
    }
  }

  Future<void> setMusicSource(String source) async {
    try {
      await _audioPlayer.setUrl(source);
    } catch (e, st) {
      debugPrint('AudioService: setMusicSource error: $e\n$st');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
