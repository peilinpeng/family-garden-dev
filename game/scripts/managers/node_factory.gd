extends Node

## Family Garden 节点工厂（autoload 单例）。
## 按 asset_manifest 把记忆节点放到 slot 的落点（bottom_center 近似），
## 自动建 ≥80×80 点击区。AI 不输出坐标（docs/09 §5/6/9）。
## 正式美术未覆盖的 AI 节点会回退到程序化 soft pixel 贴图，并带可点击光晕与阴影。

const MANIFEST_PATH := "res://assets/manifest/asset_manifest.json"
const DYNAMIC_NODE_PREFAB := "res://scenes/prefabs/DynamicNode.tscn"
const BOTTLE_FLOAT_FRAMES := "res://assets/pond/bottle/bottle_float_sprite_frames.tres"
const GARDEN_ARCHIVE_NODE_TYPES := {
	"flowers": "memory_flower",
	"photos": "photo_board",
	"postcards": "postcard",
}

var _by_asset_id: Dictionary = {}
var _prefab: PackedScene  # 动态节点预制体；缺失时回退代码构建（见 _new_root）
var _placeholder_textures: Dictionary = {}
var _soft_disc_textures: Dictionary = {}

func _ready() -> void:
	_load_manifest()
	if ResourceLoader.exists(DYNAMIC_NODE_PREFAB):
		_prefab = load(DYNAMIC_NODE_PREFAB)

func _get_placeholder(node_type: String) -> Texture2D:
	if _placeholder_textures.has(node_type):
		return _placeholder_textures[node_type]
	var tex := _make_placeholder_texture(node_type)
	_placeholder_textures[node_type] = tex
	return tex

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
func make_memory_node(card: Dictionary, slot: Dictionary, on_click: Callable, state: String = "grown") -> Node2D:
	var node_type := String(card.get("node_type", "memory_flower"))
	var scene := String(card.get("suggested_scene", ""))
	var entry := get_node_asset(node_type, scene)
	if entry.is_empty():
		entry = get_node_asset(node_type)
	var pos := _to_vec(slot.get("pos", [640, 400]))

	var root := _new_root()
	root.name = "Node_%s_%s" % [node_type, String(slot.get("slot_id", ""))]
	root.position = pos
	root.z_index = int(pos.y)  # ysort 带（docs/09 §10）
	root.z_as_relative = false

	if node_type == "bottle":
		_configure_bottle_sprite(root, entry)
		_decorate_bottle_node(root)
	else:
		_configure_sprite(root.get_node("Sprite"), entry, node_type, state)
		_decorate_memory_node(root, node_type, float(entry.get("display_height", 96)))
		if node_type in ["photo_board", "postcard"]:
			_decorate_memory_board(root, node_type, float(entry.get("display_height", 92)))
	_configure_click_area(root.get_node("ClickArea"), entry, on_click)
	return root

## 花园长期只渲染三个稳定入口；单条记忆仍完整保留在数据层与入口面板中。
func make_memory_archive(archive_key: String, slot: Dictionary, on_click: Callable, state: String = "grown") -> Node2D:
	var node_type := String(GARDEN_ARCHIVE_NODE_TYPES.get(archive_key, "memory_flower"))
	var card := {
		"node_type": node_type,
		"suggested_scene": "garden",
	}
	var root := make_memory_node(card, slot, on_click, state)
	root.name = "GardenArchive_%s" % archive_key
	if archive_key == "flowers":
		_configure_background_flower_archive(root)
	elif archive_key in ["photos", "postcards"]:
		_configure_memory_corner_archive(root, archive_key)
	return root

func garden_archive_key(node_type: String) -> String:
	match node_type:
		"photo_board":
			return "photos"
		"postcard":
			return "postcards"
		_:
			return "flowers"

