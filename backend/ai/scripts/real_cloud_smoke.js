#!/usr/bin/env node

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { SchemaValidator } = require('../validators/schema_validator');

const REQUIRED_FLAG = 'FG_AI_REAL_SMOKE';

function repoRoot() {
  return path.resolve(__dirname, '../../..');
}

function loadJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(repoRoot(), relativePath), 'utf8'));
}

async function post(endpoint, body, token = '') {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(endpoint, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(60_000),
  });
  const text = await response.text();
  let payload;
  try {
    payload = text ? JSON.parse(text) : {};
  } catch (_) {
    throw new Error(`HTTP ${response.status} 返回非 JSON（${text.length} bytes）`);
  }
  if (!response.ok) throw new Error(`HTTP ${response.status}: ${payload.code || payload.error || 'unknown'}`);
  return payload;
}

async function run() {
  if (process.env[REQUIRED_FLAG] !== '1') {
    process.stdout.write(`真实云 smoke 已跳过；必须显式设置 ${REQUIRED_FLAG}=1\n`);
    return;
  }

  const cloud = loadJson('game/config/cloudbase.json');
  const ai = loadJson('game/config/ai.json');
  const dataEndpoint = process.env.FG_DATA_GATEWAY_ENDPOINT || cloud.endpoint;
  const aiEndpoint = process.env.FG_AI_GATEWAY_ENDPOINT || ai.endpoint;
  assert.match(dataEndpoint, /^https:\/\//, 'Data Gateway 必须使用 HTTPS');
  assert.match(aiEndpoint, /^https:\/\//, 'AI Gateway 必须使用 HTTPS');

  const stamp = `${Date.now()}_${crypto.randomBytes(3).toString('hex')}`;
  const familyId = `release_smoke_${stamp}`;
  const joined = await post(dataEndpoint, {
    action: 'join_family',
    family_id: familyId,
    role: 'player',
    display_name: 'Release Smoke',
  });
  assert.equal(joined.ok, true, 'join_family 必须成功');
  assert.equal(typeof joined.member_token, 'string', 'join_family 必须返回临时成员令牌');
  process.stdout.write('PASS Data Gateway 匿名加入返回隔离身份\n');

  const whoami = await post(dataEndpoint, { action: 'whoami' }, joined.member_token);
  assert.equal(whoami.ok, true, 'whoami 必须成功');
  assert.equal(whoami.family_id, familyId, 'whoami 不得串家庭');
  process.stdout.write('PASS Data Gateway Bearer 身份与家庭隔离\n');

  const moderationRequest = {
    kind: 'memory_card_edit',
    texts: ['周末一家人在阳台给薄荷浇水。'],
    language: 'zh-CN',
  };
  const moderation = await post(
    aiEndpoint,
    { action: 'moderate-user-content', ...moderationRequest },
    joined.member_token,
  );
  new SchemaValidator().validateResponse('moderate-user-content', moderation, moderationRequest);
  if (!moderation.ok) {
    throw new Error(
      `内容安全 smoke 失败: ${moderation.error?.code || 'unknown'}（request_id=${moderation.meta?.request_id || 'n/a'}）`,
    );
  }
  process.stdout.write('PASS AI Gateway 腾讯文本内容安全\n');

  const request = {
    memory_id: `memory_${stamp}`,
    input_type: 'text',
    raw_text: '周末一家人在阳台给薄荷浇水，大家一起讨论晚饭吃什么。',
    language: 'zh-CN',
  };
  const response = await post(aiEndpoint, { action: 'generate-memory-card', ...request }, joined.member_token);
  new SchemaValidator().validateResponse('generate-memory-card', response, request);
  if (!response.ok) {
    throw new Error(
      `AI smoke 失败: ${response.error?.code || 'unknown'}（request_id=${response.meta?.request_id || 'n/a'}）`,
    );
  }
  assert.equal(response.meta?.source, 'ai', '真实 AI smoke 不接受 fallback 冒充模型成功');
  assert.equal(response.meta?.model, 'hy3', '真实 AI smoke 必须使用生产 hy3 模型');
  process.stdout.write(`PASS AI Gateway 真实模型 + 内容安全 + Schema（request_id=${response.meta?.request_id || 'n/a'}）\n`);
  process.stdout.write('NOTE smoke 使用随机隔离家庭；Data Gateway 当前没有 members 管理删除 API，会留下一条无业务数据的成员记录。\n');
}

run().catch((error) => {
  process.stderr.write(`FAIL ${error.message}\n`);
  process.exitCode = 1;
});
