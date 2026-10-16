const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');
const hallConfig = require('./hall_config');
const handleDuelRoom = require('./duel_rooms.cjs')();

const PORT = Number(process.env.PORT || 3000);
const ROOT = __dirname;
const WS_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.mp3': 'audio/mpeg',
  '.ico': 'image/x-icon'
};

const COLORS = ['y', 'r', 'b', 'g'];
const WAVE_START_BUFFER_MS = 120;
const SPAWN_SLOTS = hallConfig.slots.map((slot) => slot.id);

const clients = new Map();
let nextClientId = 1;
let nextWaveId = 1;
let currentWave = null;
let waveClearers = new Set();
let waveTimer = null;

function sendJson(socket, payload) {
  const body = Buffer.from(JSON.stringify(payload));
  let header;

  if (body.length < 126) {
    header = Buffer.from([0x81, body.length]);
  } else if (body.length < 65536) {
    header = Buffer.alloc(4);
    header[0] = 0x81;
    header[1] = 126;
    header.writeUInt16BE(body.length, 2);
  } else {
    header = Buffer.alloc(10);
    header[0] = 0x81;
    header[1] = 127;
    header.writeBigUInt64BE(BigInt(body.length), 2);
  }

  socket.write(Buffer.concat([header, body]));
}

function broadcast(payload) {
  for (const client of clients.values()) {
    sendJson(client.socket, payload);
  }
}

function shuffle(items) {
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function randomInt(min, max) {
  return Math.floor(min + Math.random() * (max - min + 1));
}

function makeWave() {
  const targetCount = 2;
  const colors = shuffle(COLORS).slice(0, targetCount);
  const slots = shuffle(SPAWN_SLOTS).slice(0, targetCount);

  return {
    type: 'wave',
    waveId: nextWaveId,
    startAt: Date.now() + WAVE_START_BUFFER_MS,
    targets: colors.map((color, index) => ({
      id: `w${nextWaveId}_${index + 1}`,
      color,
      slotId: slots[index],
      duration: randomInt(1000, 5000)
    }))
  };
}

function scheduleWave(delay = 900) {
  clearTimeout(waveTimer);
  waveTimer = setTimeout(() => {
    if (clients.size === 0) return;
    currentWave = makeWave();
    waveClearers = new Set();
    nextWaveId += 1;
    broadcast(currentWave);
  }, delay);
}

function sendRoster() {
  broadcast({
    type: 'roster',
    players: [...clients.values()].map(({ id, player }) => ({ id, player }))
  });
}

function safeResolve(urlPath) {
  const cleanPath = decodeURIComponent(urlPath.split('?')[0]);
  const normalized = path.normalize(cleanPath === '/' ? '/index.html' : cleanPath);
  const resolved = path.join(ROOT, normalized);

  if (!resolved.startsWith(ROOT)) {
    return null;
  }

  return resolved;
}

const server = http.createServer(async (req, res) => {
  if (await handleDuelRoom(req, res)) return;
  const filePath = safeResolve(req.url || '/');
  if (!filePath) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  fs.stat(filePath, (statError, stat) => {
    if (statError || !stat.isFile()) {
      res.writeHead(404);
      res.end('Not found');
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    res.writeHead(200, {
      'Content-Type': MIME_TYPES[ext] || 'application/octet-stream',
      'Cache-Control': 'no-cache'
    });
    fs.createReadStream(filePath).pipe(res);
  });
});

function parseWebSocketMessages(buffer) {
  const messages = [];
  let offset = 0;

  while (offset + 2 <= buffer.length) {
    const first = buffer[offset];
    const second = buffer[offset + 1];
    const opcode = first & 0x0f;
    const masked = (second & 0x80) !== 0;
    let length = second & 0x7f;
    let cursor = offset + 2;

    if (length === 126) {
      if (cursor + 2 > buffer.length) break;
      length = buffer.readUInt16BE(cursor);
      cursor += 2;
    } else if (length === 127) {
      if (cursor + 8 > buffer.length) break;
      length = Number(buffer.readBigUInt64BE(cursor));
      cursor += 8;
    }

    if (!masked || cursor + 4 + length > buffer.length) break;

    const mask = buffer.subarray(cursor, cursor + 4);
    cursor += 4;
    const payload = buffer.subarray(cursor, cursor + length);
    const decoded = Buffer.alloc(length);

    for (let i = 0; i < length; i += 1) {
      decoded[i] = payload[i] ^ mask[i % 4];
    }

    offset = cursor + length;

    if (opcode === 0x8) {
      messages.push({ type: 'close' });
    } else if (opcode === 0x1) {
      messages.push({ type: 'text', text: decoded.toString('utf8') });
    }
  }

  return messages;
}

server.on('upgrade', (req, socket) => {
  if (req.headers.upgrade?.toLowerCase() !== 'websocket') {
    socket.destroy();
    return;
  }

  const key = req.headers['sec-websocket-key'];
  if (!key) {
    socket.destroy();
    return;
  }

  const acceptKey = crypto
    .createHash('sha1')
    .update(key + WS_GUID)
    .digest('base64');

  socket.write([
    'HTTP/1.1 101 Switching Protocols',
    'Upgrade: websocket',
    'Connection: Upgrade',
    `Sec-WebSocket-Accept: ${acceptKey}`,
    '',
    ''
  ].join('\r\n'));

  const id = nextClientId;
  nextClientId += 1;
  const player = clients.size + 1;
  clients.set(id, { id, player, socket });

  sendJson(socket, { type: 'hello', id, player });
  if (currentWave) {
    sendJson(socket, currentWave);
  } else {
    scheduleWave(WAVE_START_BUFFER_MS);
  }
  sendRoster();

  socket.on('data', (buffer) => {
    for (const message of parseWebSocketMessages(buffer)) {
      if (message.type === 'close') {
        socket.end();
        continue;
      }

      try {
        const payload = JSON.parse(message.text);
        if (payload.type === 'waveCleared') {
          if (payload.waveId === currentWave?.waveId) {
            waveClearers.add(id);
            if (waveClearers.size >= clients.size) {
              scheduleWave(randomInt(2000, 3000));
            }
          }
        } else if (payload.type === 'judgement') {
          broadcast({ ...payload, type: 'peerJudgement', from: id });
        }
      } catch {
        // Ignore malformed prototype messages.
      }
    }
  });

  socket.on('close', () => {
    clients.delete(id);
    waveClearers.delete(id);
    if (clients.size > 0 && currentWave && waveClearers.size >= clients.size) {
      scheduleWave(700);
    }
    sendRoster();
  });

  socket.on('error', () => {
    clients.delete(id);
    waveClearers.delete(id);
    if (clients.size > 0 && currentWave && waveClearers.size >= clients.size) {
      scheduleWave(700);
    }
    sendRoster();
  });
});

function getLocalAddresses() {
  const addresses = [];
  for (const net of Object.values(os.networkInterfaces())) {
    for (const item of net || []) {
      if (item.family === 'IPv4' && !item.internal) {
        addresses.push(item.address);
      }
    }
  }
  return addresses;
}

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Timing Shooter server running on http://localhost:${PORT}`);
  for (const address of getLocalAddresses()) {
    console.log(`Phone URL: http://${address}:${PORT}`);
  }
});
