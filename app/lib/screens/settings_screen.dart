import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../services/connection_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: context.read<AppConfig>().serverUrl,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final config = context.read<AppConfig>();
    await config.setServerUrl(_urlController.text);
    context.read<ConnectionService>().reconnectNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Адрес сервера сохранён'),
        backgroundColor: Color(0xFF00FF88),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final config = context.read<AppConfig>();
    await config.setServerUrl(_urlController.text);
    final ok = await config.testHealth();
    setState(() {
      _testing = false;
      _testResult = ok
          ? 'Сервер доступен ✓'
          : 'Нет ответа: ${config.lastHealthError ?? "ошибка"}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: const Color(0xFF0A0A14),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Адрес сигнального сервера',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Укажите IP ПК в той же Wi‑Fi сети, например http://192.168.1.50:3000',
            style: TextStyle(color: Color(0xFF808090), fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'http://192.168.x.x:3000',
              hintStyle: const TextStyle(color: Color(0xFF505060)),
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
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _test,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00D4FF),
                    side: const BorderSide(color: Color(0xFF00D4FF)),
                    minimumSize: const Size(0, 48),
                  ),
                  child: _testing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Проверить'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 16),
            Text(
              _testResult!,
              style: TextStyle(
                color: _testResult!.contains('✓')
                    ? const Color(0xFF00FF88)
                    : const Color(0xFFFF3366),
              ),
            ),
          ],
          const SizedBox(height: 40),
          const Text(
            'Как узнать IP',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'На компьютере с сервером:\n'
            '  ./scripts/show-ip.sh\n'
            'или: ip -4 addr show | grep inet',
            style: TextStyle(
              color: Color(0xFF808090),
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () async {
              await context.read<ConnectionService>().clearSession();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text(
              'Выйти из комнаты',
              style: TextStyle(color: Color(0xFFFF3366)),
            ),
          ),
        ],
      ),
    );
  }
}
