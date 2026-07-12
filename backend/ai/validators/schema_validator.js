"use strict";

const fs = require("node:fs");
const path = require("node:path");
const Ajv = require("ajv/dist/2020");
const addFormats = require("ajv-formats");
const { AppError } = require("../errors");

const ROUTES = Object.freeze([
  "generate-memory-card",
  "generate-bottle-question",
  "analyze-room-photo",
  "cross-memory-link",
  "moderate-user-content",
]);

function loadSchemas(schemaDir = path.join(__dirname, "..", "schemas")) {
  const ajv = new Ajv({ allErrors: true, strict: true, strictRequired: false });
  addFormats(ajv);
  const files = fs.readdirSync(schemaDir).filter((name) => name.endsWith(".schema.json")).sort();
  for (const file of files) {
    const schema = JSON.parse(fs.readFileSync(path.join(schemaDir, file), "utf8"));
    ajv.addSchema(schema);
  }
  const validators = {};
  for (const route of ROUTES) {
    validators[route] = {
      request: ajv.getSchema(`https://family-garden.local/schemas/${route}.request.schema.json`),
      response: ajv.getSchema(`https://family-garden.local/schemas/${route}.response.schema.json`),
    };
    if (!validators[route].request || !validators[route].response) {
      throw new Error(`Schema 缺失: ${route}`);
    }
  }
  return validators;
}

function formatErrors(errors = []) {
  return errors.slice(0, 10).map((error) => `${error.instancePath || "/"} ${error.message}`);
}

function validateMemoryLinks(response, request) {
  if (!response?.ok || !Array.isArray(response?.data?.links)) return;
  const allowedIds = new Set([
    request?.memory_id,
    ...(Array.isArray(request?.candidates) ? request.candidates.map((candidate) => candidate?.memory_id) : []),
  ].filter(Boolean));
  const pairs = new Set();
  const errors = [];

  for (const link of response.data.links) {
    const a = String(link?.memory_id_a || "");
    const b = String(link?.memory_id_b || "");
    if (a === b) errors.push(`记忆不能与自身建立连线: ${a}`);
    if (allowedIds.size > 0 && (!allowedIds.has(a) || !allowedIds.has(b))) {
      errors.push(`连线引用了输入中不存在的 memory_id: ${a}, ${b}`);
    }
    const pair = [a, b].sort().join("\u0000");
    if (pairs.has(pair)) errors.push(`同一对记忆只能保留一条连线: ${a}, ${b}`);
    pairs.add(pair);
  }

  if (errors.length > 0) {
    throw new AppError("AI_INVALID_OUTPUT", "模型输出不符合跨记忆语义约束。", {
      details: errors.slice(0, 10),
    });
  }
}

class SchemaValidator {
  constructor(validators = loadSchemas()) {
    this.validators = validators;
  }

  assertRoute(route) {
    if (!this.validators[route]) throw new AppError("INVALID_REQUEST", "未知 AI 路由。", { details: [route] });
  }

  validateRequest(route, payload) {
    this.assertRoute(route);
    const validate = this.validators[route].request;
    if (!validate(payload)) {
      throw new AppError("INVALID_REQUEST", "请求不符合接口契约。", { details: formatErrors(validate.errors) });
    }
  }

  validateResponse(route, response, request) {
    this.assertRoute(route);
    const validate = this.validators[route].response;
    if (!validate(response)) {
      throw new AppError("AI_INVALID_OUTPUT", "模型输出不符合接口契约。", { details: formatErrors(validate.errors) });
    }
    if (route === "cross-memory-link") validateMemoryLinks(response, request);
  }
}

module.exports = { SchemaValidator, loadSchemas, ROUTES, validateMemoryLinks };
