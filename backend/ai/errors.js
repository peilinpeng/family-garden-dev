"use strict";

const STATUS_BY_CODE = Object.freeze({
  INVALID_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  DATA_NOT_FOUND: 404,
  DATA_CONFLICT: 409,
  IMAGE_UNSUPPORTED: 415,
  CONTENT_UNSAFE: 422,
  RATE_LIMITED: 429,
  UPLOAD_FAILED: 502,
  AI_UPSTREAM_ERROR: 502,
  AI_INVALID_OUTPUT: 502,
  NETWORK_OFFLINE: 503,
  AI_TIMEOUT: 504,
  INTERNAL_ERROR: 500,
});

class AppError extends Error {
  constructor(code, message, options = {}) {
    super(message);
    this.name = "AppError";
    this.code = code;
    this.status = options.status || STATUS_BY_CODE[code] || 500;
    this.retryable = options.retryable ?? ["RATE_LIMITED", "AI_TIMEOUT", "AI_UPSTREAM_ERROR", "AI_INVALID_OUTPUT", "NETWORK_OFFLINE"].includes(code);
    this.expose = options.expose ?? true;
    this.details = options.details;
    this.cause = options.cause;
  }
}

function asAppError(error) {
  if (error instanceof AppError) return error;
  return new AppError("INTERNAL_ERROR", "服务暂时不可用。", { expose: false, cause: error });
}

function errorEnvelope(error, requestId) {
  const appError = asAppError(error);
  const message = appError.expose ? appError.message : "服务暂时不可用。";
  const body = {
    ok: false,
    error: { code: appError.code, message, retryable: appError.retryable },
    meta: { request_id: requestId },
  };
  if (appError.expose && Array.isArray(appError.details) && appError.details.length > 0) {
    body.error.details = appError.details.slice(0, 10).map(String);
  }
  return body;
}

module.exports = { AppError, asAppError, errorEnvelope, STATUS_BY_CODE };
