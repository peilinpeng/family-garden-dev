#!/usr/bin/env bash

# Family Garden 生产环境只读核验。
# 仅访问公开静态资源与 presence-relay 健康检查；不携带成员 token、不调用数据网关，
# 不创建、修改或删除 CloudBase 中的任何数据。

set -euo pipefail

WEB_BASE_URL="${FG_WEB_BASE_URL:-https://familygarden-d7gy18huh87fd41d2-1449262000.tcloudbaseapp.com}"
PRESENCE_HEALTH_URL="${FG_PRESENCE_HEALTH_URL:-https://familygarden-d7gy18huh87fd41d2-1449262000.ap-shanghai.app.tcloudbase.com/presence-relay/healthz}"
EXPECTED_INDEX_SHA256="${FG_EXPECTED_INDEX_SHA256:-}"
EXPECTED_MANIFEST_SHA256="${FG_EXPECTED_MANIFEST_SHA256:-}"

usage() {
  cat <<'EOF'
用法：./tools/verify_production.sh [选项]

只读核验公开 Web 运行时资源和 Presence 健康检查，不访问业务数据。

选项：
  --web-url URL             覆盖 Web 根地址
  --presence-health-url URL 覆盖 Presence /healthz 地址
  --index-sha256 SHA256     额外校验下载的 index.html 哈希
  --manifest-sha256 SHA256  额外校验 release-manifest.json 哈希
  -h, --help                显示帮助

等价环境变量：FG_WEB_BASE_URL、FG_PRESENCE_HEALTH_URL、FG_EXPECTED_INDEX_SHA256、
FG_EXPECTED_MANIFEST_SHA256。
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --web-url)
      WEB_BASE_URL="${2:?--web-url 需要 URL}"; shift 2 ;;
    --presence-health-url)
      PRESENCE_HEALTH_URL="${2:?--presence-health-url 需要 URL}"; shift 2 ;;
    --index-sha256)
      EXPECTED_INDEX_SHA256="${2:?--index-sha256 需要 SHA-256}"; shift 2 ;;
    --manifest-sha256)
      EXPECTED_MANIFEST_SHA256="${2:?--manifest-sha256 需要 SHA-256}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      printf '未知参数：%s\n' "$1" >&2
      usage >&2
      exit 2 ;;
  esac
done

if ! command -v curl >/dev/null 2>&1; then
  printf '需要 curl。\n' >&2
  exit 2
fi
if ! command -v node >/dev/null 2>&1; then
  printf '核验发布清单需要 Node.js。\n' >&2
  exit 2
fi
if { [ -n "$EXPECTED_INDEX_SHA256" ] || [ -n "$EXPECTED_MANIFEST_SHA256" ]; } \
  && ! command -v shasum >/dev/null 2>&1; then
  printf '校验发布哈希需要 shasum。\n' >&2
  exit 2
fi
if [ -n "$EXPECTED_INDEX_SHA256" ] && ! [[ "$EXPECTED_INDEX_SHA256" =~ ^[A-Fa-f0-9]{64}$ ]]; then
  printf 'index.html SHA-256 必须为 64 位十六进制字符串。\n' >&2
  exit 2
fi
if [ -n "$EXPECTED_MANIFEST_SHA256" ] && ! [[ "$EXPECTED_MANIFEST_SHA256" =~ ^[A-Fa-f0-9]{64}$ ]]; then
  printf 'release-manifest.json SHA-256 必须为 64 位十六进制字符串。\n' >&2
  exit 2
fi

WEB_BASE_URL="${WEB_BASE_URL%/}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/family-garden-production-verify.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fetch_file() {
  local relative_path="$1"
  local output_path="$2"
  curl --fail --silent --show-error --location \
    --connect-timeout 10 --max-time 30 \
    -H 'Cache-Control: no-cache' \
    "${WEB_BASE_URL}/${relative_path}" \
    -o "$output_path"
  printf 'PASS Web 资源：%s\n' "$relative_path"
}

fetch_file 'index.html' "$TMP_DIR/index.html"
fetch_file 'index.js' "$TMP_DIR/index.js"
fetch_file 'release-manifest.json' "$TMP_DIR/release-manifest.json"

