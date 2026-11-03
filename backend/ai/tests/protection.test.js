"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const { CircuitBreaker, Semaphore, retry } = require("../services/protection");
const { AppError } = require("../errors");
const { redact } = require("../logger");
const { errorFromStatus } = require("../providers/tokenhub");

test("有限重试只重试可恢复的上游错误", async () => {
  let calls = 0;
  const result = await retry(async () => {
    calls += 1;
    if (calls < 2) throw new AppError("AI_TIMEOUT", "timeout");
    return "ok";
  }, 1, { sleep: async () => {} });
  assert.equal(result, "ok");
  assert.equal(calls, 2);

  await assert.rejects(
    () => retry(async () => { throw new AppError("CONTENT_UNSAFE", "unsafe"); }, 2, { sleep: async () => {} }),
    (error) => error.code === "CONTENT_UNSAFE",
  );
});

test("上游不可重试的请求错误只调用一次且不等待退避", async () => {
  const upstreamError = errorFromStatus(400, { error: { code: "bad_request" } });
  let calls = 0;
  let waits = 0;
  await assert.rejects(() => retry(async () => {
    calls += 1;
    throw upstreamError;
  }, 3, { sleep: async () => { waits += 1; } }), (error) => error === upstreamError);
  assert.equal(calls, 1);
  assert.equal(waits, 0);
});

test("可重试的上游故障达到预算后保留原错误", async () => {
  const upstreamError = errorFromStatus(503, {});
  let calls = 0;
  const waits = [];
  await assert.rejects(() => retry(async () => {
    calls += 1;
    throw upstreamError;
  }, 2, { sleep: async (ms) => { waits.push(ms); } }), (error) => error === upstreamError);
  assert.equal(calls, 3);
  assert.deepEqual(waits, [100, 200]);
});

test("熔断器达到阈值后快速失败并可恢复", async () => {
  let now = 1000;
  const breaker = new CircuitBreaker(2, 500, () => now);
  const fail = () => { throw new AppError("AI_UPSTREAM_ERROR", "down"); };
  await assert.rejects(() => breaker.run(fail));
  await assert.rejects(() => breaker.run(fail));
  await assert.rejects(() => breaker.run(async () => "never"), /熔断/);
  now += 501;
  assert.equal(await breaker.run(async () => "recovered"), "recovered");
});

test("并发限制拒绝超额请求并在结束后释放", async () => {
  const semaphore = new Semaphore(1);
  let release;
  const waiting = semaphore.run(() => new Promise((resolve) => { release = resolve; }));
  await assert.rejects(() => semaphore.run(async () => "extra"), (error) => error.code === "RATE_LIMITED");
  release("done");
  assert.equal(await waiting, "done");
  assert.equal(await semaphore.run(async () => "next"), "next");
});

test("日志脱敏隐藏令牌、密钥、原文和 URL 查询参数", () => {
  const value = redact({
    authorization: "Bearer secret-token",
    secretKey: "secret-key",
    raw_text: "private memory",
    image_url: "https://example.com/photo.jpg?signature=secret",
    route: "generate-memory-card",
  });
  const serialized = JSON.stringify(value);
  assert.equal(serialized.includes("secret-token"), false);
  assert.equal(serialized.includes("secret-key"), false);
  assert.equal(serialized.includes("private memory"), false);
  assert.equal(serialized.includes("signature"), false);
  assert.equal(value.route, "generate-memory-card");
});
