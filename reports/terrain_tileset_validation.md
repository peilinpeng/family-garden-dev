# Terrain TileSet 验证

## 结论

泥土、石板路和水面现已统一使用素材图集前 `6x8` 区域的 47 格 blob 排布。运行时解析器同时计算四方向和有效对角邻居，可覆盖单格、直线、外角、T 形、多内凹角和完整填充。

## 实现说明

- `garden_ground_tileset.tres` has AtlasSource entries for ground and road.
- It does not contain configured Terrain Sets or Terrain Peering Bits.
- The previous UI exposed atlas tiles directly to the player. This is now hidden from the player UI.
- `terrain_autotile_resolver.gd` 使用 47 个唯一的八邻域掩码映射图集坐标。
- 三类地形共用同一坐标排布，仅 TileSet source/layer 不同。
- 修改任意地形格时会重算其周围八格，内凹角能即时更新。

## Tile Counts

- Ground atlas scanned: 12 columns x 10 rows, 107 non-empty tiles.
- Road atlas scanned: 6 columns x 12 rows, 65 non-empty tiles.
- Water atlas scanned: 24 columns x 13 rows, 264 non-empty tiles.

## 验证结果

- Terrain Peering Bits complete: no.
- Duplicate mask check: passed; 47 个掩码和 47 个图集坐标均唯一。
- Missing mask check: passed for the 47-tile blob rule.
- Wrong direction check: requires visual QA in Godot editor.
- 图集其余区域属于装饰/变化版本，不参与基础连接计算。

## 当前支持

- Mud ground: semantic paint, custom 47-tile auto variant.
- Light stone: semantic paint, custom 47-tile auto variant.
- Water: semantic paint, runtime water TileMapLayer, custom 47-tile auto variant.
- Grass restore: semantic erase back to base grass.

## 已知限制

- No finalized water collision/navigation.
- No cross-material transition tiles.
- Current resolver is intentionally isolated in `terrain_autotile_resolver.gd` so it can be replaced by Godot Terrain Set later.
