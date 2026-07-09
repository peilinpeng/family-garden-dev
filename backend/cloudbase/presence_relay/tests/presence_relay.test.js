const assert = require('node:assert/strict');
const test = require('node:test');
const WebSocket = require('ws');
const { createPresenceRelay } = require('../server.js');

function onceMessage(ws) {
  return new Promise((resolve) => {
    ws.once('message', (data) => resolve(JSON.parse(data.toString('utf8'))));
  });
}

function openClient(url) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(url);
    ws.once('open', () => resolve(ws));
    ws.once('error', reject);
  });
}

async function makeRelay() {
  const identities = new Map([
    ['token_a', { member_id: 'member_a', family_id: 'family_a', role: 'father', display_name: '爸爸' }],
    ['token_b', { member_id: 'member_b', family_id: 'family_a', role: 'mother', display_name: '妈妈' }],
    ['token_c', { member_id: 'member_c', family_id: 'family_b', role: 'player', display_name: '隔离成员' }],
  ]);
  const relay = createPresenceRelay({
    verifyToken: async (token) => {
      if (!identities.has(token)) throw new Error('unauthorized');
      return identities.get(token);
    },
    heartbeatMs: 100,
    staleMs: 1000,
  });
  await relay.listen(0, '127.0.0.1');
  const port = relay.server.address().port;
  return { relay, url: `ws://127.0.0.1:${port}` };
}

async function hello(ws, token, sceneId = 'farm') {
  ws.send(JSON.stringify({ type: 'hello', token, scene_id: sceneId }));
  return await onceMessage(ws);
}

test('presence relay authenticates hello and returns current peers', async () => {
  const { relay, url } = await makeRelay();
  try {
    const a = await openClient(url);
    const helloA = await hello(a, 'token_a');
    assert.equal(helloA.type, 'hello_ok');
    assert.equal(helloA.self.member_id, 'member_a');
    assert.deepEqual(helloA.peers, []);

    const b = await openClient(url);
    const joinedForA = onceMessage(a);
    const helloB = await hello(b, 'token_b');
    assert.equal(helloB.type, 'hello_ok');
    assert.deepEqual(helloB.peers.map((peer) => peer.member_id), ['member_a']);
    assert.equal((await joinedForA).peer.member_id, 'member_b');
  } finally {
    await relay.close();
  }
});

test('presence relay broadcasts movement only inside the same family', async () => {
  const { relay, url } = await makeRelay();
  try {
    const a = await openClient(url);
    await hello(a, 'token_a');
    const b = await openClient(url);
    const joinedForA = onceMessage(a);
    await hello(b, 'token_b');
    await joinedForA;
    const c = await openClient(url);
    await hello(c, 'token_c');

    const moveForB = onceMessage(b);
    let isolatedSawMove = false;
    c.once('message', () => {
      isolatedSawMove = true;
    });
    a.send(JSON.stringify({
      type: 'move',
      scene_id: 'farm',
      position: { x: 123.456, y: 234.567 },
      direction: 'right',
      animation_state: 'walk',
      timestamp: 1000,
      sequence: 1,
    }));
    const moved = await moveForB;
    assert.equal(moved.type, 'peer_moved');
    assert.equal(moved.peer.member_id, 'member_a');
    assert.deepEqual(moved.peer.position, { x: 123.46, y: 234.57 });
    assert.equal(moved.peer.sequence, 1);

    a.send(JSON.stringify({ type: 'move', position: { x: 999, y: 999 }, sequence: 1 }));
    await new Promise((resolve) => setTimeout(resolve, 50));
    assert.equal(isolatedSawMove, false);
  } finally {
    await relay.close();
  }
});

test('presence relay rejects invalid token and announces leave', async () => {
  const { relay, url } = await makeRelay();
  try {
    const a = await openClient(url);
    await hello(a, 'token_a');
    const bad = await openClient(url);
    bad.send(JSON.stringify({ type: 'hello', token: 'bad', scene_id: 'farm' }));
    const error = await onceMessage(bad);
    assert.equal(error.code, 'UNAUTHORIZED');

    const b = await openClient(url);
    const joinedForA = onceMessage(a);
    await hello(b, 'token_b');
    await joinedForA;
    const leftForA = onceMessage(a);
    b.send(JSON.stringify({ type: 'leave' }));
    const left = await leftForA;
    assert.equal(left.type, 'peer_left');
    assert.equal(left.member_id, 'member_b');
  } finally {
    await relay.close();
  }
});
