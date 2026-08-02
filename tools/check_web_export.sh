#!/usr/bin/env bash

# Family Garden Web Release 导出审计。
# 验证生产包体积、动态加载资源、排除边界和导出包启动，不访问任何线上服务。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAX_PCK_BYTES="${WEB_EXPORT_MAX_PCK_BYTES:-130000000}"
KEEP_EXPORT="${KEEP_WEB_EXPORT:-0}"
AUDIT_PASSED=0

usage() {
  printf '%s\n' \
    "用法: ./tools/check_web_export.sh" \
    "" \
    "可选环境变量:" \
    "  GODOT_BIN                 Godot 4.7 可执行文件路径" \
    "  WEB_EXPORT_MAX_PCK_BYTES  PCK 体积上限，默认 130000000" \
    "  KEEP_WEB_EXPORT           设为 1 时保留成功导出产物"
}

if [ "$#" -gt 0 ]; then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf '未知参数: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
fi

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

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

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

if ! [[ "$MAX_PCK_BYTES" =~ ^[1-9][0-9]*$ ]]; then
  printf 'WEB_EXPORT_MAX_PCK_BYTES 必须是正整数。\n' >&2
  exit 2
fi

if ! GODOT_EXECUTABLE="$(resolve_godot)"; then
  printf '找不到 Godot 4.7；可通过 GODOT_BIN 指定路径。\n' >&2
  exit 2
fi

GODOT_VERSION="$($GODOT_EXECUTABLE --version 2>/dev/null || true)"
case "$GODOT_VERSION" in
  4.7*)
    ;;
  *)
    printf '当前 Godot 为 %s，项目要求 4.7。\n' "${GODOT_VERSION:-未知版本}" >&2
    exit 2
    ;;
esac

EXPORT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/family-garden-web-export.XXXXXX")"
EXPORT_LOG="$EXPORT_DIR/export.log"
STARTUP_LOG="$EXPORT_DIR/startup.log"

cleanup() {
  if [ "$AUDIT_PASSED" -eq 1 ] && [ "$KEEP_EXPORT" != "1" ]; then
    rm -rf "$EXPORT_DIR"
  else
    printf '审计产物: %s\n' "$EXPORT_DIR"
  fi
}
trap cleanup EXIT

printf 'RUN  Web Release 导出\n'
if ! "$GODOT_EXECUTABLE" \
  --headless \
  --path "$ROOT_DIR/game" \
  --export-release Web "$EXPORT_DIR/index.html" \
  >"$EXPORT_LOG" 2>&1; then
  sed -n '1,240p' "$EXPORT_LOG" >&2
  fail "Web Release 导出失败。"
fi

for artifact_name in index.html index.js index.wasm index.pck; do
  if [ ! -s "$EXPORT_DIR/$artifact_name" ]; then
    fail "缺少导出产物 $artifact_name。"
  fi
done

PCK_BYTES="$(wc -c <"$EXPORT_DIR/index.pck" | tr -d '[:space:]')"
if [ "$PCK_BYTES" -gt "$MAX_PCK_BYTES" ]; then
  fail "index.pck 为 $PCK_BYTES bytes，超过上限 $MAX_PCK_BYTES bytes。"
fi

REQUIRED_PATHS=(
  "res://scenes/Main.tscn"
  "res://scenes/rooms/AnnaRoom.tscn"
  "res://scenes/pond/pond_area.tscn"
  "res://scenes/Farm.tscn"
  "res://scenes/KitchenNew.tscn"
  "res://scenes/GardenTiled.tscn"
  "res://scenes/prefabs/DynamicNode.tscn"
  "res://config/ai.json"
  "res://config/cloudbase.json"
  "res://assets/manifest/appearances.json"
  "res://assets/manifest/characters.json"
  "res://assets/manifest/items.json"
  "res://assets/manifest/recipes.json"
  "res://assets/manifest/room_object_catalog.json"
  "res://assets/memory_links/memory_link_config.json"
)

for required_path in "${REQUIRED_PATHS[@]}"; do
  if ! grep -Fq "$required_path" "$EXPORT_LOG"; then
    fail "导出清单缺少关键资源 $required_path。"
  fi
