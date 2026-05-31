import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class ConnectionService extends ChangeNotifier {
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
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  // Геттеры
  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  bool get peerOnline => _peerOnline;
  String? get userId => _userId;
  String? get username => _username;
  String? get peerId => _peerId;
  String? get peerUsername => _peerUsername;
  bool get peerTalking => _peerTalking;

  ConnectionService() {
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

  Future<bool> register(String pin, String username) async {
    try {
      final response = await _httpPost('/api/register', {
        'pin': pin,
        'username': username,
      });

      if (response['error'] != null) {
        return false;
      }

      _userId = response['userId'];
      _username = response['username'];
      _pin = pin;
      await _saveCredentials();
      return true;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }

  Future<bool> login(String pin) async {
    try {
      final response = await _httpPost('/api/login', {'pin': pin});

      if (response['error'] != null) {
        return false;
      }

      _userId = response['userId'];
      _username = response['username'];
      _pin = pin;
      await _saveCredentials();
      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> _httpPost(String endpoint, Map<String, dynamic> data) async {
    // Простая реализация HTTP с использованием dart:io была бы здесь
    // Пока возвращаем мок-ответ для разработки
    return Future.value({'userId': 'mock_id', 'username': 'User'});
  }

  void connect() {
    if (_socket != null && _socket!.connected) {
      return;
    }

    _socket = IO.io(Config.serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionDelay': Config.initialReconnectDelayMs,
      'reconnectionAttempts': Config.maxReconnectAttempts,
    });

    _socket!.on('connect', _onConnect);
    _socket!.on('disconnect', _onDisconnect);
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
    print('Connected to server');
    _isConnected = true;
    _reconnectAttempts = 0;
    notifyListeners();

    if (_userId != null && _pin != null) {
      authenticate();
    }
  }

  void _onDisconnect(_) {
    print('Disconnected from server');
    _isConnected = false;
    _isAuthenticated = false;
    _peerOnline = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _onAuthSuccess(data) {
    print('Authentication successful');
    _isAuthenticated = true;
    notifyListeners();
  }

  void _onAuthError(data) {
    print('Authentication error: ${data['error']}');
    _isAuthenticated = false;
    notifyListeners();
  }

  void _onUserJoined(data) {
    print('User joined: ${data['username']}');
    _peerId = data['userId'];
    _peerUsername = data['username'];
    _peerOnline = true;
    notifyListeners();
  }

  void _onUserOnline(data) {
    print('User online: ${data['userId']}');
    _peerId = data['userId'];
    _peerOnline = true;
    notifyListeners();
  }

  void _onUserLeft(data) {
    print('User left: ${data['userId']}');
    _peerOnline = false;
    _peerTalking = false;
    notifyListeners();
  }

  void _onPeerTalking(data) {
    _peerTalking = data['talking'];
    notifyListeners();
  }

  void _onPeerStatus(data) {
    print('Peer status: ${data['status']}');
  }

  void _onOffer(data) {
    // Обработка WebRTC offer - будет обработано WebRTCService
    print('Received offer from ${data['fromUserId']}');
  }

  void _onAnswer(data) {
    // Обработка WebRTC answer - будет обработано WebRTCService
    print('Received answer from ${data['fromUserId']}');
  }

  void _onIceCandidate(data) {
    // Обработка ICE candidate - будет обработано WebRTCService
    print('Received ICE candidate from ${data['fromUserId']}');
  }

  void _onError(data) {
    print('Socket error: $data');
  }

  void authenticate() {
    if (_userId != null && _pin != null) {
      _socket!.emit('auth', {
        'userId': _userId,
        'pin': _pin,
      });
    }
  }

  void sendOffer(String targetUserId, dynamic offer) {
    _socket?.emit('offer', {
      'targetUserId': targetUserId,
      'offer': offer,
    });
  }

  void sendAnswer(String targetUserId, dynamic answer) {
    _socket?.emit('answer', {
      'targetUserId': targetUserId,
      'answer': answer,
    });
  }

  void sendIceCandidate(String targetUserId, dynamic candidate) {
    _socket?.emit('ice-candidate', {
      'targetUserId': targetUserId,
      'candidate': candidate,
    });
  }

  void sendPttStart() {
    _socket?.emit('ptt_start');
  }

  void sendPttEnd() {
    _socket?.emit('ptt_end');
  }

  void sendConnectionStatus(String status) {
    _socket?.emit('connection_status', {'status': status});
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    
    if (_reconnectAttempts >= Config.maxReconnectAttempts) {
      print('Max reconnection attempts reached');
      return;
    }

    final delay = _calculateReconnectDelay();
    _reconnectAttempts++;

    print('Scheduling reconnect in ${delay}ms (attempt $_reconnectAttempts)');
    
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      connect();
    });
  }

  int _calculateReconnectDelay() {
    final delay = Config.initialReconnectDelayMs * (1 << (_reconnectAttempts - 1));
    return delay.clamp(Config.initialReconnectDelayMs, Config.maxReconnectDelayMs);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isAuthenticated = false;
    _peerOnline = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
