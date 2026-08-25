# DIY Garden Terrain System Analysis

## Project

- Project file: `game/project.godot`
- Godot feature version: `4.6`
- Main scene: `res://scenes/Main.tscn`
- Garden build autoload: `res://scripts/garden_builder/garden_build_manager.gd`
- Current formal garden scene: runtime scene built by `SceneManager`; tiled reference scene exists at `res://scenes/GardenTiled.tscn`.

## Current Tile System

- The project uses `TileMapLayer`, not Godot 3 `TileMap`.
- Main ground TileSet: `res://assets/garden/tileset/garden_ground_tileset.tres`
- Ground texture: `res://assets/garden/tileset/ground/Tileset_Ground.png`
- Road texture: `res://assets/garden/tileset/ground/Tileset_Road.png`
- Water texture exists: `res://assets/garden/tileset/water/Tileset_Water.png`
- Base tile size: 16 px texture tiles, displayed at 32 px because the build TileMapLayer scale is `2,2`.

## Terrain Set Status

`garden_ground_tileset.tres` currently contains AtlasSource entries only. It does not define Godot Terrain Sets or Terrain Peering Bits. Because of that, the current implementation cannot safely use `set_cells_terrain_connect(...)` yet.

Current phase uses a semantic terrain grid plus `terrain_autotile_resolver.gd` as a compatibility resolver. The save data stores material ids (`dirt`, `stone`, `water`) rather than atlas coordinates.

## Available Terrain Assets

- Ground atlas: 107 non-empty 16x16 tiles detected in the first 10 rows scanned for terrain use.
- Road atlas: 65 non-empty 16x16 tiles detected in the first 12 rows scanned for terrain use.
- Water atlas: 264 non-empty 16x16 tiles detected, but not configured in the project TileSet. It is attached at runtime as a separate water TileMapLayer for this phase.

## Missing / Incomplete

- No configured Terrain Peering Bits.
- No verified 47-tile blob mask manifest in the TileSet.
- No verified material-to-material transition set, such as dirt-to-stone or stone-to-water.
- Water collision/navigation is not finalized in this phase.

## Incorrect Legacy Design

The previous DIY UI exposed individual atlas tiles as selectable player buttons. That mixed renderer resources with player-facing garden products. This has been changed:

- Player terrain UI now exposes material tools only: mud ground, light stone, water, grass restore.
- Individual object placement remains separate: pots, flowerbeds, plants, bridges, furniture, decorations, tools.
- Legacy tile saves can still migrate to semantic terrain data.

## Files Prepared / Modified

- `game/scripts/garden_builder/garden_build_manager.gd`
- `game/scripts/garden_builder/terrain_autotile_resolver.gd`
- `docs/garden_terrain_system_analysis.md`
- `reports/terrain_tileset_validation.md`
- `reports/terrain_mask_manifest.csv`

## Current Material Adjacency Rule

Phase A is used: different terrain materials may be adjacent, but each grid cell stores exactly one semantic material. There are no cross-material transition tiles yet. If visual seams become unacceptable, the next phase should switch to rule B for incomplete material pairs: require one grass cell between incompatible materials.
