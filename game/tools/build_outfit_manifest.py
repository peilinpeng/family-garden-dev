#!/usr/bin/env python3
"""从透明服装动作图集生成精确裁切矩形，并写入外观清单。

每张服装图固定为 3 列 × 5 行。脚本在每个网格单元中读取 alpha 包围盒，
再生成同一张图内尺寸一致、脚底对齐且不会越过单元边界的 15 个裁切矩形。
"""

from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


GAME_ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = GAME_ROOT / "assets/manifest/appearances.json"
OUTFIT_ROOT = GAME_ROOT / "assets/characters/outfits"

STYLE_PREFIXES = {
    ("feminine", "braid_hat"): "girl_braid_hat",
    ("feminine", "soft_bob"): "girl_soft_bob",
    ("masculine", "tousled"): "boy_tousled",
    ("masculine", "side_part"): "boy_sidepart",
}
OUTFIT_IDS = ("forest", "berry", "ocean", "sand")


def _frame_rects(image: Image.Image) -> tuple[list[list[int]], int]:
    alpha = np.asarray(image.getchannel("A"))
    component_count, _, stats, centroids = cv2.connectedComponentsWithStats((alpha > 128).astype(np.uint8), 8)
    components = []
    for component in range(1, component_count):
        left, top, width, height, area = (int(value) for value in stats[component])
        if area < 1000:
            continue
        center_x, center_y = (float(value) for value in centroids[component])
        components.append((center_x, center_y, (left, top, left + width, top + height)))
    if len(components) != 15:
        raise RuntimeError(f"应识别到 15 个完整人物，实际为 {len(components)}")

    components.sort(key=lambda item: item[1])
    boxes: list[tuple[int, int, int, int]] = []
    for row in range(5):
        row_components = sorted(components[row * 3 : row * 3 + 3], key=lambda item: item[0])
        boxes.extend(item[2] for item in row_components)

    frame_width = max(right - left for left, _, right, _ in boxes) + 12
    frame_height = max(bottom - top for _, top, _, bottom in boxes) + 10
    rects: list[list[int]] = []
    for bbox in boxes:
        left, top, right, bottom = bbox
        center_x = (left + right) / 2.0
        rect_left = round(center_x - frame_width / 2.0)
        rect_top = bottom + 4 - frame_height
        rect_left = max(0, min(rect_left, image.width - frame_width))
        rect_top = max(0, min(rect_top, image.height - frame_height))
        rect = [rect_left, rect_top, frame_width, frame_height]
        if not (rect_left <= left and rect_top <= top and rect_left + frame_width >= right and rect_top + frame_height >= bottom):
            raise RuntimeError(f"裁切未完整包含人物：bbox={bbox}, rect={rect}")
        rects.append(rect)
    return rects, frame_height


def build() -> None:
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    for (body_id, style_id), prefix in STYLE_PREFIXES.items():
        style = catalog["body_types"][body_id]["hair_styles"][style_id]
        existing_variants = style.get("outfit_variants", {})
        variants = {}
        for outfit_id in OUTFIT_IDS:
            stem = f"{prefix}_{outfit_id}"
            source_path = OUTFIT_ROOT / f"{stem}.png"
            if not source_path.exists():
                raise FileNotFoundError(source_path)
            source = Image.open(source_path).convert("RGBA")
            rects, frame_height = _frame_rects(source)
            variants[outfit_id] = {
                "sheet": f"outfits/{stem}",
                "mask": f"masks/outfits/{stem}",
                "scale": round(96.0 / frame_height, 4),
                "hframes": 3,
                "vframes": 5,
                "frame_rects": rects,
            }
            # 发色成品由 build_hair_color_sheets.py 生成。重新计算服装裁切时
            # 保留已有映射，避免常规资源维护把运行时可用的发色清单覆盖掉。
            previous = existing_variants.get(outfit_id, {})
            if "hair_sheets" in previous:
                variants[outfit_id]["hair_sheets"] = previous["hair_sheets"]
            print(f"{stem}: {source.width}×{source.height}, frame={rects[0][2]}×{rects[0][3]}, scale={variants[outfit_id]['scale']}")
        style["outfit_variants"] = variants

    CATALOG_PATH.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"已更新 {CATALOG_PATH.relative_to(GAME_ROOT)}")


if __name__ == "__main__":
    build()
