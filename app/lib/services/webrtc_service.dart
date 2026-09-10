import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config.dart';
import '../models/call_state.dart';
import 'connection_service.dart';
import 'audio_service.dart';

class WebRTCService extends ChangeNotifier {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  MediaStreamTrack? _localAudioTrack;
  bool _isInitiator = false;
  bool _isSettingUp = false;
  bool _isTransmitting = false;
  CallState _callState = CallState.idle;
  int _iceCandidatesSent = 0;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  bool _remoteDescriptionSet = false;
  Timer? _remoteLevelTimer;
  bool _remoteSpeaking = false;

  final ConnectionService _connectionService;
  final AudioService _audioService;

  CallState get callState => _callState;
  bool get isConnected => _callState.isMediaReady;
  bool get isTransmitting => _isTransmitting;
  /// True when inbound WebRTC audio level indicates the peer is speaking.
  bool get partnerTalking => _remoteSpeaking;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  WebRTCService(this._connectionService, this._audioService) {
    _wireSignaling();
  }

  void _wireSignaling() {
    _connectionService.onOfferReceived = _onOfferPayload;
    _connectionService.onAnswerReceived = _onAnswerPayload;
    _connectionService.onIceCandidateReceived = _onIcePayload;
    _connectionService.onPeerJoined = _onPeerJoined;
    _connectionService.onPeerLeft = _onPeerLeft;
    _connectionService.addListener(_onConnectionChanged);
  }

