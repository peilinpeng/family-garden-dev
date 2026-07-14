#!/usr/bin/env python3
"""将五套发色离线烘焙为完整角色动作图集，并登记到外观清单。

游戏运行时只加载这里输出的成品 PNG，不再使用 Shader 或遮罩换色。现有头发
遮罩仅作为离线选区：每个被选中的像素都会映射到人工配置的多级色板，因此
不会出现只染头顶、刘海残留原色，或单色覆盖破坏像素明暗关系的问题。
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image


GAME_ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = GAME_ROOT / "assets/manifest/appearances.json"
CHARACTER_CATALOG_PATH = GAME_ROOT / "assets/manifest/characters.json"
OUTPUT_DIR = GAME_ROOT / "assets/characters/hair_colors"

# 从最暗轮廓到最亮高光。这里直接定义成品美术色阶，不再由运行时目标色乘亮度。
COLOR_RAMPS: dict[str, tuple[str, ...]] = {
    "dark": ("#15161b", "#202128", "#2b2d36", "#383b47", "#4a4e5c", "#626775", "#7d8390"),
    "chestnut": ("#2b1716", "#43201d", "#5d2a25", "#79372e", "#98493a", "#bc624a", "#dc8665"),
    "blonde": ("#3d2c1c", "#5b4124", "#7b592d", "#9e7539", "#c0954c", "#dfb966", "#f4d88f"),
    "midnight": ("#151a29", "#20283b", "#2c374f", "#394862", "#4a5d78", "#607590", "#7e91aa"),
}


def _hex_rgb(value: str) -> np.ndarray:
    value = value.removeprefix("#")
    return np.array([int(value[index : index + 2], 16) for index in (0, 2, 4)], dtype=np.float32)


def _characters() -> dict[str, dict[str, Any]]:
    raw = json.loads(CHARACTER_CATALOG_PATH.read_text(encoding="utf-8"))
    return {entry["id"]: entry for entry in raw.get("characters", [])}


def _base_definition(style: dict[str, Any], characters: dict[str, dict[str, Any]]) -> dict[str, Any]:
    return characters[style["character_id"]] if "character_id" in style else style


def _output_stem(sheet: str, color_id: str) -> str:
    return f"{Path(sheet).name}__{color_id}"


def _ramp_image(source: Image.Image, mask: Image.Image, ramp_hex: tuple[str, ...]) -> Image.Image:
    source_array = np.asarray(source.convert("RGBA"), dtype=np.uint8).copy()
    mask_array = np.asarray(mask.convert("RGBA"), dtype=np.uint8)
    selected = (mask_array[:, :, 0] >= 128) & (source_array[:, :, 3] > 0)
    if not np.any(selected):
        raise RuntimeError("发色遮罩没有选中任何像素")

    rgb = source_array[:, :, :3].astype(np.float32)
    # 感知亮度决定像素落入哪一段色阶；以每张图自己的暗部/高光分位校准，
    # 保留不同动作里的立体明暗，同时避免少量纯黑描边拉低整个色阶。
    luminance = 0.2126 * rgb[:, :, 0] + 0.7152 * rgb[:, :, 1] + 0.0722 * rgb[:, :, 2]
    selected_luminance = luminance[selected]
    low, high = np.percentile(selected_luminance, (2.0, 98.0))
    if high - low < 1.0:
        high = low + 1.0
    tone = np.clip((luminance - low) / (high - low), 0.0, 1.0)
    # 轻微抬高中间调，避免乌木黑与雾夜蓝在游戏缩放后糊成整块。
    tone = np.power(tone, 0.88)

    ramp = np.stack([_hex_rgb(value) for value in ramp_hex])
    position = tone * (len(ramp) - 1)
    lower = np.floor(position).astype(np.int16)
    upper = np.minimum(lower + 1, len(ramp) - 1)
    fraction = (position - lower)[..., None]
    recolored = ramp[lower] * (1.0 - fraction) + ramp[upper] * fraction
    source_array[:, :, :3][selected] = np.clip(np.rint(recolored[selected]), 0, 255).astype(np.uint8)
    return Image.fromarray(source_array)


def _bake_definition(definition: dict[str, Any]) -> dict[str, str]:
    sheet = str(definition["sheet"])
    mask = str(definition["mask"])
    source_path = GAME_ROOT / f"assets/characters/{sheet}.png"
    mask_path = GAME_ROOT / f"assets/characters/{mask}.png"
    if not source_path.exists() or not mask_path.exists():
        raise FileNotFoundError(f"缺少角色原图或离线选区：{source_path} / {mask_path}")

    source = Image.open(source_path).convert("RGBA")
    mask_image = Image.open(mask_path).convert("RGBA")
    if source.size != mask_image.size:
        raise RuntimeError(f"图集与离线选区尺寸不一致：{source_path.name}")

    sheets = {"brown": sheet}
    for color_id, ramp in COLOR_RAMPS.items():
        stem = _output_stem(sheet, color_id)
        relative_sheet = f"hair_colors/{stem}"
        output_path = OUTPUT_DIR / f"{stem}.png"
        _ramp_image(source, mask_image, ramp).save(output_path, optimize=True, compress_level=9)
        sheets[color_id] = relative_sheet
        print(f"生成 {output_path.relative_to(GAME_ROOT)}")
    return sheets


def build() -> None:
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    characters = _characters()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    expected_outputs: set[Path] = set()

    for body in catalog["body_types"].values():
        for style in body["hair_styles"].values():
            base = _base_definition(style, characters)
            style_definition = {"sheet": base["sheet"], "mask": style["mask"]}
            style["hair_sheets"] = _bake_definition(style_definition)
            for path in style["hair_sheets"].values():
                if path.startswith("hair_colors/"):
                    expected_outputs.add(GAME_ROOT / f"assets/characters/{path}.png")

            for variant in style.get("outfit_variants", {}).values():
                variant["hair_sheets"] = _bake_definition(variant)
                for path in variant["hair_sheets"].values():
                    if path.startswith("hair_colors/"):
                        expected_outputs.add(GAME_ROOT / f"assets/characters/{path}.png")

    # 清理仅由本脚本管理且已经不在清单中的旧生成物，避免改名后残留幽灵资源。
    for old_path in OUTPUT_DIR.glob("*.png"):
        if old_path not in expected_outputs:
            old_path.unlink()
    catalog["version"] = max(2, int(catalog.get("version", 1)))
    CATALOG_PATH.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"已登记 {len(expected_outputs) + 20} 种完整角色组合（新增 {len(expected_outputs)} 张发色图集）")


if __name__ == "__main__":
    build()
