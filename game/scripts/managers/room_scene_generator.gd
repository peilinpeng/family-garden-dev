class_name RoomSceneGenerator
extends RefCounted

const CATALOG_PATH := "res://assets/manifest/room_object_catalog.json"
const DEFAULT_TILESET := "kitchen"

# v1 房间已经把 cell 写进存档。这里仅在渲染时把旧位置映射到新版构图，
# 不改存档、不改 AI 契约；交互锚点和碰撞也使用同一映射。
const LEGACY_PRESENTATION_CELLS := {
	"desk:back_left": Vector2i(2, 4),
	"lamp:back_left": Vector2i(5, 4),
	"lamp:back_center": Vector2i(7, 4),
	"photo_wall:back_wall": Vector2i(6, 1),
	"plant:right_side": Vector2i(16, 5),
	"chair:floor_center": Vector2i(7, 6),
	"bed:back_right": Vector2i(14, 4),
}

const LEGACY_ZONE_CELLS := {
	"back_wall": Vector2i(6, 1),
	"back_left": Vector2i(2, 4),
	"back_center": Vector2i(7, 4),
	"back_right": Vector2i(14, 4),
	"left_side": Vector2i(2, 6),
	"right_side": Vector2i(16, 5),
	"front_left": Vector2i(3, 8),
	"front_center": Vector2i(8, 8),
	"front_right": Vector2i(15, 8),
	"floor_center": Vector2i(7, 6),
}

static var _catalog_cache: Dictionary = {}

static func catalog() -> Dictionary:
	if not _catalog_cache.is_empty():
		return _catalog_cache
	if not FileAccess.file_exists(CATALOG_PATH):
		return {}
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_catalog_cache = parsed
	return _catalog_cache

static func catalog_entry(object_id: String) -> Dictionary:
	var objects: Dictionary = catalog().get("objects", {})
	return (objects.get(object_id, {}) as Dictionary).duplicate(true)

static func has_scene_schema(room: Dictionary) -> bool:
	var schema: Variant = room.get("scene_schema", {})
	return schema is Dictionary and not (schema as Dictionary).is_empty()

static func build_schema(analysis: Dictionary, layout: Dictionary) -> Dictionary:
	var cat := catalog()
	if cat.is_empty():
		return {"ok": false, "errors": ["missing_catalog"]}
	var tileset: Dictionary = (cat.get("tilesets", {}) as Dictionary).get(DEFAULT_TILESET, {})
	if tileset.is_empty():
		return {"ok": false, "errors": ["missing_tileset"]}
	var zone_cells: Dictionary = cat.get("zone_cells", {})
	var used: Dictionary = {}
	var objects: Array = []
	var errors: Array[String] = []
	var warnings: Array[String] = []
	for raw in layout.get("objects", []):
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw
		var object_id := String(item.get("object_type", ""))
		var entry := catalog_entry(object_id)
		if entry.is_empty():
			errors.append("unknown_object:" + object_id)
			continue
		var zone := String(item.get("zone", ""))
		var cell := _next_cell_for_zone(zone_cells, zone, entry, used)
		if cell == Vector2i(-1, -1):
			warnings.append("zone_full:" + zone + ":" + object_id)
			continue
		var size := _vec2i(entry.get("size", [1, 1]), Vector2i.ONE)
		objects.append({
			"id": object_id,
			"label": String(entry.get("label", object_id)),
			"zone": zone,
			"slot_id": String(item.get("slot_id", "")),
			"cell": [cell.x, cell.y],
			"size": [size.x, size.y],
			"collision": bool(entry.get("collision", false)),
			"anchor": String(entry.get("anchor", "bottom")),
		})
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "warnings": warnings}
	if objects.is_empty():
		return {"ok": false, "errors": ["empty_scene"], "warnings": warnings}
	var grid_size := _vec2i(tileset.get("grid_size", [34, 22]), Vector2i(34, 22))
	var tile_size := _vec2i(tileset.get("tile_size", [16, 16]), Vector2i(16, 16))
	var origin := _vec2(tileset.get("origin", [96, 8]), Vector2(96, 8))
	return {
		"ok": true,
		"schema": {
			"version": 3,
			"visual_version": 3,
			"generator": "room-scene-v1",
			"tileset": DEFAULT_TILESET,
			"tile_set": String(tileset.get("tile_set", "")),
			"source_id": int(tileset.get("source_id", 0)),
			"tile_size": [tile_size.x, tile_size.y],
			"display_scale": int(tileset.get("display_scale", 2)),
			"grid_size": [grid_size.x, grid_size.y],
			"origin": [origin.x, origin.y],
			"wall_height": 4,
			"floor": tileset.get("floor", [4, 3]),
			"wall": tileset.get("wall", [0, 0]),
			"room_type": String(analysis.get("room_type", "unknown")),
			"theme": String(analysis.get("suggested_room_theme", "memory_corner")),
			"style": String(analysis.get("style", "warm_cozy")),
			"objects": objects,
		},
		"warnings": warnings,
	}

