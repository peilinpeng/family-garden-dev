"use strict";

const { assertSafeText, assertSafeImageUrl, textFromPayload } = require("./local_policy");
const { TencentModeration } = require("./tencent_moderation");

class SafetyService {
  constructor(config, options = {}) {
    this.config = config;
    this.remote = options.remote || (config.safetyMode === "tencent" ? new TencentModeration(config) : null);
  }

  async inspectInput(payload, requestId) {
    const text = textFromPayload(payload);
    assertSafeText(text);
    assertSafeImageUrl(payload.image_url || "", this.config.imageAllowedHosts || []);
    if (this.remote) {
      await Promise.all([
        this.remote.inspectText(text, requestId),
        this.remote.inspectImage(payload.image_url || "", requestId),
      ]);
    }
  }

  async inspectOutput(data, requestId) {
    const text = data === null ? "" : JSON.stringify(data);
    assertSafeText(text);
    if (this.remote) await this.remote.inspectText(text, requestId);
  }
}

module.exports = { SafetyService };
