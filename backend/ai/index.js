"use strict";

const crypto = require("node:crypto");
const { loadConfig } = require("./config");
const { AppError, errorEnvelope } = require("./errors");
const { createLogger } = require("./logger");
const { SchemaValidator } = require("./validators/schema_validator");
const { HunyuanProvider } = require("./providers/hunyuan");
const { SafetyService } = require("./safety");
const { DataGatewayIdentityClient } = require("./services/identity_client");
const { createProtection } = require("./services/protection");
const { AiRouter } = require("./router");

function lowerHeaders(headers = {}) {
  return Object.fromEntries(Object.entries(headers).map(([key, value]) => [key.toLowerCase(), String(value)]));
}

function requestIdFrom(headers) {
  const supplied = headers["x-request-id"] || "";
  if (/^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(supplied)) return supplied;
  return `req_${crypto.randomUUID()}`;
}

function parseEvent(event, maxBodyBytes) {
  const headers = lowerHeaders(event?.headers || {});
  const method = String(event?.httpMethod || event?.requestContext?.http?.method || "POST").toUpperCase();
  if (method !== "POST") throw new AppError("INVALID_REQUEST", "只允许 POST 请求。", { retryable: false });
  const contentType = headers["content-type"] || "application/json";
  if (!contentType.toLowerCase().startsWith("application/json")) {
    throw new AppError("INVALID_REQUEST", "Content-Type 必须是 application/json。", { retryable: false });
  }

  let body = event?.body ?? event ?? {};
  if (typeof body === "string") {
    const raw = event?.isBase64Encoded ? Buffer.from(body, "base64").toString("utf8") : body;
    if (Buffer.byteLength(raw) > maxBodyBytes) throw new AppError("INVALID_REQUEST", "请求体过大。", { retryable: false });
    try {
      body = JSON.parse(raw);
    } catch (error) {
      throw new AppError("INVALID_REQUEST", "请求体不是合法 JSON。", { retryable: false, cause: error });
    }
  } else if (Buffer.byteLength(JSON.stringify(body)) > maxBodyBytes) {
    throw new AppError("INVALID_REQUEST", "请求体过大。", { retryable: false });
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) throw new AppError("INVALID_REQUEST", "请求体必须是 JSON 对象。");

  const rawPath = String(event?.path || event?.rawPath || event?.requestContext?.path || "");
  const pathMatch = /\/api\/ai\/([a-z-]+)\/?$/.exec(rawPath);
  const action = pathMatch?.[1] || body.action || "";
  const payload = { ...body };
  delete payload.action;
  return { headers, method, route: String(action), payload };
}

function createApp(config = loadConfig(), overrides = {}) {
  const logger = overrides.logger || createLogger();
  const validator = overrides.validator || new SchemaValidator();
  const provider = overrides.provider || new HunyuanProvider(config);
  const identity = overrides.identity || new DataGatewayIdentityClient(config);
  const safety = overrides.safety || new SafetyService(config);
  const protection = overrides.protection || createProtection(config, overrides.protectionOptions);
  const router = overrides.router || new AiRouter({ config, provider, identity, safety, validator, protection, logger, sleep: overrides.sleep, mocks: overrides.mocks });

  return async function handle(event) {
    const startedAt = Date.now();
    const headers = lowerHeaders(event?.headers || {});
    const requestId = requestIdFrom(headers);
    try {
      const request = parseEvent(event, config.maxBodyBytes);
      logger.info("ai_request_started", { request_id: requestId, route: request.route });
      const response = await router.handle(request.route, request.payload, {
        requestId,
        authorization: request.headers.authorization || "",
      });
      logger.info("ai_request_completed", { request_id: requestId, route: request.route, source: response.meta.source, duration_ms: Date.now() - startedAt });
      return response;
    } catch (error) {
      const response = errorEnvelope(error, requestId);
      logger.warn("ai_request_failed", { request_id: requestId, code: response.error.code, duration_ms: Date.now() - startedAt });
      return response;
    }
  };
}

let defaultApp;
exports.main = async (event) => {
  if (!defaultApp) defaultApp = createApp();
  return defaultApp(event);
};
exports.createApp = createApp;
exports.parseEvent = parseEvent;
exports.requestIdFrom = requestIdFrom;
