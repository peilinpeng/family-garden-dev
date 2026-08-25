#!/usr/bin/env python3
"""基于现有儿子/女儿动作图集烘焙统一画风的爸爸妈妈版本。"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


GAME_ROOT = Path(__file__).resolve().parents[1]
CHARACTER_ROOT = GAME_ROOT / "assets" / "characters"
MANIFEST_PATH = GAME_ROOT / "assets" / "manifest" / "appearances.json"
OUTPUT_ROOT = CHARACTER_ROOT / "parents"

FRONT_FRAMES = (0, 1, 2, 12, 13, 14)
LEFT_FRAMES = (3, 4, 5)
RIGHT_FRAMES = (6, 7, 8)


def _line(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], color: tuple[int, int, int, int], width: int = 1) -> None:
    draw.line(points, fill=color, width=width)


def _add_father_face(image: Image.Image, rects: list[list[int]]) -> None:
    """增加短髭与眼角纹；身体、服装和动作像素完全沿用儿子图集。"""
    draw = ImageDraw.Draw(image)
    ink = (75, 42, 29, 255)
    soft = (132, 70, 48, 220)
    for index, (x, y, width, height) in enumerate(rects):
        if index in FRONT_FRAMES:
            cx = x + round(width * 0.50)
            mouth_y = y + round(height * 0.420)
            _line(draw, [(cx - 9, mouth_y - 1), (cx - 2, mouth_y + 1)], ink, 2)
            _line(draw, [(cx + 2, mouth_y + 1), (cx + 9, mouth_y - 1)], ink, 2)
            draw.point((cx - 11, mouth_y - 12), fill=soft)
            draw.point((cx + 11, mouth_y - 12), fill=soft)
        elif index in LEFT_FRAMES:
            px = x + round(width * 0.235)
            py = y + round(height * 0.355)
            _line(draw, [(px - 1, py), (px + 6, py + 1)], ink, 2)
        elif index in RIGHT_FRAMES:
            px = x + round(width * 0.765)
            py = y + round(height * 0.355)
            _line(draw, [(px - 6, py + 1), (px + 1, py)], ink, 2)


def _rect_outline(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], color: tuple[int, int, int, int]) -> None:
    draw.rectangle(box, outline=color, width=1)


def _add_mother_face(image: Image.Image, rects: list[list[int]]) -> None:
    """增加轻巧圆框眼镜；身体、服装和动作像素完全沿用女儿图集。"""
    draw = ImageDraw.Draw(image)
    frame = (86, 53, 42, 255)
    highlight = (185, 137, 91, 210)
    for index, (x, y, width, height) in enumerate(rects):
        if index in FRONT_FRAMES:
            eye_y = y + round(height * 0.345)
            left_x = x + round(width * 0.388)
            right_x = x + round(width * 0.612)
            lens_w = max(12, round(width * 0.082))
            lens_h = max(10, round(height * 0.039))
            _rect_outline(draw, (left_x - lens_w // 2, eye_y - lens_h // 2, left_x + lens_w // 2, eye_y + lens_h // 2), frame)
            _rect_outline(draw, (right_x - lens_w // 2, eye_y - lens_h // 2, right_x + lens_w // 2, eye_y + lens_h // 2), frame)
            _line(draw, [(left_x + lens_w // 2, eye_y), (right_x - lens_w // 2, eye_y)], frame)
            draw.point((left_x - 2, eye_y - 2), fill=highlight)
            draw.point((right_x - 2, eye_y - 2), fill=highlight)
        elif index in LEFT_FRAMES:
            eye_x = x + round(width * 0.292)
            eye_y = y + round(height * 0.325)
            lens_w = max(12, round(width * 0.082))
            lens_h = max(10, round(height * 0.039))
            _rect_outline(draw, (eye_x - lens_w // 2, eye_y - lens_h // 2, eye_x + lens_w // 2, eye_y + lens_h // 2), frame)
            _line(draw, [(eye_x + lens_w // 2, eye_y), (eye_x + lens_w // 2 + 5, eye_y + 1)], frame)
        elif index in RIGHT_FRAMES:
            eye_x = x + round(width * 0.708)
            eye_y = y + round(height * 0.325)
            lens_w = max(12, round(width * 0.082))
            lens_h = max(10, round(height * 0.039))
            _rect_outline(draw, (eye_x - lens_w // 2, eye_y - lens_h // 2, eye_x + lens_w // 2, eye_y + lens_h // 2), frame)
            _line(draw, [(eye_x - lens_w // 2 - 5, eye_y + 1), (eye_x - lens_w // 2, eye_y)], frame)


def _build_variant(source_path: Path, output_path: Path, rects: list[list[int]], role: str) -> None:
    image = Image.open(source_path).convert("RGBA")
    if role == "father":
        _add_father_face(image, rects)
    else:
        _add_mother_face(image, rects)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path, optimize=True)


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    specs = {
        "father": ("masculine", "side_part"),
        "mother": ("feminine", "soft_bob"),
    }
    for role, (body_id, style_id) in specs.items():
        style = manifest["body_types"][body_id]["hair_styles"][style_id]
        variants = {"original": style}
        variants.update(style.get("outfit_variants", {}))
        for outfit_id, definition in variants.items():
            source = CHARACTER_ROOT / f"{definition['sheet']}.png"
            output = OUTPUT_ROOT / f"{role}_{outfit_id}.png"
            _build_variant(source, output, definition["frame_rects"], role)
            print(output.relative_to(GAME_ROOT))


if __name__ == "__main__":
    main()
