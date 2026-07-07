extends Node

## Family Garden 场景入口管理器（autoload 单例）。
## 加载 portals_{scene}.json：提供 spawn 点查询 + 按 trigger_rect 生成 ScenePortal(Area2D)。
## 入口走入(body_entered, 仅主控角色)、点按(tap)、按键(key_interact, 站在门口按 E)
## 三种触发走同一回调（docs/09 §14）。
## 阶段 1 / feature/garden-mvp-loop。

const PLAYER_GROUP := "player"
const FADE_OUT_DURATION := 0.4   ## fade=true 传送门:人物淡出到透明用的时长(秒)
const INTERACT_KEYCODE := KEY_E  ## key_interact=true 传送门:站在触发区内按这个键才传送

# scene -> { "spawn_points": Dictionary, "portals": Array<Dictionary> }
var _scenes: Dictionary = {}

# 当前场景里 key_interact=true 的传送门:{inside, body, target, spawn_key, fade, delay, travel_cb}
var _key_interact_portals: Array[Dictionary] = []

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
	_key_interact_portals.clear()  # 场景重建后旧 Area2D 已失效,清空按键传送门登记表
	var built := 0
	for portal in _scenes[scene].get("portals", []):
		if not (portal is Dictionary):
			continue
		_build_one(portal, world, travel_cb)
		built += 1
	return built

## fade=true 时不立即切场景:人物先锁住输入原地淡出,delay 秒后才真正传送,
## 避免"一脚踩进去画面突然跳走"的突兀感（见 docs/09 §14 之外的手感调整）。
func _build_one(portal: Dictionary, world: Node2D, travel_cb: Callable) -> void:
	var rect := _to_rect(portal.get("trigger_rect", [0, 0, 96, 128]))
	var target := String(portal.get("target_scene", ""))
	var spawn_key := String(portal.get("spawn_point", "default"))
	var tap_enabled := bool(portal.get("tap_enabled", true))
	var key_interact := bool(portal.get("key_interact", false))
	var fade := bool(portal.get("fade", false))
	var delay := float(portal.get("delay", 0.0))

	var area := Area2D.new()
	area.name = String(portal.get("portal_id", "portal"))
	area.monitoring = true
	area.collision_mask = 1  # 主控角色在 layer 1
	area.position = rect.position + rect.size * 0.5

	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	area.add_child(shape)

	if key_interact:
		# 站在门口按 E 才传送：走入只登记"人在不在门口",不像普通传送门那样自动触发。
		var entry := {"inside": false, "body": null, "target": target, "spawn_key": spawn_key,
			"fade": fade, "delay": delay, "travel_cb": travel_cb}
		_key_interact_portals.append(entry)
		area.body_entered.connect(func(body: Node) -> void:
			if body.is_in_group(PLAYER_GROUP):
				entry.inside = true
				entry.body = body)
		area.body_exited.connect(func(body: Node) -> void:
			if body.is_in_group(PLAYER_GROUP):
				entry.inside = false
				entry.body = null)
	else:
		var firing := false   # 防止渐隐等待期间重复触发同一个传送门
		# 走入触发：仅主控角色（player 组）
		area.body_entered.connect(func(body: Node) -> void:
			if not body.is_in_group(PLAYER_GROUP) or firing:
				return
			firing = true
			if fade:
				await _fade_then_travel(body, delay)
			travel_cb.call(target, spawn_key))

	# 点按触发（可与 key_interact 并存,兼容鼠标/触屏）
	if tap_enabled:
		area.input_pickable = true
		area.input_event.connect(func(_vp: Node, event: InputEvent, _idx: int) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				get_viewport().set_input_as_handled()
				travel_cb.call(target, spawn_key))

	world.add_child(area)

## 站在 key_interact 传送门触发区内按 E:淡出(若配置)后调用同一个 travel_cb。
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo
			and (event as InputEventKey).keycode == INTERACT_KEYCODE):
		return
	for entry in _key_interact_portals:
		var body: Variant = entry.get("body")
		if not entry.get("inside", false) or body == null or not is_instance_valid(body):
			continue
		get_viewport().set_input_as_handled()
		var travel_cb: Callable = entry.get("travel_cb")
		var target: String = entry.get("target")
		var spawn_key: String = entry.get("spawn_key")
		if entry.get("fade", false):
			await _fade_then_travel(body, float(entry.get("delay", 0.0)))
		travel_cb.call(target, spawn_key)
		return

## 人物锁住输入原地站定,Sprite2D 淡出到透明,等 delay 秒再放行去真正传送。
func _fade_then_travel(body: Node, delay: float) -> void:
	if body.has_method("set_movement_locked"):
		body.call("set_movement_locked", true)
	var visual: CanvasItem = body.get_node_or_null("Sprite2D") as CanvasItem
	if visual != null:
		var tween := body.get_tree().create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, FADE_OUT_DURATION)
	await body.get_tree().create_timer(delay).timeout

func _to_vec(arr: Variant) -> Vector2:
	if arr is Array and (arr as Array).size() >= 2:
		return Vector2(float(arr[0]), float(arr[1]))
	return Vector2(640, 480)

func _to_rect(arr: Variant) -> Rect2:
	if arr is Array and (arr as Array).size() >= 4:
		return Rect2(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
	return Rect2(0, 0, 96, 128)
