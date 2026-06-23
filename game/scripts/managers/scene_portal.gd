extends Node

## Family Garden 场景入口管理器（autoload 单例）。
## 加载 portals_{scene}.json：提供 spawn 点查询 + 按 trigger_rect 生成 ScenePortal(Area2D)。
## 入口走入(body_entered, 仅主控角色) 与点按(tap) 两种触发走同一回调（docs/09 §14）。
## 阶段 1 / feature/garden-mvp-loop。

const PLAYER_GROUP := "player"

# scene -> { "spawn_points": Dictionary, "portals": Array<Dictionary> }
var _scenes: Dictionary = {}

func load_scene(scene: String) -> void:
	var path := "res://assets/manifest/portals_%s.json" % scene
	if not FileAccess.file_exists(path):
		push_warning("[ScenePortal] 缺少 portal 文件: " + path)
		_scenes[scene] = {"spawn_points": {}, "portals": []}
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	var spawn_points: Dictionary = {}
	var portals: Array = []
	if data is Dictionary:
		spawn_points = data.get("spawn_points", {})
		portals = data.get("portals", [])
	_scenes[scene] = {"spawn_points": spawn_points, "portals": portals}

## 取场景中某 spawn_point 的逻辑坐标；找不到回退 default 并打印警告（docs/09 §14.3）。
func get_spawn(scene: String, key: String = "default") -> Vector2:
	if not _scenes.has(scene):
		load_scene(scene)
	var sp: Dictionary = _scenes[scene].get("spawn_points", {})
	if sp.has(key):
		return _to_vec(sp[key])
	if key != "default":
		push_warning("[ScenePortal] %s 无 spawn_point '%s'，回退 default" % [scene, key])
	if sp.has("default"):
		return _to_vec(sp["default"])
	push_warning("[ScenePortal] %s 无 default spawn_point，回退屏幕中心" % scene)
	return Vector2(640, 480)

## 为场景生成全部 ScenePortal 节点并加进 world。
## travel_cb(target_scene: String, spawn_point: String) 在走入/点按时调用。
func build_portals(scene: String, world: Node2D, travel_cb: Callable) -> int:
	if not _scenes.has(scene):
		load_scene(scene)
	var built := 0
	for portal in _scenes[scene].get("portals", []):
		if not (portal is Dictionary):
			continue
		_build_one(portal, world, travel_cb)
		built += 1
	return built

func _build_one(portal: Dictionary, world: Node2D, travel_cb: Callable) -> void:
	var rect := _to_rect(portal.get("trigger_rect", [0, 0, 96, 128]))
	var target := String(portal.get("target_scene", ""))
	var spawn_key := String(portal.get("spawn_point", "default"))
	var tap_enabled := bool(portal.get("tap_enabled", true))

	var area := Area2D.new()
	area.name = "Portal_" + String(portal.get("portal_id", "portal"))
	area.monitoring = true
	area.collision_mask = 1  # 主控角色在 layer 1
	area.position = rect.position + rect.size * 0.5

	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	area.add_child(shape)

	# 走入触发：仅主控角色（player 组）
	area.body_entered.connect(func(body: Node) -> void:
		if body.is_in_group(PLAYER_GROUP):
			travel_cb.call(target, spawn_key))

	# 点按触发
	if tap_enabled:
		area.input_pickable = true
		area.input_event.connect(func(_vp: Node, event: InputEvent, _idx: int) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				get_viewport().set_input_as_handled()
				travel_cb.call(target, spawn_key))

	world.add_child(area)

func _to_vec(arr: Variant) -> Vector2:
	if arr is Array and (arr as Array).size() >= 2:
		return Vector2(float(arr[0]), float(arr[1]))
	return Vector2(640, 480)

func _to_rect(arr: Variant) -> Rect2:
	if arr is Array and (arr as Array).size() >= 4:
		return Rect2(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
	return Rect2(0, 0, 96, 128)