done

REQUIRED_PREFIXES=(
  "res://assets/characters/"
  "res://assets/farm/"
  "res://assets/garden/"
  "res://assets/kitchen/"
  "res://assets/pond/"
  "res://music/"
  "res://soundeffect/"
)

for required_prefix in "${REQUIRED_PREFIXES[@]}"; do
  if ! grep -Fq "$required_prefix" "$EXPORT_LOG"; then
    fail "导出清单缺少动态资源目录 $required_prefix。"
  fi
done

EXCLUDED_PATHS=(
  "res://tests/"
  "res://tools/"
  "res://scenes/Fishpond.tscn"
  "res://scenes/GardenTiledSandbox.tscn"
  "res://scenes/garden_builder/test/"
  "res://assets/fishpond/"
  "res://assets/tilemap/"
  "res://assets/tilemap_gardening/"
  "res://assets/kitchen_ai/"
)

PRODUCTION_REFERENCE_FILES=("$ROOT_DIR/game/project.godot")
while IFS= read -r -d '' reference_file; do
  case "$reference_file" in
    "$ROOT_DIR/game/scenes/Fishpond.tscn"|\
    "$ROOT_DIR/game/scenes/GardenTiledSandbox.tscn"|\
    "$ROOT_DIR/game/scenes/garden_builder/test/"*)
      continue
      ;;
  esac
  PRODUCTION_REFERENCE_FILES+=("$reference_file")
done < <(
  find \
    "$ROOT_DIR/game/scripts" \
    "$ROOT_DIR/game/scenes" \
    "$ROOT_DIR/game/config" \
    "$ROOT_DIR/game/assets/manifest" \
    "$ROOT_DIR/game/assets/memory_links" \
    -type f \
    \( -name '*.gd' -o -name '*.tscn' -o -name '*.tres' -o -name '*.cfg' -o -name '*.json' \) \
    -print0
)

REFERENCE_LOG="$EXPORT_DIR/excluded-reference.log"
for excluded_path in "${EXCLUDED_PATHS[@]}"; do
  if grep -F -n "$excluded_path" "${PRODUCTION_REFERENCE_FILES[@]}" >"$REFERENCE_LOG"; then
    sed -n '1,80p' "$REFERENCE_LOG" >&2
    fail "生产代码或场景重新引用了排除项 $excluded_path。"
  fi
done

for excluded_path in "${EXCLUDED_PATHS[@]}"; do
  if grep -Fq "$excluded_path" "$EXPORT_LOG"; then
    fail "导出清单仍包含排除项 $excluded_path。"
  fi
done

printf 'RUN  导出包启动检查\n'
if ! "$GODOT_EXECUTABLE" \
  --headless \
  --main-pack "$EXPORT_DIR/index.pck" \
  --quit-after 180 \
  >"$STARTUP_LOG" 2>&1; then
  sed -n '1,240p' "$STARTUP_LOG" >&2
  fail "导出包启动失败。"
fi

if grep -Eq 'SCRIPT ERROR|ERROR:|Failed loading resource|Cannot open file' "$STARTUP_LOG"; then
  sed -n '1,240p' "$STARTUP_LOG" >&2
  fail "导出包启动日志包含资源或脚本错误。"
fi

WASM_BYTES="$(wc -c <"$EXPORT_DIR/index.wasm" | tr -d '[:space:]')"
TOTAL_BYTES="$((
  $(wc -c <"$EXPORT_DIR/index.html")
  + $(wc -c <"$EXPORT_DIR/index.js")
  + WASM_BYTES
  + PCK_BYTES
))"

printf '%s\n' \
  "PASS Web Release 导出审计" \
  "  PCK:   ${PCK_BYTES} bytes（上限 ${MAX_PCK_BYTES}）" \
  "  WASM:  $WASM_BYTES bytes" \
  "  核心四文件合计: $TOTAL_BYTES bytes" \
  "  动态资源、生产引用边界和导出包启动检查均通过"
AUDIT_PASSED=1
