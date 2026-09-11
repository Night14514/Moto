import 'dart:async';

/// Debounced local music ducking driven by voice activity (TX or RX).
///
/// Invariant: ducking is **device-local**. We never signal peers about music;
/// each handset ducks only its own external players via Android AudioFocus.
class MusicDuckingController {
  static const resumeDelay = Duration(seconds: 5);

  MusicDuckingController({
    required this.onDuckRequested,
    required this.onResumeRequested,
  });

  final Future<void> Function() onDuckRequested;
  final Future<void> Function() onResumeRequested;

  Timer? _resumeTimer;
  bool _duckActive = false;

  bool get duckActive => _duckActive;

  /// [active] = local TX or remote partner speaking.
  void onVoiceActivityChanged(bool active) {
    if (active) {
      _resumeTimer?.cancel();
      _resumeTimer = null;
      if (!_duckActive) {
        _duckActive = true;
        unawaited(onDuckRequested());
      }
      return;
    }

    // Silence — (re)start 5s grace before releasing focus.
    _resumeTimer?.cancel();
    _resumeTimer = Timer(resumeDelay, () {
      _resumeTimer = null;
      if (!_duckActive) return;
      _duckActive = false;
      unawaited(onResumeRequested());
    });
  }

  /// Immediate resume (call end / peer left). Does not wait for [resumeDelay].
  void forceResumeNow() {
    _resumeTimer?.cancel();
    _resumeTimer = null;
    if (!_duckActive) return;
    _duckActive = false;
    unawaited(onResumeRequested());
  }

  void dispose() {
    _resumeTimer?.cancel();
    _resumeTimer = null;
  }
}
