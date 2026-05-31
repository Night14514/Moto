import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/connection_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isRegistering = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final connectionService = context.read<ConnectionService>();
    bool success;

    if (_isRegistering) {
      success = await connectionService.register(
        _pinController.text,
        _usernameController.text,
      );
    } else {
      success = await connectionService.login(_pinController.text);
    }

    setState(() => _isLoading = false);

    if (success) {
      connectionService.connect();
    } else {
      _showError(_isRegistering ? 'Ошибка регистрации' : 'Неверный PIN');
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
                  const SizedBox(height: 40),
                  _buildTitle(),
                  const SizedBox(height: 40),
                  if (_isRegistering) _buildUsernameField(),
                  if (_isRegistering) const SizedBox(height: 20),
                  _buildPinField(),
                  const SizedBox(height: 30),
                  _buildSubmitButton(),
                  const SizedBox(height: 20),
                  _buildToggleMode(),
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
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00D4FF), Color(0xFF0066FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4FF).withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: const Icon(
        Icons.motorcycle,
        size: 60,
        color: Colors.white,
      ),
    ).animate().fadeIn(duration: 600.ms).scale();
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'MotoTalk',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: const Color(0xFF00D4FF),
            fontWeight: FontWeight.bold,
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3),
        const SizedBox(height: 8),
        Text(
          _isRegistering ? 'Создайте аккаунт' : 'Войдите в систему',
          style: Theme.of(context).textTheme.bodyLarge,
        ).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideY(begin: 0.3),
      ],
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Имя пользователя',
        labelStyle: const TextStyle(color: Color(0xFF808090)),
        prefixIcon: const Icon(Icons.person, color: Color(0xFF00D4FF)),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A1A2E)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A1A2E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Введите имя пользователя';
        }
        return null;
      },
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideX(begin: -0.3);
  }

  Widget _buildPinField() {
    return TextFormField(
      controller: _pinController,
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      maxLength: 4,
      obscureText: true,
      decoration: InputDecoration(
        labelText: 'PIN-код',
        labelStyle: const TextStyle(color: Color(0xFF808090)),
        prefixIcon: const Icon(Icons.lock, color: Color(0xFF00D4FF)),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A1A2E)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A1A2E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
        ),
        counterText: '',
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Введите PIN-код';
        }
        if (value.length != 4) {
          return 'PIN-код должен быть 4 цифры';
        }
        return null;
      },
    ).animate().fadeIn(duration: 600.ms, delay: 300.ms).slideX(begin: -0.3);
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00D4FF),
          foregroundColor: const Color(0xFF0A0A14),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A0A14)),
                ),
              )
            : Text(
                _isRegistering ? 'Создать аккаунт' : 'Войти',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideY(begin: 0.3);
  }

  Widget _buildToggleMode() {
    return TextButton(
      onPressed: _isLoading ? null : () {
        setState(() {
          _isRegistering = !_isRegistering;
          _formKey.currentState?.reset();
          _pinController.clear();
          _usernameController.clear();
        });
      },
      child: Text(
        _isRegistering 
          ? 'Уже есть аккаунт? Войти' 
          : 'Нет аккаунта? Создать',
        style: const TextStyle(
          color: Color(0xFF00D4FF),
          fontSize: 14,
        ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 500.ms);
  }
}
