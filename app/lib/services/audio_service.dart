import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../config.dart';

class AudioService extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioSession? _audioSession;
  
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  double _volume = 1.0;
  bool _isBluetoothConnected = false;
  bool _isMusicPaused = false;
  String? _currentMusicSource;

  // Геттеры
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  double get volume => _volume;
  bool get isBluetoothConnected => _isBluetoothConnected;
  bool get isMusicPaused => _isMusicPaused;

  AudioService() {
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
      
      _isBluetoothConnected = true; // Предполагаем, что Bluetooth доступен
      notifyListeners();
    } catch (e) {
      print('Audio initialization error: $e');
    }
  }

  Future<bool> startRecording() async {
    try {
      await _audioSession?.setActive(true);
      
      // Pause music if playing
      if (_audioPlayer.playing) {
        _isMusicPaused = true;
        await _audioPlayer.pause();
      }
      
      _isRecording = true;
      notifyListeners();
      
      return true;
    } catch (e) {
      print('Start recording error: $e');
      return false;
    }
  }

  Future<bool> stopRecording() async {
    try {
      _isRecording = false;
      
      // Resume music if it was paused
      if (_isMusicPaused) {
        await _audioPlayer.play();
        _isMusicPaused = false;
      }
      
      await _audioSession?.setActive(false);
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Stop recording error: $e');
      return false;
    }
  }

  Future<bool> startPlaying() async {
    try {
      await _audioSession?.setActive(true);
      _isPlaying = true;
      notifyListeners();
      return true;
    } catch (e) {
      print('Start playing error: $e');
      return false;
    }
  }

  Future<bool> stopPlaying() async {
    try {
      await _audioSession?.setActive(false);
      _isPlaying = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Stop playing error: $e');
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
    try {
      _isBluetoothConnected = true;
      notifyListeners();
    } catch (e) {
      print('Enable Bluetooth SCO error: $e');
    }
  }

  Future<void> disableBluetoothSco() async {
    try {
      _isBluetoothConnected = false;
      notifyListeners();
    } catch (e) {
      print('Disable Bluetooth SCO error: $e');
    }
  }

  // Music integration methods
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
      _currentMusicSource = source;
    } catch (e) {
      print('Set music source error: $e');
    }
  }

  // Audio processing configuration
  Future<void> configureAudioProcessing() async {
    // WebRTC handles most audio processing internally
    // Noise suppression, echo cancellation, AGC are built into WebRTC
    // Additional configuration can be added here if needed
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
