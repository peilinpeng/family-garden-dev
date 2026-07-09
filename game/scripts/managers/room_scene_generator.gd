class_name RoomSceneGenerator
extends RefCounted

const CATALOG_PATH := "res://assets/manifest/room_object_catalog.json"
const DEFAULT_TILESET := "kitchen"

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
			"version": 1,
			"generator": "room-scene-v1",
			"tileset": DEFAULT_TILESET,
			"tile_set": String(tileset.get("tile_set", "")),
			"source_id": int(tileset.get("source_id", 0)),
			"tile_size": [tile_size.x, tile_size.y],
			"display_scale": int(tileset.get("display_scale", 2)),
			"grid_size": [grid_size.x, grid_size.y],
			"origin": [origin.x, origin.y],
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
	var tile_set_path := String(schema.get("tile_set", ""))
	var tile_set := load(tile_set_path) as TileSet
	if tile_set == null:
		return {"ok": false, "errors": ["missing_tileset_resource"]}
	var root := Node2D.new()
	root.name = "GeneratedRoomScene"
	root.position = _vec2(schema.get("origin", [96, 8]), Vector2(96, 8))
	root.scale = Vector2.ONE * float(schema.get("display_scale", 2))
	root.z_index = -90
	root.z_as_relative = false
	world.add_child(root)
	var floor := _make_layer("Floor", tile_set, -2)
	var furniture := _make_layer("Furniture", tile_set, 0)
	root.add_child(floor)
	root.add_child(furniture)
	_paint_floor(floor, schema)
	_paint_walls(floor, schema)
	_paint_objects(furniture, schema)
	_add_collisions(root, schema)
	return {"ok": true, "root": root}

static func point_for_room_object(room: Dictionary, object: Dictionary) -> Dictionary:
	var schema: Dictionary = room.get("scene_schema", {})
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
	var schema: Dictionary = room.get("scene_schema", {})
	if schema.is_empty():
		return fallback
	var origin := _vec2(schema.get("origin", [96, 8]), Vector2(96, 8))
	var tile := _vec2i(schema.get("tile_size", [16, 16]), Vector2i(16, 16))
	var scale := float(schema.get("display_scale", 2))
	var grid := _vec2i(schema.get("grid_size", [34, 22]), Vector2i(34, 22))
	return origin + Vector2(float(grid.x) * float(tile.x) * 0.5, float(grid.y - 2) * float(tile.y)) * scale

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
	for y in range(grid.y):
		for x in range(grid.x):
			layer.set_cell(Vector2i(x, y), source_id, floor_tile)

static func _paint_walls(layer: TileMapLayer, schema: Dictionary) -> void:
	var grid := _vec2i(schema.get("grid_size", [34, 22]), Vector2i(34, 22))
	var wall_tile := _vec2i(schema.get("wall", [0, 0]), Vector2i.ZERO)
	var source_id := int(schema.get("source_id", 0))
	for x in range(grid.x):
		layer.set_cell(Vector2i(x, 0), source_id, wall_tile)
		layer.set_cell(Vector2i(x, 1), source_id, wall_tile)

static func _paint_objects(layer: TileMapLayer, schema: Dictionary) -> void:
	var source_id := int(schema.get("source_id", 0))
	for raw in schema.get("objects", []):
		if not (raw is Dictionary):
			continue
		var obj: Dictionary = raw
		var entry := catalog_entry(String(obj.get("id", "")))
		var cell := _vec2i(obj.get("cell", [0, 0]), Vector2i.ZERO)
		var size := _vec2i(entry.get("size", [1, 1]), Vector2i.ONE)
		var tiles: Array = entry.get("tiles", [])
		for i in range(mini(tiles.size(), size.x * size.y)):
			var local := Vector2i(i % size.x, int(i / size.x))
			layer.set_cell(cell + local, source_id, _vec2i(tiles[i], Vector2i.ZERO))

static func _add_collisions(root: Node2D, schema: Dictionary) -> void:
	var body := StaticBody2D.new()
	body.name = "GeneratedRoomCollision"
	root.add_child(body)
	var grid := _vec2i(schema.get("grid_size", [34, 22]), Vector2i(34, 22))
	var tile := _vec2i(schema.get("tile_size", [16, 16]), Vector2i(16, 16))
	_add_collision_rect(body, "wall_top", Vector2(tile.x * grid.x * 0.5, tile.y), Vector2(tile.x * grid.x, tile.y * 2))
	_add_collision_rect(body, "wall_left", Vector2(tile.x * 0.5, tile.y * grid.y * 0.5), Vector2(tile.x, tile.y * grid.y))
	_add_collision_rect(body, "wall_right", Vector2(tile.x * (grid.x - 0.5), tile.y * grid.y * 0.5), Vector2(tile.x, tile.y * grid.y))
	_add_collision_rect(body, "wall_bottom", Vector2(tile.x * grid.x * 0.5, tile.y * (grid.y - 0.5)), Vector2(tile.x * grid.x, tile.y))
	for raw in schema.get("objects", []):
		if not (raw is Dictionary):
			continue
		var obj: Dictionary = raw
		if not bool(obj.get("collision", false)):
			continue
		var cell := _vec2i(obj.get("cell", [0, 0]), Vector2i.ZERO)
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
	var cell := _vec2i(obj.get("cell", [0, 0]), Vector2i.ZERO)
	var size := _vec2i(obj.get("size", [1, 1]), Vector2i.ONE)
	var pos := origin + Vector2(float(cell.x) + float(size.x) * 0.5, float(cell.y + size.y)) * Vector2(tile) * scale
	return {
		"slot_id": String(obj.get("slot_id", "")),
		"zone": String(obj.get("zone", "")),
		"pos": [pos.x, pos.y],
		"semantic_scene": true,
	}

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
