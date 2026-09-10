/**
 * MotoTalk signaling server — room-PIN pairing (max 2), WebRTC relay.
 * Binds 0.0.0.0 so phones on LAN can connect.
 */
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

function loadEnv() {
  const envPath = path.join(__dirname, '../.env');
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, 'utf8').split('\n')) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const i = t.indexOf('=');
    if (i < 0) continue;
    const key = t.slice(0, i).trim();
    const val = t.slice(i + 1).trim();
    if (!(key in process.env)) process.env[key] = val;
  }
}
loadEnv();

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';
const MAX_USERS = Number(process.env.MAX_USERS || 2);
const HEARTBEAT_TTL_MS = Number(process.env.HEARTBEAT_TTL_MS || 90_000);
const HEARTBEAT_CHECK_MS = Number(process.env.HEARTBEAT_CHECK_MS || 15_000);

const log = (level, message, data = null) => {
  const timestamp = new Date().toISOString();
  const entry = `[${timestamp}] [${level.toUpperCase()}] ${message}`;
  if (data) console.log(entry, JSON.stringify(data));
  else console.log(entry);
};

const dataDir = path.join(__dirname, '../data');
fs.mkdirSync(dataDir, { recursive: true });
const db = new Database(path.join(dataDir, 'mototalk.db'));

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    pin TEXT NOT NULL,
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

