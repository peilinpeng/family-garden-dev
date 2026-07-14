extends Node

signal room_generated(room: Dictionary)

## Family Garden 房间布局管理器（autoload 单例）。
## 吃 AI 房间识别结果（room_analysis），把每件物件按 zone 分配落点、落库、生成家具节点。
## Gate 4：room_analysis 来自 AIWorkflowManager 的草稿预览，确认后才进入这里落库。
## AI 只给 object_type / zone，落点由 ZoneManager 分配（docs/09 §8.2）。

const ROOM_SCENE := "room"
const ROOM_SCENE_GENERATOR := preload("res://scripts/managers/room_scene_generator.gd")
# 挂墙物件（进 kind=wall 的 zone）；其余按地面物件处理。
const WALL_OBJECTS := ["photo_wall", "picture", "painting", "clock", "window"]

## 只规划、不落库。返回的 objects 已经过契约、zone 容量和墙面类型校验。
func plan(analysis: Dictionary) -> Dictionary:
	var validation := AIContractValidator.validate_data("analyze-room-photo", analysis)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "errors": validation.get("errors", [])}
	ZoneManager.load_scene(ROOM_SCENE)
	var planned: Array = []
	var rejected: Array = []
	for raw_object in analysis.get("objects", []):
		var object := raw_object as Dictionary
		var object_type := String(object.get("object_type", ""))
		var zone := String(object.get("zone", ""))
		var footprint := "wall_object" if object_type in WALL_OBJECTS else "floor_object"
		var point: Variant = ZoneManager.allocate_zone(ROOM_SCENE, zone, footprint)
		if point == null:
			rejected.append({"object_type": object_type, "zone": zone, "reason": "zone_unavailable"})
			continue
		planned.append({
			"object_type": object_type,
			"zone": zone,
			"slot_id": String(point.get("slot_id", "")),
		})
	var layout := {"ok": not planned.is_empty(), "objects": planned, "rejected": rejected}
	if not planned.is_empty():
		var scene: Dictionary = ROOM_SCENE_GENERATOR.build_schema(analysis, layout)
		if not bool(scene.get("ok", false)):
			layout["ok"] = false
			layout["errors"] = scene.get("errors", [])
		else:
			layout["scene_schema"] = scene.get("schema", {})
			layout["scene_warnings"] = scene.get("warnings", [])
	return layout

## 根据 room_analysis 生成一个房间 + 其物件（落库持久化）。返回 room dict。
func generate(analysis: Dictionary, source_memory_id: String = "", workflow_key: String = "", generation_meta: Dictionary = {}) -> Dictionary:
	var layout := plan(analysis)
	if not bool(layout.get("ok", false)):
		return {}
	var room := MemoryManager.create_room(analysis, source_memory_id, workflow_key, generation_meta, layout.get("scene_schema", {}))
	var room_id := String(room.get("id", ""))
	for object in layout.get("objects", []):
		MemoryManager.create_room_object(room_id, String(object.get("object_type", "")), String(object.get("zone", "")), String(object.get("slot_id", "")))
	room_generated.emit(room)
	return room

func replace(room_id: String, analysis: Dictionary, source_memory_id: String, workflow_key: String, generation_meta: Dictionary = {}) -> Dictionary:
	var layout := plan(analysis)
	if not bool(layout.get("ok", false)):
		return {}
	# 先完整生成新版，再删除旧版；即使新版落库失败，也不会让玩家失去原房间。
	var replacement := generate(analysis, source_memory_id, workflow_key, generation_meta)
	if replacement.is_empty():
		return {}
	MemoryManager.delete_room(room_id)
	return replacement

func move_object(object_id: String, target_zone: String) -> bool:
	var target: Dictionary = {}
	for object in MemoryManager.room_objects:
		if object is Dictionary and String(object.get("id", "")) == object_id:
			target = object
			break
	if target.is_empty():
		return false
	ZoneManager.load_scene(ROOM_SCENE)
	for object in MemoryManager.get_room_objects(String(target.get("room_id", ""))):
		if String(object.get("id", "")) != object_id:
			ZoneManager.occupy(ROOM_SCENE, String(object.get("slot_id", "")), String(object.get("id", "")))
	var object_type := String(target.get("object_type", ""))
	var footprint := "wall_object" if object_type in WALL_OBJECTS else "floor_object"
	var point: Variant = ZoneManager.allocate_zone(ROOM_SCENE, target_zone, footprint)
	if point == null:
		return false
	return MemoryManager.update_room_object(object_id, target_zone, String(point.get("slot_id", "")))

## 渲染某房间已落库的物件到 world（重入/重启后重建，回填 zone 占用）。
## on_click 绑 room_object id。返回渲染数量。
func render(room_id: String, world: Node, on_click: Callable) -> int:
	ZoneManager.load_scene(ROOM_SCENE)
	var count := 0
	for obj in MemoryManager.get_room_objects(room_id):
		var slot_id := String(obj.get("slot_id", ""))
		var obj_id := String(obj.get("id", ""))
		ZoneManager.occupy(ROOM_SCENE, slot_id, obj_id)
		var room := _room_by_id(room_id)
		var point: Dictionary = ROOM_SCENE_GENERATOR.point_for_room_object(room, obj) if not room.is_empty() else {}
		if point.is_empty():
			point = ZoneManager.get_point(ROOM_SCENE, slot_id)
		if point.is_empty():
			continue
		var node := NodeFactory.make_room_object(String(obj.get("object_type", "")), point, on_click.bind(obj_id))
		world.add_child(node)
		count += 1
	return count

func _room_by_id(room_id: String) -> Dictionary:
	for room in MemoryManager.rooms:
		if room is Dictionary and String(room.get("id", "")) == room_id:
			return room
	return {}
