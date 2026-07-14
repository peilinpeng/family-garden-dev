#!/usr/bin/env python3
"""为每套角色动作图集生成离线头发语义选区。

红色通道表示头发。服装现在使用独立美术图集，不再通过绿色通道调色。
算法先从每套原图中提取头发与皮肤色板，再结合发型在不同动作方向中的
结构区域分类，避免按单一 HSV 阈值产生碎片、漏染或把皮肤染色。
这些 PNG 只供 build_hair_color_sheets.py 烘焙成品使用，游戏运行时不会加载。
"""

from __future__ import annotations

import colorsys
import json
from pathlib import Path
from typing import Any

from PIL import Image
from scipy.spatial import cKDTree


GAME_ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = GAME_ROOT / "assets/manifest/appearances.json"
CHARACTER_CATALOG_PATH = GAME_ROOT / "assets/manifest/characters.json"
OUTPUT_DIR = GAME_ROOT / "assets/characters/masks"

RGB = tuple[int, int, int]
RGBA = tuple[int, int, int, int]


def _hsv(pixel: RGBA) -> tuple[float, float, float]:
    return colorsys.rgb_to_hsv(pixel[0] / 255.0, pixel[1] / 255.0, pixel[2] / 255.0)


def _distance_sq(pixel: RGBA, palette: Any) -> float:
    if palette is None:
        return 1 << 30
    distance, _ = palette.query(pixel[:3])
    return float(distance * distance)


