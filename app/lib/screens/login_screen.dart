import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config.dart';
import '../services/connection_service.dart';
import 'settings_screen.dart';

/// Join shared room: both riders enter the SAME 4-digit PIN + own names.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final connection = context.read<ConnectionService>();
      if (connection.username != null) {
        _usernameController.text = connection.username!;
      }
      if (connection.pin != null) {
        _pinController.text = connection.pin!;
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final connection = context.read<ConnectionService>();
    final ok = await connection.joinRoom(
      _pinController.text,
      _usernameController.text,
    );
    setState(() => _isLoading = false);

    if (ok) {
      connection.connect();
    } else {
      _showError(connection.lastError ?? 'Не удалось войти в комнату');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF3366),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serverUrl = context.watch<AppConfig>().serverUrl;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 32),
                  Text(
                    'MotoTalk',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: const Color(0xFF00D4FF),
                          fontWeight: FontWeight.bold,
                        ),
                  ).animate().fadeIn(duration: 500.ms),
                  const SizedBox(height: 8),
                  const Text(
                    'Оба вводят один PIN комнаты\nи свои имена (макс. 2)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF808090), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    serverUrl,
                    style: const TextStyle(
                      color: Color(0xFF00D4FF),
                      fontSize: 12,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings, size: 18),
                    label: const Text('Адрес сервера'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF00D4FF),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildUsernameField(),
                  const SizedBox(height: 16),
                  _buildPinField(),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleJoin,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0A0A14),
                              ),
                            )
                          : const Text(
                              'Войти в комнату',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFF0066FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4FF).withValues(alpha: 0.4),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(Icons.motorcycle, size: 48, color: Colors.white),
    ).animate().fadeIn(duration: 500.ms).scale();
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      style: const TextStyle(color: Colors.white),
      textInputAction: TextInputAction.next,
      decoration: _decoration('Ваше имя', Icons.person),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Введите имя';
        return null;
      },
    );
  }

  Widget _buildPinField() {
    return TextFormField(
      controller: _pinController,
      style: const TextStyle(color: Colors.white, letterSpacing: 8),
      keyboardType: TextInputType.number,
      maxLength: 4,
      obscureText: true,
      decoration: _decoration('PIN комнаты', Icons.lock).copyWith(counterText: ''),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      validator: (v) {
        if (v == null || v.length != 4) return 'PIN — 4 цифры';
        return null;
      },
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF808090)),
      prefixIcon: Icon(icon, color: const Color(0xFF00D4FF)),
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
      ),
    );
  }
}
