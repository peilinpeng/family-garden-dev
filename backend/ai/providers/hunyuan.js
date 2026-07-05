"use strict";

const { AppError } = require("../errors");

function withTimeout(promise, timeoutMs) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new AppError("AI_TIMEOUT", "AI 服务响应超时。")), timeoutMs);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

function mapProviderError(error) {
  if (error instanceof AppError) return error;
  const code = String(error?.code || error?.name || "");
  const message = String(error?.message || "");
  if (/Auth|Unauthorized|InvalidCredential|SecretId|Signature/i.test(`${code} ${message}`)) {
    return new AppError("INTERNAL_ERROR", "AI 服务凭据配置错误。", { expose: false, retryable: false, cause: error });
  }
  if (/Limit|Throttl|RequestLimit|429/i.test(`${code} ${message}`)) {
    return new AppError("AI_UPSTREAM_ERROR", "AI 服务当前繁忙。", { retryable: true, cause: error });
  }
  if (/Timeout|timed out|ETIMEDOUT/i.test(`${code} ${message}`)) {
    return new AppError("AI_TIMEOUT", "AI 服务响应超时。", { retryable: true, cause: error });
  }
  return new AppError("AI_UPSTREAM_ERROR", "AI 上游服务暂时不可用。", { retryable: true, cause: error });
}

class HunyuanProvider {
  constructor(config, options = {}) {
    this.config = config;
    this.client = options.client || null;
  }

  _client() {
    if (this.client) return this.client;
    const { secretId, secretKey, region } = this.config;
    if (!secretId || !secretKey) {
      throw new AppError("INTERNAL_ERROR", "缺少混元服务凭据。", { expose: false, retryable: false });
    }
    const { Client } = require("tencentcloud-sdk-nodejs-hunyuan/tencentcloud/services/hunyuan/v20230901/hunyuan_client");
    this.client = new Client({
      credential: { secretId, secretKey },
      region,
      profile: {
        signMethod: "TC3-HMAC-SHA256",
        httpProfile: { reqMethod: "POST", reqTimeout: Math.ceil(this.config.timeoutMs / 1000) },
      },
    });
    return this.client;
  }

  async complete(prompt) {
    const usesVision = Boolean(prompt.imageUrl);
    const model = usesVision ? this.config.visionModel : this.config.textModel;
    if (!model) {
      throw new AppError("INTERNAL_ERROR", `缺少${usesVision ? "图片" : "文字"}模型配置。`, { expose: false, retryable: false });
    }
    const userMessage = usesVision
      ? {
          Role: "user",
          Contents: [
            { Type: "text", Text: prompt.user },
            { Type: "image_url", ImageUrl: { Url: prompt.imageUrl } },
          ],
        }
      : { Role: "user", Content: prompt.user };
    const request = {
      Model: model,
      Stream: false,
      EnableEnhancement: false,
      Temperature: 0.2,
      Messages: [{ Role: "system", Content: prompt.system }, userMessage],
    };
    try {
      const response = await withTimeout(this._client().ChatCompletions(request), this.config.timeoutMs);
      if (response?.ErrorMsg?.Code) {
        const code = Number(response.ErrorMsg.Code);
        if (code === 4001) throw new AppError("AI_TIMEOUT", "AI 服务响应超时。");
        throw new AppError("AI_UPSTREAM_ERROR", "AI 上游返回服务错误。", { expose: false });
      }
      const choice = response?.Choices?.[0];
      if (choice?.FinishReason === "sensitive" || String(choice?.ModerationLevel || "") === "1") {
        throw new AppError("CONTENT_UNSAFE", "模型输出未通过内容安全检查。", { retryable: false });
      }
      const content = choice?.Message?.Content;
      if (typeof content !== "string" || content.trim() === "") {
        throw new AppError("AI_INVALID_OUTPUT", "AI 返回了空内容。", { expose: false });
      }
      return { text: content, provider: "hunyuan", model, upstreamRequestId: response?.RequestId || response?.Id || "" };
    } catch (error) {
      throw mapProviderError(error);
    }
  }
}

module.exports = { HunyuanProvider, mapProviderError, withTimeout };
