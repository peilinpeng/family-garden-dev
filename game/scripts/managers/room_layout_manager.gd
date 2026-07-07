extends Node

## Family Garden 房间布局管理器（autoload 单例）。
## 吃 AI 房间识别结果（room_analysis），把每件物件按 zone 分配落点、落库、生成家具节点。
## 阶段1：room_analysis 来自内联 mock（见 SceneManager.ROOM_ANALYSIS_MOCK）；
## 阶段2 换 CloudManager.analyze_room_photo 真调用，本管理器逻辑不变。
## AI 只给 object_type / zone，落点由 ZoneManager 分配（docs/09 §8.2）。

const ROOM_SCENE := "room"
# 挂墙物件（进 kind=wall 的 zone）；其余按地面物件处理。
const WALL_OBJECTS := ["photo_wall", "picture", "painting", "clock", "window"]

## 根据 room_analysis 生成一个房间 + 其物件（落库持久化）。返回 room dict。
func generate(analysis: Dictionary, source_memory_id: String = "") -> Dictionary:
	var room := MemoryManager.create_room(analysis, source_memory_id)
	var room_id := String(room.get("id", ""))
	ZoneManager.load_scene(ROOM_SCENE)  # 重置占用，从干净布局开始
	for obj in analysis.get("objects", []):
		if not (obj is Dictionary):
			continue
		var object_type := String(obj.get("object_type", ""))
		var zone := String(obj.get("zone", ""))
		var footprint := "wall_object" if object_type in WALL_OBJECTS else "floor_object"
		var point: Variant = ZoneManager.allocate_zone(ROOM_SCENE, zone, footprint)
		if point == null:
			push_warning("[RoomLayout] 无法为 %s 分配 zone %s（满或 footprint 不符）" % [object_type, zone])
			continue
		MemoryManager.create_room_object(room_id, object_type, zone, String(point.get("slot_id", "")))
	return room

## 渲染某房间已落库的物件到 world（重入/重启后重建，回填 zone 占用）。
## on_click 绑 room_object id。返回渲染数量。
func render(room_id: String, world: Node, on_click: Callable) -> int:
	ZoneManager.load_scene(ROOM_SCENE)
	var count := 0
	for obj in MemoryManager.get_room_objects(room_id):
		var slot_id := String(obj.get("slot_id", ""))
		var obj_id := String(obj.get("id", ""))
		ZoneManager.occupy(ROOM_SCENE, slot_id, obj_id)
		var point := ZoneManager.get_point(ROOM_SCENE, slot_id)
		if point.is_empty():
			continue
		var node := NodeFactory.make_room_object(String(obj.get("object_type", "")), point, on_click.bind(obj_id))
		world.add_child(node)
		count += 1
	return count
