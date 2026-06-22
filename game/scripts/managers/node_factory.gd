extends Node

## Family Garden 节点工厂（autoload 单例）。
## 按 asset_manifest 把记忆节点放到 slot 的落点（bottom_center 近似），
## 自动建 ≥80×80 点击区。AI 不输出坐标（docs/09 §5/6/9）。
## 阶段 1 / feature/garden-mvp-loop。
## 注：A 的正式美术尚未产出（manifest status=todo），此处贴图回退到占位 flower.png。

const MANIFEST_PATH := "res://assets/manifest/asset_manifest.json"
const PLACEHOLDER_TEXTURE := "res://assets/garden/flower.png"

var _by_asset_id: Dictionary = {}

func _ready() -> void:
	_load_manifest()

func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("[NodeFactory] 缺少 asset_manifest.json")
		return
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return
	for entry in data.get("assets", []):
		if entry is Dictionary:
			_by_asset_id[String(entry.get("asset_id", ""))] = entry

## 按 node_type（可选 scene）从 manifest 找一个 category=node 的资产条目。
func get_node_asset(node_type: String, scene: String = "") -> Dictionary:
	for id in _by_asset_id:
		var e: Dictionary = _by_asset_id[id]
		if String(e.get("category", "")) == "node" and String(id).find(node_type) != -1:
			if scene == "" or String(e.get("scene", "")) == scene:
				return e
	return {}

## 用一张 AI 记忆卡片 + 一个 slot 生成可点击节点。on_click 无参回调。
func make_memory_node(card: Dictionary, slot: Dictionary, on_click: Callable) -> Node2D:
	var node_type := String(card.get("node_type", "memory_flower"))
	var scene := String(card.get("suggested_scene", ""))
	var entry := get_node_asset(node_type, scene)
	var pos := _to_vec(slot.get("pos", [640, 400]))

	var root := Node2D.new()
	root.name = "Node_%s_%s" % [node_type, String(slot.get("slot_id", ""))]
	root.position = pos
	root.z_index = int(pos.y)  # ysort 带（docs/09 §10）

	var display_h := float(entry.get("display_height", 96))
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	if ResourceLoader.exists(PLACEHOLDER_TEXTURE):
		var tex: Texture2D = load(PLACEHOLDER_TEXTURE)
		sprite.texture = tex
		if tex.get_height() > 0:
			sprite.scale = Vector2.ONE * (display_h / float(tex.get_height()))
	sprite.position = Vector2(0, -display_h * 0.5)  # 把贴图抬到落点上方 = bottom_center 近似
	root.add_child(sprite)

	root.add_child(_make_click_area(entry, on_click))
	return root

## 点击区：取自 manifest click_rect（相对 pivot，逻辑坐标），最小 80×80。
func _make_click_area(entry: Dictionary, on_click: Callable) -> Area2D:
	var area := Area2D.new()
	area.name = "ClickArea"
	area.input_pickable = true
	area.monitoring = true
	area.monitorable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var cr: Variant = entry.get("click_rect", null)
	if cr is Array and (cr as Array).size() == 4:
		var w := maxf(80.0, float(cr[2]))
		var h := maxf(80.0, float(cr[3]))
		rect.size = Vector2(w, h)
		area.position = Vector2(float(cr[0]) + float(cr[2]) * 0.5, float(cr[1]) + float(cr[3]) * 0.5)
	else:
		rect.size = Vector2(96, 96)
		area.position = Vector2(0, -48)
	shape.shape = rect
	area.add_child(shape)
	if on_click.is_valid():
		area.input_event.connect(func(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				get_viewport().set_input_as_handled()
				on_click.call())
	return area

func _to_vec(arr: Variant) -> Vector2:
	if arr is Array and (arr as Array).size() >= 2:
		return Vector2(float(arr[0]), float(arr[1]))
	return Vector2(640, 400)