static func validate_schema(schema: Dictionary) -> Dictionary:
	var cat := catalog()
	var errors: Array[String] = []
	var tileset_key := String(schema.get("tileset", ""))
	var tileset: Dictionary = (cat.get("tilesets", {}) as Dictionary).get(tileset_key, {})
	if tileset.is_empty():
		errors.append("unknown_tileset:" + tileset_key)
	var grid := _vec2i(schema.get("grid_size", [0, 0]), Vector2i.ZERO)
	var occupied: Dictionary = {}
	for raw in schema.get("objects", []):
		if not (raw is Dictionary):
			continue
		var obj: Dictionary = raw
		var object_id := String(obj.get("id", ""))
		var entry := catalog_entry(object_id)
		if entry.is_empty():
			errors.append("unknown_object:" + object_id)
			continue
		var cell := _vec2i(obj.get("cell", [-1, -1]), Vector2i(-1, -1))
		var size := _vec2i(obj.get("size", entry.get("size", [1, 1])), Vector2i.ONE)
		if cell.x < 0 or cell.y < 0 or cell.x + size.x > grid.x or cell.y + size.y > grid.y:
			errors.append("out_of_bounds:" + object_id)
			continue
		for y in range(cell.y, cell.y + size.y):
			for x in range(cell.x, cell.x + size.x):
				var key := "%d,%d" % [x, y]
				if occupied.has(key):
					errors.append("overlap:" + object_id)
				occupied[key] = object_id
	return {"ok": errors.is_empty(), "errors": errors}

static func render_scene(room: Dictionary, world: Node) -> Dictionary:
	var schema: Dictionary = room.get("scene_schema", {})
	var validation := validate_schema(schema)
	if not bool(validation.get("ok", false)):
		return validation
	var visual_schema := _presentation_schema(schema)
	var tile_set_path := String(visual_schema.get("tile_set", ""))
	var tile_set := load(tile_set_path) as TileSet
	if tile_set == null:
		return {"ok": false, "errors": ["missing_tileset_resource"]}
	var root := Node2D.new()
	root.name = "GeneratedRoomScene"
	root.position = _vec2(visual_schema.get("origin", [96, 8]), Vector2(96, 8))
	root.scale = Vector2.ONE * float(visual_schema.get("display_scale", 2))
	root.z_index = -90
	root.z_as_relative = false
	world.add_child(root)
	_add_room_backdrop(root, visual_schema)
	var wall_texture := _make_layer("WallTexture", tile_set, -2)
	var floor := _make_layer("Floor", tile_set, -1)
	var furniture := _make_layer("Furniture", tile_set, 0)
	# TileSet 只承担轻微材质颗粒，主色由程序化背景控制，避免整间房偏灰紫。
	wall_texture.modulate = Color(1.0, 0.96, 0.90, 0.055)
	floor.modulate = Color(1.0, 0.93, 0.86, 0.10)
	root.add_child(wall_texture)
	root.add_child(floor)
	root.add_child(furniture)
	_paint_floor(floor, visual_schema)
	_paint_walls(wall_texture, visual_schema)
	_paint_objects(furniture, visual_schema)
	_paint_procedural_objects(root, visual_schema)
	_add_collisions(root, visual_schema)
	return {"ok": true, "root": root}

