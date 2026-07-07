extends Node

## Family Garden 房间区域分配器（autoload 单例）。
## 读 zones_{scene}.json，把房间物件分配到 zone 内的落点。
## 仿 SlotManager：动态物件【只能】落在 zone 落点上；AI 只给 object_type / zone，不输出坐标（docs/09 §8.2）。
## kind=wall 的 zone 只接受 footprint=wall_object 的物件。
## 阶段 1 / feature/garden-mvp-loop。

# scene -> { "points": Array<Dictionary{slot_id, zone, kind, pos}>, "occupied": Dictionary(slot_id -> obj_id) }
var _scenes: Dictionary = {}

func load_scene(scene: String) -> void:
	var path := "res://assets/manifest/zones_%s.json" % scene
	if not FileAccess.file_exists(path):
		push_warning("[ZoneManager] 缺少 zone 文件: " + path)
		_scenes[scene] = {"points": [], "occupied": {}}
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	var points: Array = []
	if data is Dictionary:
		var zones: Dictionary = data.get("zones", {})
		for zone_key in zones:
			var z: Dictionary = zones[zone_key]
			var rect: Array = z.get("rect", [0, 0, 0, 0])
			var kind := String(z.get("kind", "floor"))
			var count := int(z.get("slots", 1))
			for i in range(count):
				# 横向均分；y 取 zone 矩形底边 = 接地点（bottom_center，与 NodeFactory 一致）。
				var px := float(rect[0]) + float(rect[2]) * (i + 0.5) / float(count)
				var py := float(rect[1]) + float(rect[3])
				points.append({
					"slot_id": "%s#%d" % [zone_key, i],
					"zone": zone_key, "kind": kind, "pos": [px, py]
				})
	_scenes[scene] = {"points": points, "occupied": {}}

func reset(scene: String) -> void:
	if _scenes.has(scene):
		_scenes[scene]["occupied"] = {}

## 在指定 zone 分配一个空闲落点。footprint=="wall_object" 才能进 kind=wall 的 zone。
## 成功返回 { slot_id, zone, pos }；zone 满 / footprint 不匹配 / 无此 zone 时返回 null。
func allocate_zone(scene: String, zone: String, footprint: String = "floor_object") -> Variant:
	if not _scenes.has(scene):
		load_scene(scene)
	var bucket: Dictionary = _scenes[scene]
	var occupied: Dictionary = bucket["occupied"]
	for p in bucket["points"]:
		if String(p.get("zone", "")) != zone:
			continue
		var sid := String(p.get("slot_id", ""))
		if occupied.has(sid):
			continue
		var is_wall := String(p.get("kind", "")) == "wall"
		if is_wall != (footprint == "wall_object"):
			continue
		occupied[sid] = ""
		return p
	return null

## 直接标记某落点已占用（渲染已落库物件时回填占用表）。
func occupy(scene: String, slot_id: String, obj_id: String = "") -> void:
	if not _scenes.has(scene):
		load_scene(scene)
	_scenes[scene]["occupied"][slot_id] = obj_id

## 按 slot_id 取落点定义（含 pos）；找不到返回 {}。
func get_point(scene: String, slot_id: String) -> Dictionary:
	if not _scenes.has(scene):
		load_scene(scene)
	for p in _scenes[scene]["points"]:
		if String(p.get("slot_id", "")) == slot_id:
			return p
	return {}

## 调试用：当前占用数 / 总落点数。
func usage(scene: String) -> Vector2i:
	if not _scenes.has(scene):
		return Vector2i.ZERO
	return Vector2i(_scenes[scene]["occupied"].size(), (_scenes[scene]["points"] as Array).size())
