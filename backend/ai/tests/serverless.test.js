"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const { createApp } = require("../index");
const { loadConfig } = require("../config");
const { AppError } = require("../errors");
const { SafetyService } = require("../safety");

const FIXTURES = path.join(__dirname, "fixtures");
const MOCKS = path.join(__dirname, "..", "..", "mocks");
const ROUTES = ["generate-memory-card", "generate-bottle-question", "analyze-room-photo", "cross-memory-link"];

function json(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function testConfig(overrides = {}) {
  return {
    ...loadConfig({ NODE_ENV: "test", AUTH_MODE: "disabled", SAFETY_MODE: "local" }),
    textModel: "test-text-model",
    visionModel: "test-vision-model",
    ...overrides,
  };
}

function request(route, payload, requestId = `req_${route}`) {
  return {
    httpMethod: "POST",
    path: `/api/ai/${route}`,
    headers: { "content-type": "application/json", authorization: "Bearer test", "x-request-id": requestId },
    body: JSON.stringify(payload),
  };
}

function silentLogger() {
  return { info() {}, warn() {}, error() {} };
}

function fakeIdentity() {
  return { authorize: async () => ({ member_id: "member_1", family_id: "family_1", role: "player" }) };
}

function makeApp(provider, config = testConfig(), overrides = {}) {
  return createApp(config, {
    provider,
    identity: overrides.identity || fakeIdentity(),
    safety: overrides.safety || new SafetyService(config),
    logger: overrides.logger || silentLogger(),
    sleep: async () => {},
  });
}

test("四个路由均返回通过 Gate 1 Schema 的响应", async () => {
  const byRoute = {
    "generate-memory-card": "memory_card_mock.json",
    "generate-bottle-question": "bottle_question_mock.json",
    "analyze-room-photo": "room_analysis_mock.json",
    "cross-memory-link": "cross_memory_link_mock.json",
  };
  for (const route of ROUTES) {
    const provider = { complete: async (prompt) => ({ text: JSON.stringify(json(path.join(MOCKS, byRoute[route]))), provider: "fake", model: prompt.imageUrl ? "vision" : "text" }) };
    const response = await makeApp(provider)(request(route, json(path.join(FIXTURES, `${route}.request.json`))));
    assert.equal(response.ok, true, route);
    assert.equal(response.meta.source, "ai");
  }
});

test("支持 Markdown JSON 代码块", async () => {
  const data = json(path.join(MOCKS, "memory_card_mock.json"));
  const provider = { complete: async () => ({ text: `\`\`\`json\n${JSON.stringify(data)}\n\`\`\``, provider: "fake", model: "text" }) };
  const response = await makeApp(provider)(request("generate-memory-card", json(path.join(FIXTURES, "generate-memory-card.request.json")), "req_markdown"));
  assert.equal(response.ok, true);
  assert.deepEqual(response.data, data);
});

test("首次非法输出触发一次修复重采样", async () => {
  let calls = 0;
  const data = json(path.join(MOCKS, "memory_card_mock.json"));
  const provider = { complete: async () => ({ text: calls++ === 0 ? "not json" : JSON.stringify(data), provider: "fake", model: "text" }) };
  const response = await makeApp(provider)(request("generate-memory-card", json(path.join(FIXTURES, "generate-memory-card.request.json")), "req_repair"));
  assert.equal(response.ok, true);
  assert.equal(calls, 2);
});

test("跨记忆重复、自连线或越界 ID 会触发修复重采样", async () => {
  const payload = json(path.join(FIXTURES, "cross-memory-link.request.json"));
  const valid = json(path.join(MOCKS, "cross_memory_link_mock.json"));
  const invalidCases = [
    {
      ...valid,
      links: [
        valid.links[0],
        { ...valid.links[0], memory_id_a: "mem_007", memory_id_b: "mem_new", relation_type: "same_theme" },
      ],
    },
    { ...valid, links: [{ ...valid.links[0], memory_id_b: "mem_new" }] },
    { ...valid, links: [{ ...valid.links[0], memory_id_b: "mem_not_in_request" }] },
  ];

  for (const invalid of invalidCases) {
    let calls = 0;
    const provider = {
      complete: async () => ({
        text: JSON.stringify(calls++ === 0 ? invalid : valid),
        provider: "fake",
        model: "text",
      }),
    };
    const response = await makeApp(provider)(request("cross-memory-link", payload, `req_memory_link_${calls}_${invalid.links[0].memory_id_b}`));
    assert.equal(response.ok, true);
    assert.equal(calls, 2);
    assert.deepEqual(response.data, valid);
  }
});

test("修复重采样会把具体缺字段原因反馈给模型", async () => {
  const payload = json(path.join(FIXTURES, "cross-memory-link.request.json"));
  const valid = json(path.join(MOCKS, "cross_memory_link_mock.json"));
  const incomplete = { ...valid, links: [{ ...valid.links[0] }] };
  delete incomplete.links[0].confidence;
  delete incomplete.links[0].question;
  const prompts = [];
  const provider = {
    complete: async (prompt) => {
      prompts.push(prompt.user);
      return { text: JSON.stringify(prompts.length === 1 ? incomplete : valid), provider: "fake", model: "text" };
    },
  };
  const response = await makeApp(provider)(request("cross-memory-link", payload, "req_repair_details"));
  assert.equal(response.ok, true);
  assert.equal(prompts.length, 2);
  assert.match(prompts[1], /confidence/);
  assert.match(prompts[1], /question/);
});

test("跨记忆请求必须提供新记忆内容，不能只给 ID", async () => {
  const payload = json(path.join(FIXTURES, "cross-memory-link.request.json"));
  delete payload.title;
  delete payload.description;
  delete payload.memory_type;
  const provider = { complete: async () => { throw new Error("should not call"); } };
  const response = await makeApp(provider)(request("cross-memory-link", payload, "req_missing_source_memory"));
  assert.equal(response.ok, false);
  assert.equal(response.error.code, "INVALID_REQUEST");
});

test("跨记忆上游降级不会创建带示例 ID 的假连线", async () => {
  const provider = { complete: async () => { throw new AppError("AI_UPSTREAM_ERROR", "upstream"); } };
  const payload = json(path.join(FIXTURES, "cross-memory-link.request.json"));
  const response = await makeApp(provider)(request("cross-memory-link", payload, "req_memory_link_fallback"));
  assert.equal(response.ok, true);
  assert.equal(response.meta.source, "fallback");
  assert.deepEqual(response.data.links, []);
  assert.equal(response.meta.result, "empty");
});

test("二次非法输出返回 AI_INVALID_OUTPUT", async () => {
  const provider = { complete: async () => ({ text: "{}", provider: "fake", model: "text" }) };
  const response = await makeApp(provider)(request("generate-memory-card", json(path.join(FIXTURES, "generate-memory-card.request.json")), "req_invalid_twice"));
  assert.equal(response.ok, false);
  assert.equal(response.error.code, "AI_INVALID_OUTPUT");
});

test("空输出和非法枚举在二次失败后返回 AI_INVALID_OUTPUT", async () => {
  const payload = json(path.join(FIXTURES, "generate-memory-card.request.json"));
  const emptyProvider = { complete: async () => ({ text: "", provider: "fake", model: "text" }) };
  const empty = await makeApp(emptyProvider)(request("generate-memory-card", payload, "req_empty_output"));
  assert.equal(empty.error.code, "AI_INVALID_OUTPUT");

  const invalidData = { ...json(path.join(MOCKS, "memory_card_mock.json")), suggested_scene: "moon" };
  const invalidProvider = { complete: async () => ({ text: JSON.stringify(invalidData), provider: "fake", model: "text" }) };
  const invalid = await makeApp(invalidProvider)(request("generate-memory-card", payload, "req_invalid_enum"));
  assert.equal(invalid.error.code, "AI_INVALID_OUTPUT");
});

test("上游超时和限流均可降级为 fallback", async () => {
  for (const code of ["AI_TIMEOUT", "AI_UPSTREAM_ERROR"]) {
    const provider = { complete: async () => { throw new AppError(code, "upstream"); } };
    const response = await makeApp(provider)(request("generate-bottle-question", json(path.join(FIXTURES, "generate-bottle-question.request.json")), `req_${code}`));
    assert.equal(response.ok, true);
    assert.equal(response.meta.fallback_reason, code);
  }
});

test("输入和输出内容安全失败不会被 fallback 掩盖", async () => {
  let providerCalls = 0;
  const safeData = json(path.join(MOCKS, "memory_card_mock.json"));
  const provider = { complete: async () => { providerCalls += 1; return { text: JSON.stringify(safeData), provider: "fake", model: "text" }; } };
  const unsafeInput = json(path.join(FIXTURES, "generate-memory-card.request.json"));
  unsafeInput.raw_text = "我不想活了，想自杀";
  const inputResponse = await makeApp(provider)(request("generate-memory-card", unsafeInput, "req_unsafe_input"));
  assert.equal(inputResponse.ok, false);
  assert.equal(inputResponse.error.code, "CONTENT_UNSAFE");
  assert.equal(providerCalls, 0);

  const unsafeData = { ...safeData, title: "自杀的方法" };
  const unsafeProvider = { complete: async () => ({ text: JSON.stringify(unsafeData), provider: "fake", model: "text" }) };
  const outputResponse = await makeApp(unsafeProvider)(request("generate-memory-card", json(path.join(FIXTURES, "generate-memory-card.request.json")), "req_unsafe_output"));
  assert.equal(outputResponse.ok, false);
  assert.equal(outputResponse.error.code, "CONTENT_UNSAFE");
});

test("请求方法、Content-Type、大小和 Schema 均受限制", async () => {
  const provider = { complete: async () => { throw new Error("should not call"); } };
  const app = makeApp(provider, testConfig({ maxBodyBytes: 1024 }));
  const payload = json(path.join(FIXTURES, "generate-memory-card.request.json"));

  const badMethod = request("generate-memory-card", payload, "req_method");
  badMethod.httpMethod = "GET";
  assert.equal((await app(badMethod)).error.code, "INVALID_REQUEST");

  const badType = request("generate-memory-card", payload, "req_type");
  badType.headers["content-type"] = "text/plain";
  assert.equal((await app(badType)).error.code, "INVALID_REQUEST");

  const tooLarge = request("generate-memory-card", { ...payload, raw_text: "a".repeat(2000) }, "req_size");
  assert.equal((await app(tooLarge)).error.code, "INVALID_REQUEST");

  const invalid = request("generate-memory-card", { memory_id: "mem_1", input_type: "photo", language: "zh-CN" }, "req_schema");
  assert.equal((await app(invalid)).error.code, "INVALID_REQUEST");
});

test("同一 request ID 幂等复用，不同内容返回冲突", async () => {
  let calls = 0;
  const data = json(path.join(MOCKS, "memory_card_mock.json"));
  const provider = { complete: async () => { calls += 1; return { text: JSON.stringify(data), provider: "fake", model: "text" }; } };
  const app = makeApp(provider);
  const payload = json(path.join(FIXTURES, "generate-memory-card.request.json"));
  const first = await app(request("generate-memory-card", payload, "req_same"));
  const second = await app(request("generate-memory-card", payload, "req_same"));
  assert.deepEqual(second, first);
  assert.equal(calls, 1);

  const changed = { ...payload, raw_text: "另一段合法记忆" };
  const conflict = await app(request("generate-memory-card", changed, "req_same"));
  assert.equal(conflict.ok, false);
  assert.equal(conflict.error.code, "DATA_CONFLICT");
});

test("进程内限流生效", async () => {
  const data = json(path.join(MOCKS, "bottle_question_mock.json"));
  const provider = { complete: async () => ({ text: JSON.stringify(data), provider: "fake", model: "text" }) };
  const app = makeApp(provider, testConfig({ rateLimitMax: 1 }));
  const payload = json(path.join(FIXTURES, "generate-bottle-question.request.json"));
  assert.equal((await app(request("generate-bottle-question", payload, "req_rate_1"))).ok, true);
  const limited = await app(request("generate-bottle-question", payload, "req_rate_2"));
  assert.equal(limited.error.code, "RATE_LIMITED");
});

test("错误响应不暴露内部堆栈或密钥", async () => {
  const provider = { complete: async () => { throw new AppError("INTERNAL_ERROR", "SecretId=secret-value stack=/private/path", { expose: false }); } };
  const response = await makeApp(provider)(request("generate-memory-card", json(path.join(FIXTURES, "generate-memory-card.request.json")), "req_internal"));
  const serialized = JSON.stringify(response);
  assert.equal(response.error.code, "INTERNAL_ERROR");
  assert.equal(serialized.includes("secret-value"), false);
  assert.equal(serialized.includes("/private/path"), false);
});

test("失败日志只记录安全诊断码，不记录上游敏感消息", async () => {
  const events = [];
  const logger = {
    info() {},
    error() {},
    warn(event, fields) { events.push({ event, fields }); },
  };
  const provider = {
    complete: async () => {
      const cause = new Error("SecretKey=never-log-this");
      cause.code = "ResourceUnavailable.InArrears";
      throw new AppError("INTERNAL_ERROR", "hidden", { expose: false, cause, stage: "ims" });
    },
  };
  const response = await makeApp(provider, testConfig(), { logger })(request(
    "generate-memory-card",
    json(path.join(FIXTURES, "generate-memory-card.request.json")),
    "req_safe_diagnostic",
  ));
  assert.equal(response.ok, false);
  const failed = events.find((entry) => entry.event === "ai_request_failed");
  assert.equal(failed.fields.stage, "ims");
  assert.equal(failed.fields.upstream_code, "ResourceUnavailable.InArrears");
  assert.equal(JSON.stringify(events).includes("never-log-this"), false);
});
