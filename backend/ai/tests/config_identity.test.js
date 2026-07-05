"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const { loadConfig } = require("../config");
const { DataGatewayIdentityClient } = require("../services/identity_client");
const { assertSafeImageUrl } = require("../safety/local_policy");

test("production 拒绝关闭鉴权或使用本地安全模式", () => {
  assert.throws(
    () => loadConfig({ NODE_ENV: "production", AUTH_MODE: "disabled", SAFETY_MODE: "tencent" }),
    (error) => error.code === "INTERNAL_ERROR",
  );
  assert.throws(
    () => loadConfig({ NODE_ENV: "production", AUTH_MODE: "gateway", SAFETY_MODE: "local" }),
    (error) => error.code === "INTERNAL_ERROR",
  );
  assert.throws(
    () => loadConfig({ NODE_ENV: "staging", AUTH_MODE: "gateway", SAFETY_MODE: "tencent" }),
    (error) => error.code === "INTERNAL_ERROR",
  );
  assert.throws(
    () => loadConfig({ NODE_ENV: "test", AUTH_MODE: "disabled", SAFETY_MODE: "local", AI_PROVIDER: "unknown" }),
    (error) => error.code === "INTERNAL_ERROR",
  );
});

test("身份客户端转发 Authorization，并区分无效身份与上游故障", async () => {
  const config = { authMode: "gateway", dataGatewayUrl: "https://example.com/data_gateway", timeoutMs: 1000 };
  let captured;
  const success = new DataGatewayIdentityClient(config, {
    transport: async (...args) => {
      captured = args;
      return { ok: true, member_id: "member_1", family_id: "family_1", role: "player" };
    },
  });
  const identity = await success.authorize("Bearer member-token", "req_1");
  assert.equal(identity.member_id, "member_1");
  assert.equal(captured[2].authorization, "Bearer member-token");

  await assert.rejects(() => success.authorize("", "req_2"), (error) => error.code === "UNAUTHORIZED");

  const invalid = new DataGatewayIdentityClient(config, { transport: async () => ({ ok: false, code: 401, error: "unauthorized" }) });
  await assert.rejects(() => invalid.authorize("Bearer bad", "req_3"), (error) => error.code === "UNAUTHORIZED");

  const failed = new DataGatewayIdentityClient(config, { transport: async () => ({ ok: false, error: "database unavailable" }) });
  await assert.rejects(() => failed.authorize("Bearer token", "req_4"), (error) => error.code === "AI_UPSTREAM_ERROR");
});

test("图片地址拒绝 HTTP、本机、云元数据与常见私网", () => {
  const blocked = [
    "http://example.com/a.jpg",
    "https://localhost/a.jpg",
    "https://127.0.0.1/a.jpg",
    "https://10.0.0.1/a.jpg",
    "https://172.16.0.1/a.jpg",
    "https://192.168.1.1/a.jpg",
    "https://169.254.169.254/a.jpg",
    "https://metadata.tencentyun.com/a.jpg",
    "https://[::1]/a.jpg",
  ];
  for (const url of blocked) assert.throws(() => assertSafeImageUrl(url), (error) => error.code === "IMAGE_UNSUPPORTED");
  assert.doesNotThrow(() => assertSafeImageUrl("https://example.com/a.jpg"));
});
