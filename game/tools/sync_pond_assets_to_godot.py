#!/usr/bin/env python3
"""Sync organized pond source assets into the real Godot project.

Dry run:
    python tools/sync_pond_assets_to_godot.py --dry-run

Apply:
    python tools/sync_pond_assets_to_godot.py --apply
"""

from __future__ import annotations

import argparse
import json
import shutil
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, List, Tuple

DEFAULT_SOURCE = Path(r"E:\000\family garden\assets\pond")
DIRECTIONS = [
    "up",
    "up_right",
    "right",
    "down_right",
    "down",
    "down_left",
    "left",
    "up_left",
]

PROPS = {
    "bench_seat.png",
    "fishing_platform.png",
    "metal_bucket.png",
    "metal_crate.png",
    "rope_coil.png",
    "water_bucket.png",
    "wooden_sign.png",
}

DECORATIONS = {
    "fence_section.png",
    "flower_bed.png",
    "flower_pot.png",
    "lotus_flower_01.png",
    "lotus_flower_02.png",
    "lotus_flower_03.png",
    "pond_hut_01.png",
    "pond_hut_02.png",
    "stone_lantern.png",
}


@dataclass
class SyncOp:
    source_path: str
    target_path: str
    action: str
    asset_type: str
    notes: str


def rel(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def target_for(source: Path, source_root: Path, godot_root: Path) -> Tuple[Path, str, str]:
    source_rel = source.relative_to(source_root)
    parts = source_rel.parts
    name = source.name

    if parts[0] == "background":
        return godot_root / "assets" / "pond" / "background" / name, "background", "Pond background layer."

    if parts[0] == "fish":
        variant = parts[1] if len(parts) > 2 else "koi_fish_01"
        return (
            godot_root / "assets" / "pond" / "fish" / "koi_fish" / variant / name,
            "fish",
            "Koi fish 8-direction sprite frame; variant folder prevents filename collisions.",
        )

    if parts[0] == "frog":
        return godot_root / "assets" / "pond" / "frog" / name, "frog", "Frog sprite; source action is not yet identified."

    if parts[0] == "water":
        return godot_root / "assets" / "pond" / "water" / name, "water", "Water ripple/effect sprite."

    if parts[0] == "items":
        if name in PROPS:
            return godot_root / "assets" / "pond" / "props" / name, "prop", "Interactive or placeable pond prop."
        if name in DECORATIONS:
            return godot_root / "assets" / "pond" / "decorations" / name, "decoration", "Static pond decoration."
        return godot_root / "assets" / "pond" / "unsorted" / name, "unsorted", "Item needs manual review."

    if parts[0] == "unsorted":
        return godot_root / "assets" / "pond" / "unsorted" / name, "unsorted", "Unsorted source asset copied for review."

    return godot_root / "assets" / "pond" / "unsorted" / name, "unsorted", "Unknown source folder; copied for review."


def action_for(source: Path, target: Path) -> Tuple[str, str]:
    if not target.exists():
        return "copy", "Target does not exist yet."

    source_stat = source.stat()
    target_stat = target.stat()
    same_size = source_stat.st_size == target_stat.st_size
    same_mtime = abs(source_stat.st_mtime - target_stat.st_mtime) < 1.0
    if same_size and same_mtime:
        return "skip_same", "Target already matches source size and modified time."

    return (
        "copy_overwrite",
        "Target exists but differs from source: "
        f"source_size={source_stat.st_size}, target_size={target_stat.st_size}, "
        f"source_mtime={source_stat.st_mtime:.0f}, target_mtime={target_stat.st_mtime:.0f}.",
    )


def build_plan(source_root: Path, godot_root: Path) -> List[SyncOp]:
    if not source_root.exists():
        raise FileNotFoundError(f"Source pond directory not found: {source_root}")

    ops: List[SyncOp] = []
    seen: Dict[str, str] = {}
    for source in sorted(path for path in source_root.rglob("*") if path.is_file()):
        if "backup" in [part.lower() for part in source.parts]:
            continue
        target, asset_type, notes = target_for(source, source_root, godot_root)
        target_rel = rel(target, godot_root)
        if target_rel in seen:
            raise RuntimeError(f"Target collision: {target_rel} from {seen[target_rel]} and {source}")
        seen[target_rel] = str(source)
        action, action_notes = action_for(source, target)
        ops.append(
            SyncOp(
                source_path=str(source),
                target_path=target_rel,
                action=action,
                asset_type=asset_type,
                notes=f"{notes} {action_notes}",
            )
        )
    return ops


def write_plan(godot_root: Path, ops: List[SyncOp]) -> Path:
    plan_path = godot_root / "tools" / "sync_pond_assets_plan.json"
    plan_path.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "godot_root": str(godot_root),
        "source_root": str(DEFAULT_SOURCE),
        "total_files": len(ops),
        "operations": [asdict(op) for op in ops],
    }
    plan_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return plan_path


