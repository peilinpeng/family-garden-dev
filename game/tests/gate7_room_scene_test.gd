extends Node

const ROOM_SCENE_GENERATOR := preload("res://scripts/managers/room_scene_generator.gd")

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	MemoryManager._reset_all()
	MemoryManager.selected_role_key = "player"

	var analysis := {
		"room_type": "bedroom",
		"style": "warm_cozy",
		"suggested_room_theme": "study_corner",
		"description": "一个适合生成温暖学习角落的房间。",
		"objects": [
			{"object_type": "desk", "zone": "back_left"},
			{"object_type": "lamp", "zone": "back_center"},
			{"object_type": "plant", "zone": "right_side"},
			{"object_type": "photo_wall", "zone": "back_wall"},
			{"object_type": "chair", "zone": "floor_center"}
		]
	}
	var layout := RoomLayoutManager.plan(analysis)
	_assert(bool(layout.get("ok", false)), "合法房间分析应生成布局")
	var schema: Dictionary = layout.get("scene_schema", {})
	_assert(not schema.is_empty(), "布局应包含室内 Scene Schema")
	_assert(int(schema.get("visual_version", 0)) == 3, "新房间应使用第三版紧凑视觉布局")
	_assert(ROOM_SCENE_GENERATOR.validate_schema(schema).ok, "生成的 Scene Schema 应通过校验")
	_assert((schema.get("objects", []) as Array).size() >= 4, "schema 应保留主要语义家具")

	var bad_schema := schema.duplicate(true)
	bad_schema["objects"] = (bad_schema.get("objects", []) as Array).duplicate(true)
	bad_schema["objects"].append({"id": "unknown", "cell": [1, 1], "size": [1, 1]})
	_assert(not ROOM_SCENE_GENERATOR.validate_schema(bad_schema).ok, "未知 catalog 物件必须被拒绝")

	var room := MemoryManager.create_room(analysis, "mem_room_test", "room:test_gate7", {}, schema)
	for object in layout.get("objects", []):
		MemoryManager.create_room_object(String(room.get("id", "")), String(object.get("object_type", "")), String(object.get("zone", "")), String(object.get("slot_id", "")))
	var world := Node2D.new()
	add_child(world)
	var rendered: Dictionary = ROOM_SCENE_GENERATOR.render_scene(room, world)
	_assert(bool(rendered.get("ok", false)), "语义房间应能渲染成 TileMapLayer")
	var root := world.get_node_or_null("GeneratedRoomScene")
	_assert(root != null, "渲染后应存在 GeneratedRoomScene")
	if root != null:
		var wall_texture := root.get_node_or_null("WallTexture") as TileMapLayer
		var floor := root.get_node_or_null("Floor") as TileMapLayer
		var furniture := root.get_node_or_null("Furniture") as TileMapLayer
		_assert(wall_texture != null and wall_texture.get_used_cells().size() > 50, "墙面应保留低对比材质层")
		_assert(floor != null and floor.get_used_cells().size() > 100, "地板层应铺满房间")
		_assert(furniture != null and furniture.get_used_cells().size() > 0, "家具层应绘制 catalog stamp")
		_assert(root.get_node_or_null("RoomAtmosphere") != null, "房间应包含冷暖环境光层")
		_assert(root.get_node_or_null("GeneratedRoomCollision/wall_floor_edge") != null, "墙地交界应阻止玩家走进墙面")
		var point: Dictionary = ROOM_SCENE_GENERATOR.point_for_room_object(room, MemoryManager.room_objects[0])
		_assert(bool(point.get("semantic_scene", false)), "房间物件应映射到语义网格锚点")
		var spawn := ROOM_SCENE_GENERATOR.spawn_position(room)
		_assert(spawn.y <= 590.0, "玩家出生点应避开底部常驻导航")

	# 旧存档不迁移数据，但渲染时应采用新版紧凑构图。
	var legacy_room := room.duplicate(true)
	var legacy_schema: Dictionary = schema.duplicate(true)
	legacy_schema["version"] = 1
	legacy_schema.erase("visual_version")
	legacy_room["scene_schema"] = legacy_schema
	var legacy_point := ROOM_SCENE_GENERATOR.point_for_room_object(legacy_room, MemoryManager.room_objects[0])
	_assert(float((legacy_point.get("pos", [9999, 9999]) as Array)[0]) < 300.0, "旧版书桌应只读映射到新版学习角，不要求清空存档")

	if failures.is_empty():
		print("Gate 7 room scene tests passed: schema, catalog validation, tile render")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
