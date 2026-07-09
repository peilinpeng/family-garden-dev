#!/usr/bin/env node

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const REQUIRED_FLAG = 'FG_GATE5_REAL_SMOKE';
const TABLES = ['travel_places', 'postcards', 'messages', 'mailbox_events'];

function repoRoot() {
  return path.resolve(__dirname, '../../../..');
}

function loadCloudBaseConfig() {
  const configPath = path.join(repoRoot(), 'game/config/cloudbase.json');
  const raw = fs.readFileSync(configPath, 'utf8');
  return JSON.parse(raw);
}

function shortStamp() {
  const now = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 14);
  return `${now}_${crypto.randomBytes(3).toString('hex')}`;
}

function describeRow(row) {
  return `${row.id || row._id || '(no id)'}:${row.title || row.text || row.name || ''}`;
}

function responseSummary(data) {
  if (!data || typeof data !== 'object') return String(data);
  return JSON.stringify({
    ok: data.ok,
    code: data.code,
    error: data.error,
    id: data.id,
    member_id: data.member_id,
    family_id: data.family_id,
  });
}

function hasMissingCollectionText(value) {
  return String(value || '').includes('DATABASE_COLLECTION_NOT_EXIST')
    || String(value || '').includes('Db or Table not exist');
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
    throw new Error(`HTTP ${response.status} 返回非 JSON: ${text.slice(0, 300)}`);
  }
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${responseSummary(data)}`);
  }
  return data;
}

async function expectOk(label, promise) {
  const data = await promise;
  if (!data.ok) {
    if (hasMissingCollectionText(data.error)) {
      throw new Error(`${label} 失败: ${responseSummary(data)}。线上 data_gateway 尚未具备 Gate5 集合自愈能力，或目标环境未创建 Gate5 集合；请先部署本目录最新 data_gateway.zip 后重跑。`);
    }
    throw new Error(`${label} 失败: ${responseSummary(data)}`);
  }
  console.log(`OK  ${label}`);
  return data;
}

async function expectRejected(label, promise, code) {
  const data = await promise;
  assert.equal(data.ok, false, `${label} 应失败，但返回成功`);
  if (code !== undefined) {
    assert.equal(Number(data.code), code, `${label} 应返回 code=${code}，实际 ${responseSummary(data)}`);
  }
  console.log(`OK  ${label}`);
  return data;
}

function findRow(rows, id) {
  return (rows || []).find((row) => String(row.id || row._id || '') === id);
}

async function queryRows(endpoint, token, table) {
  const result = await expectOk(`query ${table}`, request(endpoint, { action: 'query', table }, token));
  assert.ok(Array.isArray(result.rows), `${table} query.rows 应为数组`);
  return result.rows;
}

async function snapshotTables(endpoint, token) {
  const result = await expectOk('snapshot Gate5 tables', request(endpoint, { action: 'snapshot', tables: TABLES }, token));
  for (const table of TABLES) {
    assert.ok(Array.isArray(result.tables?.[table]), `snapshot 缺少 ${table} 数组`);
  }
  return result.tables;
}

async function deleteIfPresent(endpoint, token, table, id) {
  const result = await request(endpoint, { action: 'delete', table, id }, token).catch((err) => ({ ok: false, error: err.message }));
  if (result.ok) {
    console.log(`OK  cleanup ${table}/${id}`);
  }
}

async function run() {
  if (process.env[REQUIRED_FLAG] !== '1') {
    console.log(`Gate5 real cloud smoke skipped: set ${REQUIRED_FLAG}=1 explicitly`);
    return;
  }

  const config = loadCloudBaseConfig();
  const endpoint = process.env.FG_GATE5_ENDPOINT || config.endpoint;
  if (!endpoint) throw new Error('缺少 CloudBase endpoint');

  const configuredFamily = process.env.FG_GATE5_FAMILY_ID || config.family_id;
  if (!configuredFamily) throw new Error('缺少 family_id');

  const runId = `gate5_real_${shortStamp()}`;
  const primaryFamily = process.env.FG_GATE5_USE_CONFIG_FAMILY === '1'
    ? configuredFamily
    : `${configuredFamily}_${runId}`;
  const isolatedFamily = `${primaryFamily}_isolated`;
  const ids = {
    place: `${runId}_place`,
    postcard: `${runId}_postcard`,
    message: `${runId}_message`,
    event: `${runId}_mailbox_event`,
  };

  let memberA;
  let memberB;
  let memberC;

  console.log(`Gate5 real cloud smoke endpoint: ${endpoint}`);
  console.log(`Gate5 real cloud smoke family: ${primaryFamily}`);
  console.log('注意: join_family 会留下少量测试 members 记录；业务表测试记录会在结束时清理。');

  try {
    await expectRejected('whoami rejects missing token', request(endpoint, { action: 'whoami' }), 401);
    await expectRejected('whoami rejects invalid token', request(endpoint, { action: 'whoami' }, `${runId}_invalid`), 401);

    const joinA = await expectOk('join member A', request(endpoint, {
      action: 'join_family',
      family_id: primaryFamily,
      role: 'father',
      display_name: `Gate5 A ${runId}`,
    }));
    const joinB = await expectOk('join member B', request(endpoint, {
      action: 'join_family',
      family_id: primaryFamily,
      role: 'mother',
      display_name: `Gate5 B ${runId}`,
    }));
    const joinC = await expectOk('join isolated member', request(endpoint, {
      action: 'join_family',
      family_id: isolatedFamily,
      role: 'player',
      display_name: `Gate5 C ${runId}`,
    }));
    memberA = { token: joinA.member_token, id: joinA.member_id };
    memberB = { token: joinB.member_token, id: joinB.member_id };
    memberC = { token: joinC.member_token, id: joinC.member_id };

    const whoA = await expectOk('whoami member A', request(endpoint, { action: 'whoami' }, memberA.token));
    const whoB = await expectOk('whoami member B', request(endpoint, { action: 'whoami' }, memberB.token));
    assert.equal(whoA.family_id, primaryFamily);
    assert.equal(whoB.family_id, primaryFamily);
    assert.notEqual(whoA.member_id, whoB.member_id);

    await expectOk('A creates travel place with forged audit fields', request(endpoint, {
      action: 'upsert',
      table: 'travel_places',
      row: {
        id: ids.place,
        family_id: isolatedFamily,
        created_by_member_id: 'forged_creator',
        updated_by_member_id: 'forged_updater',
        name: 'Gate5 真实联调地点',
        title: 'Gate5 真实联调地点',
        note: runId,
        created_at: new Date().toISOString(),
      },
    }, memberA.token));

    let place = findRow(await queryRows(endpoint, memberB.token, 'travel_places'), ids.place);
    assert.ok(place, `B 未看到 A 创建的 travel_places；当前行: ${(await queryRows(endpoint, memberB.token, 'travel_places')).map(describeRow).join(', ')}`);
    assert.equal(place.family_id, primaryFamily, 'travel_places family_id 未由服务端覆盖');
    assert.equal(place.created_by_member_id, memberA.id, 'travel_places created_by_member_id 未由服务端写入');
    assert.equal(place.updated_by_member_id, memberA.id, 'travel_places updated_by_member_id 未由服务端写入');

    await expectOk('B updates travel place and keeps creator', request(endpoint, {
      action: 'upsert',
      table: 'travel_places',
      row: {
        id: ids.place,
        created_by_member_id: 'forged_creator_again',
        updated_by_member_id: 'forged_updater_again',
        name: 'Gate5 真实联调地点 已更新',
        title: 'Gate5 真实联调地点 已更新',
        note: `${runId} updated`,
      },
    }, memberB.token));
    place = findRow(await queryRows(endpoint, memberA.token, 'travel_places'), ids.place);
    assert.equal(place.created_by_member_id, memberA.id, '更新后 created_by_member_id 应保持原创建者');
    assert.equal(place.updated_by_member_id, memberB.id, '更新后 updated_by_member_id 应为更新者');

    await expectOk('A creates postcard', request(endpoint, {
      action: 'upsert',
      table: 'postcards',
      row: {
        id: ids.postcard,
        place_id: ids.place,
        title: 'Gate5 真实联调明信片',
        body: '来自真实 CloudBase smoke 的明信片。',
        is_read: false,
        created_at: new Date().toISOString(),
      },
    }, memberA.token));
    await expectOk('B marks postcard read', request(endpoint, {
      action: 'upsert',
      table: 'postcards',
      row: {
        id: ids.postcard,
        place_id: ids.place,
        title: 'Gate5 真实联调明信片',
        body: '来自真实 CloudBase smoke 的明信片。',
        is_read: true,
      },
    }, memberB.token));
    const postcard = findRow(await queryRows(endpoint, memberA.token, 'postcards'), ids.postcard);
    assert.equal(postcard.is_read, true, 'postcard 已读状态未跨成员同步');
    assert.equal(postcard.created_by_member_id, memberA.id);
    assert.equal(postcard.updated_by_member_id, memberB.id);

    await expectOk('B creates message', request(endpoint, {
      action: 'upsert',
      table: 'messages',
      row: {
        id: ids.message,
        sender_role: 'mother',
        text: `Gate5 真实联调留言 ${runId}`,
        created_at: new Date().toISOString(),
      },
    }, memberB.token));
    const message = findRow(await queryRows(endpoint, memberA.token, 'messages'), ids.message);
    assert.ok(message, 'A 未看到 B 创建的 message');
    assert.equal(message.family_id, primaryFamily);
    assert.equal(message.created_by_member_id, memberB.id);

    await expectOk('A creates mailbox event', request(endpoint, {
      action: 'upsert',
      table: 'mailbox_events',
      row: {
        id: ids.event,
        event_type: 'postcard',
        ref_id: ids.postcard,
        title: 'Gate5 真实联调邮箱提醒',
        is_read: false,
        created_at: new Date().toISOString(),
      },
    }, memberA.token));
    await expectOk('B marks mailbox event read', request(endpoint, {
      action: 'upsert',
      table: 'mailbox_events',
      row: {
        id: ids.event,
        event_type: 'postcard',
        ref_id: ids.postcard,
        title: 'Gate5 真实联调邮箱提醒',
        is_read: true,
      },
    }, memberB.token));
    const event = findRow(await queryRows(endpoint, memberA.token, 'mailbox_events'), ids.event);
    assert.equal(event.is_read, true, 'mailbox_events 已读状态未跨成员同步');
    assert.equal(event.updated_by_member_id, memberB.id);

    const snapshot = await snapshotTables(endpoint, memberB.token);
    for (const [table, id] of [
      ['travel_places', ids.place],
      ['postcards', ids.postcard],
      ['messages', ids.message],
      ['mailbox_events', ids.event],
    ]) {
      assert.ok(findRow(snapshot[table], id), `snapshot 中缺少 ${table}/${id}`);
    }

    const isolatedRows = await queryRows(endpoint, memberC.token, 'travel_places');
    assert.equal(findRow(isolatedRows, ids.place), undefined, '隔离家庭不应读到主家庭 travel_places');
    await expectRejected('isolated member cannot overwrite primary family row', request(endpoint, {
      action: 'upsert',
      table: 'travel_places',
      row: { id: ids.place, family_id: primaryFamily, title: 'forbidden overwrite' },
    }, memberC.token), 403);
    await expectRejected('isolated member cannot delete primary family row', request(endpoint, {
      action: 'delete',
      table: 'travel_places',
      id: ids.place,
    }, memberC.token), 403);

    console.log('Gate5 real cloud smoke passed');
  } finally {
    if (process.env.FG_GATE5_KEEP_DATA === '1') {
      console.log('FG_GATE5_KEEP_DATA=1，保留业务测试记录用于人工检查。');
      return;
    }
    if (memberA?.token) {
      await deleteIfPresent(endpoint, memberA.token, 'mailbox_events', ids.event);
      await deleteIfPresent(endpoint, memberA.token, 'messages', ids.message);
      await deleteIfPresent(endpoint, memberA.token, 'postcards', ids.postcard);
      await deleteIfPresent(endpoint, memberA.token, 'travel_places', ids.place);
    }
  }
}

run().catch((err) => {
  console.error(`Gate5 real cloud smoke failed: ${err.stack || err.message}`);
  process.exitCode = 1;
});