  void _setCallState(CallState state) {
    if (_callState == state) return;
    _log('CallState: $_callState → $state');
    _callState = state;
    notifyListeners();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('WebRTC: $message');
    }
  }

  void _onConnectionChanged() {
    // Socket-level peerTalkingHint is not used for CallState.talking.
  }

  void _onPeerJoined() {
    if (!_callState.isMediaReady && !_isSettingUp) {
      unawaited(_maybeInitiateCall());
    }
  }

  void _onPeerLeft() {
    unawaited(_cleanup(reason: 'peer left'));
    _setCallState(CallState.idle);
  }

  /// Deterministic offerer: lower userId creates the offer to avoid glare.
  bool _shouldBeInitiator() {
    final me = _connectionService.userId;
    final peer = _connectionService.peerId;
    if (me == null || peer == null) return false;
    return me.compareTo(peer) < 0;
  }

  Future<void> _maybeInitiateCall() async {
    if (!_connectionService.peerOnline || _connectionService.peerId == null) {
      return;
    }
    if (_callState.isMediaReady || _isSettingUp) return;
    if (!_shouldBeInitiator()) {
      _log('Waiting for peer offer (we are answerer)');
      _setCallState(CallState.connecting);
      return;
    }
    await _initiateCall();
  }

  Future<void> _createPeerConnection() async {
    final configuration = AppConfig.rtcConfiguration;
    _peerConnection = await createPeerConnection(configuration);
    _iceCandidatesSent = 0;
    _remoteDescriptionSet = false;
    _pendingRemoteCandidates.clear();

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate == null || candidate.candidate!.isEmpty) {
        _log('ICE gathering complete');
        return;
      }
      _iceCandidatesSent++;
      _log('ICE candidate #$_iceCandidatesSent → peer');
      final peerId = _connectionService.peerId;
      if (peerId != null) {
        _connectionService.sendIceCandidate(peerId, candidate.toMap());
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      _log('ICE connection state: $state');
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _setCallState(CallState.connected);
          _startRemoteLevelMonitor();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _setCallState(CallState.reconnecting);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _setCallState(CallState.failed);
          unawaited(_reconnect());
          break;
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          if (_callState != CallState.idle) {
            _setCallState(CallState.idle);
          }
          break;
        default:
          break;
      }
    };

    _peerConnection!.onConnectionState = (state) {
      _log('PC connection state: $state');
    };

    _peerConnection!.onSignalingState = (state) {
      _log('Signaling state: $state');
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      _log(
        'onTrack kind=${event.track.kind} id=${event.track.id} '
        'enabled=${event.track.enabled} muted=${event.track.muted} '
        'streams=${event.streams.length}',
      );
      if (event.track.kind != 'audio') return;

      event.track.enabled = true;

      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
      } else {
        // Some platforms deliver track without streams — synthesize one.
        _remoteStream ??= event.streams.isEmpty ? null : event.streams.first;
      }

      unawaited(_audioService.prepareForPlayback());
      if (!_callState.isMediaReady) {
        _setCallState(CallState.connected);
      }
      _startRemoteLevelMonitor();
    };

  }

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _log('RECORD_AUDIO not granted: $status');
      _setCallState(CallState.failed);
      return false;
    }
    return true;
  }

  Future<void> _getUserMedia() async {
    if (!await _ensureMicPermission()) {
      throw StateError('Microphone permission denied');
    }

    final constraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'googNoiseSuppression': true,
        'googEchoCancellation': true,
        'googAutoGainControl': true,
        'googHighpassFilter': true,
      },
      'video': false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isEmpty) {
      throw StateError('getUserMedia returned no audio tracks');
    }
    _localAudioTrack = audioTracks.first;
    // PTT: keep track in SDP but silent until button held.
    _localAudioTrack!.enabled = false;
    _log('Local audio track ready id=${_localAudioTrack!.id} enabled=false');
  }

  Future<void> _attachLocalTracks() async {
    if (_localStream == null || _peerConnection == null) return;

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
      _log('addTrack kind=${track.kind} enabled=${track.enabled}');
    }
  }

  Future<void> _initiateCall() async {
    if (_isSettingUp || _callState.isMediaReady) return;
    if (_connectionService.peerId == null) return;

    _isSettingUp = true;
    _isInitiator = true;
    _setCallState(CallState.connecting);

    try {
      await _audioService.prepareForCall();
      await _createPeerConnection();
      await _getUserMedia();
      await _attachLocalTracks();

      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });
      await _peerConnection!.setLocalDescription(offer);
      _log('Local SDP offer set, length=${offer.sdp?.length}');
      _logSdpSummary(offer.sdp, 'offer');

      _connectionService.sendOffer(
        _connectionService.peerId!,
        offer.toMap(),
      );
    } catch (e, st) {
      _log('Initiate call failed: $e\n$st');
      _setCallState(CallState.failed);
      await _cleanup(reason: 'initiate failed');
    } finally {
      _isSettingUp = false;
    }
  }

  Future<void> _onOfferPayload(Map<String, dynamic> payload) async {
    final offerMap = _asNestedMap(payload['offer']);
    if (offerMap == null) {
      _log('Offer payload missing offer object');
      return;
    }

    // Glare: if we already sent an offer and peer also offered, lower id wins.
    if (_isInitiator && _peerConnection != null) {
      if (_shouldBeInitiator()) {
        _log('Ignoring remote offer (we are deterministic initiator)');
        return;
      }
      _log('Glare: rolling back our offer, becoming answerer');
      await _cleanup(reason: 'glare rollback');
    }

    _isInitiator = false;
    _isSettingUp = true;
    _setCallState(CallState.connecting);

    try {
      await _audioService.prepareForCall();
      if (_peerConnection == null) {
        await _createPeerConnection();
      }
      if (_localStream == null) {
        await _getUserMedia();
        await _attachLocalTracks();
      }

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(
          offerMap['sdp'] as String?,
          offerMap['type'] as String?,
        ),
      );
      _remoteDescriptionSet = true;
      _logSdpSummary(offerMap['sdp'] as String?, 'remote-offer');
      await _flushPendingCandidates();

      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });
      await _peerConnection!.setLocalDescription(answer);
      _logSdpSummary(answer.sdp, 'answer');

      final peerId = _connectionService.peerId;
      if (peerId == null) {
        throw StateError('No peerId when sending answer');
      }
      _connectionService.sendAnswer(peerId, answer.toMap());
    } catch (e, st) {
      _log('handleOffer failed: $e\n$st');
      _setCallState(CallState.failed);
      await _cleanup(reason: 'handleOffer failed');
    } finally {
      _isSettingUp = false;
    }
  }

  Future<void> _onAnswerPayload(Map<String, dynamic> payload) async {
    if (!_isInitiator || _peerConnection == null) {
      _log('Ignoring answer (not initiator or no PC)');
      return;
    }
    final answerMap = _asNestedMap(payload['answer']);
    if (answerMap == null) {
      _log('Answer payload missing answer object');
      return;
    }

    try {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(
          answerMap['sdp'] as String?,
          answerMap['type'] as String?,
        ),
      );
      _remoteDescriptionSet = true;
      _logSdpSummary(answerMap['sdp'] as String?, 'remote-answer');
      await _flushPendingCandidates();
    } catch (e, st) {
      _log('handleAnswer failed: $e\n$st');
      _setCallState(CallState.failed);
    }
  }

  Future<void> _onIcePayload(Map<String, dynamic> payload) async {
    final candidateMap = _asNestedMap(payload['candidate']);
    if (candidateMap == null) return;

    final candidate = RTCIceCandidate(
      candidateMap['candidate'] as String?,
      candidateMap['sdpMid'] as String?,
      candidateMap['sdpMLineIndex'] as int?,
    );

    if (_peerConnection == null || !_remoteDescriptionSet) {
      _pendingRemoteCandidates.add(candidate);
      _log('Queued remote ICE (${_pendingRemoteCandidates.length} pending)');
      return;
    }

    try {
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      _log('addCandidate failed: $e');
    }
  }

  Future<void> _flushPendingCandidates() async {
    if (_peerConnection == null) return;
    for (final c in List<RTCIceCandidate>.from(_pendingRemoteCandidates)) {
      try {
        await _peerConnection!.addCandidate(c);
      } catch (e) {
        _log('flush addCandidate failed: $e');
      }
    }
    _pendingRemoteCandidates.clear();
  }

  Map<String, dynamic>? _asNestedMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  void _logSdpSummary(String? sdp, String label) {
    if (sdp == null) {
      _log('SDP[$label]: null');
      return;
    }
    final hasAudio = sdp.contains('m=audio');
    final direction = RegExp(r'a=(sendrecv|sendonly|recvonly|inactive)')
        .firstMatch(sdp)
        ?.group(1);
    _log('SDP[$label]: m=audio=$hasAudio direction=$direction bytes=${sdp.length}');
  }

  void _startRemoteLevelMonitor() {
    _remoteLevelTimer?.cancel();
    _remoteLevelTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      unawaited(_sampleRemoteAudioLevel());
    });
  }

  Future<void> _sampleRemoteAudioLevel() async {
    final pc = _peerConnection;
    if (pc == null) return;
    try {
      final stats = await pc.getStats();
      double level = 0;
      for (final report in stats) {
        final values = report.values;
        if (report.type == 'inbound-rtp' &&
            (values['kind'] == 'audio' || values['mediaType'] == 'audio')) {
          final raw = values['audioLevel'] ?? values['totalAudioEnergy'];
          if (raw is num) {
            level = raw.toDouble();
          }
        }
        if (report.type == 'track' && values['kind'] == 'audio') {
          final raw = values['audioLevel'];
          if (raw is num && raw.toDouble() > level) {
            level = raw.toDouble();
          }
        }
      }
      // audioLevel is 0..1; energy can be larger — treat modest threshold as speech.
      final speaking = level > 0.01;
      if (speaking != _remoteSpeaking) {
        _remoteSpeaking = speaking;
        _setCallState(speaking ? CallState.talking : CallState.connected);
        _log('Remote speaking=$speaking level=$level');
      }
    } catch (e) {
      // Stats can fail transiently during renegotiation.
    }
  }

  Future<void> startTransmitting() async {
    if (_peerConnection == null || _localAudioTrack == null) {
      _log('startTransmitting: media not ready (pc=${_peerConnection != null})');
      return;
    }

    try {
      await _audioService.startRecording();
      _localAudioTrack!.enabled = true;
      _isTransmitting = true;
      notifyListeners();
      _connectionService.sendPttStart();
      _log('PTT TX on');
    } catch (e, st) {
      _log('startTransmitting failed: $e\n$st');
      _setCallState(CallState.failed);
    }
  }

  Future<void> stopTransmitting() async {
    try {
      if (_localAudioTrack != null) {
        _localAudioTrack!.enabled = false;
      }
      _isTransmitting = false;
      await _audioService.stopRecording();
      _connectionService.sendPttEnd();
      notifyListeners();
      _log('PTT TX off');
    } catch (e, st) {
      _log('stopTransmitting failed: $e\n$st');
    }
  }

  Future<void> _reconnect() async {
    _setCallState(CallState.reconnecting);
    await _cleanup(reason: 'reconnect');
    await Future.delayed(const Duration(seconds: 2));
    if (_connectionService.peerOnline) {
      await _maybeInitiateCall();
    } else {
      _setCallState(CallState.idle);
    }
  }

  Future<void> _cleanup({String reason = ''}) async {
    _log('Cleanup ($reason)');
    _remoteLevelTimer?.cancel();
    _remoteLevelTimer = null;
    _remoteSpeaking = false;
    _pendingRemoteCandidates.clear();
    _remoteDescriptionSet = false;
    _isTransmitting = false;
    _iceCandidatesSent = 0;

    try {
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;
    _localAudioTrack = null;
    _remoteStream = null;

    try {
      await _peerConnection?.close();
    } catch (_) {}
    _peerConnection = null;
    _isInitiator = false;
    _isSettingUp = false;

    await _audioService.endCall();
  }

  /// Public entry after socket reconnect restores peer presence.
  Future<void> ensureCall() => _maybeInitiateCall();

  @override
  void dispose() {
    _connectionService.onOfferReceived = null;
    _connectionService.onAnswerReceived = null;
    _connectionService.onIceCandidateReceived = null;
    _connectionService.onPeerJoined = null;
    _connectionService.onPeerLeft = null;
    _connectionService.removeListener(_onConnectionChanged);
    unawaited(_cleanup(reason: 'dispose'));
    super.dispose();
  }
}