def _deduplicate_palette(colors: list[RGB]) -> list[RGB]:
    # 角色图是柔和像素画，同一材质会有少量抗锯齿近似色。16级量化可去重，
    # 同时保留暗部、中间色和高光，分类时仍使用原始 RGB 距离。
    buckets: dict[tuple[int, int, int], RGB] = {}
    for color in colors:
        key = (color[0] // 16, color[1] // 16, color[2] // 16)
        buckets.setdefault(key, color)
    return list(buckets.values())


def _sample_palettes(source: Image.Image, frame_rects: list[list[float]], style_id: str) -> tuple[list[RGB], list[RGB]]:
    pixels = source.load()
    hair_colors: list[RGB] = []
    skin_colors: list[RGB] = []
    # 第一排与第五排都是正面动作，脸部和发型采样最稳定。
    for frame_index in [0, 1, 2, 12, 13, 14]:
        left, top, width, height = (int(value) for value in frame_rects[frame_index][:4])
        for py in range(top, min(top + height, source.height)):
            for px in range(left, min(left + width, source.width)):
                pixel: RGBA = pixels[px, py]
                if pixel[3] <= 16:
                    continue
                x = (px - left) / max(1, width)
                y = (py - top) / max(1, height)
                hue, saturation, value = _hsv(pixel)

                # 只取脸中央偏下的肤色，避开刘海、眼睛与衣领。
                if 0.40 < x < 0.60 and 0.28 < y < 0.40:
                    if (hue < 0.14 or hue > 0.98) and 0.12 < saturation < 0.78 and value > 0.48:
                        skin_colors.append(pixel[:3])

                if style_id == "braid_hat":
                    hair_sample = 0.30 < y < 0.40 and (0.23 < x < 0.36 or 0.64 < x < 0.77)
                else:
                    # 发顶提供主体色板；两侧鬓发与中央刘海补充亮部颜色，采样区
                    # 均停在眼睛上方，避免把脸、眉眼或衣领并入头发色板。
                    top_hair = 0.05 < y < 0.18 and 0.18 < x < 0.82
                    side_hair = 0.18 <= y < 0.30 and (0.16 < x < 0.35 or 0.65 < x < 0.84)
                    center_fringe = 0.17 <= y < 0.22 and 0.42 < x < 0.58
                    hair_sample = top_hair or side_hair or center_fringe
                red, green, blue = pixel[:3]
                hair_tone = red >= green + 12 and green >= blue + 8 and red < 235
                if hair_sample and hair_tone and saturation > 0.18 and value > 0.08:
                    hair_colors.append(pixel[:3])

    return _deduplicate_palette(hair_colors), _deduplicate_palette(skin_colors)


def _hair_zone(style_id: str, row: int, x: float, y: float) -> bool:
    if style_id == "braid_hat":
        # 草帽位于 0.08~0.30，不属于头发；刘海、鬓发和辫子分别覆盖。
        upper = 0.28 < y < 0.43 and 0.20 < x < 0.80
        left_side = 0.30 <= y < 0.45 and 0.23 < x < 0.39
        right_braid = 0.30 <= y < 0.55 and 0.61 < x < 0.77
        return upper or left_side or right_braid
    if style_id == "soft_bob":
        if row == 3:  # 背面整块短发
            return 0.05 < y < 0.50 and 0.16 < x < 0.84
        cap = 0.05 < y < 0.35 and 0.16 < x < 0.84
        sides = 0.20 <= y < 0.42 and (0.16 < x < 0.38 or 0.62 < x < 0.84)
        # 该发型只有画面右侧的一条长辫，缩窄区域避免把袖子和围裙算作头发。
        braids = 0.32 <= y < 0.57 and 0.60 < x < 0.78
        return cap or sides or braids
    # 两套男性发型：正面有中央刘海，侧面与背面延伸到耳后和后颈。
    if row == 3:
        return 0.04 < y < 0.47 and 0.16 < x < 0.84
    cap = 0.04 < y < 0.34 and 0.16 < x < 0.84
    sides = 0.24 <= y < 0.38 and (0.16 < x < 0.40 or 0.60 < x < 0.84)
    return cap or sides


def _hair_color_matches(pixel: RGBA, hair_palette: Any, skin_palette: Any) -> bool:
    _, saturation, value = _hsv(pixel)
    if value <= 0.11 or saturation <= 0.08:
        return False
    hair_distance = _distance_sq(pixel, hair_palette)
    skin_distance = _distance_sq(pixel, skin_palette)
    return hair_distance <= 34**2 and hair_distance + 120 < skin_distance


def _skin_pixel(pixel: RGBA, skin_palette: Any, hair_palette: Any) -> bool:
    _, saturation, value = _hsv(pixel)
    if value <= 0.28 or saturation <= 0.08:
        return False
    skin_distance = _distance_sq(pixel, skin_palette)
    hair_distance = _distance_sq(pixel, hair_palette)
    return skin_distance <= 52**2 and skin_distance + 100 < hair_distance


def _skin_zone(row: int, x: float, y: float) -> bool:
    # 肤色只可能出现在头脸和身体两侧的手部。限制空间区域后，卡其色制服
    # 即使与肤色接近，也不会在胸口和裤腿上被挖成碎片。
    face = row != 3 and y < 0.49 and 0.14 < x < 0.86
    hands = 0.39 < y < 0.79 and (x < 0.38 or x > 0.62)
    return face or hands


def _character_definitions() -> dict[str, dict]:
    raw = json.loads(CHARACTER_CATALOG_PATH.read_text(encoding="utf-8"))
    return {entry["id"]: entry for entry in raw.get("characters", [])}


def _source_for(style: dict, characters: dict[str, dict]) -> tuple[Path, list[list[float]]]:
    if "character_id" in style:
        definition = characters[style["character_id"]]
        return GAME_ROOT / f"assets/characters/{definition['sheet']}.png", definition["frame_rects"]
    return GAME_ROOT / f"assets/characters/{style['sheet']}.png", style["frame_rects"]


def _generate_mask(source_path: Path, frame_rects: list[list[float]], style_id: str, mask_name: str) -> None:
    source = Image.open(source_path).convert("RGBA")
    hair_palette, skin_palette = _sample_palettes(source, frame_rects, style_id)
    if not hair_palette or not skin_palette:
        raise RuntimeError(f"{source_path.name} 无法提取完整的头发或皮肤色板")
    mask = Image.new("RGBA", source.size, (0, 0, 0, 255))
    source_pixels = source.load()
    mask_pixels = mask.load()
    hair_count = 0
    hair_tree = cKDTree(hair_palette)
    skin_tree = cKDTree(skin_palette)
    hair_cache: dict[RGBA, bool] = {}
    skin_cache: dict[RGBA, bool] = {}
    for frame_index, raw_rect in enumerate(frame_rects):
        left, top, width, height = (int(value) for value in raw_rect[:4])
        row = frame_index // 3
        for py in range(top, min(top + height, source.height)):
            for px in range(left, min(left + width, source.width)):
                pixel: RGBA = source_pixels[px, py]
                if pixel[3] <= 16:
                    continue
                x = (px - left) / max(1, width)
                y = (py - top) / max(1, height)
                if pixel not in skin_cache:
                    skin_cache[pixel] = _skin_pixel(pixel, skin_tree, hair_tree)
                if pixel not in hair_cache:
                    hair_cache[pixel] = _hair_color_matches(pixel, hair_tree, skin_tree)
                # 0.24 以上仍属于刘海覆盖带；从眼睛上沿附近开始才进入需要
                # 颜色判定的脸部核心，避免在额头处形成一条未染色横线。
                face_core = row != 3 and 0.24 < y < 0.44 and 0.30 < x < 0.70
                skin = _skin_zone(row, x, y) and skin_cache[pixel]
                hair_zone = _hair_zone(style_id, row, x, y)
                # 脸部中央不能先按肤色排除：棕色刘海的亮部与肤色很接近，会被
                # 提前挖掉。中央区域直接以头发色板作最终判定，脸外区域再用肤色
                # 排除，既补齐整片刘海，又不会把眼睛和额头写进离线选区。
                hair = hair_zone and hair_cache[pixel] if face_core else hair_zone and not skin
                if hair and y > 0.43:
                    hair = hair_cache[pixel]
                if hair:
                    hair_count += 1
                mask_pixels[px, py] = (255 if hair else 0, 0, 0, 255)
    output_path = GAME_ROOT / f"assets/characters/{mask_name}.png"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    mask.save(output_path)
    print(
        f"生成 {output_path.relative_to(GAME_ROOT)} "
        f"(头发 {hair_count} 像素，色板 {len(hair_palette)}/{len(skin_palette)})"
    )


def generate() -> None:
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    characters = _character_definitions()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for body_type, body in catalog["body_types"].items():
        for style_id, style in body["hair_styles"].items():
            source_path, frame_rects = _source_for(style, characters)
            _generate_mask(
                source_path,
                frame_rects,
                style_id,
                style.get("mask", f"masks/{body_type}_{style_id}"),
            )
            for variant in style.get("outfit_variants", {}).values():
                variant_source = GAME_ROOT / f"assets/characters/{variant['sheet']}.png"
                _generate_mask(
                    variant_source,
                    variant["frame_rects"],
                    style_id,
                    variant["mask"],
                )


if __name__ == "__main__":
    generate()
