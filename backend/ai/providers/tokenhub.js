"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { AppError } = require("../errors");

const TEXT_ROUTES = new Set([
  "generate-memory-card",
  "generate-bottle-question",
  "generate-kitchen-dish",
  "cross-memory-link",
]);
const SCHEMA_ROUTES = new Set([...TEXT_ROUTES, "analyze-room-photo"]);
const MAX_UPSTREAM_RESPONSE_BYTES = 2 * 1024 * 1024;

function withTimeout(promise, timeoutMs) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new AppError("AI_TIMEOUT", "AI 服务响应超时。", { retryable: true })), timeoutMs);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

function mapProviderError(error) {
  if (error instanceof AppError) {
    if (!error.stage) error.stage = "tokenhub";
    return error;
  }
  const code = String(error?.code || error?.name || "");
  const message = String(error?.message || "");
  if (/Abort|Timeout|timed out|ETIMEDOUT/i.test(`${code} ${message}`)) {
    return new AppError("AI_TIMEOUT", "AI 服务响应超时。", { retryable: true, cause: error, stage: "tokenhub" });
  }
  return new AppError("AI_UPSTREAM_ERROR", "AI 上游服务暂时不可用。", { retryable: true, cause: error, stage: "tokenhub" });
}

function rewriteCommonRefs(value) {
  if (Array.isArray(value)) return value.map(rewriteCommonRefs);
  if (!value || typeof value !== "object") {
    return typeof value === "string" ? value.replace("common.schema.json#/$defs/", "#/$defs/") : value;
  }
  return Object.fromEntries(Object.entries(value).map(([key, child]) => [key, rewriteCommonRefs(child)]));
}

function loadDataSchema(route, schemaDir = path.join(__dirname, "..", "schemas")) {
  if (!SCHEMA_ROUTES.has(route)) return null;
  const response = JSON.parse(fs.readFileSync(path.join(schemaDir, `${route}.response.schema.json`), "utf8"));
  const common = JSON.parse(fs.readFileSync(path.join(schemaDir, "common.schema.json"), "utf8"));
  const data = structuredClone(response.oneOf[0].properties.data);
  return { ...rewriteCommonRefs(data), $defs: rewriteCommonRefs(common.$defs) };
}

function endpoint(baseUrl) {
  let url;
  try {
    url = new URL(baseUrl);
  } catch (error) {
    throw new AppError("INTERNAL_ERROR", "TokenHub 地址配置无效。", { expose: false, retryable: false, cause: error });
  }
  if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash) {
    throw new AppError("INTERNAL_ERROR", "TokenHub 地址配置无效。", { expose: false, retryable: false });
  }
  return `${url.toString().replace(/\/$/, "")}/chat/completions`;
}

function errorFromStatus(status, payload) {
  const upstreamCode = String(payload?.error?.code || payload?.code || "");
  if (status === 401 || status === 403) {
    return new AppError("INTERNAL_ERROR", "TokenHub 凭据或授权范围配置错误。", { expose: false, retryable: false });
  }
  if (status === 408 || status === 504) {
    return new AppError("AI_TIMEOUT", "AI 服务响应超时。", { retryable: true });
  }
  if (status === 429) {
    return new AppError("AI_UPSTREAM_ERROR", "AI 服务当前繁忙或额度已用尽。", { retryable: true });
  }
  if (status >= 400 && status < 500) {
    const configurationError = /invalid.?model|20033/i.test(upstreamCode);
    return new AppError(configurationError ? "INTERNAL_ERROR" : "AI_UPSTREAM_ERROR", "TokenHub 请求配置错误。", {
      expose: false,
      retryable: false,
    });
  }
  return new AppError("AI_UPSTREAM_ERROR", "AI 上游服务暂时不可用。", { retryable: true });
}

class TokenHubProvider {
  constructor(config, options = {}) {
    this.config = config;
    this.transport = options.transport || globalThis.fetch;
    this.schemas = new Map();
  }

