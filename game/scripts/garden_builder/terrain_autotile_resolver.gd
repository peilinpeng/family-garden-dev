extends RefCounted
class_name TerrainAutotileResolver

const TERRAIN_GRASS := "grass"
const TERRAIN_DIRT := "dirt"
const TERRAIN_STONE := "stone"
const TERRAIN_WATER := "water"

const BIT_N := 1
const BIT_E := 2
const BIT_S := 4
const BIT_W := 8
const BIT_NW := 16
const BIT_NE := 32
const BIT_SE := 64
const BIT_SW := 128

# Tileset_Dirt、Tileset_Road 与 Tileset_Water 的前 6x8 区域使用同一套
# 47-tile blob 排布。键由四个正交邻居和有效的对角邻居组成；只有相邻的
# 两个正交方向都连通时，对应的对角位才参与匹配。
const BLOB_MASK_TO_ATLAS := {
	4: Vector2i(0, 0),
	70: Vector2i(1, 0),
	206: Vector2i(2, 0),
	140: Vector2i(3, 0),
	78: Vector2i(4, 0),
	141: Vector2i(5, 0),
	5: Vector2i(0, 1),
	103: Vector2i(1, 1),
	255: Vector2i(2, 1),
	157: Vector2i(3, 1),
	39: Vector2i(4, 1),
	27: Vector2i(5, 1),
	1: Vector2i(0, 2),
	35: Vector2i(1, 2),
	59: Vector2i(2, 2),
	25: Vector2i(3, 2),
	71: Vector2i(4, 2),
	142: Vector2i(5, 2),
	0: Vector2i(0, 3),
	2: Vector2i(1, 3),
	10: Vector2i(2, 3),
	8: Vector2i(3, 3),
	43: Vector2i(4, 3),
	29: Vector2i(5, 3),
	191: Vector2i(0, 4),
	127: Vector2i(1, 4),
	6: Vector2i(2, 4),
	12: Vector2i(3, 4),
	207: Vector2i(4, 4),
	159: Vector2i(5, 4),
	223: Vector2i(0, 5),
	239: Vector2i(1, 5),
	3: Vector2i(2, 5),
	9: Vector2i(3, 5),
	111: Vector2i(4, 5),
	63: Vector2i(5, 5),
	79: Vector2i(0, 6),
	143: Vector2i(1, 6),
	11: Vector2i(2, 6),
	7: Vector2i(3, 6),
	175: Vector2i(4, 6),
	95: Vector2i(5, 6),
	47: Vector2i(0, 7),
	31: Vector2i(1, 7),
	13: Vector2i(2, 7),
	14: Vector2i(3, 7),
	15: Vector2i(4, 7)
}

static func mask_for(cell: Vector2i, terrain_id: String, terrain_cells: Dictionary) -> int:
	var mask: int = 0
	if _is_terrain(cell + Vector2i(0, -1), terrain_id, terrain_cells):
		mask |= BIT_N
	if _is_terrain(cell + Vector2i(1, 0), terrain_id, terrain_cells):
		mask |= BIT_E
	if _is_terrain(cell + Vector2i(0, 1), terrain_id, terrain_cells):
		mask |= BIT_S
	if _is_terrain(cell + Vector2i(-1, 0), terrain_id, terrain_cells):
		mask |= BIT_W
	return mask

static func blob_mask_for(cell: Vector2i, terrain_id: String, terrain_cells: Dictionary) -> int:
	var mask: int = mask_for(cell, terrain_id, terrain_cells)
	if (mask & BIT_N) != 0 and (mask & BIT_W) != 0 and _is_terrain(cell + Vector2i(-1, -1), terrain_id, terrain_cells):
		mask |= BIT_NW
	if (mask & BIT_N) != 0 and (mask & BIT_E) != 0 and _is_terrain(cell + Vector2i(1, -1), terrain_id, terrain_cells):
		mask |= BIT_NE
	if (mask & BIT_S) != 0 and (mask & BIT_E) != 0 and _is_terrain(cell + Vector2i(1, 1), terrain_id, terrain_cells):
		mask |= BIT_SE
	if (mask & BIT_S) != 0 and (mask & BIT_W) != 0 and _is_terrain(cell + Vector2i(-1, 1), terrain_id, terrain_cells):
		mask |= BIT_SW
	return mask

static func resolve_cell(terrain_id: String, cell: Vector2i, terrain_cells: Dictionary) -> Dictionary:
	return _resolve_blob(terrain_id, blob_mask_for(cell, terrain_id, terrain_cells))

static func resolve_water(cell: Vector2i, terrain_cells: Dictionary) -> Dictionary:
	return resolve_cell(TERRAIN_WATER, cell, terrain_cells)

# 保留四方向 resolve 接口给工具图标和旧调用；把存在的对角视为完整连接。
static func resolve(terrain_id: String, cardinal_mask: int) -> Dictionary:
	return _resolve_blob(terrain_id, _with_connected_diagonals(cardinal_mask & 15))

static func _resolve_blob(terrain_id: String, blob_mask: int) -> Dictionary:
	var atlas_value: Variant = BLOB_MASK_TO_ATLAS.get(blob_mask, Vector2i(0, 3))
	var atlas: Vector2i = atlas_value if atlas_value is Vector2i else Vector2i(0, 3)
	match terrain_id:
		TERRAIN_DIRT:
			return {"source_id": 0, "atlas": atlas, "layer": "surface", "mask": blob_mask}
		TERRAIN_STONE:
			return {"source_id": 1, "atlas": atlas, "layer": "surface", "mask": blob_mask}
		TERRAIN_WATER:
			return {"source_id": 0, "atlas": atlas, "layer": "water", "mask": blob_mask}
		_:
			return {"source_id": -1, "atlas": Vector2i.ZERO, "layer": "base", "mask": blob_mask}

static func _with_connected_diagonals(cardinal_mask: int) -> int:
	var mask: int = cardinal_mask
	if (mask & BIT_N) != 0 and (mask & BIT_W) != 0:
		mask |= BIT_NW
	if (mask & BIT_N) != 0 and (mask & BIT_E) != 0:
		mask |= BIT_NE
	if (mask & BIT_S) != 0 and (mask & BIT_E) != 0:
		mask |= BIT_SE
	if (mask & BIT_S) != 0 and (mask & BIT_W) != 0:
		mask |= BIT_SW
	return mask

static func _is_terrain(cell: Vector2i, terrain_id: String, terrain_cells: Dictionary) -> bool:
	return String(terrain_cells.get(cell, TERRAIN_GRASS)) == terrain_id

static func affected_cells(cell: Vector2i) -> Array[Vector2i]:
	return [
		cell,
		cell + Vector2i(0, -1),
		cell + Vector2i(1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(-1, 0),
		cell + Vector2i(-1, -1),
		cell + Vector2i(1, -1),
		cell + Vector2i(1, 1),
		cell + Vector2i(-1, 1)
	]
