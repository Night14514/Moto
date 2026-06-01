import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/connection_service.dart';
import '../services/audio_service.dart';
import '../services/webrtc_service.dart';
import '../services/voice_control_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isTransmitting = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    // Автоматическое подключение если есть учетные данные
    final connectionService = context.read<ConnectionService>();
    if (connectionService.userId != null) {
      connectionService.connect();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handlePttStart() {
    setState(() => _isTransmitting = true);
    HapticFeedback.heavyImpact();
    
    final webrtcService = context.read<WebRTCService>();
    webrtcService.startTransmitting();
  }

  void _handlePttEnd() {
    setState(() => _isTransmitting = false);
    HapticFeedback.lightImpact();
    
    final webrtcService = context.read<WebRTCService>();
    webrtcService.stopTransmitting();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: Consumer<ConnectionService>(
          builder: (context, connection, _) {
            // Проверка авторизации пользователя
            if (!connection.isAuthenticated && connection.userId == null) {
              return const LoginScreen();
            }

            return Consumer4<AudioService, WebRTCService, 
                      VoiceControlService, VoiceControlService>(
              builder: (context, audio, webrtc, voice, voiceControl, _) {
                return Column(
                  children: [
                    _buildHeader(connection),
                    const SizedBox(height: 20),
                    _buildStatusCards(connection, audio, webrtc),
                    const SizedBox(height: 30),
                    _buildModeSelector(voiceControl),
                    const Spacer(),
                    _buildPttButton(connection, webrtc, voiceControl),
                    const SizedBox(height: 40),
                    _buildPeerStatus(connection),
                    const SizedBox(height: 20),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(ConnectionService connection) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MotoTalk',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF00D4FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                connection.username ?? 'Гость',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          _buildConnectionIndicator(connection),
        ],
      ),
    );
  }

  Widget _buildConnectionIndicator(ConnectionService connection) {
    final isConnected = connection.isConnected;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isConnected 
          ? const Color(0xFF00FF88).withOpacity(0.1)
          : const Color(0xFFFF3366).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? const Color(0xFF00FF88) : const Color(0xFFFF3366),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnected ? const Color(0xFF00FF88) : const Color(0xFFFF3366),
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (controller) => controller.repeat())
            .fadeIn(duration: 500.ms)
            .then().fadeOut(duration: 500.ms),
          const SizedBox(width: 8),
          Text(
            isConnected ? 'Онлайн' : 'Оффлайн',
            style: TextStyle(
              color: isConnected ? const Color(0xFF00FF88) : const Color(0xFFFF3366),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCards(ConnectionService connection, AudioService audio, WebRTCService webrtc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatusCard(
              'Сервер',
              connection.isConnected ? 'Подключен' : 'Отключен',
              connection.isConnected ? Icons.cloud_done : Icons.cloud_off,
              connection.isConnected ? const Color(0xFF00FF88) : const Color(0xFFFF3366),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatusCard(
              'Собеседник',
              connection.peerOnline ? 'Онлайн' : 'Оффлайн',
              connection.peerOnline ? Icons.person : Icons.person_outline,
              connection.peerOnline ? const Color(0xFF00FF88) : const Color(0xFF808090),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatusCard(
              'Bluetooth',
              audio.isBluetoothConnected ? 'Активен' : 'Неактивен',
              audio.isBluetoothConnected ? Icons.bluetooth : Icons.bluetooth_disabled,
              audio.isBluetoothConnected ? const Color(0xFF00D4FF) : const Color(0xFF808090),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, String status, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(VoiceControlService voiceControl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildModeButton(
                'PTT',
                VoiceControlMode.ptt,
                voiceControl,
                Icons.push_pin,
              ),
            ),
            Expanded(
              child: _buildModeButton(
                'Голос',
                VoiceControlMode.voice,
                voiceControl,
                Icons.mic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(
    String label,
    VoiceControlMode mode,
    VoiceControlService voiceControl,
    IconData icon,
  ) {
    final isSelected = voiceControl.mode == mode;
    
    return GestureDetector(
      onTap: () => voiceControl.setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
            ? const Color(0xFF00D4FF).withOpacity(0.2)
            : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF00D4FF) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF00D4FF) : const Color(0xFF808090),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00D4FF) : const Color(0xFF808090),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPttButton(ConnectionService connection, WebRTCService webrtc, VoiceControlService voiceControl) {
    final isVoiceMode = voiceControl.mode == VoiceControlMode.voice;
    
    return Center(
      child: GestureDetector(
        onLongPress: isVoiceMode ? null : _handlePttStart,
        onLongPressEnd: isVoiceMode ? null : (_) => _handlePttEnd,
        onTap: isVoiceMode ? () {
          if (voiceControl.isListening) {
            voiceControl.stopListening();
          } else {
            voiceControl.startListening();
          }
        } : null,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _isTransmitting 
                      ? const Color(0xFF00D4FF).withOpacity(0.8)
                      : const Color(0xFF0066FF).withOpacity(0.6),
                    const Color(0xFF1A1A2E),
                  ],
                  stops: [_pulseController.value, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isTransmitting ? const Color(0xFF00D4FF) : const Color(0xFF0066FF))
                      .withOpacity(0.5),
                    blurRadius: _isTransmitting ? 40 : 20,
                    spreadRadius: _isTransmitting ? 10 : 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isVoiceMode 
                      ? (voiceControl.isListening ? Icons.mic : Icons.mic_none)
                      : (_isTransmitting ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                    size: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isVoiceMode 
                      ? (voiceControl.isListening ? 'Слушаю...' : 'Нажми')
                      : (_isTransmitting ? 'Передача' : 'Удерживай'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPeerStatus(ConnectionService connection) {
    if (!connection.peerOnline) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: connection.peerTalking 
          ? const Color(0xFF00D4FF).withOpacity(0.1)
          : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: connection.peerTalking 
            ? const Color(0xFF00D4FF)
            : const Color(0xFF1A1A2E),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: connection.peerTalking 
                ? const Color(0xFF00D4FF)
                : const Color(0xFF00FF88),
              shape: BoxShape.circle,
            ),
          ),
          if (connection.peerTalking)
            ...List.generate(2, (index) => 
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF),
                  shape: BoxShape.circle,
                ),
              ).animate(onPlay: (controller) => controller.repeat())
                .fadeIn(duration: 300.ms, delay: Duration(milliseconds: (index + 1) * 150))
                .then().fadeOut(duration: 300.ms),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connection.peerUsername ?? 'Собеседник',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  connection.peerTalking ? 'Говорит...' : 'Онлайн',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: connection.peerTalking 
                      ? const Color(0xFF00D4FF)
                      : const Color(0xFF00FF88),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
