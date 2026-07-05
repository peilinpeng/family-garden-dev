"use strict";

const { AppError } = require("../errors");

function clientConfig(config) {
  if (!config.secretId || !config.secretKey) {
    throw new AppError("INTERNAL_ERROR", "缺少内容安全服务凭据。", { expose: false, retryable: false });
  }
  return {
    credential: { secretId: config.secretId, secretKey: config.secretKey },
    region: config.region,
    profile: { signMethod: "TC3-HMAC-SHA256", httpProfile: { reqMethod: "POST", reqTimeout: Math.ceil(config.timeoutMs / 1000) } },
  };
}

function assertPass(response, kind) {
  const suggestion = String(response?.Suggestion || "").toLowerCase();
  if (suggestion !== "pass") {
    throw new AppError("CONTENT_UNSAFE", `${kind}未通过内容安全检查。`, {
      retryable: false,
      details: [String(response?.Label || "risk")],
    });
  }
}

function moderationDataId(value) {
  return String(value || "request").replace(/[^A-Za-z0-9_@#-]/g, "_").slice(0, 64);
}

class TencentModeration {
  constructor(config, options = {}) {
    this.config = config;
    this.textClient = options.textClient || null;
    this.imageClient = options.imageClient || null;
  }

  _textClient() {
    if (!this.textClient) {
      const { Client } = require("tencentcloud-sdk-nodejs-tms/tencentcloud/services/tms/v20201229/tms_client");
      this.textClient = new Client(clientConfig(this.config));
    }
    return this.textClient;
  }

  _imageClient() {
    if (!this.imageClient) {
      const { Client } = require("tencentcloud-sdk-nodejs-ims/tencentcloud/services/ims/v20201229/ims_client");
      this.imageClient = new Client(clientConfig(this.config));
    }
    return this.imageClient;
  }

  async inspectText(text, dataId) {
    if (!text) return;
    try {
      const response = await this._textClient().TextModeration({
        Content: Buffer.from(text, "utf8").toString("base64"),
        DataId: moderationDataId(dataId),
        SourceLanguage: "zh",
        Type: "TEXT",
        ...(this.config.tmsBizType ? { BizType: this.config.tmsBizType } : {}),
      });
      assertPass(response, "文本");
    } catch (error) {
      if (error instanceof AppError) throw error;
      throw new AppError("AI_UPSTREAM_ERROR", "文本内容安全服务暂时不可用。", { expose: false, cause: error });
    }
  }

  async inspectImage(imageUrl, dataId) {
    if (!imageUrl) return;
    try {
      const response = await this._imageClient().ImageModeration({
        FileUrl: imageUrl,
        DataId: moderationDataId(dataId),
        Type: "IMAGE",
        ...(this.config.imsBizType ? { BizType: this.config.imsBizType } : {}),
      });
      assertPass(response, "图片");
    } catch (error) {
      if (error instanceof AppError) throw error;
      throw new AppError("AI_UPSTREAM_ERROR", "图片内容安全服务暂时不可用。", { expose: false, cause: error });
    }
  }
}

module.exports = { TencentModeration, assertPass, moderationDataId };
