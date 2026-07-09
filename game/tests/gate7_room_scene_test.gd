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
		var floor := root.get_node_or_null("Floor") as TileMapLayer
		var furniture := root.get_node_or_null("Furniture") as TileMapLayer
		_assert(floor != null and floor.get_used_cells().size() > 100, "地板层应铺满房间")
		_assert(furniture != null and furniture.get_used_cells().size() > 0, "家具层应绘制 catalog stamp")
		var point: Dictionary = ROOM_SCENE_GENERATOR.point_for_room_object(room, MemoryManager.room_objects[0])
		_assert(bool(point.get("semantic_scene", false)), "房间物件应映射到语义网格锚点")

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
