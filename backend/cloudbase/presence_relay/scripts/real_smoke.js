#!/usr/bin/env node

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const WebSocket = require('ws');

const REQUIRED_FLAG = 'FG_GATE6_REAL_SMOKE';
const DEFAULT_DATA_GATEWAY_URL = 'https://familygarden-d7gy18huh87fd41d2-1449262000.ap-shanghai.app.tcloudbase.com/data_gateway';
const DEFAULT_PRESENCE_ENDPOINT = 'wss://familygarden-d7gy18huh87fd41d2-1449262000.ap-shanghai.app.tcloudbase.com/presence-relay';

function repoRoot() {
  return path.resolve(__dirname, '../../../..');
}

function loadConfig() {
  const configPath = path.join(repoRoot(), 'game/config/cloudbase.json');
  if (!fs.existsSync(configPath)) return {};
  return JSON.parse(fs.readFileSync(configPath, 'utf8'));
}

function shortStamp() {
  const now = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 14);
  return `${now}_${crypto.randomBytes(3).toString('hex')}`;
}

function responseSummary(data) {
  if (!data || typeof data !== 'object') return String(data);
  return JSON.stringify({
    ok: data.ok,
    code: data.code,
    error: data.error,
    member_id: data.member_id,
    family_id: data.family_id,
  });
}

async function request(endpoint, body, token = '') {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(endpoint, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
  const text = await response.text();
  let data;
  try {
    data = text ? JSON.parse(text) : {};
  } catch (err) {
    throw new Error(`HTTP ${response.status} returned non-JSON: ${text.slice(0, 300)}`);
  }
  if (!response.ok || !data.ok) {
    throw new Error(`data_gateway request failed: HTTP ${response.status} ${responseSummary(data)}`);
  }
  return data;
}

async function joinMember(dataGatewayUrl, familyId, role, displayName) {
  const data = await request(dataGatewayUrl, {
    action: 'join_family',
    family_id: familyId,
    role,
    display_name: displayName,
  });
  assert.ok(data.member_token, 'join_family should return member_token');
  assert.ok(data.member_id, 'join_family should return member_id');
  return { token: data.member_token, member_id: data.member_id, family_id: familyId, role, display_name: displayName };
}

function openClient(url) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(url);
    ws.once('open', () => resolve(ws));
    ws.once('error', reject);
  });
}

function waitFor(ws, predicate, label, timeoutMs = 6000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      cleanup();
      reject(new Error(`timed out waiting for ${label}`));
    }, timeoutMs);
    function cleanup() {
      clearTimeout(timer);
      ws.off('message', onMessage);
      ws.off('close', onClose);
      ws.off('error', onError);
    }
    function onMessage(data) {
      const message = JSON.parse(data.toString('utf8'));
      if (message.type === 'error' && !predicate(message)) {
        cleanup();
        reject(new Error(`received error while waiting for ${label}: ${JSON.stringify(message)}`));
        return;
      }
      if (!predicate(message)) return;
      cleanup();
      resolve(message);
    }
    function onClose(code, reason) {
      cleanup();
      reject(new Error(`socket closed while waiting for ${label}: ${code} ${reason}`));
    }
    function onError(err) {
      cleanup();
      reject(err);
    }
    ws.on('message', onMessage);
    ws.once('close', onClose);
    ws.once('error', onError);
  });
}

function expectNoMessage(ws, label, timeoutMs = 350) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      cleanup();
      resolve();
    }, timeoutMs);
    function cleanup() {
      clearTimeout(timer);
      ws.off('message', onMessage);
    }
    function onMessage(data) {
      cleanup();
      reject(new Error(`${label} received unexpected message: ${data.toString('utf8')}`));
    }
    ws.on('message', onMessage);
  });
}

async function hello(ws, member) {
  ws.send(JSON.stringify({ type: 'hello', token: member.token, scene_id: 'farm' }));
  const message = await waitFor(ws, (msg) => msg.type === 'hello_ok', `hello_ok for ${member.member_id}`);
  assert.equal(message.self.member_id, member.member_id);
  return message;
}