func _configure_background_flower_archive(root: Node2D) -> void:
	# 右下角背景花丛本身就是景观，不再叠加一盆独立的记忆花。
	var sprite := root.get_node_or_null("Sprite") as Sprite2D
	if sprite != null:
		sprite.visible = false
	for decoration_name in ["NodeShadow", "MemoryAura", "MemoryRing"]:
		var decoration := root.get_node_or_null(decoration_name) as CanvasItem
		if decoration != null:
			decoration.visible = false
	var area := root.get_node_or_null("ClickArea") as Area2D
	if area != null:
		area.position = Vector2.ZERO
		var shape := area.get_node_or_null("Shape") as CollisionShape2D
		if shape != null:
			var rect := RectangleShape2D.new()
			rect.size = Vector2(188, 124)
			shape.shape = rect
	var glow := _add_soft_disc(
		root,
		"ArchiveAmbientGlow",
		Vector2(0, -4),
		Vector2(1.58, 0.78),
		Color(1.0, 0.91, 0.58, 0.08),
		128,
		-7
	)
	_pulse_node(glow, 0.96, 1.04, 0.05, 0.11, 2.8)
	var hover_glow := _add_soft_disc(
		root,
		"ArchiveHoverGlow",
		Vector2(0, -4),
		Vector2(1.68, 0.84),
		Color(1.0, 0.94, 0.64, 0.22),
		128,
		-6
	)
	hover_glow.visible = false

func _configure_memory_corner_archive(root: Node2D, archive_key: String) -> void:
	for decoration_name in ["Sprite", "NodeShadow", "BoardSemanticIcon"]:
		var decoration := root.get_node_or_null(decoration_name) as CanvasItem
		if decoration != null:
			decoration.visible = false
	var area := root.get_node_or_null("ClickArea") as Area2D
	if area != null:
		area.position = Vector2(0, -36)
		var shape := area.get_node_or_null("Shape") as CollisionShape2D
		if shape != null:
			var rect := RectangleShape2D.new()
			rect.size = Vector2(92, 76)
			shape.shape = rect
	var visual := Node2D.new()
	visual.name = "ArchiveVisual"
	root.add_child(visual)
	if archive_key == "photos":
		_build_photo_garland(visual)
	else:
		_build_letter_satchel(visual)
	visual.scale = Vector2.ONE * 0.86
	var glow := _add_soft_disc(root, "ArchiveObjectGlow", Vector2(0, -36), Vector2(0.66, 0.50), Color(1.0, 0.90, 0.58, 0.07), 92, -6)
	_pulse_node(glow, 0.96, 1.05, 0.04, 0.10, 2.6)

func _build_photo_garland(parent: Node2D) -> void:
	var cord := Line2D.new()
	cord.name = "PhotoCord"
	cord.points = PackedVector2Array([Vector2(-45, -58), Vector2(-14, -55), Vector2(14, -58), Vector2(45, -55)])
	cord.width = 2.0
	cord.default_color = Color(0.38, 0.25, 0.16, 0.90)
	parent.add_child(cord)
	_add_hanging_photo(parent, "PhotoLeft", Vector2(-29, 0), -0.08, Color(0.54, 0.72, 0.58, 1.0))
	_add_hanging_photo(parent, "PhotoCenter", Vector2(0, -1), 0.05, Color(0.82, 0.58, 0.62, 1.0))
	_add_hanging_photo(parent, "PhotoRight", Vector2(29, 1), -0.04, Color(0.61, 0.72, 0.84, 1.0))
	_add_archive_icon(parent, "PhotoCamera", "res://assets/ui/icons/icon_camera.png", Vector2(0, -31), 12.0)

func _add_hanging_photo(parent: Node2D, photo_name: String, pos: Vector2, angle: float, image_color: Color) -> void:
	var photo := Node2D.new()
	photo.name = photo_name
	photo.position = pos
	photo.rotation = angle
	parent.add_child(photo)
	_add_archive_polygon(photo, "PaperBorder", PackedVector2Array([
		Vector2(-13, -52), Vector2(13, -52), Vector2(13, -13), Vector2(-13, -13)
	]), Color(0.46, 0.29, 0.17, 1.0))
	_add_archive_polygon(photo, "Paper", PackedVector2Array([
		Vector2(-11, -50), Vector2(11, -50), Vector2(11, -15), Vector2(-11, -15)
	]), Color(1.0, 0.93, 0.76, 1.0))
	_add_archive_polygon(photo, "Image", PackedVector2Array([
		Vector2(-8, -46), Vector2(8, -46), Vector2(8, -27), Vector2(-8, -27)
	]), image_color)
	_add_archive_polygon(photo, "Clip", PackedVector2Array([
		Vector2(-3, -58), Vector2(3, -58), Vector2(3, -51), Vector2(-3, -51)
	]), Color(0.82, 0.58, 0.28, 1.0))

