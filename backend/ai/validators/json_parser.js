"use strict";

const { AppError } = require("../errors");

function parseJsonOutput(text) {
  if (typeof text !== "string" || text.trim() === "") {
    throw new AppError("AI_INVALID_OUTPUT", "模型返回了空内容。", { expose: false });
  }
  const trimmed = text.trim();
  const fenced = /^```(?:json)?\s*([\s\S]*?)\s*```$/i.exec(trimmed);
  const candidate = fenced ? fenced[1].trim() : trimmed;
  try {
    const parsed = JSON.parse(candidate);
    if (parsed !== null && (typeof parsed !== "object" || Array.isArray(parsed))) {
      throw new Error("root must be object or null payload wrapper");
    }
    return parsed;
  } catch (error) {
    throw new AppError("AI_INVALID_OUTPUT", "模型没有返回可靠的 JSON 对象。", { expose: false, cause: error });
  }
}

module.exports = { parseJsonOutput };
