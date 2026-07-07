"use strict";

const crypto = require("node:crypto");
const { AppError } = require("../errors");

function stableHash(value) {
  return crypto.createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

class RateLimiter {
  constructor(limit, windowMs, clock = () => Date.now()) {
    this.limit = limit;
    this.windowMs = windowMs;
    this.clock = clock;
    this.buckets = new Map();
  }

  consume(key) {
    const now = this.clock();
    const bucket = this.buckets.get(key);
    if (!bucket || now - bucket.startedAt >= this.windowMs) {
      this.buckets.set(key, { startedAt: now, count: 1 });
      return;
    }
    if (bucket.count >= this.limit) throw new AppError("RATE_LIMITED", "请求过于频繁，请稍后重试。", { retryable: true });
    bucket.count += 1;
  }
}

class Semaphore {
  constructor(max) {
    this.max = max;
    this.active = 0;
  }

  async run(task) {
    if (this.active >= this.max) throw new AppError("RATE_LIMITED", "服务当前繁忙，请稍后重试。", { retryable: true });
    this.active += 1;
    try {
      return await task();
    } finally {
      this.active -= 1;
    }
  }
}

class CircuitBreaker {
  constructor(threshold, resetMs, clock = () => Date.now()) {
    this.threshold = threshold;
    this.resetMs = resetMs;
    this.clock = clock;
    this.failures = 0;
    this.openedAt = 0;
  }

  async run(task) {
    const now = this.clock();
    if (this.openedAt && now - this.openedAt < this.resetMs) {
      throw new AppError("AI_UPSTREAM_ERROR", "AI 服务暂时熔断。", { retryable: true });
    }
    if (this.openedAt) {
      this.openedAt = 0;
      this.failures = 0;
    }
    try {
      const result = await task();
      this.failures = 0;
      return result;
    } catch (error) {
      if (["AI_TIMEOUT", "AI_UPSTREAM_ERROR"].includes(error?.code)) {
        this.failures += 1;
        if (this.failures >= this.threshold) this.openedAt = this.clock();
      }
      throw error;
    }
  }
}

class IdempotencyStore {
  constructor(ttlMs, clock = () => Date.now()) {
    this.ttlMs = ttlMs;
    this.clock = clock;
    this.entries = new Map();
  }

  async run(key, hash, task) {
    const now = this.clock();
    const existing = this.entries.get(key);
    if (existing && now - existing.createdAt < this.ttlMs) {
      if (existing.hash !== hash) throw new AppError("DATA_CONFLICT", "同一 request ID 不能用于不同请求。", { retryable: false });
      return existing.promise;
    }
    if (existing) this.entries.delete(key);
    const promise = Promise.resolve().then(task);
    this.entries.set(key, { hash, createdAt: now, promise });
    try {
      return await promise;
    } catch (error) {
      this.entries.delete(key);
      throw error;
    }
  }
}

async function retry(task, maxRetries, options = {}) {
  const sleep = options.sleep || ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
  let attempt = 0;
  while (true) {
    try {
      return await task(attempt);
    } catch (error) {
      if (attempt >= maxRetries || !["AI_TIMEOUT", "AI_UPSTREAM_ERROR"].includes(error?.code)) throw error;
      attempt += 1;
      await sleep(Math.min(100 * (2 ** (attempt - 1)), 1000));
    }
  }
}

function createProtection(config, options = {}) {
  return {
    rateLimiter: options.rateLimiter || new RateLimiter(config.rateLimitMax, config.rateLimitWindowMs, options.clock),
    semaphore: options.semaphore || new Semaphore(config.maxConcurrency),
    circuitBreaker: options.circuitBreaker || new CircuitBreaker(config.circuitFailureThreshold, config.circuitResetMs, options.clock),
    idempotency: options.idempotency || new IdempotencyStore(config.idempotencyTtlMs, options.clock),
  };
}

module.exports = { RateLimiter, Semaphore, CircuitBreaker, IdempotencyStore, retry, stableHash, createProtection };
