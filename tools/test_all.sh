#!/usr/bin/env bash

# Family Garden 本地全量回归入口。
# 只运行本地 Godot 场景、Node 单元测试和 Python JSON Schema 契约测试；
# 不调用真实 AI、CloudBase、Presence 线上服务或任何收费接口。

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP=false
KEEP_LOGS="${KEEP_TEST_LOGS:-0}"
TEST_TIMEOUT_SECONDS="${TEST_TIMEOUT_SECONDS:-0}"
FAILURES=0
PASSES=0
TOTALS=0

usage() {
  printf '%s\n' \
    "用法: ./tools/test_all.sh [--bootstrap]" \
    "" \
    "  --bootstrap  首次运行时安装三个 Node 工作区依赖，并创建 .venv 安装契约测试依赖" \
    "" \
    "可选环境变量:" \
    "  GODOT_BIN       Godot 可执行文件路径" \
    "  PYTHON_BIN      Python 3 可执行文件路径" \
    "  KEEP_TEST_LOGS  设为 1 时保留成功测试日志" \
    "  TEST_TIMEOUT_SECONDS  单个执行单元超时秒数，默认 0（不限制）"
}

for argument in "$@"; do
  case "$argument" in
    --bootstrap)
      BOOTSTRAP=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf '未知参数: %s\n\n' "$argument" >&2
      usage >&2
      exit 2
      ;;
  esac
done

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

if ! [[ "$TEST_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]]; then
  printf 'TEST_TIMEOUT_SECONDS 必须是非负整数。\n' >&2
  exit 2
fi

TIMEOUT_EXECUTABLE=""
if [ "$TEST_TIMEOUT_SECONDS" -gt 0 ]; then
  if command_exists timeout; then
    TIMEOUT_EXECUTABLE="$(command -v timeout)"
  elif command_exists gtimeout; then
    TIMEOUT_EXECUTABLE="$(command -v gtimeout)"
  else
    printf '启用 TEST_TIMEOUT_SECONDS 需要 timeout（GNU coreutils）。\n' >&2
    exit 2
  fi
fi

resolve_godot() {
  if [ -n "${GODOT_BIN:-}" ]; then
    printf '%s' "$GODOT_BIN"
  elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
    printf '%s' "/Applications/Godot.app/Contents/MacOS/Godot"
  elif command_exists godot; then
    command -v godot
  elif command_exists godot4; then
    command -v godot4
  else
    return 1
  fi
}

fail_preflight() {
  printf '环境检查失败: %s\n' "$1" >&2
  exit 2
}

if ! command_exists node || ! command_exists npm; then
  fail_preflight "需要 Node.js 20.19+ 和 npm。"
fi

if ! node -e '
  const [major, minor] = process.versions.node.split(".").map(Number);
  process.exit(major > 20 || (major === 20 && minor >= 19) ? 0 : 1);
'; then
  fail_preflight "当前 Node.js 为 $(node --version)，需要 20.19+。"
fi

DEFAULT_PYTHON="${PYTHON_BIN:-python3}"
if ! command_exists "$DEFAULT_PYTHON"; then
  fail_preflight "找不到 Python 3；可通过 PYTHON_BIN 指定路径。"
fi

if ! GODOT_EXECUTABLE="$(resolve_godot)"; then
  fail_preflight "找不到 Godot 4.7；可通过 GODOT_BIN 指定路径。"
fi

GODOT_VERSION="$("$GODOT_EXECUTABLE" --version 2>/dev/null || true)"
case "$GODOT_VERSION" in
  4.7*)
    ;;
  *)
    fail_preflight "当前 Godot 为 ${GODOT_VERSION:-未知版本}，项目要求 4.7。"
    ;;
esac

NODE_WORKSPACES=(
  "$ROOT_DIR/backend/ai"
  "$ROOT_DIR/backend/cloudbase/data_gateway"
  "$ROOT_DIR/backend/cloudbase/presence_relay"
)

if [ "$BOOTSTRAP" = true ]; then
  printf '首次环境准备：安装本地测试依赖\n'
  for workspace in "${NODE_WORKSPACES[@]}"; do
    printf '  npm ci: %s\n' "${workspace#"$ROOT_DIR/"}"
    (cd "$workspace" && npm ci) || fail_preflight "npm ci 失败: ${workspace#"$ROOT_DIR/"}"
  done
  "$DEFAULT_PYTHON" -m venv "$ROOT_DIR/.venv" \
    || fail_preflight "无法创建 .venv。"
  "$ROOT_DIR/.venv/bin/python" -m pip install \
    -r "$ROOT_DIR/backend/ai/tests/requirements.txt" \
    || fail_preflight "无法安装 Python 契约测试依赖。"
