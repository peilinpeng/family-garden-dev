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
  "analyze-room-photo": {
    prompt: require("./prompts/room_analysis"),
    mock: "room_analysis_mock.json",
  },
  "cross-memory-link": {
    prompt: require("./prompts/memory_link"),
    mock: "cross_memory_link_mock.json",
  },
});

const FALLBACK_CODES = new Set(["AI_TIMEOUT", "AI_UPSTREAM_ERROR"]);

function resultType(route, data) {
  if (data === null) return "empty";
  if (route === "cross-memory-link" && Array.isArray(data?.links) && data.links.length === 0) return "empty";
  return "complete";
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
    return Object.fromEntries(Object.entries(ROUTES).map(([route, definition]) => [
      route,
      JSON.parse(fs.readFileSync(path.join(mockDir, definition.mock), "utf8")),
    ]));
  }

  async handle(route, payload, context) {
    if (!ROUTES[route]) throw new AppError("INVALID_REQUEST", "未知 AI 路由。", { details: [route] });
    this.validator.validateRequest(route, payload);
    const identity = await this.identity.authorize(context.authorization, context.requestId);
    await this.safety.inspectInput(payload, context.requestId);
    const hash = stableHash({ route, payload, memberId: identity.member_id });
    return this.protection.idempotency.run(context.requestId, hash, async () => {
      this.protection.rateLimiter.consume(identity.member_id);
      return this.protection.semaphore.run(() => this._generate(route, payload, context));
    });
  }

  async _providerCall(prompt) {
    return this.protection.circuitBreaker.run(() => retry(
      () => this.provider.complete(prompt),
      this.config.maxRetries,
      { sleep: this.sleep },
    ));
  }

  async _generate(route, payload, context) {
    const definition = ROUTES[route];
    let lastError;
    for (let attempt = 0; attempt < 2; attempt += 1) {
      try {
        const prompt = definition.prompt.build(payload, attempt === 1 ? "JSON 解析或 Schema 校验失败" : "");
        const providerResult = await this._providerCall(prompt);
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
        this.validator.validateResponse(route, response);
        await this.safety.inspectOutput(data, context.requestId);
        return response;
      } catch (error) {
        lastError = error;
        if (error?.code !== "AI_INVALID_OUTPUT" || attempt === 1) break;
        this.logger.warn("ai_output_repair", { request_id: context.requestId, route, code: error.code });
      }
    }
    if (FALLBACK_CODES.has(lastError?.code)) return this._fallback(route, context, lastError.code);
    throw lastError;
  }

  async _fallback(route, context, reason) {
    const data = structuredClone(this.mocks[route]);
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
    this.validator.validateResponse(route, response);
    this.logger.warn("ai_fallback", { request_id: context.requestId, route, reason });
    return response;
  }
}

module.exports = { AiRouter, ROUTES, FALLBACK_CODES, resultType };
