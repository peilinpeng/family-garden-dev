# Garden Terrain Test Report

## Static Checks

- `git diff --check`: passed after implementation.
- 47 个八邻域掩码唯一性：通过。
- 47 个图集坐标唯一性与范围检查：通过；全部位于三张素材共同的前 `6x8` 排布内。
- Godot CLI: not available in PATH in this environment, so editor-level scene validation could not be executed from shell.

## Manual Test Checklist

- Open the main garden.
- Press `B` or use the garden build icon.
- Confirm UI shows `铺地` and `摆设`, not individual atlas tile buttons.
- In `铺地`, choose `泥土地面`, click once, and confirm one semantic terrain cell is painted.
- 分别用泥土和水面绘制 L 形、U 形、窄颈和带多个凹角的不规则区域，确认边缘连续且没有矩形填充块。
- Drag quickly and confirm interpolation prevents gaps.
- Hold `Shift` while dragging and confirm a rectangle preview appears, then commits as one stroke on release.
- Choose `草地恢复` and erase an existing terrain cell.
- Use `Ctrl+Z` and `Ctrl+Y` to undo/redo the last stroke.
- Switch to `摆设` and confirm pots/furniture still place as independent objects.
- Save/reload and confirm `terrain_cells` are loaded semantically rather than as atlas tile ids.

## Current Coverage

- Implemented in code: click, drag, shift-rectangle, erase via grass restore, undo/redo, semantic save/load, old tile migration.
- Implemented in code: shared 47-tile blob mapping for dirt, stone and water, including diagonal inner corners.
- Needs editor QA: visual correctness of irregular terrain, water collision/navigation, camera zoom coordinate validation.
