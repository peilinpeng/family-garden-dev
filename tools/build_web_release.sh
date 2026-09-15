#!/usr/bin/env bash

# 构建可直接上传到 CloudBase/EdgeOne 的 Web Release；大文件按页面壳约定拆成 20 MiB 分片。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-}"

if [ -z "$OUTPUT_DIR" ]; then
  printf '用法: ./tools/build_web_release.sh <空的输出目录>\n' >&2
  exit 2
fi

if [ -e "$OUTPUT_DIR" ] && [ ! -d "$OUTPUT_DIR" ]; then
  printf '输出路径不是目录: %s\n' "$OUTPUT_DIR" >&2
  exit 2
fi
if [ -d "$OUTPUT_DIR" ] && [ -n "$(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  printf '为防止覆盖，输出目录必须为空: %s\n' "$OUTPUT_DIR" >&2
  exit 2
fi
mkdir -p "$OUTPUT_DIR"

resolve_godot() {
  if [ -n "${GODOT_BIN:-}" ]; then
    printf '%s' "$GODOT_BIN"
  elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
    printf '%s' "/Applications/Godot.app/Contents/MacOS/Godot"
  elif command -v godot >/dev/null 2>&1; then
    command -v godot
  elif command -v godot4 >/dev/null 2>&1; then
    command -v godot4
  else
    return 1
  fi
}

if ! GODOT_EXECUTABLE="$(resolve_godot)"; then
  printf '找不到 Godot 4.7；可通过 GODOT_BIN 指定路径。\n' >&2
  exit 2
fi

GODOT_VERSION="$($GODOT_EXECUTABLE --version 2>/dev/null || true)"
case "$GODOT_VERSION" in
  4.7*) ;;
  *)
    printf '当前 Godot 为 %s，项目要求 4.7。\n' "${GODOT_VERSION:-未知版本}" >&2
    exit 2
    ;;
esac

printf 'RUN  构建 Godot Web Release\n'
"$GODOT_EXECUTABLE" --headless --path "$ROOT_DIR/game" \
  --export-release Web "$OUTPUT_DIR/index.html"

node "$ROOT_DIR/tools/split_web_payloads.js" "$OUTPUT_DIR"

for required in index.html index.js release-manifest.json chunks/index.pck.part00 chunks/index.wasm.part00; do
  if [ ! -s "$OUTPUT_DIR/$required" ]; then
    printf '构建产物缺失: %s\n' "$required" >&2
    exit 1
  fi
done

if find "$OUTPUT_DIR" -type f -size +25M -print -quit | grep -q .; then
  printf '仍存在超过 25 MiB 的托管文件。\n' >&2
  exit 1
fi

printf 'PASS 可部署 Web Release 已生成: %s\n' "$OUTPUT_DIR"
