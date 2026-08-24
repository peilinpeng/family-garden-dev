#!/usr/bin/env node

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const REQUIRED_FLAG = 'FG_GATE6_FARM_REAL_SMOKE';

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
    throw new Error(`HTTP ${response.status} 返回非 JSON: ${text.slice(0, 300)}`);
  }
  if (!response.ok) throw new Error(`HTTP ${response.status}: ${responseSummary(data)}`);
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
  if (code !== undefined) assert.equal(Number(data.code), code, `${label} 应返回 code=${code}，实际 ${responseSummary(data)}`);
  console.log(`OK  ${label}`);
  return data;
}

function findPlot(rows, plotIndex) {
  return (rows || []).find((row) => Number(row.plot_index) === plotIndex);
}

async function queryPlots(endpoint, token) {
  const result = await expectOk('query farm_plots', request(endpoint, { action: 'query', table: 'farm_plots' }, token));
  assert.ok(Array.isArray(result.rows), 'farm_plots query.rows 应为数组');
  return result.rows;
}

async function run() {
  if (process.env[REQUIRED_FLAG] !== '1') {
    console.log(`Gate6 farm real cloud smoke skipped: set ${REQUIRED_FLAG}=1 explicitly`);
    return;
  }

  const config = loadCloudBaseConfig();
  const endpoint = process.env.FG_GATE6_FARM_ENDPOINT || config.endpoint;
  if (!endpoint) throw new Error('缺少 CloudBase endpoint');
  const configuredFamily = process.env.FG_GATE6_FARM_FAMILY_ID || config.family_id;
  if (!configuredFamily) throw new Error('缺少 family_id');

  const runId = `gate6_farm_${shortStamp()}`;
  const familyId = `${configuredFamily}_${runId}`;
  const isolatedFamilyId = `${familyId}_isolated`;
  const plotId = `farm_plot:${familyId}:0`;
  let memberA;
  let memberB;
  let memberC;

  console.log(`Gate6 farm real smoke endpoint: ${endpoint}`);
  console.log(`Gate6 farm real smoke family: ${familyId}`);
  console.log('注意: join_family 会留下少量测试 members 记录；地块会通过 uproot 事务清理。');

  try {
    const joinA = await expectOk('join member A', request(endpoint, {
      action: 'join_family', family_id: familyId, role: 'father', display_name: `Gate6 Farm A ${runId}`,
    }));
    const joinB = await expectOk('join member B', request(endpoint, {
      action: 'join_family', family_id: familyId, role: 'mother', display_name: `Gate6 Farm B ${runId}`,
    }));
    const joinC = await expectOk('join isolated member', request(endpoint, {
      action: 'join_family', family_id: isolatedFamilyId, role: 'player', display_name: `Gate6 Farm C ${runId}`,
    }));
    memberA = { token: joinA.member_token, id: joinA.member_id };
    memberB = { token: joinB.member_token, id: joinB.member_id };
    memberC = { token: joinC.member_token, id: joinC.member_id };

    await expectOk('grant one seed atomically', request(endpoint, {
      action: 'mutate_storehouse',
      operation_id: `${runId}:grant-seed`,
      grants: [{ id: 'seed_corrato', quantity: 1, max_stack: 99 }],
    }, memberA.token));
    const planted = await expectOk('A plants farm plot', request(endpoint, {
      action: 'farm_action',
      farm_action: 'plant',
      operation_id: `${runId}:plant-a`,
      plot_index: 0,
      crop_id: 'corrato',
    }, memberA.token));
    assert.equal(planted.plot.id, plotId);

    const sameFamilyRows = await queryPlots(endpoint, memberB.token);
    const plot = findPlot(sameFamilyRows, 0);
    assert.ok(plot, 'B 应看到 A 种下的地块');
    assert.equal(plot.id, plotId);
    assert.equal(plot.family_id, familyId);
    assert.equal(plot.crop_id, 'corrato');
    assert.equal(plot.created_by_member_id, memberA.id);
    assert.equal(plot.updated_by_member_id, memberA.id);

    await expectRejected('B cannot overwrite occupied plot', request(endpoint, {
      action: 'farm_action',
      farm_action: 'plant',
      operation_id: `${runId}:plant-b`,
      plot_index: 0,
      crop_id: 'tomelone',
    }, memberB.token), 409);

    const isolatedRows = await queryPlots(endpoint, memberC.token);
    assert.equal(findPlot(isolatedRows, 0), undefined, '隔离家庭不应看到 farm_plots');

    await expectRejected('isolated member cannot uproot other family plot', request(endpoint, {
      action: 'farm_action',
      farm_action: 'uproot',
      operation_id: `${runId}:uproot-isolated`,
      plot_index: 0,
    }, memberC.token), 404);

    await expectOk('B uproots farm plot', request(endpoint, {
      action: 'farm_action',
      farm_action: 'uproot',
      operation_id: `${runId}:uproot-b`,
      plot_index: 0,
    }, memberB.token));
    assert.equal(findPlot(await queryPlots(endpoint, memberA.token), 0), undefined, '铲除后 A 不应再看到该地块');
  } finally {
    if (memberA?.token) {
      await request(endpoint, {
        action: 'farm_action', farm_action: 'uproot', operation_id: `${runId}:cleanup`, plot_index: 0,
      }, memberA.token).catch(() => {});
    }
  }

  console.log('Gate6 farm real cloud smoke passed');
}

run().catch((err) => {
  console.error(`Gate6 farm real cloud smoke failed: ${err.stack || err.message}`);
  process.exitCode = 1;
});