func _build_letter_satchel(parent: Node2D) -> void:
	for x in [-23.0, 23.0]:
		var strap := Line2D.new()
		strap.points = PackedVector2Array([Vector2(x, -64), Vector2(x, -42)])
		strap.width = 3.0
		strap.default_color = Color(0.42, 0.27, 0.16, 0.90)
		parent.add_child(strap)
	_add_small_postcard(parent, "LetterLeft", Vector2(-13, -42), -0.10, Color(0.94, 0.76, 0.61, 1.0))
	_add_small_postcard(parent, "LetterRight", Vector2(13, -43), 0.08, Color(0.75, 0.87, 0.72, 1.0))
	_add_archive_polygon(parent, "SatchelBorder", PackedVector2Array([
		Vector2(-34, -43), Vector2(34, -43), Vector2(31, -7), Vector2(-31, -7)
	]), Color(0.43, 0.27, 0.16, 1.0))
	_add_archive_polygon(parent, "Satchel", PackedVector2Array([
		Vector2(-30, -39), Vector2(30, -39), Vector2(27, -10), Vector2(-27, -10)
	]), Color(0.72, 0.54, 0.32, 1.0))
	_add_archive_polygon(parent, "SatchelFlap", PackedVector2Array([
		Vector2(-27, -37), Vector2(27, -37), Vector2(0, -20)
	]), Color(0.84, 0.66, 0.40, 1.0))
	_add_archive_polygon(parent, "SatchelClasp", PackedVector2Array([
		Vector2(-4, -23), Vector2(4, -23), Vector2(4, -16), Vector2(-4, -16)
	]), Color(0.39, 0.25, 0.16, 1.0))
	_add_archive_icon(parent, "LetterIcon", "res://assets/ui/icons/icon_postcard.png", Vector2(0, -29), 13.0)

func _add_small_postcard(parent: Node2D, card_name: String, pos: Vector2, angle: float, paper_color: Color) -> void:
	var card := Node2D.new()
	card.name = card_name
	card.position = pos
	card.rotation = angle
	parent.add_child(card)
	_add_archive_polygon(card, "Border", PackedVector2Array([
		Vector2(-17, -24), Vector2(17, -24), Vector2(17, 1), Vector2(-17, 1)
	]), Color(0.45, 0.28, 0.17, 1.0))
	_add_archive_polygon(card, "Paper", PackedVector2Array([
		Vector2(-15, -22), Vector2(15, -22), Vector2(15, -1), Vector2(-15, -1)
	]), paper_color)
	_add_archive_polygon(card, "Stamp", PackedVector2Array([
		Vector2(7, -19), Vector2(13, -19), Vector2(13, -13), Vector2(7, -13)
	]), Color(0.83, 0.49, 0.53, 1.0))

