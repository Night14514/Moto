import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../config.dart';

enum VoiceControlMode {
  ptt,
  voice,
}

typedef VoiceTransmitCallback = Future<void> Function();

class VoiceControlService extends ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  VoiceControlMode _mode = VoiceControlMode.ptt;
  bool _isListening = false;
  bool _isTransmitting = false;
  String _lastRecognizedWords = '';
  Timer? _silenceTimer;
  Timer? _debounceTimer;

  /// Wired from UI / composition root to WebRTC PTT start/stop.
  VoiceTransmitCallback? onStartTransmit;
  VoiceTransmitCallback? onStopTransmit;

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
        debugPrint('VoiceControl: speech recognition not available');
      }
    } catch (e, st) {
      debugPrint('VoiceControl: init error: $e\n$st');
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
      debugPrint('VoiceControl: speech recognition not available');
      return false;
    }

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'ru_RU',
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.confirmation,
          cancelOnError: true,
        ),
      );

      _isListening = true;
      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('VoiceControl: startListening error: $e\n$st');
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

  void _onSpeechResult(dynamic result) {
    final words = result.recognizedWords.toLowerCase();
    _lastRecognizedWords = words;

    debugPrint(
      'VoiceControl: recognized "$words" final=${result.finalResult}',
    );

    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('VoiceControl: silence detected');
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      Duration(milliseconds: AppConfig.voiceCommandDebounceMs),
      () => _processVoiceCommand(words),
    );
  }

  void _processVoiceCommand(String words) {
    for (final command in AppConfig.voiceCommandsStart) {
      if (words.contains(command)) {
        unawaited(_startTransmission());
        return;
      }
    }

    for (final command in AppConfig.voiceCommandsStop) {
      if (words.contains(command)) {
        unawaited(_stopTransmission());
        return;
      }
    }
  }

  Future<void> _startTransmission() async {
    if (_isTransmitting) return;
    _isTransmitting = true;
    notifyListeners();
    try {
      await onStartTransmit?.call();
    } catch (e, st) {
      debugPrint('VoiceControl: onStartTransmit failed: $e\n$st');
      _isTransmitting = false;
      notifyListeners();
    }
  }

  Future<void> _stopTransmission() async {
    if (!_isTransmitting) return;
    _isTransmitting = false;
    notifyListeners();
    try {
      await onStopTransmit?.call();
    } catch (e, st) {
      debugPrint('VoiceControl: onStopTransmit failed: $e\n$st');
    }
  }

  bool isStartCommand(String words) {
    final lowerWords = words.toLowerCase();
    return AppConfig.voiceCommandsStart.any((cmd) => lowerWords.contains(cmd));
  }

  bool isStopCommand(String words) {
    final lowerWords = words.toLowerCase();
    return AppConfig.voiceCommandsStop.any((cmd) => lowerWords.contains(cmd));
  }

  @override
  void dispose() {
    stopListening();
    _silenceTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
