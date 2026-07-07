"use strict";

const SECRET_KEY = /(authorization|token|secret|password|credential|cookie)/i;
const PRIVATE_KEY = /(raw_text|content|prompt|image_url|fileurl|file_url)/i;

function sanitizeUrl(value) {
  try {
    const url = new URL(value);
    return `${url.protocol}//${url.host}${url.pathname}`;
  } catch (_) {
    return "[REDACTED_URL]";
  }
}

function redact(value, key = "", depth = 0) {
  if (depth > 5) return "[TRUNCATED]";
  if (SECRET_KEY.test(key)) return "[REDACTED]";
  if (PRIVATE_KEY.test(key)) {
    if (/url/i.test(key) && typeof value === "string") return sanitizeUrl(value);
    return "[REDACTED_PRIVATE_CONTENT]";
  }
  if (Array.isArray(value)) return value.slice(0, 20).map((item) => redact(item, key, depth + 1));
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([childKey, child]) => [childKey, redact(child, childKey, depth + 1)]));
  }
  if (typeof value === "string" && value.length > 240) return `${value.slice(0, 240)}…`;
  return value;
}

function createLogger(sink = console) {
  function write(level, event, fields = {}) {
    const payload = JSON.stringify({ event, ...redact(fields) });
    const fn = sink[level] || sink.log;
    fn.call(sink, payload);
  }
  return {
    info: (event, fields) => write("info", event, fields),
    warn: (event, fields) => write("warn", event, fields),
    error: (event, fields) => write("error", event, fields),
  };
}

module.exports = { createLogger, redact };
