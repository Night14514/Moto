# Быстрый старт

## Предварительные требования

### Сервер
- Docker / Docker Compose **или** Node.js 18+
- Порт 3000 доступен

### Мобильное устройство
- Flutter SDK 3.19+
- Android Studio
- Два физических Android-устройства (для проверки звука)

## Шаг 1: Запуск сервера

```bash
cd server
cp .env.example .env   # если есть
docker-compose up -d
# или: cd server && npm install && node src/server.js
```

Получите IP ПК: `ip addr show`

## Шаг 2: Конфиг клиента

В `app/lib/config.dart`:
```dart
static const String serverUrl = 'http://YOUR_PC_IP:3000';
```

## Шаг 3: Сборка

```bash
cd app
flutter pub get
flutter devices
flutter run
```

## Шаг 4: Регистрация

1. Телефон A: имя + PIN → создать аккаунт
2. Телефон B: другое имя + другой PIN
3. Оба должны увидеть «Онлайн» и статус WebRTC «Аудио OK» / «Готов»

## Шаг 5: Проверка звука

1. **Без Bluetooth** — встроенный микрофон/динамик
2. A удерживает PTT и говорит
3. На B должен быть **слышен** голос (не только индикатор)
4. Повторить B → A
5. Затем проверить с Bluetooth-гарнитурой

## Голосовое управление

1. Режим «Голос» → «Нажми» → слушание
2. «Приём» / «Пуск» — передача
3. «Стоп» / «Отбой» — стоп

## Устранение неполадок

- Сервер: `curl http://PC_IP:3000/health`, firewall `ufw allow 3000`
- Нет звука при живом индикаторе: смотрите логи `WebRTC:` / `ConnectionService: received offer`
- Подробнее: [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
