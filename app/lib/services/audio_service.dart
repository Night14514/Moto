import 'package:flutter/foundation.dart';
import 'package:audio_manager/audio_manager.dart';
import 'package:just_audio/just_audio.dart';
import '../config.dart';

class AudioService extends ChangeNotifier {
  final AudioManager _audioManager = AudioManager();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
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
      await _audioManager.init();
      
      // Установить аудио-режим для коммуникации
      await _audioManager.setMode(AudioMode.communication);
      
      // Включить Bluetooth SCO для микрофона гарнитуры
      await _audioManager.setBluetoothScoOn(true);
      
      // Проверить статус Bluetooth
      _isBluetoothConnected = await _audioManager.isBluetoothScoOn();
      notifyListeners();
      
      // Слушать аудио-события
      _audioManager.onAudioDeviceChanged.listen((devices) {
        _checkBluetoothConnection();
      });
    } catch (e) {
      print('Audio initialization error: $e');
    }
  }

  Future<void> _checkBluetoothConnection() async {
    _isBluetoothConnected = await _audioManager.isBluetoothScoOn();
    notifyListeners();
  }

  Future<bool> startRecording() async {
    try {
      // Request audio focus
      await _audioManager.requestAudioFocus();
      
      // Pause music if playing
      if (_audioPlayer.playing) {
        _isMusicPaused = true;
        _currentMusicSource = _audioPlayer.audioSource.toString();
        await _audioPlayer.pause();
      }
      
      // Start recording
      await _audioManager.startRecording();
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
      await _audioManager.stopRecording();
      _isRecording = false;
      
      // Resume music if it was paused
      if (_isMusicPaused) {
        await _audioPlayer.play();
        _isMusicPaused = false;
      }
      
      // Abandon audio focus
      await _audioManager.abandonAudioFocus();
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Stop recording error: $e');
      return false;
    }
  }

  Future<bool> startPlaying() async {
    try {
      await _audioManager.requestAudioFocus();
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
      await _audioManager.abandonAudioFocus();
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
    await _audioManager.setVolume(_volume);
    notifyListeners();
  }

  Future<void> mute() async {
    _isMuted = true;
    await _audioManager.setVolume(0.0);
    notifyListeners();
  }

  Future<void> unmute() async {
    _isMuted = false;
    await _audioManager.setVolume(_volume);
    notifyListeners();
  }

  Future<void> enableBluetoothSco() async {
    try {
      await _audioManager.setBluetoothScoOn(true);
      _isBluetoothConnected = true;
      notifyListeners();
    } catch (e) {
      print('Enable Bluetooth SCO error: $e');
    }
  }

  Future<void> disableBluetoothSco() async {
    try {
      await _audioManager.setBluetoothScoOn(false);
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
    // This is a placeholder for custom audio processing if needed
    // Noise suppression, echo cancellation, AGC are built into WebRTC
  }

  @override
  void dispose() {
    _audioManager.release();
    _audioPlayer.dispose();
    super.dispose();
  }
}
