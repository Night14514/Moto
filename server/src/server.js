const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const Database = require('better-sqlite3');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  },
  pingTimeout: 60000,
  pingInterval: 25000
});

// Настройка базы данных
const dbPath = path.join(__dirname, '../data/mototalk.db');
const db = new Database(dbPath);

// Инициализация базы данных
db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    pin TEXT UNIQUE NOT NULL,
    username TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );
  
  CREATE TABLE IF NOT EXISTS connections (
    user_id TEXT PRIMARY KEY,
    socket_id TEXT,
    connected_at DATETIME,
    peer_connected BOOLEAN DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
  );
`);

// Хранение активных соединений
const activeUsers = new Map();
const MAX_USERS = 2;

// Генерация уникального ID
function generateId() {
  return Math.random().toString(36).substring(2, 15);
}

// REST API для регистрации пользователя
app.post('/api/register', (req, res) => {
  const { pin, username } = req.body;
  
  if (!pin || pin.length !== 4) {
    return res.status(400).json({ error: 'PIN must be 4 digits' });
  }
  
  if (activeUsers.size >= MAX_USERS) {
    return res.status(400).json({ error: 'Maximum users reached' });
  }
  
  try {
    const userId = generateId();
    const stmt = db.prepare('INSERT INTO users (id, pin, username) VALUES (?, ?, ?)');
    stmt.run(userId, pin, username || 'User');
    
    res.json({ userId, pin, username });
  } catch (err) {
    if (err.code === 'SQLITE_CONSTRAINT') {
      return res.status(400).json({ error: 'PIN already exists' });
    }
    res.status(500).json({ error: 'Database error' });
  }
});

// REST API для входа пользователя
app.post('/api/login', (req, res) => {
  const { pin } = req.body;
  
  const stmt = db.prepare('SELECT * FROM users WHERE pin = ?');
  const user = stmt.get(pin);
  
  if (!user) {
    return res.status(401).json({ error: 'Invalid PIN' });
  }
  
  res.json({ userId: user.id, username: user.username });
});

// REST API для получения информации о собеседнике
app.get('/api/peer/:userId', (req, res) => {
  const { userId } = req.params;
  
  const stmt = db.prepare('SELECT id, username FROM users WHERE id != ?');
  const peer = stmt.get(userId);
  
  if (!peer) {
    return res.status(404).json({ error: 'No peer found' });
  }
  
  // Проверка, онлайн ли собеседник
  const peerOnline = activeUsers.has(peer.id);
  
  res.json({ ...peer, online: peerOnline });
});

// Обработка соединений Socket.io
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);
  
  let currentUserId = null;
  
  // Авторизация пользователя
  socket.on('auth', ({ userId, pin }) => {
    const stmt = db.prepare('SELECT * FROM users WHERE id = ? AND pin = ?');
    const user = stmt.get(userId, pin);
    
    if (!user) {
      socket.emit('auth_error', { error: 'Invalid credentials' });
      return;
    }
    
    if (activeUsers.size >= MAX_USERS && !activeUsers.has(userId)) {
      socket.emit('auth_error', { error: 'Server full' });
      return;
    }
    
    currentUserId = user.id;
    activeUsers.set(userId, socket.id);
    
    // Обновление соединения в базе данных
    const connStmt = db.prepare(`
      INSERT OR REPLACE INTO connections (user_id, socket_id, connected_at, peer_connected)
      VALUES (?, ?, CURRENT_TIMESTAMP, 0)
    `);
    connStmt.run(userId, socket.id);
    
    socket.emit('auth_success', { userId: user.id, username: user.username });
    
    // Уведомление другого пользователя
    for (const [uid, sid] of activeUsers.entries()) {
      if (uid !== userId) {
        io.to(sid).emit('user_joined', { userId: user.id, username: user.username });
        socket.emit('user_online', { userId: uid });
      }
    }
    
    console.log('User authenticated:', user.username, 'ID:', userId);
  });
  
  // Сигнализация WebRTC
  socket.on('offer', ({ targetUserId, offer }) => {
    const targetSocketId = activeUsers.get(targetUserId);
    if (targetSocketId) {
      io.to(targetSocketId).emit('offer', { offer, fromUserId: currentUserId });
    }
  });
  
  socket.on('answer', ({ targetUserId, answer }) => {
    const targetSocketId = activeUsers.get(targetUserId);
    if (targetSocketId) {
      io.to(targetSocketId).emit('answer', { answer, fromUserId: currentUserId });
    }
  });
  
  socket.on('ice-candidate', ({ targetUserId, candidate }) => {
    const targetSocketId = activeUsers.get(targetUserId);
    if (targetSocketId) {
      io.to(targetSocketId).emit('ice-candidate', { candidate, fromUserId: currentUserId });
    }
  });
  
  // Сигнализация PTT
  socket.on('ptt_start', () => {
    for (const [uid, sid] of activeUsers.entries()) {
      if (uid !== currentUserId) {
        io.to(sid).emit('peer_talking', { talking: true });
      }
    }
  });
  
  socket.on('ptt_end', () => {
    for (const [uid, sid] of activeUsers.entries()) {
      if (uid !== currentUserId) {
        io.to(sid).emit('peer_talking', { talking: false });
      }
    }
  });
  
  // Статус соединения
  socket.on('connection_status', ({ status }) => {
    for (const [uid, sid] of activeUsers.entries()) {
      if (uid !== currentUserId) {
        io.to(sid).emit('peer_status', { status, userId: currentUserId });
      }
    }
  });
  
  // Обработка отключения
  socket.on('disconnect', () => {
    if (currentUserId) {
      console.log('User disconnected:', currentUserId);
      activeUsers.delete(currentUserId);
      
      // Уведомление другого пользователя
      for (const [uid, sid] of activeUsers.entries()) {
        io.to(sid).emit('user_left', { userId: currentUserId });
      }
      
      // Обновление базы данных
      const stmt = db.prepare('DELETE FROM connections WHERE user_id = ?');
      stmt.run(currentUserId);
    }
  });
  
  // Обработка ошибок
  socket.on('error', (error) => {
    console.error('Socket error:', error);
  });
});

// Проверка работоспособности
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    users: activeUsers.size,
    maxUsers: MAX_USERS 
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`MotoTalk server running on port ${PORT}`);
  console.log(`Max users: ${MAX_USERS}`);
});

// Корректное завершение
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    db.close();
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close(() => {
    db.close();
    process.exit(0);
  });
});
