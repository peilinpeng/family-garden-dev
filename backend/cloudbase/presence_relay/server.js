const http = require('node:http');
const { WebSocketServer } = require('ws');

const DEFAULT_PORT = Number(process.env.PORT || 8080);
const HEARTBEAT_MS = Number(process.env.PRESENCE_HEARTBEAT_MS || 15000);
const STALE_MS = Number(process.env.PRESENCE_STALE_MS || 45000);
const MAX_PAYLOAD_BYTES = 4096;
const VALID_TYPES = new Set(['hello', 'move', 'leave', 'ping']);

function json(data) {
  return JSON.stringify(data);
}

function safeString(value, max = 80) {
  return String(value || '').trim().slice(0, max);
}

function asFiniteNumber(value, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function sanitizePosition(value) {
  const p = value && typeof value === 'object' ? value : {};
  return {
    x: Math.round(asFiniteNumber(p.x) * 100) / 100,
    y: Math.round(asFiniteNumber(p.y) * 100) / 100,
  };
}

function sanitizePresenceMessage(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const type = safeString(raw.type, 24);
  if (!VALID_TYPES.has(type)) return null;
  if (type === 'hello') {
    return {
      type,
      token: safeString(raw.token, 256),
      scene_id: safeString(raw.scene_id, 40),
    };
  }
  if (type === 'move') {
    return {
      type,
      scene_id: safeString(raw.scene_id, 40),
      position: sanitizePosition(raw.position),
      direction: safeString(raw.direction, 16),
      animation_state: safeString(raw.animation_state, 24),
      timestamp: asFiniteNumber(raw.timestamp, Date.now()),
      sequence: Math.max(0, Math.floor(asFiniteNumber(raw.sequence, 0))),
    };
  }
  return { type };
}

async function verifyWithDataGateway(token, dataGatewayUrl = process.env.DATA_GATEWAY_URL) {
  if (!dataGatewayUrl) throw new Error('DATA_GATEWAY_URL is required');
  const response = await fetch(dataGatewayUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: json({ action: 'whoami' }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok || !data.ok) {
    const err = new Error('unauthorized');
    err.code = 401;
    throw err;
  }
  return {
    member_id: safeString(data.member_id, 80),
    family_id: safeString(data.family_id, 80),
    role: safeString(data.role, 40),
    display_name: safeString(data.display_name, 80),
  };
}

function createPresenceRelay(options = {}) {
  const verifyToken = options.verifyToken || verifyWithDataGateway;
  const heartbeatMs = Number(options.heartbeatMs || HEARTBEAT_MS);
  const staleMs = Number(options.staleMs || STALE_MS);
  const server = options.server || http.createServer((req, res) => {
    if (req.url === '/healthz') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(json({ ok: true }));
      return;
    }
    res.writeHead(404);
    res.end();
  });
  const wss = new WebSocketServer({
    server,
    maxPayload: MAX_PAYLOAD_BYTES,
  });
  const clients = new Map();

  function peersFor(client) {
    return [...clients.values()]
      .filter((peer) => peer.ws !== client.ws && peer.family_id === client.family_id)
      .map(publicPeer);
  }

  function publicPeer(client) {
    return {
      member_id: client.member_id,
      family_id: client.family_id,
      role: client.role,
      display_name: client.display_name,
      scene_id: client.scene_id,
      position: client.position,
      direction: client.direction,
      animation_state: client.animation_state,
      timestamp: client.timestamp,
      sequence: client.sequence,
    };
  }

  function send(ws, payload) {
    if (ws.readyState === ws.OPEN) ws.send(json(payload));
  }

  function broadcast(client, payload) {
    for (const peer of clients.values()) {
      if (peer.ws !== client.ws && peer.family_id === client.family_id && peer.ws.readyState === peer.ws.OPEN) {
        send(peer.ws, payload);
      }
    }
  }

  function removeClient(ws, reason = 'left') {
    const client = clients.get(ws);
    if (!client) return;
    clients.delete(ws);
    broadcast(client, { type: 'peer_left', member_id: client.member_id, reason });
  }

  async function handleHello(ws, msg) {
    if (!msg.token) {
      send(ws, { type: 'error', code: 'UNAUTHORIZED', message: 'missing token' });
      ws.close(1008, 'unauthorized');
      return;
    }
    let identity;
    try {
      identity = await verifyToken(msg.token);
    } catch (err) {
      send(ws, { type: 'error', code: 'UNAUTHORIZED', message: 'invalid token' });
      ws.close(1008, 'unauthorized');
      return;
    }
    const client = {
      ws,
      member_id: safeString(identity.member_id, 80),
      family_id: safeString(identity.family_id, 80),
      role: safeString(identity.role, 40),
      display_name: safeString(identity.display_name, 80),
      scene_id: msg.scene_id || 'farm',
      position: { x: 0, y: 0 },
      direction: 'down',
      animation_state: 'idle',
      timestamp: Date.now(),
      sequence: 0,
      last_seen: Date.now(),
    };
    clients.set(ws, client);
    send(ws, { type: 'hello_ok', self: publicPeer(client), peers: peersFor(client), server_time: Date.now() });
    broadcast(client, { type: 'peer_joined', peer: publicPeer(client) });
  }

  function handleMove(ws, msg) {
    const client = clients.get(ws);
    if (!client) {
      send(ws, { type: 'error', code: 'HELLO_REQUIRED', message: 'send hello first' });
      return;
    }
    if (msg.sequence <= client.sequence) return;
    client.scene_id = msg.scene_id || client.scene_id;
    client.position = msg.position;
    client.direction = msg.direction || client.direction;
    client.animation_state = msg.animation_state || client.animation_state;
    client.timestamp = msg.timestamp || Date.now();
    client.sequence = msg.sequence;
    client.last_seen = Date.now();
    broadcast(client, { type: 'peer_moved', peer: publicPeer(client) });
  }

  wss.on('connection', (ws) => {
    ws.on('message', async (buffer) => {
      let raw;
      try {
        raw = JSON.parse(buffer.toString('utf8'));
      } catch (err) {
        send(ws, { type: 'error', code: 'BAD_JSON', message: 'invalid json' });
        return;
      }
      const msg = sanitizePresenceMessage(raw);
      if (!msg) {
        send(ws, { type: 'error', code: 'BAD_MESSAGE', message: 'unsupported message' });
        return;
      }
      if (msg.type === 'hello') {
        await handleHello(ws, msg);
      } else if (msg.type === 'move') {
        handleMove(ws, msg);
      } else if (msg.type === 'ping') {
        const client = clients.get(ws);
        if (client) client.last_seen = Date.now();
        send(ws, { type: 'pong', server_time: Date.now() });
      } else if (msg.type === 'leave') {
        removeClient(ws, 'leave');
        ws.close(1000, 'leave');
      }
    });
    ws.on('close', () => removeClient(ws, 'close'));
    ws.on('error', () => removeClient(ws, 'error'));
  });

  const staleTimer = setInterval(() => {
    const now = Date.now();
    for (const client of clients.values()) {
      if (now - client.last_seen > staleMs) {
        send(client.ws, { type: 'error', code: 'STALE', message: 'presence timed out' });
        client.ws.close(1001, 'stale');
        removeClient(client.ws, 'stale');
      }
    }
  }, heartbeatMs);
  staleTimer.unref();

  return {
    server,
    wss,
    clients,
    listen(port = DEFAULT_PORT, host = '0.0.0.0') {
      return new Promise((resolve) => {
        server.listen(port, host, () => resolve(server));
      });
    },
    close() {
      clearInterval(staleTimer);
      for (const client of clients.values()) client.ws.close();
      return new Promise((resolve) => {
        wss.close(() => server.close(() => resolve()));
      });
    },
  };
}

if (require.main === module) {
  const relay = createPresenceRelay();
  relay.listen().then(() => {
    console.log(`Family Garden presence relay listening on ${DEFAULT_PORT}`);
  });
}

module.exports = {
  createPresenceRelay,
  sanitizePresenceMessage,
  verifyWithDataGateway,
};
