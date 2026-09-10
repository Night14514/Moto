import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'config.dart';
import 'screens/home_screen.dart';
import 'services/connection_service.dart';
import 'services/audio_service.dart';
import 'services/webrtc_service.dart';
import 'services/voice_control_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final appConfig = AppConfig();
  await appConfig.load();
  await _requestPermissions();

  runApp(MotoTalkApp(appConfig: appConfig));
}

Future<void> _requestPermissions() async {
  final permissions = [
    Permission.microphone,
    Permission.bluetooth,
    Permission.bluetoothConnect,
    Permission.notification,
  ];

  for (final permission in permissions) {
    try {
      await permission.request();
    } catch (e) {
      debugPrint('Permission request failed: $permission $e');
    }
  }
}

class MotoTalkApp extends StatelessWidget {
  final AppConfig appConfig;

  const MotoTalkApp({super.key, required this.appConfig});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfig>.value(value: appConfig),
        ChangeNotifierProvider(
          create: (ctx) => ConnectionService(ctx.read<AppConfig>()),
        ),
        ChangeNotifierProvider(create: (_) => AudioService()),
        ChangeNotifierProvider(create: (_) => VoiceControlService()),
        ChangeNotifierProxyProvider2<ConnectionService, AudioService,
            WebRTCService>(
          create: (context) => WebRTCService(
            context.read<ConnectionService>(),
            context.read<AudioService>(),
          ),
          update: (context, connection, audio, previous) => previous!,
        ),
      ],
      child: MaterialApp(
        title: 'MotoTalk',
        debugShowCheckedModeBanner: false,
        theme: _buildDarkTheme(),
        home: const HomeScreen(),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark().copyWith(
      primaryColor: const Color(0xFF1A1A2E),
      scaffoldBackgroundColor: const Color(0xFF0A0A14),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00D4FF),
        secondary: Color(0xFF0066FF),
        surface: Color(0xFF1A1A2E),
        error: Color(0xFFFF3366),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0A14),
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A2E),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00D4FF),
          foregroundColor: const Color(0xFF0A0A14),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFFFFFF),
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color(0xFFFFFFFF),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFFB0B0C0),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF808090),
        ),
      ),
    );
  }
}
