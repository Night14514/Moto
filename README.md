# MotoTalk - Голосовая связь PTT для мотоциклистов

Android-приложение Push-to-Talk для двух мотоциклистов с голосовым управлением и интеграцией музыки. Self-hosted, без облачных сервисов.

## Возможности

- **Push-to-Talk (PTT)**: Удерживайте кнопку для разговора, отпустите для остановки
- **Голосовое управление**: Команды «Приём», «Пуск», «Стоп», «Отбой»
- **Интеграция музыки**: Пауза/возобновление при PTT
- **Низкая задержка**: WebRTC P2P
- **Подавление шума**: Встроенные AEC/NS/AGC WebRTC
- **Автопереподключение**: Экспоненциальная задержка 1с → 30с
- **Премиум UI**: Тёмная тема для использования в перчатках

## Технологический стек

- **Backend**: Node.js + Express + Socket.io + SQLite
- **Frontend**: Flutter (Android) + flutter_webrtc + speech_to_text
- **Контейнеризация**: Docker Compose

## Быстрый старт

### Сервер

```bash
./scripts/start-server.sh
./scripts/show-ip.sh
```

### Android APK

```bash
./scripts/build-apk.sh debug
adb install -r app/build/app/outputs/flutter-apk/app-debug.apk
```

В приложении: **Настройки →** `http://IP:3000` → оба райдера входят с **одним PIN** и разными именами.

Полный список команд: [docs/COMMANDS.md](docs/COMMANDS.md) · ТЗ пика: [docs/IDEAL_SPEC.md](docs/IDEAL_SPEC.md)

## Требования

- Сервер: Linux с Docker (или Node.js 18+)
- Android 11+
- Bluetooth-гарнитура (опционально; сначала тестируйте без неё)

## Документация

- [Архитектура](docs/ARCHITECTURE.md)
- [Настройка сервера](docs/SERVER_SETUP.md)
- [Сборка приложения](docs/APP_BUILD.md)
- [Ограничения Android](docs/PLATFORM_LIMITATIONS.md)