static func point_for_room_object(room: Dictionary, object: Dictionary) -> Dictionary:
	var schema: Dictionary = _presentation_schema(room.get("scene_schema", {}))
	if schema.is_empty():
		return {}
	for raw in schema.get("objects", []):
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw
		if String(item.get("slot_id", "")) != "" and String(item.get("slot_id", "")) == String(object.get("slot_id", "")):
			return _point_from_schema_object(schema, item)
		if String(item.get("id", "")) == String(object.get("object_type", "")) and String(item.get("zone", "")) == String(object.get("zone", "")):
			return _point_from_schema_object(schema, item)
	return {}

static func spawn_position(room: Dictionary, fallback: Vector2 = Vector2(640, 560)) -> Vector2:
	var schema: Dictionary = _presentation_schema(room.get("scene_schema", {}))
	if schema.is_empty():
		return fallback
	var origin := _vec2(schema.get("origin", [96, 8]), Vector2(96, 8))
	var tile := _vec2i(schema.get("tile_size", [16, 16]), Vector2i(16, 16))
	var scale := float(schema.get("display_scale", 2))
	var grid := _vec2i(schema.get("grid_size", [34, 22]), Vector2i(34, 22))
	# 给底部常驻导航留出 96px 视觉安全区，角色进入房间时完整可见。
	return origin + Vector2(float(grid.x) * float(tile.x) * 0.5, (float(grid.y) - 3.15) * float(tile.y)) * scale

