"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { AppError } = require("./errors");
const { parseJsonOutput } = require("./validators/json_parser");
const { retry, stableHash } = require("./services/protection");

const ROUTES = Object.freeze({
  "generate-memory-card": {
    prompt: require("./prompts/memory_card"),
    mock: "memory_card_mock.json",
  },
  "generate-bottle-question": {
    prompt: require("./prompts/bottle_question"),
    mock: "bottle_question_mock.json",
  },
  "generate-kitchen-dish": {
    prompt: require("./prompts/kitchen_dish"),
    mock: "kitchen_dish_mock.json",
  },
  "analyze-room-photo": {
    prompt: require("./prompts/room_analysis"),
    mock: "room_analysis_mock.json",
  },
  "cross-memory-link": {
    prompt: require("./prompts/memory_link"),
    mock: "cross_memory_link_mock.json",
  },
  "moderate-user-content": {
    moderationOnly: true,
  },
});

const FALLBACK_CODES = new Set(["AI_TIMEOUT", "AI_UPSTREAM_ERROR"]);

function resultType(route, data) {
  if (data === null) return "empty";
  if (route === "cross-memory-link" && Array.isArray(data?.links) && data.links.length === 0) return "empty";
  return "complete";
}

function repairReasonFrom(error) {
  const details = Array.isArray(error?.details) ? error.details.map(String).slice(0, 6) : [];
  return (details.length > 0 ? details.join("；") : "JSON 解析或输出校验失败").slice(0, 600);
}

class AiRouter {
  constructor(options) {
    this.config = options.config;
    this.provider = options.provider;
    this.identity = options.identity;
    this.safety = options.safety;
    this.validator = options.validator;
    this.protection = options.protection;
    this.logger = options.logger;
    this.sleep = options.sleep;
    this.mocks = options.mocks || this._loadMocks();
  }

  _loadMocks() {
    const mockDir = [path.join(__dirname, "..", "mocks"), path.join(__dirname, "mocks")]
      .find((candidate) => fs.existsSync(candidate));
    if (!mockDir) throw new AppError("INTERNAL_ERROR", "fallback 数据未包含在部署包中。", { expose: false });
    return Object.fromEntries(Object.entries(ROUTES).filter(([, definition]) => definition.mock).map(([route, definition]) => [
      route,
      JSON.parse(fs.readFileSync(path.join(mockDir, definition.mock), "utf8")),
    ]));
  }

  async handle(route, payload, context) {
    if (!ROUTES[route]) throw new AppError("INVALID_REQUEST", "未知 AI 路由。", { details: [route] });
    this.validator.validateRequest(route, payload);
    const identity = await this.identity.authorize(context.authorization, context.requestId);
    const modelPayload = await this._resolveImagePayload(payload, context);
    await this.safety.inspectInput(modelPayload, context.requestId);
    const hash = stableHash({ route, payload, memberId: identity.member_id });
    return this.protection.idempotency.run(`${identity.member_id}:${context.requestId}`, hash, async () => {
      this.protection.rateLimiter.consume(identity.member_id);
      if (ROUTES[route].moderationOnly) return this._moderationResponse(context);
      return this.protection.semaphore.run(() => this._generate(route, modelPayload, context, payload));
    });
  }

  async _resolveImagePayload(payload, context) {
    if (!payload.upload_id) return payload;
    if (!this.identity.resolveImage) {
      throw new AppError("INTERNAL_ERROR", "身份服务不支持受控图片解析。", { expose: false, retryable: false });
    }
    const image = await this.identity.resolveImage(context.authorization, payload.upload_id, context.requestId);
    return { ...payload, image_url: image.image_url };
  }

  _moderationResponse(context) {
    const response = {
      ok: true,
      data: { approved: true, safety_note: "用户确认内容已通过安全检查。" },
      meta: {
        request_id: context.requestId,
        provider: "content-safety",
        model: this.config.safetyMode,
        prompt_version: "user-content-safety-v1",
        source: "ai",
        result: "complete",
      },
    };
    this.validator.validateResponse("moderate-user-content", response, {});
    return response;
  }

  async _providerCall(prompt, route) {
    return this.protection.circuitBreaker.run(() => retry(
      () => this.provider.complete(prompt, { route }),
      this.config.maxRetries,
      { sleep: this.sleep },
    ));
  }

  async _generate(route, payload, context, requestPayload = payload) {
    const definition = ROUTES[route];
    let lastError;
    let repairReason = "";
    for (let attempt = 0; attempt < 2; attempt += 1) {
      try {
        const prompt = definition.prompt.build(payload, repairReason);
        const providerResult = await this._providerCall(prompt, route);
        const data = parseJsonOutput(providerResult.text);
        const response = {
          ok: true,
          data,
          meta: {
            request_id: context.requestId,
            provider: providerResult.provider,
            model: providerResult.model,
            prompt_version: definition.prompt.version,
            source: "ai",
            result: resultType(route, data),
          },
        };
        this.validator.validateResponse(route, response, requestPayload);
        await this.safety.inspectOutput(data, context.requestId);
        return response;
      } catch (error) {
        lastError = error;
        if (error?.code !== "AI_INVALID_OUTPUT" || attempt === 1) break;
        repairReason = repairReasonFrom(error);
        this.logger.warn("ai_output_repair", { request_id: context.requestId, route, code: error.code });
      }
    }
    if (FALLBACK_CODES.has(lastError?.code)) return this._fallback(route, payload, context, lastError.code);
    throw lastError;
  }

  async _fallback(route, payload, context, reason) {
    const data = structuredClone(this.mocks[route]);
    if (route === "cross-memory-link") {
      data.links = [];
      data.safety_note = "AI 服务暂时不可用，未创建未经验证的跨记忆连线。";
    }
    await this.safety.inspectOutput(data, context.requestId);
    const response = {
      ok: true,
      data,
      meta: {
        request_id: context.requestId,
        provider: "mock",
        model: "mock",
        prompt_version: ROUTES[route].prompt.version,
        source: "fallback",
        result: resultType(route, data),
        fallback_reason: reason,
      },
    };
    this.validator.validateResponse(route, response, payload);
    this.logger.warn("ai_fallback", { request_id: context.requestId, route, reason });
    return response;
  }
}

module.exports = { AiRouter, ROUTES, FALLBACK_CODES, resultType, repairReasonFrom };
