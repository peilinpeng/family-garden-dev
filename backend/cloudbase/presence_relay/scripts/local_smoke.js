#!/usr/bin/env node

const assert = require('node:assert/strict');
const WebSocket = require('ws');
const { createPresenceRelay } = require('../server.js');

const identities = new Map([
  ['token_a', { member_id: 'member_a', family_id: 'family_smoke', role: 'father', display_name: '爸爸' }],
  ['token_b', { member_id: 'member_b', family_id: 'family_smoke', role: 'mother', display_name: '妈妈' }],
  ['token_c', { member_id: 'member_c', family_id: 'family_other', role: 'player', display_name: '隔离成员' }],
]);

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

async function hello(ws, token) {
  ws.send(JSON.stringify({ type: 'hello', token, scene_id: 'farm' }));
  const message = await onceMessage(ws);
  assert.equal(message.type, 'hello_ok');
  return message;
}

async function main() {
  const relay = createPresenceRelay({
    verifyToken: async (token) => {
      if (!identities.has(token)) throw new Error('unauthorized');
      return identities.get(token);
    },
    heartbeatMs: 100,
    staleMs: 2000,
  });
  await relay.listen(0, '127.0.0.1');
  const url = `ws://127.0.0.1:${relay.server.address().port}`;
  console.log(`Presence local smoke relay: ${url}`);

  try {
    const a = await openClient(url);
    const helloA = await hello(a, 'token_a');
    assert.deepEqual(helloA.peers, []);
    console.log('OK  member A joined');

    const b = await openClient(url);
    const joinedForA = onceMessage(a);
    const helloB = await hello(b, 'token_b');
    assert.deepEqual(helloB.peers.map((peer) => peer.member_id), ['member_a']);
    assert.equal((await joinedForA).peer.member_id, 'member_b');
    console.log('OK  member B joined and A saw it');

    const c = await openClient(url);
    await hello(c, 'token_c');
    console.log('OK  isolated member joined');

    let isolatedSawMove = false;
    c.once('message', () => {
      isolatedSawMove = true;
    });
    const moveForB = onceMessage(b);
    a.send(JSON.stringify({
      type: 'move',
      scene_id: 'farm',
      position: { x: 520, y: 360 },
      direction: 'right',
      animation_state: 'walk',
      timestamp: Date.now(),
      sequence: 1,
    }));
    const moved = await moveForB;
    assert.equal(moved.type, 'peer_moved');
    assert.equal(moved.peer.member_id, 'member_a');
    assert.deepEqual(moved.peer.position, { x: 520, y: 360 });
    await new Promise((resolve) => setTimeout(resolve, 60));
    assert.equal(isolatedSawMove, false);
    console.log('OK  movement broadcast stayed inside family');

    const leftForA = onceMessage(a);
    b.send(JSON.stringify({ type: 'leave' }));
    const left = await leftForA;
    assert.equal(left.type, 'peer_left');
    assert.equal(left.member_id, 'member_b');
    console.log('OK  leave announced');

    a.close();
    c.close();
    console.log('Presence local smoke passed');
  } finally {
    await relay.close();
  }
}

main().catch((err) => {
  console.error(`Presence local smoke failed: ${err.stack || err.message}`);
  process.exitCode = 1;
});
