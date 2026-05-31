import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../config.dart';
import 'connection_service.dart';
import 'audio_service.dart';

class WebRTCService extends ChangeNotifier {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _isConnected = false;
  bool _isInitiator = false;
  final ConnectionService _connectionService;
  final AudioService _audioService;

  // Геттеры
  bool get isConnected => _isConnected;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  WebRTCService(this._connectionService, this._audioService) {
    _setupConnectionListeners();
  }

  void _setupConnectionListeners() {
    _connectionService.addListener(_onConnectionServiceChanged);
  }

  void _onConnectionServiceChanged() {
    if (_connectionService.peerOnline && !_isConnected) {
      _initiateCall();
    }
  }

  Future<void> _createPeerConnection() async {
    final configuration = Config.rtcConfiguration;
    
    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (candidate) {
      print('ICE candidate generated');
      if (_connectionService.peerId != null) {
        _connectionService.sendIceCandidate(
          _connectionService.peerId!,
          candidate.toMap(),
        );
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      print('ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        _isConnected = true;
        notifyListeners();
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
                 state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _isConnected = false;
        notifyListeners();
        _reconnect();
      }
    };

    _peerConnection!.onAddStream = (stream) {
      print('Remote stream added');
      _remoteStream = stream;
      notifyListeners();
      
      // Play remote audio
      _audioService.startPlaying();
    };

    _peerConnection!.onRemoveStream = (stream) {
      print('Remote stream removed');
      _remoteStream = null;
      notifyListeners();
      _audioService.stopPlaying();
    };

    _peerConnection!.onTrack = (track) {
      print('Track added: ${track.kind}');
      if (track.kind == 'audio') {
        _audioService.startPlaying();
      }
    };
  }

  Future<void> _getUserMedia() async {
    final constraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'googNoiseSuppression': true,
        'googEchoCancellation': true,
        'googAutoGainControl': true,
        'googHighpassFilter': true,
        'googNoiseSuppression2': true,
        'googEchoCancellation2': true,
      },
      'video': false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      notifyListeners();
    } catch (e) {
      print('Get user media error: $e');
      rethrow;
    }
  }

  Future<void> _initiateCall() async {
    if (_isConnected || _connectionService.peerId == null) {
      return;
    }

    _isInitiator = true;
    await _createPeerConnection();
    await _getUserMedia();

    if (_localStream != null) {
      _peerConnection!.addStream(_localStream!);
    }

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    _connectionService.sendOffer(_connectionService.peerId!, offer.toMap());
  }

  Future<void handleOffer(Map<String, dynamic> offer) async {
    if (_isInitiator) {
      return;
    }

    await _createPeerConnection();
    await _getUserMedia();

    if (_localStream != null) {
      _peerConnection!.addStream(_localStream!);
    }

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    
    _connectionService.sendAnswer(_connectionService.peerId!, answer.toMap());
  }

  Future<void handleAnswer(Map<String, dynamic> answer) async {
    if (!_isInitiator) {
      return;
    }

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(answer['sdp'], answer['type']),
    );
  }

  Future<void handleIceCandidate(Map<String, dynamic> candidate) async {
    if (_peerConnection != null) {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex'],
        ),
      );
    }
  }

  Future<void> startTransmitting() async {
    if (_localStream == null) {
      await _getUserMedia();
    }

    if (_localStream != null && _peerConnection != null) {
      // Enable audio tracks
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = true;
      }
      
      await _audioService.startRecording();
      _connectionService.sendPttStart();
    }
  }

  Future<void> stopTransmitting() async {
    if (_localStream != null) {
      // Disable audio tracks
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = false;
      }
    }
    
    await _audioService.stopRecording();
    _connectionService.sendPttEnd();
  }

  Future<void> _reconnect() async {
    // Clean up existing connection
    await _cleanup();
    
    // Wait a bit before reconnecting
    await Future.delayed(const Duration(seconds: 2));
    
    // Re-initiate call if peer is still online
    if (_connectionService.peerOnline) {
      await _initiateCall();
    }
  }

  Future<void> _cleanup() async {
    if (_localStream != null) {
      await _localStream!.dispose();
      _localStream = null;
    }

    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    _isConnected = false;
    _isInitiator = false;
    _remoteStream = null;
    notifyListeners();
  }

  Future<void> dispose() async {
    await _cleanup();
    _connectionService.removeListener(_onConnectionServiceChanged);
    super.dispose();
  }
}
