import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Runtime configuration (server URL editable without rebuild).
class AppConfig extends ChangeNotifier {
  static const _prefsKey = 'serverUrl';
  static const defaultServerUrl = 'http://192.168.1.100:3000';

  String _serverUrl = defaultServerUrl;
  bool _ready = false;
  String? _lastHealthError;

  String get serverUrl => _serverUrl;
  bool get ready => _ready;
  String? get lastHealthError => _lastHealthError;

  /// ICE / WebRTC STUN (public, free).
  static const Map<String, dynamic> rtcConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    'iceTransportPolicy': 'all',
    'sdpSemantics': 'unified-plan',
  };

  static const int maxReconnectAttempts = 10;
  static const int initialReconnectDelayMs = 1000;
  static const int maxReconnectDelayMs = 30000;
  static const int voiceCommandDebounceMs = 500;
  static const List<String> voiceCommandsStart = ['приём', 'пуск'];
  static const List<String> voiceCommandsStop = ['стоп', 'отбой'];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_prefsKey) ?? defaultServerUrl;
    _ready = true;
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    var normalized = url.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'http://$normalized';
    }
    _serverUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _serverUrl);
    notifyListeners();
  }

  Future<bool> testHealth() async {
    _lastHealthError = null;
    try {
      final response = await http
          .get(Uri.parse('$_serverUrl/health'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        notifyListeners();
        return true;
      }
      _lastHealthError = 'HTTP ${response.statusCode}';
    } catch (e) {
      _lastHealthError = e.toString();
      debugPrint('AppConfig: health check failed: $e');
    }
    notifyListeners();
    return false;
  }
}