func _add_archive_polygon(parent: Node2D, polygon_name: String, points: PackedVector2Array, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.name = polygon_name
	polygon.polygon = points
	polygon.color = color
	parent.add_child(polygon)
	return polygon

func _add_archive_icon(parent: Node2D, icon_name: String, texture_path: String, pos: Vector2, display_size: float) -> void:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return
	var icon := Sprite2D.new()
	icon.name = icon_name
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = pos
	if texture.get_height() > 0:
		icon.scale = Vector2.ONE * (display_size / float(texture.get_height()))
	icon.modulate = Color(0.36, 0.25, 0.18, 0.92)
	parent.add_child(icon)

## 用一个房间物件（object_type）+ 一个 zone 落点生成可点击家具节点。
## 真美术未产出时占位渲染 + 物件名标签（看清是 desk/lamp/...）。point = ZoneManager 落点 {slot_id, zone, pos}。
func make_room_object(object_type: String, point: Dictionary, on_click: Callable) -> Node2D:
	var entry := get_node_asset(object_type, "room")  # 无对应资产时为 {} → 占位
	var pos := _to_vec(point.get("pos", [640, 400]))
	var root := _new_root()
	root.name = "Obj_%s_%s" % [object_type, String(point.get("slot_id", ""))]
	root.position = pos
	root.z_index = int(pos.y)  # ysort 带（docs/09 §10）
	root.z_as_relative = false
	var semantic_scene := bool(point.get("semantic_scene", false))
	var click_entry := entry.duplicate(true)
	if semantic_scene:
		(root.get_node("Sprite") as Sprite2D).visible = false
		click_entry["click_rect"] = [-42, -86, 84, 104]
		_decorate_semantic_room_object(root, object_type)
	else:
		_configure_sprite(root.get_node("Sprite"), entry, object_type)
		_decorate_room_object(root, object_type, float(entry.get("display_height", 96)))
	_configure_click_area(root.get_node("ClickArea"), click_entry, on_click)
	if not semantic_scene:
		var label := Label.new()
		label.name = "ObjTag"
		label.text = _room_object_label(object_type)
		label.position = Vector2(-52, -124)
		label.size = Vector2(104, 22)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.22, 0.19, 0.15, 0.92))
		root.add_child(label)
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

func _configure_sprite(sprite: Sprite2D, entry: Dictionary, node_type: String, state: String = "") -> void:
	var display_h := float(entry.get("display_height", 96))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	var tex := _resolve_texture(entry, node_type, state)
	sprite.texture = tex
	if tex.get_height() > 0:
		sprite.scale = Vector2.ONE * (display_h / float(tex.get_height()))
	sprite.position = Vector2(0, -display_h * 0.5)  # 把贴图抬到落点上方 = bottom_center 近似

## 优先按 manifest file_name 读真实美术(res://assets/<scene>/<file>)，缺图回退程序化占位。
## A 的正式美术到位后无需改代码，丢进对应场景目录即自动生效。
func _configure_bottle_sprite(root: Node2D, entry: Dictionary) -> void:
	var sprite: Sprite2D = root.get_node("Sprite")
	sprite.visible = false

	var frames := load(BOTTLE_FLOAT_FRAMES) as SpriteFrames
	if frames == null:
		_configure_sprite(sprite, entry, "bottle")
		sprite.visible = true
		return

	var display_h := float(entry.get("display_height", 80)) * 0.5
	var animated := AnimatedSprite2D.new()
	animated.name = "BottleFloat"
	animated.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated.sprite_frames = frames
	animated.animation = &"float_loop"
	animated.autoplay = "float_loop"

	var first_frame := frames.get_frame_texture(&"float_loop", 0)
	if first_frame != null and first_frame.get_height() > 0:
		animated.scale = Vector2.ONE * (display_h / float(first_frame.get_height()))
	animated.position = Vector2(0, -display_h * 0.5)
	root.add_child(animated)

func _resolve_texture(entry: Dictionary, node_type: String, state: String = "") -> Texture2D:
	var state_files: Dictionary = entry.get("state_files", {})
	var state_path := String(state_files.get(state, ""))
	if state_path != "" and ResourceLoader.exists(state_path):
		return load(state_path)
	var resource_path := String(entry.get("resource_path", ""))
	if resource_path != "" and ResourceLoader.exists(resource_path):
		return load(resource_path)
	var scene := String(entry.get("scene", ""))
	var file_name := String(entry.get("file_name", ""))
	if scene != "" and file_name != "":
		var real_path := "res://assets/%s/%s" % [scene, file_name]
		if ResourceLoader.exists(real_path):
			return load(real_path)
	return _get_placeholder(node_type)

func apply_memory_state(root: Node2D, state: String) -> void:
	if root == null or not is_instance_valid(root):
		return
	var sprite := root.get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return
	var entry := get_node_asset("memory_flower")
	_configure_sprite(sprite, entry, "memory_flower", state)

