# Руководство по сборке приложения

## Требования

### Android
- Android Studio (последняя версия)
- Android SDK 11+
- Flutter SDK 3.19+
- Физическое устройство или эмулятор с Bluetooth

### iOS
- macOS с Xcode 15+
- iOS SDK 16+
- Устройство iPhone/iPad (симулятор имеет ограниченную поддержку Bluetooth)
- Учётная запись Apple Developer (для тестирования на устройстве)
- CocoaPods

## Установка

### 1. Установка Flutter
```bash
# Скачайте Flutter с https://flutter.dev/docs/get-started/install
# Добавьте в PATH
export PATH="$PATH:/path/to/flutter/bin"

# Проверьте установку
flutter doctor
```

### 2. Клонирование репозитория
```bash
cd /path/to/project
cd app
```

### 3. Установка зависимостей
```bash
flutter pub get
```

### 4. Специфичная настройка платформы

#### Настройка Android
```bash
# Примите лицензии Android
flutter doctor --android-licenses

# Проверьте подключённое устройство
flutter devices
```

#### Настройка iOS
```bash
# Установите CocoaPods
sudo gem install cocoapods

# Установите pods iOS
cd ios
pod install
cd ..

# Откройте в Xcode (для подписи кода)
open ios/Runner.xcworkspace
```

## Разработка

### Запуск на Android
```bash
flutter run -d <device_id>
# или
flutter run
```

### Запуск на iOS
```bash
flutter run -d <device_id>
# или
open ios/Runner.xcworkspace
# Затем запустите из Xcode
```

## Сборка для релиза

### Android APK
```bash
flutter build apk --release
# Вывод: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Play Store)
```bash
flutter build appbundle --release
# Вывод: build/app/outputs/bundle/release/app-release.aab
```

### iOS IPA
```bash
flutter build ios --release
# Затем используйте Xcode для архивации и распространения
```

## Подпись кода

### Android
- Debug: Автоматически (используя debug keystore)
- Release: Настройте в `android/app/build.gradle`

### iOS
- Debug: Автоматически (используя personal team)
- Release: Настройте в Xcode с учётной записью Apple Developer

## Разрешения

### Android (android/app/src/main/AndroidManifest.xml)
Уже настроено в проекте:
- RECORD_AUDIO
- FOREGROUND_SERVICE
- INTERNET
- BLUETOOTH
- BLUETOOTH_CONNECT
- BLUETOOTH_ADMIN

### iOS (ios/Runner/Info.plist)
Уже настроено в проекте:
- NSMicrophoneUsageDescription
- NSBluetoothAlwaysUsageDescription
- NSBluetoothPeripheralUsageDescription

## Тестирование

### Модульные тесты
```bash
flutter test
```

### Интеграционные тесты
```bash
flutter drive --target=test_driver/app.dart
```

## Устранение неполадок

### Проблемы с Flutter Doctor
```bash
flutter doctor -v
# Следуйте рекомендациям
```

### Сборка Android не удалась
```bash
flutter clean
flutter pub get
flutter build apk
```

### Сборка iOS не удалась
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
flutter build ios
```

### Bluetooth не работает
- Убедитесь, что Bluetooth включён на устройстве
- Проверьте разрешения в настройках устройства
- Протестируйте с реальными Bluetooth-наушниками (симулятор ограничен)

### Аудио не работает
- Проверьте разрешения микрофона
- Протестируйте с разными источниками аудио
- Проверьте конфигурацию аудио-сессии

## Развертывание

### Sideloading Android
```bash
# Установите ADB
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Sideloading iOS
- Используйте Xcode для установки на подключённое устройство
- Или используйте TestFlight для бета-распространения

## Подключение к серверу

Убедитесь, что сервер запущен и доступен:
```bash
# Отредактируйте lib/config.dart
const String serverUrl = 'http://YOUR_PC_IP:3000';
```

## Чек-лист для продакшена

- [ ] Обновите URL сервера в конфигурации
- [ ] Протестируйте на реальных устройствах
- [ ] Протестируйте с Bluetooth-наушниками
- [ ] Протестируйте фоновый режим
- [ ] Протестируйте интеграцию музыки
- [ ] Протестируйте голосовые команды
- [ ] Протестируйте переподключение
- [ ] Проверьте все разрешения
- [ ] Подпишите код для релиза
