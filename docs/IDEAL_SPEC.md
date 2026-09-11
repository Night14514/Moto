# MotoTalk — ТЗ «Пик» (Ideal Spec)

> Цель: два Android-устройства с установленным APK стабильно слышат друг друга
> (PTT в обе стороны) через self-hosted сервер в одной сети / с доступом по IP.
> Документ фиксирует максимум осмысленных улучшений без облачных SaaS.

## 0. Непреложные ограничения

- Только Android (iOS удалён).
- Self-hosted: Node.js + Socket.io + SQLite, без платных облаков.
- Лимит комнаты: **ровно 2** участника.
- PTT по удержанию + голосовые команды.
- Пауза/приглушение локальной музыки (внешние плееры) при голосовой активности
  (TX или RX) через `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`, авто-резюм через 5 с тишины.
- Автопереподключение с экспонентой 1→30 с.
- Встроенные AEC/NS/AGC WebRTC не отключать.

## 1. Критический путь «два APK → звук»

| # | Требование | Критерий приёмки |
|---|---|---|
| 1.1 | URL сервера задаётся в приложении (не только в коде) | Оба телефона подключаются к `http://IP:3000` без пересборки |
| 1.2 | Общий PIN комнаты | Оба вводят один PIN + свои имена → пара |
| 1.3 | WebRTC media path | Offer/answer/ICE доходят до PC; `ICE=connected`; `onTrack` |
| 1.4 | PTT = `track.enabled` | Трек в SDP постоянно; кнопка только mute/unmute |
| 1.5 | Android `MODE_IN_COMMUNICATION` + SCO | Звук на динамике и на BT-гарнитуре |
| 1.6 | Audio session жива весь звонок | Отпускание PTT не глушит RX |
| 1.7 | Foreground Service на время звонка | Микрофон не режется при выключенном экране |
| 1.8 | Индикатор «говорит» | По inbound audio level, не по socket-hint |
| 1.9 | Reconnect | После обрыва WS старый PC закрыт, новый offer/answer |
| 1.10 | Разрешения | Mic/BT/уведомления до getUserMedia, с экраном отказа |

## 2. Сервер (пик)

- Слушает `0.0.0.0:$PORT` (доступ с телефонов в LAN).
- Модель **комнаты по PIN** (join), max 2 socket-а.
- Heartbeat TTL + инвалидация пары при disconnect.
- Логи relay offer/answer/ICE (from→to socket.id).
- `/health` с активными пользователями.
- `.env`: `PORT`, `HOST`, `MAX_USERS`, `HEARTBEAT_TTL_MS`.
- Docker Compose + скрипт `scripts/start-server.sh`.

## 3. Клиент (пик)

- `ConfigService`: runtime URL + STUN list, SharedPreferences.
- Экран настроек: URL сервера, тест `/health`.
- Экран входа: имя + PIN комнаты (создать/войти одной кнопкой).
- Экран разрешений (если mic denied).
- `CallState` — единый источник UI.
- Native MethodChannel: audio mode, SCO on/off, FGS, wake lock.
- App lifecycle: onResume → ensure socket + call.
- Голосовые команды wired в WebRTC.
- Debug-ring log (последние N строк) в настройках (kDebugMode / toggle).

## 4. Сборка и эксплуатация

- `scripts/build-apk.sh` → debug + release APK.
- `scripts/show-ip.sh` → IP хоста для ввода в приложении.
- `docs/COMMANDS.md` — все команды одной страницей.
- `flutter analyze` без errors; `flutter build apk` успешен.

## 5. Вне скоупа (осознанно)

- Публичный TURN-сервер (опционально позже для LTE↔LTE за симметричным NAT).
- Play Store / подпись production keystore (debug signing достаточно для sideload).
- iOS / CallKit.
- Группы >2 человек.

## 6. Порядок внедрения (этот апгрейд)

1. ТЗ (этот файл)
2. Сервер: комнаты + bind + env
3. Клиент: runtime URL + settings + join UX
4. Native audio Android
5. Permissions / lifecycle
6. Scripts + COMMANDS.md
7. Verify analyze + APK + health