fi

for workspace in "${NODE_WORKSPACES[@]}"; do
  if [ ! -d "$workspace/node_modules" ]; then
    fail_preflight "${workspace#"$ROOT_DIR/"} 缺少 node_modules，请先运行 ./tools/test_all.sh --bootstrap。"
  fi
done

if [ -x "$ROOT_DIR/.venv/bin/python" ]; then
  CONTRACT_PYTHON="$ROOT_DIR/.venv/bin/python"
else
  CONTRACT_PYTHON="$DEFAULT_PYTHON"
fi

if ! "$CONTRACT_PYTHON" -c "import jsonschema" >/dev/null 2>&1; then
  fail_preflight "缺少 Python jsonschema，请先运行 ./tools/test_all.sh --bootstrap。"
fi

GODOT_TEST_COUNT="$(find "$ROOT_DIR/game/tests" -maxdepth 1 -type f -name '*.tscn' | wc -l | tr -d '[:space:]')"
if [ "$GODOT_TEST_COUNT" -lt 19 ]; then
  fail_preflight "仅发现 $GODOT_TEST_COUNT 个 Godot 测试场景，低于 M0 基线 19 个。"
fi

LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/family-garden-tests.XXXXXX")"
STARTED_AT="$(date +%s)"

cleanup() {
  if [ "$FAILURES" -eq 0 ] && [ "$KEEP_LOGS" != "1" ]; then
    rm -rf "$LOG_DIR"
  else
    printf '测试日志: %s\n' "$LOG_DIR"
  fi
}
trap cleanup EXIT

safe_log_name() {
  printf '%s' "$1" | tr '/ :()' '______' | tr -cd '[:alnum:]_.-'
}

run_in_directory() {
  local directory="$1"
  shift
  (cd "$directory" && "$@")
}

run_test() {
  local label="$1"
  shift
  local log_file="$LOG_DIR/$(safe_log_name "$label").log"
  local started
  local finished
  local status
  started="$(date +%s)"
  TOTALS=$((TOTALS + 1))

  printf 'RUN  %s\n' "$label"
  if [ "$TEST_TIMEOUT_SECONDS" -gt 0 ]; then
    "$TIMEOUT_EXECUTABLE" \
      --signal=TERM \
      --kill-after=10s \
      "$TEST_TIMEOUT_SECONDS" \
      "$@" >"$log_file" 2>&1
  else
    "$@" >"$log_file" 2>&1
  fi
  status=$?
  finished="$(date +%s)"

  if [ "$status" -eq 0 ]; then
    PASSES=$((PASSES + 1))
    printf 'PASS %s (%ss)\n' "$label" "$((finished - started))"
  else
    FAILURES=$((FAILURES + 1))
    printf 'FAIL %s (%ss, exit=%s)\n' "$label" "$((finished - started))" "$status" >&2
    sed -n '1,240p' "$log_file" >&2
  fi
}

printf '%s\n' \
  "Family Garden M0 全量回归" \
  "Godot:  $GODOT_VERSION" \
  "Node:   $(node --version)" \
  "npm:    $(npm --version)" \
  "Python: $("$CONTRACT_PYTHON" --version 2>&1)" \
  ""

while IFS= read -r scene_path; do
  scene_resource="res://${scene_path#"$ROOT_DIR/game/"}"
  run_test "Godot ${scene_resource#res://tests/}" \
    "$GODOT_EXECUTABLE" --headless --path "$ROOT_DIR/game" "$scene_resource"
done < <(find "$ROOT_DIR/game/tests" -maxdepth 1 -type f -name '*.tscn' | sort)

run_test "AI Gateway Node tests" \
  run_in_directory "$ROOT_DIR/backend/ai" npm test
run_test "AI JSON Schema contracts" \
  "$CONTRACT_PYTHON" "$ROOT_DIR/backend/ai/tests/validate_contracts.py"
run_test "Data Gateway Node tests" \
  run_in_directory "$ROOT_DIR/backend/cloudbase/data_gateway" npm test
run_test "Presence Relay Node tests" \
  run_in_directory "$ROOT_DIR/backend/cloudbase/presence_relay" npm test

FINISHED_AT="$(date +%s)"
printf '\n结果: %s/%s 通过，%s 失败，总耗时 %ss\n' \
  "$PASSES" "$TOTALS" "$FAILURES" "$((FINISHED_AT - STARTED_AT))"

if [ "$FAILURES" -ne 0 ]; then
  exit 1
fi