async function main() {
  if (process.env[REQUIRED_FLAG] !== '1') {
    console.log(`Gate6 real cloud smoke skipped: set ${REQUIRED_FLAG}=1 explicitly`);
    return;
  }

  const config = loadConfig();
  const dataGatewayUrl = process.env.DATA_GATEWAY_URL || process.env.FG_GATE6_DATA_GATEWAY_URL || config.endpoint || DEFAULT_DATA_GATEWAY_URL;
  const presenceEndpoint = process.env.PRESENCE_ENDPOINT || process.env.FG_GATE6_PRESENCE_ENDPOINT || config.presence_endpoint || DEFAULT_PRESENCE_ENDPOINT;
  const configuredFamily = process.env.FG_GATE6_FAMILY_ID || config.family_id || 'family_gate6';
  const runId = `gate6_real_${shortStamp()}`;
  const familyId = `${configuredFamily}_${runId}`;
  const isolatedFamilyId = `${familyId}_isolated`;

  console.log(`Gate6 real smoke data gateway: ${dataGatewayUrl}`);
  console.log(`Gate6 real smoke presence endpoint: ${presenceEndpoint}`);
  console.log(`Gate6 real smoke family: ${familyId}`);
  console.log('注意: join_family 会留下少量测试 members 记录；本脚本不写业务表。');

  const memberA = await joinMember(dataGatewayUrl, familyId, 'father', `Gate6 A ${runId}`);
  const memberB = await joinMember(dataGatewayUrl, familyId, 'mother', `Gate6 B ${runId}`);
  const memberC = await joinMember(dataGatewayUrl, isolatedFamilyId, 'player', `Gate6 C ${runId}`);
  console.log('OK  temporary members joined through data_gateway');

  const bad = await openClient(presenceEndpoint);
  bad.send(JSON.stringify({ type: 'hello', token: `${runId}_invalid`, scene_id: 'farm' }));
  const badError = await waitFor(bad, (msg) => msg.type === 'error', 'invalid token error');
  assert.equal(badError.code, 'UNAUTHORIZED');
  bad.close();
  console.log('OK  invalid token rejected');

  const a = await openClient(presenceEndpoint);
  const helloA = await hello(a, memberA);
  assert.deepEqual(helloA.peers, []);
  console.log('OK  member A joined');

  const b = await openClient(presenceEndpoint);
  const joinedForA = waitFor(a, (msg) => msg.type === 'peer_joined' && msg.peer?.member_id === memberB.member_id, 'B join broadcast');
  const helloB = await hello(b, memberB);
  assert.ok(helloB.peers.some((peer) => peer.member_id === memberA.member_id));
  await joinedForA;
  console.log('OK  member B joined and A saw it');

  const c = await openClient(presenceEndpoint);
  await hello(c, memberC);
  console.log('OK  isolated member joined');

  const moveForB = waitFor(b, (msg) => msg.type === 'peer_moved' && msg.peer?.member_id === memberA.member_id, 'A movement for B');
  a.send(JSON.stringify({
    type: 'move',
    scene_id: 'farm',
    position: { x: 610, y: 420 },
    direction: 'right',
    animation_state: 'walk',
    timestamp: Date.now(),
    sequence: 1,
  }));
  const moved = await moveForB;
  assert.deepEqual(moved.peer.position, { x: 610, y: 420 });
  await expectNoMessage(c, 'isolated member during movement');
  console.log('OK  movement broadcast stayed inside family');

  const eventId = `${runId}_world_changed`;
  const changeAckForA = waitFor(a, (msg) => msg.type === 'world_changed_ack' && msg.event_id === eventId, 'world change ack');
  const changeForB = waitFor(b, (msg) => msg.type === 'world_changed' && msg.event?.event_id === eventId, 'world change for B');
  a.send(JSON.stringify({
    type: 'world_changed',
    table: 'messages',
    id: `${runId}_message`,
    action: 'upsert',
    timestamp: Date.now(),
    event_id: eventId,
  }));
  await changeAckForA;
  const changed = await changeForB;
  assert.equal(changed.event.member_id, memberA.member_id);
  assert.equal(changed.event.family_id, familyId);
  assert.equal(changed.event.table, 'messages');
  await expectNoMessage(c, 'isolated member during world change');
  console.log('OK  world change broadcast stayed inside family');

  const leftForA = waitFor(a, (msg) => msg.type === 'peer_left' && msg.member_id === memberB.member_id, 'B leave broadcast');
  b.send(JSON.stringify({ type: 'leave' }));
  await leftForA;
  console.log('OK  leave announced');

  a.close();
  b.close();
  c.close();
  console.log('Gate6 real cloud smoke passed');
}

main().catch((err) => {
  console.error(`Gate6 real cloud smoke failed: ${err.stack || err.message}`);
  process.exitCode = 1;
});
