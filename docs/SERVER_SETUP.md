# Руководство по настройке сервера

## Требования

- Kali Linux (или любой Linux с Docker)
- Установлен Docker
- Установлен Docker Compose
- Порт 3000 доступен (настраивается)

## Установка

### 1. Клонирование репозитория
```bash
cd /path/to/project
```

### 2. Настройка окружения
```bash
cd server
cp .env.example .env
```

Отредактируйте `.env` при необходимости:
```env
PORT=3000
NODE_ENV=production
```

### 3. Запуск сервера
```bash
docker-compose up -d
```

### 4. Проверка статуса
```bash
docker-compose ps
docker-compose logs -f
```

## Сервисы Docker Compose

### Сервер
- Приложение Node.js
- Порт: 3000
- Автоматический перезапуск при ошибке
- Монтирование тома для сохранения базы данных

### База данных
- SQLite (встроенная, без отдельного контейнера)
- Файл: `data/mototalk.db`

## Ручной запуск (без Docker)

```bash
cd server
npm install
npm start
```

## Настройка брандмауэра

Если используется брандмауэр, разрешите порт 3000:
```bash
ufw allow 3000
# или
iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
```

## Автозапуск при загрузке

### Сервис Systemd
Создайте `/etc/systemd/system/mototalk.service`:
```ini
[Unit]
Description=MotoTalk Server
After=network.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/night/blprj/server
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

Включите сервис:
```bash
sudo systemctl enable mototalk
sudo systemctl start mototalk
```

## Пробуждение из сна

Сервер автоматически перезапускается при пробуждении ПК из-за политики автозапуска Docker.

## Мониторинг

### Просмотр логов
```bash
docker-compose logs -f server
```

### Проверка соединений
Логи сервера показывают:
- Соединения пользователей
- Сигнализацию WebRTC
- Ошибки соединения

### Инспекция базы данных
```bash
sqlite3 data/mototalk.db
.tables
SELECT * FROM users;
```

## Устранение неполадок

### Порт уже занят
Измените порт в `.env` и `docker-compose.yml`

### Docker не запущен
```bash
sudo systemctl start docker
```

### Отказано в доступе
```bash
sudo usermod -aG docker $USER
# Выйдите и войдите снова
```

### Высокое использование CPU
Нормально во время рукопожатия WebRTC. Должно быстро стабилизироваться.

## Резервное копирование

Расположение файла базы данных: `server/data/mototalk.db`

Резервное копирование:
```bash
cp server/data/mototalk.db server/data/mototalk.db.backup
```

## Обновление

```bash
cd server
git pull
docker-compose down
docker-compose build
docker-compose up -d
```