// Migrate legacy schema where pin was UNIQUE (one user per PIN).
(function migratePinUnique() {
  try {
    const row = db
      .prepare(`SELECT sql FROM sqlite_master WHERE type='table' AND name='users'`)
      .get();
    if (row && /pin\s+TEXT\s+UNIQUE/i.test(row.sql)) {
      log('info', 'Migrating users table: drop UNIQUE on pin for shared rooms');
      db.exec(`
        BEGIN;
        CREATE TABLE users_new (
          id TEXT PRIMARY KEY,
          pin TEXT NOT NULL,
          username TEXT,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        INSERT INTO users_new (id, pin, username, created_at)
          SELECT id, pin, username, created_at FROM users;
        DROP TABLE users;
        ALTER TABLE users_new RENAME TO users;
        COMMIT;
      `);
    }
    db.exec(`CREATE INDEX IF NOT EXISTS idx_users_pin ON users(pin)`);
    db.exec(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_users_pin_username
      ON users(pin, username)
    `);
  } catch (e) {
    log('error', 'Schema migration failed', { error: String(e) });
  }
})();

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = socketIo(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
  pingTimeout: 60000,
  pingInterval: 25000,
});

/** @type {Map<string, { socketId: string, lastSeen: number, username: string, pin: string }>} */
const activeUsers = new Map();

function generateId() {
  return Math.random().toString(36).substring(2, 15);
}

function usersInRoom(pin) {
  return [...activeUsers.entries()].filter(([, info]) => info.pin === pin);
}

function touchUser(userId) {
  const entry = activeUsers.get(userId);
  if (entry) entry.lastSeen = Date.now();
}

function removeUser(userId, reason) {
  const entry = activeUsers.get(userId);
  if (!entry) return;
  activeUsers.delete(userId);
  log('info', 'User removed', { userId, reason, socketId: entry.socketId, pin: entry.pin });

  for (const [uid, info] of activeUsers.entries()) {
    if (info.pin === entry.pin) {
      io.to(info.socketId).emit('user_left', { userId });
      log('debug', 'Notified peer of leave', { to: uid, left: userId });
    }
  }

  db.prepare('DELETE FROM connections WHERE user_id = ?').run(userId);
}

/**
 * Join (or create) a room by shared PIN.
 * Same PIN = same pair. Max 2 online in room.
 */
function handleJoin(req, res) {
  const { pin, username } = req.body || {};

  if (!pin || String(pin).length !== 4 || !/^\d{4}$/.test(String(pin))) {
    return res.status(400).json({ error: 'PIN must be 4 digits' });
  }
  if (!username || String(username).trim().length < 1) {
    return res.status(400).json({ error: 'Username required' });
  }

  const name = String(username).trim().slice(0, 32);
  const roomPin = String(pin);
  const onlineInRoom = usersInRoom(roomPin);

  const existing = db
    .prepare('SELECT * FROM users WHERE pin = ? AND username = ?')
    .get(roomPin, name);

  if (existing) {
    if (activeUsers.has(existing.id)) {
      return res.status(409).json({ error: 'This name is already online in the room' });
    }
    if (onlineInRoom.length >= MAX_USERS) {
      return res.status(400).json({ error: 'Room is full (max 2)' });
    }
    return res.json({
      userId: existing.id,
      pin: roomPin,
      username: existing.username,
      roomOnline: onlineInRoom.length,
    });
  }

  if (onlineInRoom.length >= MAX_USERS) {
    return res.status(400).json({ error: 'Room is full (max 2)' });
  }

  const registered = db.prepare('SELECT COUNT(*) AS c FROM users WHERE pin = ?').get(roomPin).c;
  if (registered >= MAX_USERS) {
    return res.status(400).json({
      error: 'Room already has 2 registered riders — use an existing name to rejoin',
    });
  }

  try {
    const userId = generateId();
    db.prepare('INSERT INTO users (id, pin, username) VALUES (?, ?, ?)').run(
      userId,
      roomPin,
      name,
    );
    log('info', 'User joined room', { userId, pin: roomPin, username: name });
    res.json({
      userId,
      pin: roomPin,
      username: name,
      roomOnline: onlineInRoom.length,
    });
  } catch (err) {
    log('error', 'Join failed', { error: String(err) });
    res.status(500).json({ error: 'Database error' });
  }
}

app.post('/api/join', handleJoin);
app.post('/api/register', handleJoin);

app.post('/api/login', (req, res) => {
  const { pin, username } = req.body || {};
  if (!pin || !username) {
    return res.status(400).json({ error: 'pin and username required' });
  }
  const user = db
    .prepare('SELECT * FROM users WHERE pin = ? AND username = ?')
    .get(String(pin), String(username).trim());
  if (!user) {
    return res.status(401).json({ error: 'Invalid credentials — join room first' });
  }
  res.json({ userId: user.id, username: user.username, pin: user.pin });
});

app.get('/api/peer/:userId', (req, res) => {
  const me = activeUsers.get(req.params.userId);
  if (!me) {
    const row = db.prepare('SELECT pin FROM users WHERE id = ?').get(req.params.userId);
    if (!row) return res.status(404).json({ error: 'No peer found' });
    const peer = db
      .prepare('SELECT id, username FROM users WHERE pin = ? AND id != ?')
      .get(row.pin, req.params.userId);
    if (!peer) return res.status(404).json({ error: 'No peer found' });
    return res.json({ ...peer, online: activeUsers.has(peer.id) });
  }
  const peerEntry = [...activeUsers.entries()].find(
    ([uid, info]) => uid !== req.params.userId && info.pin === me.pin,
  );
  if (!peerEntry) return res.status(404).json({ error: 'No peer online' });
  res.json({
    id: peerEntry[0],
    username: peerEntry[1].username,
    online: true,
  });
});

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    users: activeUsers.size,
    maxUsers: MAX_USERS,
    host: HOST,
    port: PORT,
    active: [...activeUsers.entries()].map(([id, info]) => ({
      userId: id,
      username: info.username,
      pin: info.pin,
      socketId: info.socketId,
      lastSeenAgeMs: Date.now() - info.lastSeen,
    })),
  });
});

io.on('connection', (socket) => {
  log('info', 'Client connected', { socketId: socket.id });
  let currentUserId = null;

  socket.on('auth', ({ userId, pin }) => {
    const user = db.prepare('SELECT * FROM users WHERE id = ? AND pin = ?').get(userId, pin);
    if (!user) {
      socket.emit('auth_error', { error: 'Invalid credentials' });
      return;
    }

    const roomOnline = usersInRoom(user.pin).filter(([uid]) => uid !== userId);
    if (roomOnline.length >= MAX_USERS - 1 && !activeUsers.has(userId)) {
      // room already has the other seat filled by someone else + ourselves would be 3rd? 
      // MAX_USERS=2 means at most 1 other online.
    }
    const othersOnline = usersInRoom(user.pin).filter(([uid]) => uid !== userId);
    if (othersOnline.length >= MAX_USERS - 1 + (activeUsers.has(userId) ? 1 : 0)) {
      // allow self replace
    }
    if (!activeUsers.has(userId) && usersInRoom(user.pin).length >= MAX_USERS) {
      socket.emit('auth_error', { error: 'Room full' });
      return;
    }

    const previous = activeUsers.get(userId);
    if (previous && previous.socketId !== socket.id) {
      log('info', 'Replacing stale socket', {
        userId,
        oldSocket: previous.socketId,
        newSocket: socket.id,
      });
    }

    currentUserId = user.id;
    activeUsers.set(userId, {
      socketId: socket.id,
      lastSeen: Date.now(),
      username: user.username,
      pin: user.pin,
    });

    db.prepare(`
      INSERT OR REPLACE INTO connections (user_id, socket_id, connected_at, peer_connected)
      VALUES (?, ?, CURRENT_TIMESTAMP, 0)
    `).run(userId, socket.id);

    socket.emit('auth_success', {
      userId: user.id,
      username: user.username,
      pin: user.pin,
    });

    for (const [uid, info] of activeUsers.entries()) {
      if (uid !== userId && info.pin === user.pin) {
        io.to(info.socketId).emit('user_joined', {
          userId: user.id,
          username: user.username,
        });
        socket.emit('user_online', { userId: uid, username: info.username });
      }
    }

    log('info', 'User authenticated', {
      username: user.username,
      userId,
      pin: user.pin,
      socketId: socket.id,
      roomSize: usersInRoom(user.pin).length,
    });
  });

  socket.on('heartbeat', () => {
    if (currentUserId) touchUser(currentUserId);
  });

  const relay = (event, payloadKey) => {
    socket.on(event, (body) => {
      touchUser(currentUserId);
      const targetUserId = body?.targetUserId;
      const target = activeUsers.get(targetUserId);
      if (!target) {
        log('warn', `Target not found for ${event}`, {
          targetUserId,
          from: currentUserId,
        });
        return;
      }
      const me = activeUsers.get(currentUserId);
      if (me && target.pin !== me.pin) {
        log('warn', `Cross-room ${event} blocked`, { from: currentUserId, to: targetUserId });
        return;
      }
      log(event === 'ice-candidate' ? 'debug' : 'info', `Relay ${event}`, {
        from: currentUserId,
        fromSocket: socket.id,
        to: targetUserId,
        toSocket: target.socketId,
      });
      io.to(target.socketId).emit(event, {
        [payloadKey]: body[payloadKey],
        fromUserId: currentUserId,
      });
    });
  };

  relay('offer', 'offer');
  relay('answer', 'answer');
  relay('ice-candidate', 'candidate');

  socket.on('ptt_start', () => {
    touchUser(currentUserId);
    const me = activeUsers.get(currentUserId);
    if (!me) return;
    for (const [uid, info] of activeUsers.entries()) {
      if (uid !== currentUserId && info.pin === me.pin) {
        io.to(info.socketId).emit('peer_talking', { talking: true });
      }
    }
  });

  socket.on('ptt_end', () => {
    touchUser(currentUserId);
    const me = activeUsers.get(currentUserId);
    if (!me) return;
    for (const [uid, info] of activeUsers.entries()) {
      if (uid !== currentUserId && info.pin === me.pin) {
        io.to(info.socketId).emit('peer_talking', { talking: false });
      }
    }
  });

  socket.on('connection_status', ({ status }) => {
    touchUser(currentUserId);
    const me = activeUsers.get(currentUserId);
    if (!me) return;
    for (const [uid, info] of activeUsers.entries()) {
      if (uid !== currentUserId && info.pin === me.pin) {
        io.to(info.socketId).emit('peer_status', { status, userId: currentUserId });
      }
    }
  });

  socket.on('disconnect', () => {
    if (currentUserId) {
      log('info', 'Socket disconnect', { userId: currentUserId, socketId: socket.id });
      const entry = activeUsers.get(currentUserId);
      if (entry && entry.socketId === socket.id) {
        removeUser(currentUserId, 'disconnect');
      }
      currentUserId = null;
    }
  });

  socket.on('error', (error) => {
    log('error', 'Socket error', { error: String(error), socketId: socket.id });
  });
});

setInterval(() => {
  const now = Date.now();
  for (const [userId, info] of [...activeUsers.entries()]) {
    if (now - info.lastSeen > HEARTBEAT_TTL_MS) {
      log('warn', 'Heartbeat TTL expired', {
        userId,
        lastSeenAgeMs: now - info.lastSeen,
      });
      const sock = io.sockets.sockets.get(info.socketId);
      if (sock) sock.disconnect(true);
      removeUser(userId, 'heartbeat-ttl');
    }
  }
}, HEARTBEAT_CHECK_MS);

server.listen(PORT, HOST, () => {
  log('info', `MotoTalk server listening on http://${HOST}:${PORT}`);
  log('info', `Max users per room: ${MAX_USERS}`);
});

const shutdown = (sig) => {
  log('info', `${sig} received, shutting down`);
  server.close(() => {
    db.close();
    process.exit(0);
  });
};
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
