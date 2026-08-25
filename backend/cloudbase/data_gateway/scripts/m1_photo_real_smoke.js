#!/usr/bin/env node

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');

const REQUIRED_FLAG = 'FG_M1_PHOTO_REAL_SMOKE';

function repoRoot() {
  return path.resolve(__dirname, '../../../..');
}

function loadCloudBaseConfig() {
  const configPath = path.join(repoRoot(), 'game/config/cloudbase.json');
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
    id: data.id,
    upload_id: data.upload_id,
    purpose: data.purpose,
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
  } catch (_) {
    throw new Error(`HTTP ${response.status} 返回非 JSON: ${text.slice(0, 300)}`);
  }
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${responseSummary(data)}`);
  }
  return data;
}

async function expectOk(label, promise) {
  const data = await promise;
  if (!data.ok) throw new Error(`${label} 失败: ${responseSummary(data)}`);
  console.log(`OK  ${label}`);
  return data;
}

async function expectRejected(label, promise, code) {
  const data = await promise;
  assert.equal(data.ok, false, `${label} 应失败，但返回成功`);
  assert.equal(Number(data.code), code, `${label} 应返回 code=${code}，实际 ${responseSummary(data)}`);
  console.log(`OK  ${label}`);
  return data;
}

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function pngChunk(type, data) {
  const typeBytes = Buffer.from(type, 'ascii');
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const checksum = Buffer.alloc(4);
  checksum.writeUInt32BE(crc32(Buffer.concat([typeBytes, data])));
  return Buffer.concat([length, typeBytes, data, checksum]);
}

function validPng(width = 64, height = 64) {
  const signature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  const stride = width * 3 + 1;
  const pixels = Buffer.alloc(stride * height);
  for (let y = 0; y < height; y += 1) {
    const offset = y * stride;
    pixels[offset] = 0;
    for (let x = 0; x < width; x += 1) {
      pixels[offset + 1 + x * 3] = 78;
      pixels[offset + 2 + x * 3] = 143;
      pixels[offset + 3 + x * 3] = 104;
    }
  }
  return Buffer.concat([
    signature,
    pngChunk('IHDR', ihdr),
    pngChunk('IDAT', zlib.deflateSync(pixels)),
    pngChunk('IEND', Buffer.alloc(0)),
  ]);
}

function findRow(rows, id) {
  return (rows || []).find((row) => String(row.id || row._id || '') === id);
}

async function queryRows(endpoint, token, table) {
  const result = await expectOk(`query ${table}`, request(endpoint, { action: 'query', table }, token));
  assert.ok(Array.isArray(result.rows), `${table} query.rows 应为数组`);
  return result.rows;
}

async function bestEffortCleanup(endpoint, token, ids, uploadId) {
  if (!token) return;
  const bundle = await request(endpoint, {
    action: 'delete_place_bundle',
    place_id: ids.place,
  }, token).catch(() => null);
  if (bundle?.ok) console.log(`OK  cleanup bundle ${ids.place}`);
  for (const [table, id] of [
    ['mailbox_events', ids.event],
    ['postcards', ids.postcard],
    ['travel_places', ids.place],
  ]) {
    const result = await request(endpoint, { action: 'delete', table, id }, token).catch(() => null);
    if (result?.ok) console.log(`OK  cleanup ${table}/${id}`);
  }
  if (uploadId) {
    const result = await request(endpoint, {
      action: 'delete_image',
      upload_id: uploadId,
    }, token).catch(() => null);
    if (result?.ok || Number(result?.code) === 404) console.log(`OK  cleanup image ${uploadId}`);
  }
}

async function run() {
  if (process.env[REQUIRED_FLAG] !== '1') {
    console.log(`M1 photo real cloud smoke skipped: set ${REQUIRED_FLAG}=1 explicitly`);
    return;
  }

  const config = loadCloudBaseConfig();
  const endpoint = process.env.FG_M1_PHOTO_ENDPOINT || config.endpoint;
  const configuredFamily = process.env.FG_M1_PHOTO_FAMILY_ID || config.family_id;
  if (!endpoint) throw new Error('缺少 CloudBase endpoint');
  if (!configuredFamily) throw new Error('缺少 family_id');

  const runId = `m1_photo_${shortStamp()}`;
  const primaryFamily = `${configuredFamily}_${runId}`;
  const isolatedFamily = `${primaryFamily}_isolated`;
  const ids = {
    place: `${runId}_place`,
    postcard: `${runId}_postcard`,
    event: `${runId}_event`,
  };
  let memberA;
  let memberB;
  let memberC;
  let uploadId = '';

  console.log(`M1 photo real cloud smoke endpoint: ${endpoint}`);
  console.log(`M1 photo real cloud smoke family: ${primaryFamily}`);
  console.log('注意: 业务记录和图片会自动清理；join_family 会留下 3 条无令牌输出的测试 members 记录。');

  try {
    const joinA = await expectOk('join uploader A', request(endpoint, {
      action: 'join_family',
      family_id: primaryFamily,
      role: 'father',
      display_name: `M1 Photo A ${runId}`,
    }));
    const joinB = await expectOk('join family viewer B', request(endpoint, {
      action: 'join_family',
      family_id: primaryFamily,
      role: 'mother',
      display_name: `M1 Photo B ${runId}`,
    }));
    const joinC = await expectOk('join isolated member C', request(endpoint, {
      action: 'join_family',
      family_id: isolatedFamily,
      role: 'player',
      display_name: `M1 Photo C ${runId}`,
    }));
    memberA = { id: joinA.member_id, token: joinA.member_token };
    memberB = { id: joinB.member_id, token: joinB.member_token };
    memberC = { id: joinC.member_id, token: joinC.member_token };

    const uploaded = await expectOk('A uploads private travel photo', request(endpoint, {
      action: 'upload_image',
      purpose: 'travel',
      content_type: 'image/png',
      base64_data: validPng().toString('base64'),
    }, memberA.token));
    uploadId = String(uploaded.upload_id || '');
    assert.match(uploadId, /^upload_[a-f0-9]{32}$/);
    assert.equal(uploaded.purpose, 'travel');
    assert.equal(uploaded.content_type, 'image/png');
    assert.equal(Number(uploaded.width), 64);
    assert.equal(Number(uploaded.height), 64);
    assert.equal(Number(uploaded.expires_in), 600);
    assert.match(String(uploaded.image_url || ''), /^https:\/\//);

    const sameFamilyResolved = await expectOk('B resolves same-family photo', request(endpoint, {
      action: 'resolve_image',
      upload_id: uploadId,
    }, memberB.token));
    assert.equal(sameFamilyResolved.purpose, 'travel');
    const imageResponse = await fetch(sameFamilyResolved.image_url);
    assert.equal(imageResponse.ok, true, `临时 URL 下载失败: HTTP ${imageResponse.status}`);
    assert.ok((await imageResponse.arrayBuffer()).byteLength > 0, '临时 URL 返回空文件');
    console.log('OK  temporary URL downloads private object');

    await expectRejected('C cannot resolve cross-family photo', request(endpoint, {
      action: 'resolve_image',
      upload_id: uploadId,
    }, memberC.token), 404);
    await expectRejected('C cannot bind cross-family upload_id', request(endpoint, {
      action: 'upsert',
      table: 'travel_places',
      row: { id: `${ids.place}_forged`, photo_upload_id: uploadId },
    }, memberC.token), 400);

    await expectOk('A creates place with controlled reference', request(endpoint, {
      action: 'upsert',
      table: 'travel_places',
      row: {
        id: ids.place,
        title: 'M1 私有照片真实烟测',
        note: runId,
        map_x: 320,
        map_y: 240,
        photo_upload_id: uploadId,
        photo_path: 'https://public.example.test/should-not-persist.jpg',
      },
    }, memberA.token));
    await expectOk('A creates postcard with controlled reference', request(endpoint, {
      action: 'upsert',
      table: 'postcards',
      row: {
        id: ids.postcard,
        place_id: ids.place,
        title: 'M1 私有照片明信片',
        message: runId,
        photo_upload_id: uploadId,
      },
    }, memberA.token));
    await expectOk('A creates linked mailbox event', request(endpoint, {
      action: 'upsert',
      table: 'mailbox_events',
      row: {
        id: ids.event,
        type: 'postcard',
        target_id: ids.postcard,
        title: 'M1 私有照片提醒',
        is_read: false,
      },
    }, memberA.token));

    const place = findRow(await queryRows(endpoint, memberB.token, 'travel_places'), ids.place);
    assert.ok(place, '同家庭成员未读到照片地点');
    assert.equal(place.family_id, primaryFamily);
    assert.equal(place.photo_upload_id, uploadId);
    assert.equal(Object.hasOwn(place, 'photo_path'), false, '网关不应持久化新 photo_path');

    await expectRejected('referenced photo cannot be directly deleted', request(endpoint, {
      action: 'delete_image',
      upload_id: uploadId,
    }, memberA.token), 409);
    await expectRejected('isolated family cannot cascade-delete place', request(endpoint, {
      action: 'delete_place_bundle',
      place_id: ids.place,
    }, memberC.token), 403);

    const deleted = await expectOk('B cascade-deletes shared place and photo', request(endpoint, {
      action: 'delete_place_bundle',
      place_id: ids.place,
    }, memberB.token));
    assert.ok((deleted.postcard_ids || []).includes(ids.postcard));
    assert.ok((deleted.event_ids || []).includes(ids.event));
    assert.ok((deleted.deleted_upload_ids || []).includes(uploadId));

    assert.equal(findRow(await queryRows(endpoint, memberA.token, 'travel_places'), ids.place), undefined);
    assert.equal(findRow(await queryRows(endpoint, memberA.token, 'postcards'), ids.postcard), undefined);
    assert.equal(findRow(await queryRows(endpoint, memberA.token, 'mailbox_events'), ids.event), undefined);
    await expectRejected('deleted photo cannot be resolved', request(endpoint, {
      action: 'resolve_image',
      upload_id: uploadId,
    }, memberA.token), 404);

    console.log('M1 photo real cloud smoke passed');
    uploadId = '';
  } finally {
    if (process.env.FG_M1_PHOTO_KEEP_DATA === '1') {
      console.log('FG_M1_PHOTO_KEEP_DATA=1，保留业务测试记录和图片用于人工检查。');
      return;
    }
    await bestEffortCleanup(endpoint, memberA?.token, ids, uploadId);
  }
}

run().catch((err) => {
  console.error(`M1 photo real cloud smoke failed: ${err.stack || err.message}`);
  process.exitCode = 1;
});