  _responseFormat(route, usesVision) {
    if (!SCHEMA_ROUTES.has(route) || (usesVision && !this.config.visionJsonSchema)) return undefined;
    if (!this.schemas.has(route)) this.schemas.set(route, loadDataSchema(route));
    return {
      type: "json_schema",
      json_schema: {
        name: route.replaceAll("-", "_"),
        schema: this.schemas.get(route),
      },
    };
  }

  async complete(prompt, options = {}) {
    const usesVision = Boolean(prompt.imageUrl);
    const model = usesVision ? this.config.visionModel : this.config.textModel;
    if (!this.config.tokenHubApiKey) {
      throw new AppError("INTERNAL_ERROR", "缺少 TokenHub API Key。", { expose: false, retryable: false });
    }
    if (!model) {
      throw new AppError("INTERNAL_ERROR", `缺少${usesVision ? "图片" : "文字"}模型配置。`, { expose: false, retryable: false });
    }
    if (typeof this.transport !== "function") {
      throw new AppError("INTERNAL_ERROR", "当前运行时不支持 HTTPS 请求。", { expose: false, retryable: false });
    }

    const messages = usesVision
      ? [
          { role: "system", content: prompt.system },
          {
            role: "user",
            content: [
              { type: "image_url", image_url: { url: prompt.imageUrl } },
              { type: "text", text: prompt.user },
            ],
          },
        ]
      : [
          { role: "system", content: prompt.system },
          { role: "user", content: prompt.user },
        ];
    const body = {
      model,
      messages,
      stream: false,
      temperature: 0.2,
      max_tokens: usesVision ? this.config.visionMaxTokens : this.config.textMaxTokens,
    };
    const responseFormat = this._responseFormat(options.route, usesVision);
    if (responseFormat) body.response_format = responseFormat;

    try {
      const controller = new AbortController();
      let response;
      let raw;
      try {
        [response, raw] = await withTimeout((async () => {
          const result = await this.transport(endpoint(this.config.tokenHubBaseUrl), {
            method: "POST",
            headers: {
              authorization: `Bearer ${this.config.tokenHubApiKey}`,
              "content-type": "application/json",
            },
            body: JSON.stringify(body),
            signal: controller.signal,
          });
          return [result, await result.text()];
        })(), this.config.timeoutMs);
      } finally {
        controller.abort();
      }
      if (Buffer.byteLength(raw) > MAX_UPSTREAM_RESPONSE_BYTES) {
        throw new AppError("AI_UPSTREAM_ERROR", "AI 上游响应过大。", { expose: false, retryable: true });
      }
      let payload;
      try {
        payload = raw ? JSON.parse(raw) : {};
      } catch (error) {
        throw new AppError("AI_UPSTREAM_ERROR", "AI 上游返回了无法解析的响应。", { expose: false, retryable: true, cause: error });
      }
      if (!response.ok) throw errorFromStatus(response.status, payload);
      const choice = payload?.choices?.[0];
      if (["content_filter", "sensitive"].includes(String(choice?.finish_reason || ""))) {
        throw new AppError("CONTENT_UNSAFE", "模型输出未通过内容安全检查。", { retryable: false });
      }
      if (choice?.finish_reason === "length") {
        throw new AppError("AI_INVALID_OUTPUT", "AI 输出因长度限制被截断。", { expose: false, retryable: false });
      }
      const content = choice?.message?.content;
      if (typeof content !== "string" || content.trim() === "") {
        throw new AppError("AI_INVALID_OUTPUT", "AI 返回了空内容。", { expose: false, retryable: false });
      }
      return {
        text: content,
        provider: "tokenhub",
        model: payload.model || model,
        upstreamRequestId: payload.id || response.headers?.get?.("x-request-id") || "",
      };
    } catch (error) {
      throw mapProviderError(error);
    }
  }
}

module.exports = {
  TokenHubProvider,
  MAX_UPSTREAM_RESPONSE_BYTES,
  TEXT_ROUTES,
  SCHEMA_ROUTES,
  endpoint,
  errorFromStatus,
  loadDataSchema,
  mapProviderError,
  withTimeout,
};