func _decorate_memory_node(root: Node2D, node_type: String, display_h: float) -> void:
	_add_soft_disc(root, "NodeShadow", Vector2(0, -8), Vector2(1.0, 0.30), Color(0.18, 0.12, 0.07, 0.24), 92, -8)
	if node_type == "memory_flower":
		var aura := _add_soft_disc(root, "MemoryAura", Vector2(0, -display_h * 0.50), Vector2(0.70, 0.70), Color(0.94, 0.78, 0.86, 0.16), 78, -7)
		var ring := _add_soft_disc(root, "MemoryRing", Vector2(0, -display_h * 0.50), Vector2(0.40, 0.40), Color(1.0, 0.92, 0.66, 0.22), 66, -6)
		_pulse_node(aura, 1.0, 1.05, 0.10, 0.18, 2.4)
		_pulse_node(ring, 0.98, 1.10, 0.12, 0.22, 2.8)

func _decorate_memory_board(root: Node2D, node_type: String, display_h: float) -> void:
	var icon_path := "res://assets/ui/icons/icon_camera.png" if node_type == "photo_board" else "res://assets/ui/icons/icon_postcard.png"
	var icon_texture := load(icon_path) as Texture2D
	if icon_texture == null:
		return
	var icon := Sprite2D.new()
	icon.name = "BoardSemanticIcon"
	icon.texture = icon_texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2(0, -display_h * 0.54)
	if icon_texture.get_height() > 0:
		icon.scale = Vector2.ONE * (24.0 / float(icon_texture.get_height()))
	icon.modulate = Color(0.40, 0.30, 0.21, 0.90)
	icon.z_index = 2
	root.add_child(icon)

func _decorate_bottle_node(root: Node2D) -> void:
	_add_soft_disc(root, "BottleShadow", Vector2(0, -8), Vector2(1.10, 0.28), Color(0.06, 0.18, 0.20, 0.28), 90, -8)
	var ripple := _add_soft_disc(root, "BottleRipple", Vector2(0, -18), Vector2(1.0, 0.36), Color(0.66, 0.90, 0.94, 0.38), 96, -7)
	_pulse_node(ripple, 0.86, 1.18, 0.18, 0.42, 1.6)

func _decorate_room_object(root: Node2D, object_type: String, display_h: float) -> void:
	_add_soft_disc(root, "RoomObjectShadow", Vector2(0, -6), Vector2(1.12, 0.30), Color(0.13, 0.10, 0.08, 0.22), 104, -8)
	var marker_color := _room_object_marker_color(object_type)
	var marker := _add_soft_disc(root, "RoomObjectAIHalo", Vector2(0, -display_h * 0.54), Vector2(0.72, 0.72), marker_color, 82, -7)
	_pulse_node(marker, 0.94, 1.08, 0.18, 0.30, 2.6)

func _decorate_semantic_room_object(root: Node2D, object_type: String) -> void:
	var marker_color := _room_object_marker_color(object_type)
	_add_soft_disc(root, "RoomObjectFocus", Vector2(0, -34), Vector2(0.46, 0.18), Color(0.13, 0.10, 0.08, 0.18), 74, -7)
	var marker := _add_soft_disc(root, "RoomObjectSemanticHalo", Vector2(0, -42), Vector2(0.34, 0.34), marker_color, 68, -6)
	_pulse_node(marker, 0.96, 1.12, 0.16, 0.28, 2.8)

