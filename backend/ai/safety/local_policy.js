"use strict";

const { AppError } = require("../errors");

const RULES = [
  ["sexual", /(色情|裸照|性行为|porn|explicit sex)/i],
  ["violence", /(杀死|砍死|血腥|虐杀|gore|kill them)/i],
  ["self_harm", /(自杀|自残|不想活|suicide|self[- ]harm)/i],
  ["child_safety", /(儿童色情|未成年裸照|child porn|sexual minor)/i],
  ["hate", /(仇恨.*群体|种族灭绝|racial slur|hate group)/i],
  ["privacy", /(?:\b1[3-9]\d{9}\b|\b\d{17}[\dXx]\b|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,})/i],
];

function assertSafeText(text) {
  if (!text) return;
  for (const [category, pattern] of RULES) {
    if (pattern.test(String(text))) {
      throw new AppError("CONTENT_UNSAFE", "输入包含不适合处理的内容。", { retryable: false, details: [category] });
    }
  }
}

function assertSafeImageUrl(rawUrl) {
  if (!rawUrl) return;
  let url;
  try {
    url = new URL(rawUrl);
  } catch (error) {
    throw new AppError("IMAGE_UNSUPPORTED", "图片地址无效。", { retryable: false, cause: error });
  }
  if (url.protocol !== "https:") throw new AppError("IMAGE_UNSUPPORTED", "图片必须使用 HTTPS 地址。", { retryable: false });
  const host = url.hostname.toLowerCase();
  const privateHost = host === "localhost"
    || host === "[::1]"
    || host === "::1"
    || host === "0.0.0.0"
    || host === "metadata.tencentyun.com"
    || host.endsWith(".local")
    || /^127\./.test(host)
    || /^10\./.test(host)
    || /^192\.168\./.test(host)
    || /^169\.254\./.test(host)
    || /^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\./.test(host)
    || /^172\.(1[6-9]|2\d|3[01])\./.test(host);
  if (privateHost) {
    throw new AppError("IMAGE_UNSUPPORTED", "图片地址不能指向本地或私有网络。", { retryable: false });
  }
}

function textFromPayload(payload) {
  const values = [];
  if (typeof payload.raw_text === "string") values.push(payload.raw_text);
  if (Array.isArray(payload.candidates)) {
    for (const item of payload.candidates) values.push(item.title || "", item.description || "");
  }
  return values.filter(Boolean).join("\n");
}

module.exports = { assertSafeText, assertSafeImageUrl, textFromPayload, RULES };
