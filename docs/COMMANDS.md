# MotoTalk — команды

Корень проекта: `/home/night/global/Moto` (или ваш путь к репозиторию).

## 1. Поднять сервер

```bash
cd /home/night/global/Moto
chmod +x scripts/*.sh

# Вариант A — Node напрямую
./scripts/start-server.sh

# Вариант B — Docker
./scripts/start-server.sh docker
# или:
cd server && docker compose up -d --build
```

Проверка:
```bash
curl http://127.0.0.1:3000/health
./scripts/show-ip.sh
```

Остановка:
```bash
# Node: Ctrl+C  или  pkill -f "node src/server.js"
# Docker:
cd server && docker compose down
```

Firewall (если телефоны не видят сервер):
```bash
sudo ufw allow 3000/tcp
# или firewall-cmd --add-port=3000/tcp --permanent && firewall-cmd --reload
```

## 2. Узнать IP для приложения

```bash
./scripts/show-ip.sh
```

В приложении: **Настройки → Адрес сервера** → `http://ВАШ_IP:3000` → Проверить → Сохранить.

## 3. Собрать APK

```bash
./scripts/build-apk.sh debug     # для тестов
./scripts/build-apk.sh release   # для установки «как прод»
./scripts/build-apk.sh both
```

Готовые файлы:
- `app/build/app/outputs/flutter-apk/app-debug.apk`
- `app/build/app/outputs/flutter-apk/app-release.apk`

## 4. Установить на телефоны

```bash
adb devices
adb -s DEVICE1 install -r app/build/app/outputs/flutter-apk/app-debug.apk
adb -s DEVICE2 install -r app/build/app/outputs/flutter-apk/app-debug.apk

# или скопировать APK и установить файловым менеджером (разрешить «неизвестные источники»)
```

## 5. Сценарий двух райдеров

1. ПК и оба Android в одной Wi‑Fi (или телефоны видят IP сервера).
2. Сервер запущен, `/health` = ok.
3. На обоих телефонах в настройках один и тот же `http://IP:3000`.
4. Оба входят с **одним PIN комнаты** (например `1451`) и **разными именами** (Алекс / Борис).
5. Дождаться статуса WebRTC «Готов» / «Аудио OK».
6. Сначала без Bluetooth: удерживать PTT → собеседник **слышит** голос.
7. Повторить в обратную сторону, затем с гарнитурой.

## 6. Полезные команды разработки

```bash
# Анализ Dart
cd app && flutter analyze

# Запуск на подключённом устройстве
cd app && flutter run

# Логи Android
adb logcat | grep -E "WebRTC|ConnectionService|AudioService|MotoTalk"

# Логи сервера (если через docker)
cd server && docker compose logs -f

# Сброс БД комнат (если «комната занята»)
rm -f server/data/mototalk.db
# затем перезапустить сервер
```

## 7. Переменные сервера (`server/.env`)

```
PORT=3000
HOST=0.0.0.0
MAX_USERS=2
HEARTBEAT_TTL_MS=90000
```

## 8. ТЗ пика

См. [IDEAL_SPEC.md](IDEAL_SPEC.md).