static func _make_layer(layer_name: String, tile_set: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.y_sort_enabled = true
	layer.z_index = z
	return layer

static func _paint_floor(layer: TileMapLayer, schema: Dictionary) -> void:
	var grid := _vec2i(schema.get("grid_size", [34, 22]), Vector2i(34, 22))
	var floor_tile := _vec2i(schema.get("floor", [4, 3]), Vector2i(4, 3))
	var source_id := int(schema.get("source_id", 0))
	var wall_height := clampi(int(schema.get("wall_height", 8)), 2, grid.y - 1)
	for y in range(wall_height, grid.y):
		for x in range(grid.x):
			layer.set_cell(Vector2i(x, y), source_id, floor_tile)

static func _paint_walls(layer: TileMapLayer, schema: Dictionary) -> void:
	var grid := _vec2i(schema.get("grid_size", [34, 22]), Vector2i(34, 22))
	var wall_tile := _vec2i(schema.get("wall", [0, 0]), Vector2i.ZERO)
	var source_id := int(schema.get("source_id", 0))
	var wall_height := clampi(int(schema.get("wall_height", 8)), 2, grid.y - 1)
	for y in range(wall_height):
		for x in range(grid.x):
			layer.set_cell(Vector2i(x, y), source_id, wall_tile)

static func _add_room_backdrop(root: Node2D, schema: Dictionary) -> void:
	var grid := _vec2i(schema.get("grid_size", [40, 23]), Vector2i(40, 23))
	var tile := _vec2i(schema.get("tile_size", [16, 16]), Vector2i(16, 16))
	var wall_height := clampi(int(schema.get("wall_height", 8)), 2, grid.y - 1)
	var room_size := Vector2(grid) * Vector2(tile)
	var wall_px := float(wall_height * tile.y)
	var backdrop := Node2D.new()
	backdrop.name = "RoomBackdrop"
	backdrop.z_index = -4
	root.add_child(backdrop)

	# 奶油灰墙 + 蜂蜜胡桃木地板。墙地对比明确，但整体保持低饱和。
	# 四周额外留出 64 美术像素出血，aspect=expand 时不会露出工程底色。
	_add_backdrop_rect(backdrop, "WallpaperBleed", Vector2(-64, -32), Vector2(room_size.x + 128, wall_px + 32), Color("d8cabb"))
	_add_backdrop_rect(backdrop, "FloorBleed", Vector2(-64, wall_px), Vector2(room_size.x + 128, room_size.y - wall_px + 32), Color("94684f"))
	_add_backdrop_rect(backdrop, "WallpaperBase", Vector2.ZERO, Vector2(room_size.x, wall_px), Color("d8cabb"))
	_add_backdrop_rect(backdrop, "WallpaperWarmth", Vector2(0, 7), Vector2(room_size.x, wall_px - 12), Color(0.96, 0.91, 0.82, 0.20))
	_add_backdrop_rect(backdrop, "FloorBase", Vector2(0, wall_px), Vector2(room_size.x, room_size.y - wall_px), Color("94684f"))
	_add_backdrop_rect(backdrop, "FloorWarmth", Vector2(0, wall_px), Vector2(room_size.x, room_size.y - wall_px), Color(0.74, 0.43, 0.25, 0.12))

	# 墙纸采用疏朗的竖向织物纹理，避免旧版横条纹带来的“灰雾”感。
	for x in range(tile.x * 2, int(room_size.x), tile.x * 2):
		_add_backdrop_rect(backdrop, "WallpaperThread_%d" % x, Vector2(x, 10), Vector2(1, wall_px - 22), Color(0.43, 0.34, 0.28, 0.055))
	for x in range(tile.x * 6, int(room_size.x), tile.x * 6):
		_add_backdrop_rect(backdrop, "WallPanel_%d" % x, Vector2(x, 12), Vector2(1, wall_px - 26), Color(0.39, 0.30, 0.25, 0.09))

	# 双层踢脚线把墙与地板牢固地压在一起。
	_add_backdrop_rect(backdrop, "BaseboardShadow", Vector2(0, wall_px - 1), Vector2(room_size.x, 7), Color(0.20, 0.14, 0.11, 0.34))
	_add_backdrop_rect(backdrop, "Baseboard", Vector2(0, wall_px - 5), Vector2(room_size.x, 5), Color("76513e"))
	_add_backdrop_rect(backdrop, "BaseboardHighlight", Vector2(0, wall_px - 5), Vector2(room_size.x, 1), Color(0.95, 0.79, 0.62, 0.40))

	# 宽木板的横缝和错位短缝，密度更接近 soft pixel art。
	for y in range(int(wall_px + tile.y * 2), int(room_size.y), tile.y * 2):
		_add_backdrop_rect(backdrop, "FloorLine_%d" % y, Vector2(0, y), Vector2(room_size.x, 1), Color(0.25, 0.14, 0.10, 0.14))
	for row in range(0, int((room_size.y - wall_px) / float(tile.y * 2)) + 1):
		var y := wall_px + float(row * tile.y * 2)
		var offset := tile.x * 2 if row % 2 == 0 else tile.x * 5
		for x in range(int(offset), int(room_size.x), tile.x * 7):
			_add_backdrop_rect(backdrop, "Plank_%d_%d" % [x, row], Vector2(x, y), Vector2(1, tile.y * 2), Color(0.24, 0.13, 0.09, 0.12))

	_add_room_window(backdrop, room_size, wall_px)
	_add_study_rug(backdrop, room_size, wall_px)
	_add_architectural_details(backdrop, room_size, wall_px)
	_add_room_light(root, room_size, wall_px)

static func _add_room_window(parent: Node2D, room_size: Vector2, wall_px: float) -> void:
	# 给右上角轻量状态卡留出独立呼吸区，宽屏和 1280 画布都不压住窗框。
	var window_pos := Vector2(room_size.x * 0.64 - 45, 10)
	var phase := _room_phase()
	var sky_color := Color("86a9bf")
	if phase == "night":
		sky_color = Color("596783")
	elif phase == "dawn":
		sky_color = Color("c48782")
	elif phase == "dusk":
		sky_color = Color("8b6f86")
	_add_backdrop_rect(parent, "WindowShadow", window_pos + Vector2(-3, 4), Vector2(96, 61), Color(0.22, 0.15, 0.14, 0.25))
	_add_backdrop_rect(parent, "WindowOuterFrame", window_pos, Vector2(92, 58), Color("5a3f39"))
	_add_backdrop_rect(parent, "WindowInnerFrame", window_pos + Vector2(4, 4), Vector2(84, 48), Color("b88965"))
	_add_backdrop_rect(parent, "WindowSky", window_pos + Vector2(7, 7), Vector2(78, 42), sky_color)
	if phase == "night":
		_add_backdrop_rect(parent, "MoonGlow", window_pos + Vector2(15, 13), Vector2(12, 12), Color(0.86, 0.91, 0.84, 0.16))
		_add_backdrop_rect(parent, "Moon", window_pos + Vector2(17, 15), Vector2(7, 7), Color("f5e4ae"))
		_add_backdrop_rect(parent, "MoonCut", window_pos + Vector2(20, 14), Vector2(6, 6), sky_color)
		for star in [Vector2(36, 13), Vector2(63, 18), Vector2(71, 9), Vector2(51, 32)]:
			_add_backdrop_rect(parent, "Star_%d_%d" % [int(star.x), int(star.y)], window_pos + star, Vector2(2, 2), Color(0.96, 0.89, 0.64, 0.72))
	else:
		_add_backdrop_rect(parent, "SunGlow", window_pos + Vector2(15, 12), Vector2(13, 13), Color(1.0, 0.86, 0.48, 0.16))
		_add_backdrop_rect(parent, "Sun", window_pos + Vector2(18, 15), Vector2(7, 7), Color("f3d47a"))
		_add_backdrop_rect(parent, "CloudLeft", window_pos + Vector2(48, 30), Vector2(18, 3), Color(0.92, 0.91, 0.84, 0.46))
		_add_backdrop_rect(parent, "CloudRight", window_pos + Vector2(57, 27), Vector2(14, 3), Color(0.92, 0.91, 0.84, 0.38))
	_add_backdrop_rect(parent, "WindowVertical", window_pos + Vector2(44, 5), Vector2(4, 46), Color("a9795c"))
	_add_backdrop_rect(parent, "WindowHorizontal", window_pos + Vector2(5, 27), Vector2(82, 4), Color("a9795c"))
	_add_backdrop_rect(parent, "WindowSillShadow", window_pos + Vector2(-4, 54), Vector2(100, 6), Color(0.24, 0.16, 0.14, 0.30))
	_add_backdrop_rect(parent, "WindowSill", window_pos + Vector2(-5, 52), Vector2(102, 5), Color("714c3d"))
	_add_backdrop_rect(parent, "CurtainLeft", window_pos + Vector2(-9, -2), Vector2(10, 64), Color(0.53, 0.33, 0.36, 0.88))
	_add_backdrop_rect(parent, "CurtainLeftFold", window_pos + Vector2(-5, 1), Vector2(2, 57), Color(0.88, 0.62, 0.58, 0.20))
	_add_backdrop_rect(parent, "CurtainRight", window_pos + Vector2(91, -2), Vector2(10, 64), Color(0.53, 0.33, 0.36, 0.88))
	_add_backdrop_rect(parent, "CurtainRightFold", window_pos + Vector2(95, 1), Vector2(2, 57), Color(0.88, 0.62, 0.58, 0.20))
	_add_backdrop_rect(parent, "CurtainRod", window_pos + Vector2(-12, -4), Vector2(116, 3), Color("604137"))

static func _add_study_rug(parent: Node2D, room_size: Vector2, wall_px: float) -> void:
	var rug_size := Vector2(112, 42)
	var rug_pos := Vector2(room_size.x * 0.51 - rug_size.x * 0.5, wall_px + 45)
	_add_backdrop_rect(parent, "RugShadow", rug_pos + Vector2(3, 4), rug_size, Color(0.18, 0.11, 0.09, 0.22))
	_add_backdrop_rect(parent, "RugBorder", rug_pos, rug_size, Color("405c55"))
	_add_backdrop_rect(parent, "RugBinding", rug_pos + Vector2(3, 3), rug_size - Vector2(6, 6), Color("b6a979"))
	_add_backdrop_rect(parent, "RugInner", rug_pos + Vector2(6, 6), rug_size - Vector2(12, 12), Color("6f8a78"))
	_add_backdrop_rect(parent, "RugCenter", rug_pos + Vector2(20, 15), Vector2(rug_size.x - 40, rug_size.y - 30), Color(0.84, 0.75, 0.54, 0.18))
	for x in range(10, int(rug_size.x - 8), 14):
		_add_backdrop_rect(parent, "RugDashTop_%d" % x, rug_pos + Vector2(x, 9), Vector2(7, 2), Color(0.93, 0.82, 0.59, 0.28))
		_add_backdrop_rect(parent, "RugDashBottom_%d" % x, rug_pos + Vector2(x, rug_size.y - 11), Vector2(7, 2), Color(0.93, 0.82, 0.59, 0.22))

static func _add_architectural_details(parent: Node2D, room_size: Vector2, wall_px: float) -> void:
	# 左侧轻量墙架与书本用于平衡窗户，不冒充 AI 生成家具。
	var shelf_pos := Vector2(38, wall_px - 28)
	_add_backdrop_rect(parent, "WallShelfShadow", shelf_pos + Vector2(2, 3), Vector2(54, 5), Color(0.22, 0.14, 0.11, 0.24))
	_add_backdrop_rect(parent, "WallShelf", shelf_pos, Vector2(54, 4), Color("77513e"))
	for book in [
		{"x": 5, "w": 5, "h": 13, "c": Color("657d6b")},
		{"x": 11, "w": 6, "h": 16, "c": Color("b46855")},
		{"x": 18, "w": 5, "h": 11, "c": Color("d0a75e")},
	]:
		_add_backdrop_rect(parent, "ShelfBook_%d" % int(book.x), shelf_pos + Vector2(float(book.x), -float(book.h)), Vector2(float(book.w), float(book.h)), book.c)
	_add_backdrop_rect(parent, "WallPrintFrame", Vector2(room_size.x * 0.42 - 16, 20), Vector2(32, 35), Color("765042"))
	_add_backdrop_rect(parent, "WallPrintPaper", Vector2(room_size.x * 0.42 - 13, 23), Vector2(26, 29), Color("eadbbd"))
	_add_backdrop_rect(parent, "WallPrintLeaf", Vector2(room_size.x * 0.42 - 2, 29), Vector2(4, 15), Color("71836b"))
	_add_backdrop_rect(parent, "WallPrintBranch", Vector2(room_size.x * 0.42 - 7, 38), Vector2(14, 2), Color("71836b"))

static func _add_room_light(root: Node2D, room_size: Vector2, wall_px: float) -> void:
	var effects := Node2D.new()
	effects.name = "RoomAtmosphere"
	effects.z_index = -3
	root.add_child(effects)
	var moonlight := Polygon2D.new()
	moonlight.name = "WindowMoonlight"
	moonlight.polygon = PackedVector2Array([
		Vector2(room_size.x * 0.69, wall_px - 2),
		Vector2(room_size.x * 0.89, wall_px - 2),
		Vector2(room_size.x * 0.83, room_size.y),
		Vector2(room_size.x * 0.48, room_size.y),
	])
	moonlight.color = Color(0.55, 0.68, 0.83, 0.075)
	effects.add_child(moonlight)
	var warm_pool := Polygon2D.new()
	warm_pool.name = "StudyWarmth"
	warm_pool.polygon = PackedVector2Array([
		Vector2(42, wall_px + 2), Vector2(176, wall_px + 2),
		Vector2(220, room_size.y * 0.82), Vector2(12, room_size.y * 0.82),
	])
	warm_pool.color = Color(1.0, 0.70, 0.34, 0.055)
	effects.add_child(warm_pool)

static func _add_backdrop_rect(parent: Node, node_name: String, pos: Vector2, size: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)

static func _paint_objects(layer: TileMapLayer, schema: Dictionary) -> void:
	var source_id := int(schema.get("source_id", 0))
	for raw in schema.get("objects", []):
		if not (raw is Dictionary):
			continue
		var obj: Dictionary = raw
		var entry := catalog_entry(String(obj.get("id", "")))
		var cell := _presentation_cell(schema, obj)
		var size := _vec2i(entry.get("size", [1, 1]), Vector2i.ONE)
		var tiles: Array = entry.get("tiles", [])
		for i in range(mini(tiles.size(), size.x * size.y)):
			var local := Vector2i(i % size.x, int(i / size.x))
			layer.set_cell(cell + local, source_id, _vec2i(tiles[i], Vector2i.ZERO))

static func _paint_procedural_objects(root: Node2D, schema: Dictionary) -> void:
	var tile := _vec2i(schema.get("tile_size", [16, 16]), Vector2i(16, 16))
	for raw in schema.get("objects", []):
		if not (raw is Dictionary):
			continue
		var obj: Dictionary = raw
		var entry := catalog_entry(String(obj.get("id", "")))
		if String(entry.get("render", "")) != "floor_lamp":
			continue
		var cell := _presentation_cell(schema, obj)
		var lamp := Node2D.new()
		lamp.name = "FloorLamp_%s" % String(obj.get("slot_id", ""))
		lamp.position = Vector2(cell) * Vector2(tile)
		lamp.z_index = 1
		root.add_child(lamp)
		_add_backdrop_rect(lamp, "ShadeShadow", Vector2(2, 4), Vector2(28, 11), Color(0.30, 0.22, 0.14, 1.0))
		_add_backdrop_rect(lamp, "Shade", Vector2(4, 3), Vector2(24, 9), Color(0.95, 0.68, 0.24, 1.0))
		_add_backdrop_rect(lamp, "ShadeLight", Vector2(8, 5), Vector2(16, 2), Color(1.0, 0.88, 0.48, 1.0))
		_add_backdrop_rect(lamp, "Stem", Vector2(15, 12), Vector2(3, 27), Color(0.38, 0.28, 0.20, 1.0))
		_add_backdrop_rect(lamp, "BaseShadow", Vector2(5, 40), Vector2(24, 5), Color(0.24, 0.18, 0.14, 0.42))
		_add_backdrop_rect(lamp, "Base", Vector2(7, 38), Vector2(20, 5), Color(0.68, 0.48, 0.24, 1.0))

static func _add_collisions(root: Node2D, schema: Dictionary) -> void:
	var body := StaticBody2D.new()
	body.name = "GeneratedRoomCollision"
	root.add_child(body)
	var grid := _vec2i(schema.get("grid_size", [34, 22]), Vector2i(34, 22))
	var tile := _vec2i(schema.get("tile_size", [16, 16]), Vector2i(16, 16))
	var wall_height := clampi(int(schema.get("wall_height", 8)), 2, grid.y - 1)
	_add_collision_rect(body, "wall_top", Vector2(tile.x * grid.x * 0.5, tile.y), Vector2(tile.x * grid.x, tile.y * 2))
	_add_collision_rect(body, "wall_floor_edge", Vector2(tile.x * grid.x * 0.5, tile.y * wall_height), Vector2(tile.x * grid.x, tile.y * 0.7))
	_add_collision_rect(body, "wall_left", Vector2(tile.x * 0.5, tile.y * grid.y * 0.5), Vector2(tile.x, tile.y * grid.y))
	_add_collision_rect(body, "wall_right", Vector2(tile.x * (grid.x - 0.5), tile.y * grid.y * 0.5), Vector2(tile.x, tile.y * grid.y))
	_add_collision_rect(body, "wall_bottom", Vector2(tile.x * grid.x * 0.5, tile.y * (grid.y - 0.5)), Vector2(tile.x * grid.x, tile.y))
	for raw in schema.get("objects", []):
		if not (raw is Dictionary):
			continue
		var obj: Dictionary = raw
		if not bool(obj.get("collision", false)):
			continue
		var cell := _presentation_cell(schema, obj)
		var size := _vec2i(obj.get("size", [1, 1]), Vector2i.ONE)
		var center := Vector2(float(cell.x) + float(size.x) * 0.5, float(cell.y) + float(size.y) * 0.5) * Vector2(tile)
		var extents := Vector2(float(size.x * tile.x), float(size.y * tile.y))
		_add_collision_rect(body, "obj_" + String(obj.get("id", "")), center, extents)

static func _add_collision_rect(parent: Node, shape_name: String, center: Vector2, size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	shape.name = shape_name
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = center
	parent.add_child(shape)

static func _point_from_schema_object(schema: Dictionary, obj: Dictionary) -> Dictionary:
	var origin := _vec2(schema.get("origin", [96, 8]), Vector2(96, 8))
	var tile := _vec2i(schema.get("tile_size", [16, 16]), Vector2i(16, 16))
	var scale := float(schema.get("display_scale", 2))
	var cell := _presentation_cell(schema, obj)
	var size := _vec2i(obj.get("size", [1, 1]), Vector2i.ONE)
	var pos := origin + Vector2(float(cell.x) + float(size.x) * 0.5, float(cell.y + size.y)) * Vector2(tile) * scale
	return {
		"slot_id": String(obj.get("slot_id", "")),
		"zone": String(obj.get("zone", "")),
		"pos": [pos.x, pos.y],
		"semantic_scene": true,
	}

static func _presentation_cell(schema: Dictionary, obj: Dictionary) -> Vector2i:
	var stored := _vec2i(obj.get("cell", [0, 0]), Vector2i.ZERO)
	if int(schema.get("_source_visual_version", schema.get("visual_version", schema.get("version", 1)))) >= 3:
		return stored
	var key := "%s:%s" % [String(obj.get("id", "")), String(obj.get("zone", ""))]
	return LEGACY_PRESENTATION_CELLS.get(key, LEGACY_ZONE_CELLS.get(String(obj.get("zone", "")), stored))

static func _presentation_schema(schema: Dictionary) -> Dictionary:
	if schema.is_empty():
		return {}
	var result := schema.duplicate(true)
	var source_version := int(schema.get("visual_version", schema.get("version", 1)))
	result["_source_visual_version"] = source_version
	if source_version >= 3:
		return result
	var tileset: Dictionary = (catalog().get("tilesets", {}) as Dictionary).get(DEFAULT_TILESET, {})
	for key in ["tile_size", "display_scale", "grid_size", "origin"]:
		if tileset.has(key):
			result[key] = tileset[key]
	result["wall_height"] = 4
	return result

static func _room_phase() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return "day"
	var clock := tree.root.get_node_or_null("GameClock")
	if clock != null and clock.has_method("phase"):
		return String(clock.call("phase"))
	return "day"

static func _next_cell_for_zone(zone_cells: Dictionary, zone: String, entry: Dictionary, used: Dictionary) -> Vector2i:
	var candidates: Array = zone_cells.get(zone, [])
	var size := _vec2i(entry.get("size", [1, 1]), Vector2i.ONE)
	for raw_cell in candidates:
		var cell := _vec2i(raw_cell, Vector2i(-1, -1))
		if cell.x < 0 or _footprint_used(cell, size, used):
			continue
		_mark_footprint(cell, size, used)
		return cell
	return Vector2i(-1, -1)

static func _footprint_used(cell: Vector2i, size: Vector2i, used: Dictionary) -> bool:
	for y in range(cell.y, cell.y + size.y):
		for x in range(cell.x, cell.x + size.x):
			if used.has("%d,%d" % [x, y]):
				return true
	return false

static func _mark_footprint(cell: Vector2i, size: Vector2i, used: Dictionary) -> void:
	for y in range(cell.y, cell.y + size.y):
		for x in range(cell.x, cell.x + size.x):
			used["%d,%d" % [x, y]] = true

static func _vec2i(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and (value as Array).size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	return fallback

static func _vec2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	return fallback
