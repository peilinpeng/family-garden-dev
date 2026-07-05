"use strict";

const https = require("node:https");
const { AppError } = require("../errors");

function postJson(urlString, body, headers, timeoutMs) {
  return new Promise((resolve, reject) => {
    let url;
    try {
      url = new URL(urlString);
    } catch (error) {
      reject(new AppError("INTERNAL_ERROR", "身份服务地址无效。", { expose: false, cause: error }));
      return;
    }
    if (url.protocol !== "https:") {
      reject(new AppError("INTERNAL_ERROR", "身份服务必须使用 HTTPS。", { expose: false }));
      return;
    }
    const payload = JSON.stringify(body);
    const request = https.request({
      protocol: url.protocol,
      hostname: url.hostname,
      port: url.port || 443,
      path: `${url.pathname}${url.search}`,
      method: "POST",
      headers: { "content-type": "application/json", "content-length": Buffer.byteLength(payload), ...headers },
      timeout: timeoutMs,
    }, (response) => {
      const chunks = [];
      let size = 0;
      response.on("data", (chunk) => {
        size += chunk.length;
        if (size > 65536) {
          request.destroy(new Error("identity response too large"));
          return;
        }
        chunks.push(chunk);
      });
      response.on("end", () => {
        try {
          resolve(JSON.parse(Buffer.concat(chunks).toString("utf8")));
        } catch (error) {
          reject(new AppError("AI_UPSTREAM_ERROR", "身份服务返回无效数据。", { expose: false, cause: error }));
        }
      });
    });
    request.on("timeout", () => request.destroy(new Error("identity timeout")));
    request.on("error", (error) => reject(new AppError("AI_UPSTREAM_ERROR", "身份服务暂时不可用。", { expose: false, cause: error })));
    request.end(payload);
  });
}

class DataGatewayIdentityClient {
  constructor(config, options = {}) {
    this.config = config;
    this.transport = options.transport || postJson;
  }

  async authorize(authorization, requestId) {
    if (this.config.authMode === "disabled") {
      return { member_id: "local-test-member", family_id: "local-test-family", role: "player" };
    }
    if (!authorization || !/^Bearer\s+\S+$/i.test(authorization)) {
      throw new AppError("UNAUTHORIZED", "缺少有效的成员身份。", { retryable: false });
    }
    if (!this.config.dataGatewayUrl) {
      throw new AppError("INTERNAL_ERROR", "身份服务尚未配置。", { expose: false, retryable: false });
    }
    const response = await this.transport(
      this.config.dataGatewayUrl,
      { action: "whoami" },
      { authorization, "x-request-id": requestId },
      Math.min(this.config.timeoutMs, 10000),
    );
    if (!response?.ok) {
      if (Number(response?.code) !== 401 && String(response?.error || "") !== "unauthorized") {
        throw new AppError("AI_UPSTREAM_ERROR", "身份服务暂时不可用。", { expose: false });
      }
      throw new AppError("UNAUTHORIZED", "成员身份无效或已失效。", { retryable: false });
    }
    if (!response.member_id || !response.family_id) throw new AppError("AI_UPSTREAM_ERROR", "身份服务返回缺少必要字段。", { expose: false });
    return {
      member_id: String(response.member_id),
      family_id: String(response.family_id),
      role: String(response.role || ""),
    };
  }
}

module.exports = { DataGatewayIdentityClient, postJson };
