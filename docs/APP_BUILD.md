# Руководство по сборке приложения (Android)

## Требования

- Android Studio (последняя версия)
- Android SDK 11+
- Flutter SDK 3.19+
- Физическое устройство (рекомендуется) или эмулятор

## Установка

### 1. Flutter
```bash
export PATH="$PATH:/path/to/flutter/bin"
flutter doctor
```

### 2. Зависимости
```bash
cd app
flutter pub get
flutter doctor --android-licenses
flutter devices
```

## Разработка

```bash
flutter run
# или
flutter run -d <device_id>
```

## Сборка для релиза

### APK
```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

### App Bundle (Play Store)
```bash
flutter build appbundle --release
```

## Подпись кода

- Debug: автоматический debug keystore
- Release: настройте в `android/app/build.gradle`

## Разрешения

Уже в `android/app/src/main/AndroidManifest.xml`:
- `RECORD_AUDIO`
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MICROPHONE`
- `INTERNET`
- `BLUETOOTH` / `BLUETOOTH_CONNECT` / `BLUETOOTH_ADMIN`
- `WAKE_LOCK`
- `POST_NOTIFICATIONS`

## Устранение неполадок

```bash
flutter clean
flutter pub get
flutter build apk --debug
```

### Аудио / WebRTC
- Проверьте разрешения микрофона
- В debug-логах ищите `WebRTC: SDP[...]`, `ICE connection state`, `onTrack`
- Убедитесь, что `Config.serverUrl` указывает на доступный сервер

## Подключение к серверу

```dart
// lib/config.dart
static const String serverUrl = 'http://YOUR_PC_IP:3000';
```

## Чек-лист

- [ ] URL сервера в конфигурации
- [ ] Два реальных Android-устройства
- [ ] Звук без Bluetooth, затем с гарнитурой
- [ ] Фоновый режим
- [ ] Пауза музыки при PTT
- [ ] Голосовые команды
- [ ] Переподключение после обрыва сети
