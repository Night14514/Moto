import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../config.dart';

enum VoiceControlMode {
  ptt,
  voice,
}

class VoiceControlService extends ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  VoiceControlMode _mode = VoiceControlMode.ptt;
  bool _isListening = false;
  bool _isTransmitting = false;
  String _lastRecognizedWords = '';
  Timer? _silenceTimer;
  Timer? _debounceTimer;

  // Геттеры
  VoiceControlMode get mode => _mode;
  bool get isListening => _isListening;
  bool get isTransmitting => _isTransmitting;
  String get lastRecognizedWords => _lastRecognizedWords;

  VoiceControlService() {
    _initSpeechRecognition();
  }

  Future<void> _initSpeechRecognition() async {
    try {
      final available = await _speechToText.initialize();
      if (!available) {
        print('Speech recognition not available');
      }
    } catch (e) {
      print('Speech recognition initialization error: $e');
    }
  }

  void setMode(VoiceControlMode mode) {
    _mode = mode;
    
    if (mode == VoiceControlMode.ptt && _isListening) {
      stopListening();
    }
    
    notifyListeners();
  }

  Future<bool> startListening() async {
    if (_mode != VoiceControlMode.voice) {
      return false;
    }

    if (!_speechToText.isAvailable) {
      print('Speech recognition not available');
      return false;
    }

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'ru_RU',
        listenMode: ListenMode.confirmation,
        cancelOnError: true,
        onSoundLevelChange: (level) {
          // Could be used for voice activity detection
        },
      );

      _isListening = true;
      notifyListeners();
      return true;
    } catch (e) {
      print('Start listening error: $e');
      return false;
    }
  }

  void stopListening() {
    _speechToText.stop();
    _isListening = false;
    _silenceTimer?.cancel();
    _debounceTimer?.cancel();
    notifyListeners();
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.toLowerCase();
    _lastRecognizedWords = words;
    
    print('Recognized: $words (confidence: ${result.finalResult})');

    // Reset silence timer on any speech
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 5), () {
      // No speech for 5 seconds, could indicate end of command
      print('Silence detected');
    });

    // Debounce to avoid rapid false positives
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      Duration(milliseconds: Config.voiceCommandDebounceMs),
      () => _processVoiceCommand(words),
    );
  }

  void _processVoiceCommand(String words) {
    // Check for start commands
    for (final command in Config.voiceCommandsStart) {
      if (words.contains(command)) {
        _startTransmission();
        return;
      }
    }

    // Check for stop commands
    for (final command in Config.voiceCommandsStop) {
      if (words.contains(command)) {
        _stopTransmission();
        return;
      }
    }
  }

  void _startTransmission() {
    if (!_isTransmitting) {
      _isTransmitting = true;
      notifyListeners();
      // Signal to start PTT transmission
      // This will be handled by the UI layer
    }
  }

  void _stopTransmission() {
    if (_isTransmitting) {
      _isTransmitting = false;
      notifyListeners();
      // Signal to stop PTT transmission
      // This will be handled by the UI layer
    }
  }

  bool isStartCommand(String words) {
    final lowerWords = words.toLowerCase();
    return Config.voiceCommandsStart.any((cmd) => lowerWords.contains(cmd));
  }

  bool isStopCommand(String words) {
    final lowerWords = words.toLowerCase();
    return Config.voiceCommandsStop.any((cmd) => lowerWords.contains(cmd));
  }

  @override
  void dispose() {
    stopListening();
    _silenceTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
