extends Node

## Family Garden 节点工厂（autoload 单例）。
## 按 asset_manifest 把记忆节点放到 slot 的落点（bottom_center 近似），
## 自动建 ≥80×80 点击区。AI 不输出坐标（docs/09 §5/6/9）。
## 阶段 1 / feature/garden-mvp-loop。
## 注：A 的正式美术尚未产出（manifest status=todo），此处贴图回退到程序化占位（_get_placeholder）。

const MANIFEST_PATH := "res://assets/manifest/asset_manifest.json"
const DYNAMIC_NODE_PREFAB := "res://scenes/prefabs/DynamicNode.tscn"

var _by_asset_id: Dictionary = {}
var _prefab: PackedScene  # 动态节点预制体；缺失时回退代码构建（见 _new_root）
var _placeholder_tex: Texture2D = null

func _ready() -> void:
	_load_manifest()
	if ResourceLoader.exists(DYNAMIC_NODE_PREFAB):
		_prefab = load(DYNAMIC_NODE_PREFAB)

## 占位记忆节点贴图：柔紫圆形 + 描边。真美术（manifest status=imported）到位后改为加载真资产。
## 用可辨识图形而非背景同款花，避免和花园背景里画的花糊在一起。
func _get_placeholder() -> Texture2D:
	if _placeholder_tex != null:
		return _placeholder_tex
	var size := 44
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(size / 2.0, size / 2.0)
	var r := size / 2.0 - 2.0
	for y in range(size):
		for x in range(size):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r:
				img.set_pixel(x, y, Color(0.64, 0.48, 0.82))
			elif d <= r + 1.5:
				img.set_pixel(x, y, Color(0.34, 0.22, 0.48))
	_placeholder_tex = ImageTexture.create_from_image(img)
	return _placeholder_tex

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
## 节点结构来自预制体 DynamicNode.tscn；此处只按 manifest 配置贴图/点击区/坐标。
func make_memory_node(card: Dictionary, slot: Dictionary, on_click: Callable) -> Node2D:
	var node_type := String(card.get("node_type", "memory_flower"))
	var scene := String(card.get("suggested_scene", ""))
	var entry := get_node_asset(node_type, scene)
	var pos := _to_vec(slot.get("pos", [640, 400]))

	var root := _new_root()
	root.name = "Node_%s_%s" % [node_type, String(slot.get("slot_id", ""))]
	root.position = pos
	root.z_index = int(pos.y)  # ysort 带（docs/09 §10）

	_configure_sprite(root.get_node("Sprite"), entry)
	_configure_click_area(root.get_node("ClickArea"), entry, on_click)
	return root

## 取预制体实例；预制体缺失时回退代码构建（节点名与预制体一致：Sprite / ClickArea / Shape）。
func _new_root() -> Node2D:
	if _prefab != null:
		return _prefab.instantiate()
	var root := Node2D.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	root.add_child(sprite)
	var area := Area2D.new()
	area.name = "ClickArea"
	area.input_pickable = true
	area.monitoring = true
	area.monitorable = true
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	area.add_child(shape)
	root.add_child(area)
	return root

func _configure_sprite(sprite: Sprite2D, entry: Dictionary) -> void:
	var display_h := float(entry.get("display_height", 96))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	var tex := _resolve_texture(entry)  # 真美术优先，缺图回退程序化占位（必非 null）
	sprite.texture = tex
	if tex.get_height() > 0:
		sprite.scale = Vector2.ONE * (display_h / float(tex.get_height()))
	sprite.position = Vector2(0, -display_h * 0.5)  # 把贴图抬到落点上方 = bottom_center 近似

## 优先按 manifest file_name 读真实美术(res://assets/<scene>/<file>)，缺图回退程序化占位。
## A 的正式美术到位后无需改代码，丢进对应场景目录即自动生效。
func _resolve_texture(entry: Dictionary) -> Texture2D:
	var scene := String(entry.get("scene", ""))
	var file_name := String(entry.get("file_name", ""))
	if scene != "" and file_name != "":
		var real_path := "res://assets/%s/%s" % [scene, file_name]
		if ResourceLoader.exists(real_path):
			return load(real_path)
	return _get_placeholder()

## 点击区：取自 manifest click_rect（相对 pivot，逻辑坐标），最小 80×80。
## 配置预制体已有的 ClickArea + ClickArea/Shape（每实例新建 RectangleShape2D，避免共享）。
func _configure_click_area(area: Area2D, entry: Dictionary, on_click: Callable) -> void:
	area.input_pickable = true
	area.monitoring = true
	area.monitorable = true
	var shape_node: CollisionShape2D = area.get_node("Shape")
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
	shape_node.shape = rect
	if on_click.is_valid():
		area.input_event.connect(func(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				get_viewport().set_input_as_handled()
				on_click.call())

func _to_vec(arr: Variant) -> Vector2:
	if arr is Array and (arr as Array).size() >= 2:
		return Vector2(float(arr[0]), float(arr[1]))
	return Vector2(640, 400)