def build_manifest(ops: List[SyncOp]) -> Dict[str, object]:
    def res_path(target_path: str) -> str:
        return "res://" + target_path.replace("\\", "/")

    manifest: Dict[str, object] = {
        "pond_background": {
            "type": "background",
            "path": "res://assets/pond/background/pond_background.png",
        },
        "koi_fish": {
            "type": "animated_sprite_collection",
            "path": "res://assets/pond/fish/koi_fish",
            "directions": DIRECTIONS,
            "variants": [],
        },
        "frog": {
            "type": "sprite_or_animation",
            "path": "res://assets/pond/frog",
            "note": "Frog actions are not identified yet; filenames remain frog_unknown_##.",
        },
        "water_ripple": {
            "type": "animation",
            "path": "res://assets/pond/water",
        },
        "props": {
            "type": "static_or_interactive_sprites",
            "path": "res://assets/pond/props",
            "files": [],
        },
        "decorations": {
            "type": "static_sprites",
            "path": "res://assets/pond/decorations",
            "files": [],
        },
        "unsorted": {
            "type": "needs_review",
            "path": "res://assets/pond/unsorted",
            "files": [],
        },
    }

    variants = sorted(
        {
            Path(op.target_path).parts[4]
            for op in ops
            if op.asset_type == "fish" and len(Path(op.target_path).parts) >= 6
        }
    )
    manifest["koi_fish"]["variants"] = [
        {
            "name": variant,
            "type": "animated_sprite_8_direction",
            "path": f"res://assets/pond/fish/koi_fish/{variant}",
        }
        for variant in variants
    ]

    for key, asset_type in [("props", "prop"), ("decorations", "decoration"), ("unsorted", "unsorted")]:
        manifest[key]["files"] = [res_path(op.target_path) for op in ops if op.asset_type == asset_type]

    return manifest


def apply_plan(godot_root: Path, ops: List[SyncOp]) -> Dict[str, object]:
    copied = 0
    overwritten = 0
    skipped = 0
    for op in ops:
        source = Path(op.source_path)
        target = godot_root / op.target_path
        target.parent.mkdir(parents=True, exist_ok=True)
        if op.action == "skip_same":
            skipped += 1
            continue

        if op.action == "copy_overwrite":
            overwritten += 1
        else:
            copied += 1
        shutil.copy2(source, target)

    manifest_path = godot_root / "assets" / "pond" / "pond_asset_manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(build_manifest(ops), ensure_ascii=False, indent=2), encoding="utf-8")

    report = {
        "total_planned_files": len(ops),
        "copied_new_files": copied,
        "overwritten_files": overwritten,
        "skipped_same_files": skipped,
        "manifest_path": str(manifest_path),
        "operations": [asdict(op) for op in ops],
    }
    report_path = godot_root / "tools" / "sync_pond_assets_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync organized pond assets into a Godot project.")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--dry-run", action="store_true", help="Generate sync_pond_assets_plan.json only.")
    group.add_argument("--apply", action="store_true", help="Copy assets into the Godot project and write manifest.")
    parser.add_argument("--source", default=str(DEFAULT_SOURCE), help="Organized source pond directory.")
    args = parser.parse_args()

    godot_root = Path(__file__).resolve().parents[1]
    source_root = Path(args.source).resolve()
    ops = build_plan(source_root, godot_root)
    plan_path = write_plan(godot_root, ops)

    if args.apply:
        report = apply_plan(godot_root, ops)

    print(f"Godot root: {godot_root}")
    print(f"Source root: {source_root}")
    print(f"Planned files: {len(ops)}")
    print(f"Plan: {plan_path}")
    if args.apply:
        print(f"Manifest: {godot_root / 'assets' / 'pond' / 'pond_asset_manifest.json'}")
        print(
            "Apply summary: "
            f"copied={report['copied_new_files']}, "
            f"overwritten={report['overwritten_files']}, "
            f"skipped_same={report['skipped_same_files']}"
        )


if __name__ == "__main__":
    main()