func _add_soft_disc(parent: Node2D, node_name: String, pos: Vector2, disc_scale: Vector2, modulate_color: Color, size: int, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = _soft_disc_texture(size)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = pos
	sprite.scale = disc_scale
	sprite.modulate = modulate_color
	sprite.z_index = z
	parent.add_child(sprite)
	return sprite

func _soft_disc_texture(size: int) -> Texture2D:
	if _soft_disc_textures.has(size):
		return _soft_disc_textures[size]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(size / 2.0, size / 2.0)
	var r := size / 2.0 - 1.0
	for y in range(size):
		for x in range(size):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r:
				var alpha: float = clampf(1.0 - d / r, 0.0, 1.0)
				alpha = pow(alpha, 0.65)
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
	var tex := ImageTexture.create_from_image(img)
	_soft_disc_textures[size] = tex
	return tex

func _pulse_node(node: Node2D, from_scale: float, to_scale: float, from_alpha: float, to_alpha: float, duration: float) -> void:
	if node == null:
		return
	if OS.get_environment("FG_CAPTURE_SCREENSHOTS") == "1":
		node.modulate.a = to_alpha
		return
	node.scale *= from_scale
	node.modulate.a = from_alpha
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(node, "scale", node.scale * (to_scale / from_scale), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(node, "modulate:a", to_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", node.scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(node, "modulate:a", from_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _make_placeholder_texture(node_type: String) -> Texture2D:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if node_type == "bottle":
		_fill_rect(img, 21, 8, 7, 8, Color(0.76, 0.88, 0.92, 1.0))
		_fill_rect(img, 17, 16, 16, 24, Color(0.58, 0.78, 0.86, 0.92))
		_fill_rect(img, 19, 18, 12, 18, Color(0.70, 0.90, 0.96, 0.78))
		_fill_rect(img, 20, 6, 9, 3, Color(0.36, 0.22, 0.12, 1.0))
		_fill_rect(img, 21, 28, 9, 3, Color(0.95, 0.82, 0.52, 1.0))
	elif node_type in ["desk", "bed", "bookshelf", "lamp", "plant", "photo_wall", "chair", "sofa", "rug", "table"]:
		_fill_rect(img, 10, 26, 28, 12, Color(0.72, 0.56, 0.38, 1.0))
		_fill_rect(img, 13, 18, 22, 10, Color(0.92, 0.80, 0.58, 1.0))
		_fill_rect(img, 16, 38, 4, 6, Color(0.38, 0.28, 0.20, 1.0))
		_fill_rect(img, 30, 38, 4, 6, Color(0.38, 0.28, 0.20, 1.0))
		_fill_circle(img, 36, 17, 5, Color(0.95, 0.76, 0.38, 1.0))
		_fill_rect(img, 35, 22, 2, 14, Color(0.42, 0.34, 0.26, 1.0))
	else:
		_fill_rect(img, 23, 25, 3, 17, Color(0.24, 0.50, 0.30, 1.0))
		_fill_rect(img, 20, 36, 9, 4, Color(0.34, 0.60, 0.38, 1.0))
		_fill_circle(img, 24, 15, 6, Color(0.92, 0.52, 0.78, 1.0))
		_fill_circle(img, 17, 22, 6, Color(0.98, 0.68, 0.76, 1.0))
		_fill_circle(img, 31, 22, 6, Color(0.92, 0.58, 0.86, 1.0))
		_fill_circle(img, 24, 29, 6, Color(1.0, 0.76, 0.68, 1.0))
		_fill_circle(img, 24, 23, 4, Color(0.98, 0.86, 0.34, 1.0))
	return ImageTexture.create_from_image(img)

func _room_object_label(object_type: String) -> String:
	match object_type:
		"desk":
			return "书桌"
		"bed":
			return "床"
		"bookshelf":
			return "书架"
		"lamp":
			return "灯"
		"plant":
			return "绿植"
		"photo_wall":
			return "照片墙"
		"chair":
			return "椅子"
		"sofa":
			return "沙发"
		"rug":
			return "地毯"
		"table":
			return "小桌"
		_:
			return "AI 物件"

func _room_object_marker_color(object_type: String) -> Color:
	match object_type:
		"lamp":
			return Color(1.0, 0.82, 0.38, 0.28)
		"plant":
			return Color(0.58, 0.82, 0.46, 0.28)
		"photo_wall":
			return Color(0.78, 0.58, 0.92, 0.28)
		_:
			return Color(0.78, 0.88, 1.0, 0.24)

func _fill_rect(img: Image, x0: int, y0: int, w: int, h: int, color: Color) -> void:
	for y in range(maxi(0, y0), mini(img.get_height(), y0 + h)):
		for x in range(maxi(0, x0), mini(img.get_width(), x0 + w)):
			img.set_pixel(x, y, color)

func _fill_circle(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	var r2 := radius * radius
	for y in range(maxi(0, cy - radius), mini(img.get_height(), cy + radius + 1)):
		for x in range(maxi(0, cx - radius), mini(img.get_width(), cx + radius + 1)):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, color)

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