node - "$TMP_DIR/release-manifest.json" "$TMP_DIR/parts.tsv" <<'NODE'
const fs = require('node:fs');
const manifest = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (manifest.schema_version !== 1 || manifest.chunk_bytes !== 20 * 1024 * 1024) {
  throw new Error('发布清单版本或分片大小不受支持');
}
const rows = [];
for (const fileName of ['index.pck', 'index.wasm']) {
  const file = manifest.files?.[fileName];
  if (!Number.isSafeInteger(file?.bytes) || file.bytes <= 0 || !Array.isArray(file.parts) || file.parts.length === 0) {
    throw new Error(`发布清单缺少 ${fileName}`);
  }
  const sum = file.parts.reduce((total, part) => {
    if (!/^chunks\/index\.(pck|wasm)\.part[0-9]{2}$/.test(part.path)
      || !Number.isSafeInteger(part.bytes) || part.bytes <= 0
      || !/^[a-f0-9]{64}$/.test(part.sha256)) {
      throw new Error(`非法分片记录: ${JSON.stringify(part)}`);
    }
    rows.push(`${part.path}\t${part.bytes}`);
    return total + part.bytes;
  }, 0);
  if (sum !== file.bytes) throw new Error(`${fileName} 分片总量与清单不一致`);
}
fs.writeFileSync(process.argv[3], `${rows.join('\n')}\n`);
NODE

while IFS=$'\t' read -r part_path expected_bytes; do
  headers_file="$TMP_DIR/$(printf '%s' "$part_path" | tr '/' '_').headers"
  curl --fail --silent --show-error --location --head \
    --connect-timeout 10 --max-time 30 \
    -H 'Cache-Control: no-cache' \
    "${WEB_BASE_URL}/${part_path}" -o "$headers_file"
  actual_bytes="$(awk 'tolower($1) == "content-length:" {gsub("\\r", "", $2); value=$2} END{print value}' "$headers_file")"
  if [ "$actual_bytes" != "$expected_bytes" ]; then
    printf '分片大小不匹配：%s，期望 %s，实际 %s。\n' "$part_path" "$expected_bytes" "${actual_bytes:-未知}" >&2
    exit 1
  fi
  printf 'PASS Web 分片：%s（%s bytes）\n' "$part_path" "$actual_bytes"
done < "$TMP_DIR/parts.tsv"

if [ -n "$EXPECTED_INDEX_SHA256" ]; then
  ACTUAL_INDEX_SHA256="$(shasum -a 256 "$TMP_DIR/index.html" | awk '{print $1}')"
  ACTUAL_INDEX_SHA256="$(printf '%s' "$ACTUAL_INDEX_SHA256" | tr '[:upper:]' '[:lower:]')"
  EXPECTED_INDEX_SHA256="$(printf '%s' "$EXPECTED_INDEX_SHA256" | tr '[:upper:]' '[:lower:]')"
  if [ "$ACTUAL_INDEX_SHA256" != "$EXPECTED_INDEX_SHA256" ]; then
    printf 'index.html SHA-256 不匹配：期望 %s，实际 %s。\n' "$EXPECTED_INDEX_SHA256" "$ACTUAL_INDEX_SHA256" >&2
    exit 1
  fi
  printf 'PASS index.html SHA-256\n'
fi

if [ -n "$EXPECTED_MANIFEST_SHA256" ]; then
  ACTUAL_MANIFEST_SHA256="$(shasum -a 256 "$TMP_DIR/release-manifest.json" | awk '{print $1}')"
  ACTUAL_MANIFEST_SHA256="$(printf '%s' "$ACTUAL_MANIFEST_SHA256" | tr '[:upper:]' '[:lower:]')"
  EXPECTED_MANIFEST_SHA256="$(printf '%s' "$EXPECTED_MANIFEST_SHA256" | tr '[:upper:]' '[:lower:]')"
  if [ "$ACTUAL_MANIFEST_SHA256" != "$EXPECTED_MANIFEST_SHA256" ]; then
    printf 'release-manifest.json SHA-256 不匹配：期望 %s，实际 %s。\n' \
      "$EXPECTED_MANIFEST_SHA256" "$ACTUAL_MANIFEST_SHA256" >&2
    exit 1
  fi
  printf 'PASS release-manifest.json SHA-256\n'
fi

HEALTH_BODY=''
HEALTH_ERROR="$TMP_DIR/presence-health.err"
HEALTH_ATTEMPT=1
while [ "$HEALTH_ATTEMPT" -le 2 ]; do
  if HEALTH_BODY="$(curl --fail --silent --show-error --location \
    --connect-timeout 10 --max-time 30 "$PRESENCE_HEALTH_URL" 2>"$HEALTH_ERROR")" \
    && [ "$HEALTH_BODY" = '{"ok":true}' ]; then
    printf 'PASS Presence 健康检查\n'
    break
  fi
  if [ "$HEALTH_ATTEMPT" -eq 2 ]; then
    printf 'Presence 健康检查失败；响应：%s\n' "$HEALTH_BODY" >&2
    sed -n '1,8p' "$HEALTH_ERROR" >&2
    exit 1
  fi
  printf 'WARN Presence 健康检查首次未通过，等待冷启动后重试。\n' >&2
  HEALTH_ATTEMPT=$((HEALTH_ATTEMPT + 1))
  sleep 3
done
printf '生产只读核验通过。\n'
