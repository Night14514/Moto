# Руководство по развертыванию MotoTalk

## Развертывание сервера на Kali Linux

### Предварительные требования
- Kali Linux с доступом к интернету
- Docker и Docker Compose установлены
- IP-адрес сервера в локальной сети

### Установка Docker (если не установлен)
```bash
sudo apt update
sudo apt install -y docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

### Развертывание сервера
```bash
# Клонирование репозитория
cd /opt
git clone <repository-url> mototalk
cd mototalk/server

# Настройка окружения
cp .env.example .env
nano .env
```

Отредактируйте `.env`:
```env
PORT=3000
NODE_ENV=production
```

### Запуск сервера
```bash
# Сборка и запуск
docker-compose up -d

# Проверка статуса
docker-compose ps
docker-compose logs -f

# Проверка health check
curl http://localhost:3000/health
```

### Настройка брандмауэра
```bash
# Разрешить порт 3000
sudo ufw allow 3000/tcp
sudo ufw reload

# Проверка статуса
sudo ufw status
```

### Автозапуск при загрузке
```bash
# Docker Compose уже настроен на автозапуск (restart: unless-stopped)
# Проверка при перезагрузке
sudo reboot
# После перезагрузки проверить:
docker-compose ps
```

### Мониторинг
```bash
# Просмотр логов
docker-compose logs -f server

# Просмотр логов в файле
tail -f logs/*.log

# Проверка health check
docker inspect mototalk-server | grep -A 10 Health
```

### Обновление сервера
```bash
cd /opt/mototalk/server
git pull
docker-compose down
docker-compose build
docker-compose up -d
```

## Установка на Android

### Предварительные требования
- Android 11 или выше
- Flutter SDK
- Android Studio или Android SDK

### Сборка APK
```bash
cd /opt/mototalk/app

# Установка зависимостей
flutter pub get

# Сборка APK для релиза
flutter build apk --release

# APK будет в: build/app/outputs/flutter-apk/app-release.apk
```

### Установка на устройство
```bash
# Через ADB
adb install build/app/outputs/flutter-apk/app-release.apk

# Или передать APK на устройство и установить вручную
```

### Настройка приложения
1. Запустите MotoTalk
2. Введите IP-адрес сервера в настройках (app/lib/config.dart)
3. Зарегистрируйтесь с 4-значным PIN-кодом
4. Предоставьте разрешения (микрофон, Bluetooth, уведомления)

### Разрешения Android
Приложение запрашивает следующие разрешения:
- **Микрофон** - для голосовой связи
- **Bluetooth** - для подключения гарнитуры
- **Уведомления** - для foreground service
- **Интернет** - для соединения с сервером

### Отладка
```bash
# Просмотр логов
adb logcat | grep mototalk

# Проверка foreground service
adb shell dumpsys activity services | grep mototalk
```

## Установка на iOS

### Предварительные требования
- macOS с Xcode 14+
- iOS 16 или выше
- Apple Developer Account (для реального устройства)
- CocoaPods

### Сборка IPA
```bash
cd /opt/mototalk/app

# Установка зависимостей
flutter pub get
cd ios
pod install
cd ..

# Сборка для iOS
flutter build ios --release
```

### Настройка в Xcode
1. Откройте `ios/Runner.xcworkspace` в Xcode
2. Выберите свой Team в Signing & Capabilities
3. Настройте Bundle Identifier
4. Соберите и запустите на устройстве

### Установка через TestFlight (опционально)
1. Загрузите в App Store Connect
2. Создайте группу внутреннего тестирования
3. Пригласите тестировщиков

### Разрешения iOS
Приложение использует следующие разрешения:
- **Микрофон** - для голосовой связи
- **Bluetooth** - для подключения гарнитуры
- **Фоновый режим** - audio, voip, fetch, remote-notification

### Отладка
```bash
# Просмотр логов через Xcode
# Window > Devices and Simulators > Выберите устройство > View Device Logs
```

## Настройка TURN сервера (опционально)

Для улучшения NAT traversal можно развернуть TURN сервер:

### Установка coturn
```bash
sudo apt install -y coturn
```

### Конфигурация
```bash
sudo nano /etc/turnserver.conf
```

Добавьте:
```
listening-port=3478
fingerprint
lt-cred-mech
user=mototalk:mototalk123
realm=mototalk.local
```

### Запуск
```bash
sudo systemctl start coturn
sudo systemctl enable coturn
```

### Обновление конфигурации приложения
В `app/lib/config.dart` обновите TURN сервер:
```dart
{
  'urls': 'turn://<server-ip>:3478',
  'username': 'mototalk',
  'credential': 'mototalk123',
}
```

## Проверка соединения

### Тестирование сервера
```bash
# Health check
curl http://<server-ip>:3000/health

# Ожидаемый ответ:
# {"status":"ok","users":0,"maxUsers":2}
```

### Тестирование WebRTC
1. Установите приложение на два устройства
2. Зарегистрируйте двух пользователей с разными PIN
3. Подключите Bluetooth-гарнитуры
4. Нажмите PTT кнопку и проверьте аудио
5. Протестируйте голосовые команды ("Приём", "Пуск", "Стоп", "Отбой")

## Устранение неполадок

### Сервер не запускается
```bash
# Проверка логов
docker-compose logs server

# Проверка порта
sudo lsof -i :3000

# Перезапуск
docker-compose restart
```

### Приложение не подключается
- Проверьте IP-адрес сервера в config.dart
- Убедитесь, что устройство и сервер в одной сети
- Проверьте брандмауэр на сервере
- Проверьте health check сервера

### Аудио не работает
- Проверьте разрешения микрофона
- Убедитесь, что Bluetooth-гарнитура подключена
- Проверьте аудио-фокус
- Протестируйте с встроенным динамиком

### Голосовые команды не работают
- Убедитесь, что выбран русский язык
- Проверьте разрешения микрофона
- Протестируйте в тихой обстановке
- Проверьте доступность распознавания речи

## Резервное копирование

### Резервное копирование базы данных
```bash
# Остановка сервера
docker-compose stop

# Копирование базы данных
cp data/mototalk.db data/mototalk.db.backup

# Запуск сервера
docker-compose start
```

### Восстановление
```bash
# Остановка сервера
docker-compose stop

# Восстановление базы данных
cp data/mototalk.db.backup data/mototalk.db

# Запуск сервера
docker-compose start
```

## Мониторинг в продакшене

### Логи
```bash
# Просмотр логов в реальном времени
docker-compose logs -f server

# Логи в файле
tail -f /opt/mototalk/server/logs/*.log
```

### Метрики
```bash
# Health check
curl http://localhost:3000/health

# Статус Docker
docker stats mototalk-server
```

### Оповещения
Настройте мониторинг (например, Prometheus + Grafana) для оповещений о:
- Недоступности сервера
- Высоком использовании CPU
- Ошибках в логах
