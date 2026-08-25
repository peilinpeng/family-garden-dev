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

test("production 对 TokenHub、模型、身份网关和内容安全凭据 fail-fast", () => {
  assert.throws(
    () => loadConfig({ NODE_ENV: "production", AUTH_MODE: "gateway", SAFETY_MODE: "tencent" }),
    (error) => error.code === "INTERNAL_ERROR" && /TOKENHUB_API_KEY/.test(error.message),
  );
  const config = loadConfig({
    NODE_ENV: "production",
    AUTH_MODE: "gateway",
    SAFETY_MODE: "tencent",
    DATA_GATEWAY_URL: "https://example.com/data_gateway",
    TOKENHUB_API_KEY: "test-key",
    HUNYUAN_TEXT_MODEL: "hy3-preview",
    HUNYUAN_VISION_MODEL: "hy-vision-2.0-instruct",
    CONTENT_SAFETY_SECRET_ID: "test-id",
    CONTENT_SAFETY_SECRET_KEY: "test-secret",
  });
  assert.equal(config.provider, "tokenhub");
  assert.equal(config.textMaxTokens, 16384);
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

  const resolver = new DataGatewayIdentityClient(config, {
    transport: async (_url, body, headers) => {
      assert.equal(body.action, "resolve_image");
      assert.equal(headers.authorization, "Bearer member-token");
      return { ok: true, image_url: "https://example.com/temp.jpg" };
    },
  });
  assert.equal((await resolver.resolveImage("Bearer member-token", "upload_0123456789abcdef0123456789abcdef", "req_img")).image_url, "https://example.com/temp.jpg");

  await assert.rejects(() => success.authorize("", "req_2"), (error) => error.code === "UNAUTHORIZED");

  const invalid = new DataGatewayIdentityClient(config, { transport: async () => ({ ok: false, code: 401, error: "unauthorized" }) });
  await assert.rejects(() => invalid.authorize("Bearer bad", "req_3"), (error) => error.code === "UNAUTHORIZED");

  const failed = new DataGatewayIdentityClient(config, { transport: async () => ({ ok: false, error: "database unavailable" }) });
  await assert.rejects(() => failed.authorize("Bearer token", "req_4"), (error) => error.code === "AI_UPSTREAM_ERROR");
});

test("图片地址拒绝 HTTP、本机、云元数据、常见私网与 host confusion", () => {
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
    "https://[::ffff:7f00:1]/a.jpg",
    "https://[fc00::1]/a.jpg",
    "https://[fe80::1]/a.jpg",
  ];
  for (const url of blocked) assert.throws(() => assertSafeImageUrl(url), (error) => error.code === "IMAGE_UNSUPPORTED");
  assert.doesNotThrow(() => assertSafeImageUrl("https://example.com/a.jpg"));
  assert.doesNotThrow(() => assertSafeImageUrl("https://img.example.com/a.jpg", ["example.com"]));
  assert.throws(() => assertSafeImageUrl("https://evil.example.net/a.jpg", ["example.com"]), (error) => error.code === "IMAGE_UNSUPPORTED");
  assert.throws(() => assertSafeImageUrl("https://evil.example.net\\@img.example.com/a.jpg", ["example.com"]), (error) => error.code === "IMAGE_UNSUPPORTED");
});
