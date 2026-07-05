"use strict";

const { AppError } = require("./errors");

function intEnv(env, name, fallback, min, max) {
  const raw = env[name];
  const value = raw === undefined || raw === "" ? fallback : Number(raw);
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new AppError("INTERNAL_ERROR", `环境变量 ${name} 配置无效。`, { expose: false });
  }
  return value;
}

function boolEnv(env, name, fallback = false) {
  if (env[name] === undefined || env[name] === "") return fallback;
  return String(env[name]).toLowerCase() === "true";
}

function loadConfig(env = process.env) {
  const config = {
    env: env.NODE_ENV || "development",
    provider: env.AI_PROVIDER || "hunyuan",
    authMode: env.AUTH_MODE || "gateway",
    safetyMode: env.SAFETY_MODE || "tencent",
    dataGatewayUrl: env.DATA_GATEWAY_URL || "",
    secretId: env.TENCENTCLOUD_SECRET_ID || "",
    secretKey: env.TENCENTCLOUD_SECRET_KEY || "",
    region: env.TENCENTCLOUD_REGION || "ap-shanghai",
    textModel: env.HUNYUAN_TEXT_MODEL || "",
    visionModel: env.HUNYUAN_VISION_MODEL || "",
    tmsBizType: env.TMS_BIZ_TYPE || "",
    imsBizType: env.IMS_BIZ_TYPE || "",
    timeoutMs: intEnv(env, "AI_TIMEOUT_MS", 20000, 1000, 120000),
    maxRetries: intEnv(env, "AI_MAX_RETRIES", 1, 0, 3),
    maxBodyBytes: intEnv(env, "AI_MAX_BODY_BYTES", 32768, 1024, 1048576),
    rateLimitWindowMs: intEnv(env, "AI_RATE_LIMIT_WINDOW_MS", 60000, 1000, 3600000),
    rateLimitMax: intEnv(env, "AI_RATE_LIMIT_MAX", 20, 1, 10000),
    maxConcurrency: intEnv(env, "AI_MAX_CONCURRENCY", 8, 1, 1000),
    circuitFailureThreshold: intEnv(env, "AI_CIRCUIT_FAILURE_THRESHOLD", 5, 1, 100),
    circuitResetMs: intEnv(env, "AI_CIRCUIT_RESET_MS", 30000, 1000, 3600000),
    idempotencyTtlMs: intEnv(env, "AI_IDEMPOTENCY_TTL_MS", 300000, 1000, 86400000),
    allowInsecureLocal: boolEnv(env, "ALLOW_INSECURE_LOCAL", false),
  };

  if (!new Set(["development", "test", "production"]).has(config.env)) {
    throw new AppError("INTERNAL_ERROR", "NODE_ENV 配置无效。", { expose: false });
  }
  if (config.provider !== "hunyuan") {
    throw new AppError("INTERNAL_ERROR", "AI_PROVIDER 配置无效。", { expose: false });
  }
  if (!new Set(["gateway", "disabled"]).has(config.authMode)) {
    throw new AppError("INTERNAL_ERROR", "AUTH_MODE 配置无效。", { expose: false });
  }
  if (!new Set(["tencent", "local"]).has(config.safetyMode)) {
    throw new AppError("INTERNAL_ERROR", "SAFETY_MODE 配置无效。", { expose: false });
  }
  if (config.env === "production" && (config.authMode === "disabled" || config.safetyMode === "local")) {
    throw new AppError("INTERNAL_ERROR", "生产环境禁止关闭鉴权或使用本地安全模式。", { expose: false });
  }
  if ((config.authMode === "disabled" || config.safetyMode === "local") && !config.allowInsecureLocal && config.env !== "test") {
    throw new AppError("INTERNAL_ERROR", "非测试环境启用不安全本地模式需要显式确认。", { expose: false });
  }
  return config;
}

module.exports = { loadConfig };
