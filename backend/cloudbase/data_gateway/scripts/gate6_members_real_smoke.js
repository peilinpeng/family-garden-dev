#!/usr/bin/env node

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const REQUIRED_FLAG = 'FG_GATE6_MEMBERS_REAL_SMOKE';

function repoRoot() {
  return path.resolve(__dirname, '../../../..');
}

function loadConfig() {
  return JSON.parse(fs.readFileSync(path.join(repoRoot(), 'game/config/cloudbase.json'), 'utf8'));
}

function shortStamp() {
  const now = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 14);
  return `${now}_${crypto.randomBytes(3).toString('hex')}`;
}

async function request(endpoint, body, token = '') {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(endpoint, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
  const data = await response.json();
  if (!response.ok) throw new Error(`HTTP ${response.status}: ${JSON.stringify(data)}`);
  return data;
}

async function expectOk(label, promise) {
  const data = await promise;
  assert.equal(data.ok, true, `${label} failed: ${JSON.stringify(data)}`);
  console.log(`OK  ${label}`);
  return data;
}

async function run() {
  if (process.env[REQUIRED_FLAG] !== '1') {
    console.log(`Gate6 members real cloud smoke skipped: set ${REQUIRED_FLAG}=1 explicitly`);
    return;
  }
  const config = loadConfig();
  const endpoint = process.env.FG_GATE6_MEMBERS_ENDPOINT || config.endpoint;
  const configuredFamily = process.env.FG_GATE6_MEMBERS_FAMILY_ID || config.family_id;
  if (!endpoint || !configuredFamily) throw new Error('missing endpoint or family_id');
  const runId = `gate6_members_${shortStamp()}`;
  const familyId = `${configuredFamily}_${runId}`;
  const isolatedFamilyId = `${familyId}_isolated`;

  console.log(`Gate6 members real smoke endpoint: ${endpoint}`);
  console.log(`Gate6 members real smoke family: ${familyId}`);
  console.log('注意: join_family 会留下少量测试 members 记录，显示名带 Gate6 Members 前缀。');

  const joinA = await expectOk('join member A', request(endpoint, {
    action: 'join_family', family_id: familyId, role: 'father', display_name: `Gate6 Members A ${runId}`,
  }));
  const joinB = await expectOk('join member B', request(endpoint, {
    action: 'join_family', family_id: familyId, role: 'mother', display_name: `Gate6 Members B ${runId}`,
  }));
  const joinC = await expectOk('join isolated member', request(endpoint, {
    action: 'join_family', family_id: isolatedFamilyId, role: 'player', display_name: `Gate6 Members C ${runId}`,
  }));

  const listed = await expectOk('A lists family members', request(endpoint, { action: 'list_family_members' }, joinA.member_token));
  assert.equal(listed.family_id, familyId);
  assert.deepEqual(new Set(listed.members.map((member) => member.member_id)), new Set([joinA.member_id, joinB.member_id]));
  assert.equal(listed.members.some((member) => Object.hasOwn(member, 'member_token')), false);

  const isolated = await expectOk('isolated member lists only own family', request(endpoint, { action: 'list_family_members' }, joinC.member_token));
  assert.deepEqual(new Set(isolated.members.map((member) => member.member_id)), new Set([joinC.member_id]));
  console.log('Gate6 members real cloud smoke passed');
}

run().catch((err) => {
  console.error(`Gate6 members real cloud smoke failed: ${err.stack || err.message}`);
  process.exitCode = 1;
});
