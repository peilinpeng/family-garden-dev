extends Node

## Family Garden 槽位分配器（autoload 单例）。
## 加载 slots_{scene}.json，给动态节点分配/释放槽位，满了走 overflow。
## 动态节点【只能】落在 slot 上；AI 不输出坐标（docs/09 §7）。
## 阶段 1 / feature/garden-mvp-loop。

# scene -> { "slots": Array<Dictionary>, "occupied": Dictionary(slot_id -> node_id) }
var _scenes: Dictionary = {}

func load_scene(scene: String) -> void:
	var path := "res://assets/manifest/slots_%s.json" % scene
	if not FileAccess.file_exists(path):
		push_warning("[SlotManager] 缺少 slot 文件: " + path)
		_scenes[scene] = {"slots": [], "occupied": {}}
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	var slots: Array = []
	if data is Dictionary:
		slots = data.get("slots", [])
	_scenes[scene] = {"slots": slots, "occupied": {}}

func reset(scene: String) -> void:
	if _scenes.has(scene):
		_scenes[scene]["occupied"] = {}

func _is_overflow(slot: Dictionary) -> bool:
	return String(slot.get("slot_id", "")).find("overflow") != -1

## 分配一个允许 node_type 的空闲槽位：优先非 overflow，再 overflow；满了返回 null。
func allocate(scene: String, node_type: String, node_id: String = "") -> Variant:
	if not _scenes.has(scene):
		load_scene(scene)
	var bucket: Dictionary = _scenes[scene]
	var occupied: Dictionary = bucket["occupied"]
	for use_overflow in [false, true]:
		for slot in bucket["slots"]:
			var sid := String(slot.get("slot_id", ""))
			if occupied.has(sid):
				continue
			if _is_overflow(slot) != use_overflow:
				continue
			var allow: Array = slot.get("allow", [])
			if node_type in allow:
				occupied[sid] = node_id
				return slot
	return null

func release(scene: String, slot_id: String) -> void:
	if _scenes.has(scene):
		_scenes[scene]["occupied"].erase(slot_id)

## 直接标记某 slot 已占用（用于渲染已落库节点时回填占用表）。
func occupy(scene: String, slot_id: String, node_id: String = "") -> void:
	if not _scenes.has(scene):
		load_scene(scene)
	_scenes[scene]["occupied"][slot_id] = node_id

## 按 slot_id 取槽位定义（含 pos）；找不到返回 {}。
func get_slot(scene: String, slot_id: String) -> Dictionary:
	if not _scenes.has(scene):
		load_scene(scene)
	for s in _scenes[scene]["slots"]:
		if String(s.get("slot_id", "")) == slot_id:
			return s
	return {}

## 调试用：当前占用数 / 总槽位数。
func usage(scene: String) -> Vector2i:
	if not _scenes.has(scene):
		return Vector2i.ZERO
	return Vector2i(_scenes[scene]["occupied"].size(), (_scenes[scene]["slots"] as Array).size())
