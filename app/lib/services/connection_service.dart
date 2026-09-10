import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

typedef SignalingPayloadHandler = void Function(Map<String, dynamic> data);

class ConnectionService extends ChangeNotifier {
  final AppConfig appConfig;

  IO.Socket? _socket;
  String? _userId;
  String? _username;
  String? _pin;
  bool _isConnected = false;
  bool _isAuthenticated = false;
  bool _peerOnline = false;
  String? _peerId;
  String? _peerUsername;
  bool _peerTalking = false;
  String? _lastError;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  SignalingPayloadHandler? onOfferReceived;
  SignalingPayloadHandler? onAnswerReceived;
  SignalingPayloadHandler? onIceCandidateReceived;
  VoidCallback? onPeerLeft;
  VoidCallback? onPeerJoined;

  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  bool get peerOnline => _peerOnline;
  String? get userId => _userId;
  String? get username => _username;
  String? get pin => _pin;
  String? get peerId => _peerId;
  String? get peerUsername => _peerUsername;
  bool get peerTalkingHint => _peerTalking;
  String? get lastError => _lastError;

  ConnectionService(this.appConfig) {
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    _username = prefs.getString('username');
    _pin = prefs.getString('pin');
    notifyListeners();
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_userId != null) await prefs.setString('userId', _userId!);
    if (_username != null) await prefs.setString('username', _username!);
    if (_pin != null) await prefs.setString('pin', _pin!);
  }

  Future<void> clearSession() async {
    disconnect();
    _userId = null;
    _username = null;
    _pin = null;
    _peerId = null;
    _peerUsername = null;
    _peerOnline = false;
    _isAuthenticated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('username');
    await prefs.remove('pin');
    notifyListeners();
  }

  /// Join shared room by PIN (create seat if room has space).
  Future<bool> joinRoom(String pin, String username) async {
    _lastError = null;
    try {
      final response = await _httpPost('/api/join', {
        'pin': pin,
        'username': username.trim(),
      });

      if (response['error'] != null) {
        _lastError = response['error'].toString();
        notifyListeners();
        return false;
      }

      _userId = response['userId'] as String?;
      _username = response['username'] as String?;
      _pin = pin;
      await _saveCredentials();
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('ConnectionService: join error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Legacy aliases used by older UI paths.
  Future<bool> register(String pin, String username) => joinRoom(pin, username);

  Future<bool> login(String pin, {String? username}) async {
    _lastError = null;
    final name = username ?? _username;
    if (name == null || name.isEmpty) {
      _lastError = 'Укажите имя для входа в комнату';
      notifyListeners();
      return false;
    }
    try {
      final response = await _httpPost('/api/login', {
        'pin': pin,
        'username': name,
      });
      if (response['error'] != null) {
        _lastError = response['error'].toString();
        notifyListeners();
        return false;
      }
      _userId = response['userId'] as String?;
      _username = response['username'] as String?;
      _pin = pin;
      await _saveCredentials();
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> _httpPost(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('${appConfig.serverUrl}$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.body.isNotEmpty) {
        try {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {
          return {'error': response.body};
        }
      }
      return {'error': 'Server error: ${response.statusCode}'};
    } catch (e) {
      debugPrint('ConnectionService: HTTP error: $e');
      return {'error': 'Нет связи с сервером: $e'};
    }
  }

  void connect() {
    if (_socket != null && _socket!.connected) return;

    _socket?.dispose();
    final url = appConfig.serverUrl;
    debugPrint('ConnectionService: connecting to $url');

    _socket = IO.io(url, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': false,
      'forceNew': true,
    });

    _socket!.on('connect', _onConnect);
    _socket!.on('disconnect', _onDisconnect);
    _socket!.on('connect_error', (err) {
      _lastError = 'Ошибка сокета: $err';
      debugPrint('ConnectionService: connect_error $err');
      notifyListeners();
    });
    _socket!.on('auth_success', _onAuthSuccess);
    _socket!.on('auth_error', _onAuthError);
    _socket!.on('user_joined', _onUserJoined);
    _socket!.on('user_online', _onUserOnline);
    _socket!.on('user_left', _onUserLeft);
    _socket!.on('peer_talking', _onPeerTalking);
    _socket!.on('peer_status', _onPeerStatus);
    _socket!.on('offer', _onOffer);
    _socket!.on('answer', _onAnswer);
    _socket!.on('ice-candidate', _onIceCandidate);
    _socket!.on('error', _onError);
  }

  void _onConnect(_) {
    debugPrint('ConnectionService: connected');
    _isConnected = true;
    _reconnectAttempts = 0;
    _lastError = null;
    notifyListeners();
    _startHeartbeat();
    if (_userId != null && _pin != null) authenticate();
  }

  void _onDisconnect(_) {
    debugPrint('ConnectionService: disconnected');
    _stopHeartbeat();
    _isConnected = false;
    _isAuthenticated = false;
    _peerOnline = false;
    _peerTalking = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_socket?.connected == true) _socket!.emit('heartbeat');
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _onAuthSuccess(data) {
    debugPrint('ConnectionService: auth success');
    _isAuthenticated = true;
    _lastError = null;
    notifyListeners();
  }

  void _onAuthError(data) {
    _lastError = data['error']?.toString() ?? 'Auth error';
    debugPrint('ConnectionService: auth error: $_lastError');
    _isAuthenticated = false;
    notifyListeners();
  }

  void _onUserJoined(data) {
    _peerId = data['userId'] as String?;
    _peerUsername = data['username'] as String?;
    _peerOnline = true;
    notifyListeners();
    onPeerJoined?.call();
  }

  void _onUserOnline(data) {
    _peerId = data['userId'] as String?;
    _peerUsername = data['username'] as String? ?? _peerUsername;
    _peerOnline = true;
    notifyListeners();
    onPeerJoined?.call();
  }

  void _onUserLeft(data) {
    _peerOnline = false;
    _peerTalking = false;
    _peerId = null;
    _peerUsername = null;
    notifyListeners();
    onPeerLeft?.call();
  }

  void _onPeerTalking(data) {
    _peerTalking = data['talking'] == true;
    notifyListeners();
  }

  void _onPeerStatus(data) {
    debugPrint('ConnectionService: peer status: ${data['status']}');
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  void _onOffer(data) {
    final payload = _asMap(data);
    final fromUserId = payload['fromUserId'] as String?;
    if (fromUserId != null) {
      _peerId = fromUserId;
      _peerOnline = true;
    }
    onOfferReceived?.call(payload);
  }

  void _onAnswer(data) {
    onAnswerReceived?.call(_asMap(data));
  }

  void _onIceCandidate(data) {
    onIceCandidateReceived?.call(_asMap(data));
  }

  void _onError(data) {
    debugPrint('ConnectionService: socket error: $data');
  }

  void authenticate() {
    if (_userId != null && _pin != null) {
      _socket!.emit('auth', {'userId': _userId, 'pin': _pin});
    }
  }

  void sendOffer(String targetUserId, dynamic offer) {
    _socket?.emit('offer', {'targetUserId': targetUserId, 'offer': offer});
  }

  void sendAnswer(String targetUserId, dynamic answer) {
    _socket?.emit('answer', {'targetUserId': targetUserId, 'answer': answer});
  }

  void sendIceCandidate(String targetUserId, dynamic candidate) {
    _socket?.emit('ice-candidate', {
      'targetUserId': targetUserId,
      'candidate': candidate,
    });
  }

  void sendPttStart() => _socket?.emit('ptt_start');
  void sendPttEnd() => _socket?.emit('ptt_end');
  void sendConnectionStatus(String status) {
    _socket?.emit('connection_status', {'status': status});
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_reconnectAttempts >= AppConfig.maxReconnectAttempts) {
      _lastError = 'Не удалось переподключиться';
      notifyListeners();
      return;
    }
    final delay = _calculateReconnectDelay();
    _reconnectAttempts++;
    debugPrint(
      'ConnectionService: reconnect in ${delay}ms (attempt $_reconnectAttempts)',
    );
    _reconnectTimer = Timer(Duration(milliseconds: delay), connect);
  }

  int _calculateReconnectDelay() {
    final exp = (_reconnectAttempts - 1).clamp(0, 10);
    final delay = AppConfig.initialReconnectDelayMs * (1 << exp);
    return delay.clamp(
      AppConfig.initialReconnectDelayMs,
      AppConfig.maxReconnectDelayMs,
    );
  }

  /// After server URL change — hard reconnect.
  void reconnectNow() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isAuthenticated = false;
    notifyListeners();
    if (_userId != null) connect();
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isAuthenticated = false;
    _peerOnline = false;
    _peerTalking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
