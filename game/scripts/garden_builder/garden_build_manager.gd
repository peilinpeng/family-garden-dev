extends Node

signal build_mode_changed(active: bool)

const DATA_PATH := "res://assets/garden_builder/data/garden_assets.json"
const SAVE_PATH := "user://garden_layout_v1.json"
const GROUND_TILESET_PATH := "res://assets/garden/tileset/garden_ground_tileset.tres"
const GROUND_TILE_TEXTURE := "res://assets/garden/tileset/ground/Tileset_Ground.png"
const ROAD_TILE_TEXTURE := "res://assets/garden/tileset/ground/Tileset_Road.png"
const GRID_SIZE := 32
const TILE_TEXTURE_SIZE := 16

const CATEGORY_LABELS := {
	"ground_tiles": "地面",
	"path_tiles": "小路",
	"tile_tools": "瓦片",
	"flowerbeds": "花坛",
	"pots": "花盆",
	"plants": "植物",
	"bridges": "桥梁",
	"furniture": "家具",
	"decorations": "装饰",
	"tools": "工具"
}

const CATEGORY_ORDER := [
	"ground_tiles",
	"path_tiles",
	"tile_tools",
	"flowerbeds",
	"pots",
	"plants",
	"bridges",
	"furniture",
	"decorations",
	"tools"
]

const TILE_PALETTE := [
	{"id": "ground_grass_light", "display_name": "浅草地", "category": "ground_tiles", "source_id": 0, "atlas": Vector2i(0, 8), "texture": GROUND_TILE_TEXTURE},
	{"id": "ground_grass_dense", "display_name": "密草地", "category": "ground_tiles", "source_id": 0, "atlas": Vector2i(1, 8), "texture": GROUND_TILE_TEXTURE},
	{"id": "ground_grass_flower", "display_name": "花草地", "category": "ground_tiles", "source_id": 0, "atlas": Vector2i(2, 8), "texture": GROUND_TILE_TEXTURE},
	{"id": "ground_dirt", "display_name": "泥土地", "category": "ground_tiles", "source_id": 0, "atlas": Vector2i(0, 0), "texture": GROUND_TILE_TEXTURE},
	{"id": "path_stone_01", "display_name": "石子路", "category": "path_tiles", "source_id": 1, "atlas": Vector2i(0, 0), "texture": ROAD_TILE_TEXTURE},
	{"id": "path_stone_02", "display_name": "浅石路", "category": "path_tiles", "source_id": 1, "atlas": Vector2i(1, 0), "texture": ROAD_TILE_TEXTURE},
	{"id": "path_edge_01", "display_name": "路边缘", "category": "path_tiles", "source_id": 1, "atlas": Vector2i(2, 0), "texture": ROAD_TILE_TEXTURE},
	{"id": "tile_erase", "display_name": "擦除瓦片", "category": "tile_tools", "erase": true, "texture": ""}
]

var world: Node2D = null
var ui_layer: CanvasLayer = null
var player: Node = null
var tile_layer: TileMapLayer = null
var object_root: Node2D = null
var preview_root: Node2D = null
var toolbar: PanelContainer = null
var build_toggle_button: Button = null
var asset_scroll_row: HBoxContainer = null
var status_label: Label = null
var preview_sprite: Sprite2D = null
var tile_preview: Polygon2D = null
var build_active: bool = false
var delete_mode: bool = false
var editable_rect: Rect2 = Rect2(Vector2(56, 272), Vector2(1168, 368))
var blocked_rects: Array[Rect2] = []

var assets: Array[Dictionary] = []
var assets_by_category: Dictionary = {}
var assets_by_id: Dictionary = {}
var tiles_by_id: Dictionary = {}
var selected_asset: Dictionary = {}
var selected_tile: Dictionary = {}
var preview_cell: Vector2i = Vector2i.ZERO
var preview_valid: bool = false
var placed_objects: Dictionary = {}
var occupied_cells: Dictionary = {}
var painted_tiles: Dictionary = {}

func _ready() -> void:
	_ensure_input_actions()
	set_process(false)
	set_process_unhandled_input(true)

func setup(p_world: Node2D, p_ui_layer: CanvasLayer, p_player: Node, p_editable_rect: Rect2, p_blocked_rects: Array) -> void:
	teardown()
	world = p_world
	ui_layer = p_ui_layer
	player = p_player
	editable_rect = p_editable_rect
	blocked_rects.clear()
	for rect in p_blocked_rects:
		if rect is Rect2:
			blocked_rects.append(rect)
	_load_asset_database()
	_ensure_roots()
	_build_toolbar()
	_load_layout()
	_set_build_active(false)

func teardown() -> void:
	if player != null and is_instance_valid(player) and player.has_method("set_movement_locked"):
		player.call("set_movement_locked", false)
	if build_toggle_button != null and is_instance_valid(build_toggle_button):
		build_toggle_button.queue_free()
	if toolbar != null and is_instance_valid(toolbar):
		toolbar.queue_free()
	if preview_root != null and is_instance_valid(preview_root):
		preview_root.queue_free()
	if object_root != null and is_instance_valid(object_root):
		object_root.queue_free()
	if tile_layer != null and is_instance_valid(tile_layer):
		tile_layer.queue_free()
	toolbar = null
	build_toggle_button = null
	asset_scroll_row = null
	status_label = null
	tile_layer = null
	preview_root = null
	object_root = null
	preview_sprite = null
	tile_preview = null
	placed_objects.clear()
	occupied_cells.clear()
	painted_tiles.clear()
	selected_asset.clear()
	selected_tile.clear()
	delete_mode = false
	build_active = false
	world = null
	ui_layer = null
	player = null
	set_process(false)

func _ensure_input_actions() -> void:
	_register_key_action("garden_build_toggle", KEY_B)
	_register_key_action("garden_build_delete", KEY_DELETE)
	_register_key_action("garden_build_cancel", KEY_ESCAPE)

func _register_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var has_key: bool = false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.keycode == keycode:
			has_key = true
			break
	if has_key:
		return
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = keycode
	InputMap.action_add_event(action_name, key_event)

func _load_asset_database() -> void:
	assets.clear()
	assets_by_category.clear()
	assets_by_id.clear()
	tiles_by_id.clear()
	for raw_tile in TILE_PALETTE:
		var tile: Dictionary = raw_tile
		tiles_by_id[String(tile.get("id", ""))] = tile
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("Garden builder asset database is missing: " + DATA_PATH)
		return
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	for raw_asset in parsed.get("assets", []):
		if not (raw_asset is Dictionary):
			continue
		var asset: Dictionary = raw_asset
		var texture_path: String = String(asset.get("texture_path", ""))
		if texture_path == "" or not ResourceLoader.exists(texture_path):
			continue
		var id: String = String(asset.get("id", ""))
		if id == "":
			continue
		asset["display_name"] = _readable_asset_name(asset)
		asset["category"] = _normalize_category(String(asset.get("category", "decorations")))
		asset["footprint"] = _normalized_footprint(asset)
		assets.append(asset)
		assets_by_id[id] = asset
		var category: String = String(asset["category"])
		if not assets_by_category.has(category):
			assets_by_category[category] = []
		(assets_by_category[category] as Array).append(asset)
	for category in assets_by_category.keys():
		(assets_by_category[category] as Array).sort_custom(func(a, b) -> bool:
			return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))
		)

func _normalize_category(category: String) -> String:
	if CATEGORY_LABELS.has(category):
		return category
	return "decorations"

func _tile_category_has(category: String) -> bool:
	for tile in TILE_PALETTE:
		if String(tile.get("category", "")) == category:
			return true
	return false

func _tiles_for_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tile in TILE_PALETTE:
		if String(tile.get("category", "")) == category:
			result.append(tile)
	return result

func _readable_asset_name(asset: Dictionary) -> String:
	var category: String = _normalize_category(String(asset.get("category", "decorations")))
	var label: String = String(asset.get("display_name", "")).strip_edges()
	if label == "" or label.contains("?"):
		var order: int = int(asset.get("sort_order", 0))
		return "%s %03d" % [CATEGORY_LABELS.get(category, "素材"), order]
	return label

func _normalized_footprint(asset: Dictionary) -> Vector2i:
	var raw: Variant = asset.get("footprint", [1, 1])
	if raw is Array and raw.size() >= 2:
		return Vector2i(maxi(1, int(raw[0])), maxi(1, int(raw[1])))
	var width: int = maxi(1, int(asset.get("width", GRID_SIZE)))
	var height: int = maxi(1, int(asset.get("height", GRID_SIZE)))
	return Vector2i(maxi(1, ceili(float(width) / float(GRID_SIZE))), maxi(1, ceili(float(height) / float(GRID_SIZE))))

func _ensure_roots() -> void:
	if world == null:
		return
	tile_layer = TileMapLayer.new()
	tile_layer.name = "GardenBuildGroundTiles"
	tile_layer.tile_set = load(GROUND_TILESET_PATH) as TileSet
	tile_layer.scale = Vector2(2, 2)
	tile_layer.z_index = 2
	world.add_child(tile_layer)

	object_root = Node2D.new()
	object_root.name = "GardenBuildObjects"
	object_root.y_sort_enabled = true
	world.add_child(object_root)
	preview_root = Node2D.new()
	preview_root.name = "GardenBuildPreview"
	preview_root.z_index = 10000
	world.add_child(preview_root)

func _build_toolbar() -> void:
	if ui_layer == null:
		return
	build_toggle_button = Button.new()
	build_toggle_button.name = "GardenBuildToggleButton"
	build_toggle_button.text = "建造"
	build_toggle_button.tooltip_text = "打开花园建造"
	build_toggle_button.position = Vector2(1170, 118)
	build_toggle_button.size = Vector2(76, 38)
	build_toggle_button.pressed.connect(func() -> void:
		_set_build_active(not build_active)
	)
	ui_layer.add_child(build_toggle_button)

	toolbar = PanelContainer.new()
	toolbar.name = "GardenBuildToolbar"
	toolbar.visible = false
	toolbar.position = Vector2(120, 552)
	toolbar.size = Vector2(1040, 146)
	toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(toolbar)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.88, 0.68, 0.96)
	style.border_color = Color(0.48, 0.32, 0.16, 1.0)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	toolbar.add_theme_stylebox_override("panel", style)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	toolbar.add_child(root)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	root.add_child(top_row)

	var title: Label = Label.new()
	title.text = "花园建造"
	title.custom_minimum_size = Vector2(78, 28)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.20, 0.16, 0.10, 1.0))
	top_row.add_child(title)

	for category_key in CATEGORY_ORDER:
		var key: String = String(category_key)
		if not assets_by_category.has(key) and not _tile_category_has(key):
			continue
		var button: Button = Button.new()
		button.text = String(CATEGORY_LABELS.get(key, key))
		button.custom_minimum_size = Vector2(58, 30)
		button.pressed.connect(func() -> void:
			_select_category(key)
		)
		top_row.add_child(button)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	var delete_button: Button = Button.new()
	delete_button.text = "删除"
	delete_button.tooltip_text = "切换删除模式"
	delete_button.custom_minimum_size = Vector2(64, 30)
	delete_button.pressed.connect(func() -> void:
		_toggle_delete_mode()
	)
	top_row.add_child(delete_button)

	var close_button: Button = Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(64, 30)
	close_button.pressed.connect(func() -> void:
		_set_build_active(false)
	)
	top_row.add_child(close_button)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(996, 78)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	asset_scroll_row = HBoxContainer.new()
	asset_scroll_row.add_theme_constant_override("separation", 8)
	scroll.add_child(asset_scroll_row)

	status_label = Label.new()
	status_label.text = "按 B 打开/关闭建造。选择素材后在草坪点击放置。"
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(0.29, 0.22, 0.15, 1.0))
	root.add_child(status_label)

	for category_key in CATEGORY_ORDER:
		if assets_by_category.has(category_key):
			_select_category(String(category_key))
			break

func _select_category(category: String) -> void:
	if asset_scroll_row == null:
		return
	for child in asset_scroll_row.get_children():
		child.queue_free()
	for tile in _tiles_for_category(category):
		var tile_button: Button = Button.new()
		tile_button.custom_minimum_size = Vector2(66, 66)
		tile_button.tooltip_text = String(tile.get("display_name", "瓦片"))
		tile_button.icon = _make_tile_icon(tile)
		tile_button.expand_icon = true
		tile_button.pressed.connect(func() -> void:
			_select_tile(tile)
		)
		asset_scroll_row.add_child(tile_button)
	var category_assets: Array = assets_by_category.get(category, [])
	for asset_value in category_assets:
		var asset: Dictionary = asset_value
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(66, 66)
		button.tooltip_text = String(asset.get("display_name", "素材"))
		button.icon = _load_texture(String(asset.get("icon_path", asset.get("texture_path", ""))))
		button.expand_icon = true
		button.pressed.connect(func() -> void:
			_select_asset(asset)
		)
		asset_scroll_row.add_child(button)
	if status_label != null:
		var action_text: String = "选择瓦片后在草坪点击铺设。" if _tile_category_has(category) else "选择素材后在草坪点击放置。"
		status_label.text = "当前分类：%s。%s" % [CATEGORY_LABELS.get(category, category), action_text]

func _select_asset(asset: Dictionary) -> void:
	selected_asset = asset.duplicate(true)
	selected_tile.clear()
	delete_mode = false
	_clear_tile_preview()
	_update_preview_sprite()
	_update_preview()
	if status_label != null:
		status_label.text = "已选择：%s。左键放置，右键取消，删除键可切换删除模式。" % selected_asset.get("display_name", "素材")

func _select_tile(tile: Dictionary) -> void:
	selected_tile = tile.duplicate(true)
	selected_asset.clear()
	delete_mode = false
	_clear_preview()
	_update_tile_preview()
	if status_label != null:
		var verb: String = "擦除" if bool(selected_tile.get("erase", false)) else "铺设"
		status_label.text = "已选择：%s。左键%s瓦片，右键取消。" % [selected_tile.get("display_name", "瓦片"), verb]

func _toggle_delete_mode() -> void:
	delete_mode = not delete_mode
	selected_asset.clear()
	selected_tile.clear()
	_clear_preview()
	_clear_tile_preview()
	if status_label != null:
		status_label.text = "删除模式：点击已放置物件删除。" if delete_mode else "删除模式已关闭。"

func _set_build_active(active: bool) -> void:
	build_active = active
	if toolbar != null:
		toolbar.visible = active
	if build_toggle_button != null:
		build_toggle_button.text = "退出" if active else "建造"
	if not active:
		delete_mode = false
		selected_asset.clear()
		selected_tile.clear()
		_clear_preview()
		_clear_tile_preview()
	if player != null and is_instance_valid(player) and player.has_method("set_movement_locked"):
		player.call("set_movement_locked", active)
	set_process(active)
	emit_signal("build_mode_changed", active)

func _unhandled_input(event: InputEvent) -> void:
	if world == null:
		return
	if event.is_action_pressed("garden_build_toggle"):
		_set_build_active(not build_active)
		get_viewport().set_input_as_handled()
		return
	if not build_active:
		return
	if event.is_action_pressed("garden_build_cancel"):
		_cancel_current_action()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("garden_build_delete"):
		_toggle_delete_mode()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_update_preview()
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_current_action()
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _handle_left_click():
				get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if build_active and not selected_asset.is_empty():
		_update_preview()
	if build_active and not selected_tile.is_empty():
		_update_tile_preview()

func _cancel_current_action() -> void:
	selected_asset.clear()
	selected_tile.clear()
	delete_mode = false
	_clear_preview()
	_clear_tile_preview()
	if status_label != null:
		status_label.text = "已取消。选择素材继续布置花园。"

func _handle_left_click() -> bool:
	if delete_mode:
		var target: Node2D = _object_at_mouse()
		if target != null:
			_delete_object(target)
			_save_layout()
			return true
		return false
	if selected_asset.is_empty():
		if not selected_tile.is_empty():
			_update_tile_preview()
			if not preview_valid:
				if status_label != null:
					status_label.text = "这里不能铺瓦片。请铺在草坪可编辑区域内。"
				return true
			_paint_tile(preview_cell, selected_tile)
			_save_layout()
			if status_label != null:
				status_label.text = "%s 已更新。" % selected_tile.get("display_name", "瓦片")
			return true
		var target: Node2D = _object_at_mouse()
		if target != null and status_label != null:
			status_label.text = "这是已放置物件。切换删除模式可以移除。"
			return true
		return false
	_update_preview()
	if not preview_valid:
		if status_label != null:
			status_label.text = "这里不能放置。请放到草坪网格空位上。"
		return true
	_place_asset(selected_asset, preview_cell)
	_save_layout()
	if status_label != null:
		status_label.text = "%s 已放置。" % selected_asset.get("display_name", "素材")
	return true

func _update_preview_sprite() -> void:
	_clear_preview()
	if selected_asset.is_empty() or preview_root == null:
		return
	preview_sprite = Sprite2D.new()
	preview_sprite.texture = _load_texture(String(selected_asset.get("texture_path", "")))
	preview_sprite.centered = false
	preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_root.add_child(preview_sprite)

func _clear_preview() -> void:
	if preview_sprite != null and is_instance_valid(preview_sprite):
		preview_sprite.queue_free()
	preview_sprite = null
	preview_valid = false

func _update_preview() -> void:
	if selected_asset.is_empty() or preview_sprite == null or world == null:
		return
	var mouse_world: Vector2 = world.get_global_mouse_position()
	preview_cell = _world_to_cell(mouse_world)
	var anchor: Vector2 = _cell_to_anchor(preview_cell, selected_asset)
	preview_sprite.position = anchor + _sprite_offset(selected_asset)
	preview_sprite.z_index = int(anchor.y) + 9000
	preview_valid = _can_place(selected_asset, preview_cell)
	preview_sprite.modulate = Color(0.50, 1.0, 0.50, 0.64) if preview_valid else Color(1.0, 0.28, 0.22, 0.58)

func _update_tile_preview() -> void:
	if selected_tile.is_empty() or preview_root == null or world == null:
		return
	if tile_preview == null or not is_instance_valid(tile_preview):
		tile_preview = Polygon2D.new()
		tile_preview.name = "TilePreview"
		tile_preview.polygon = PackedVector2Array([
			Vector2.ZERO,
			Vector2(GRID_SIZE, 0),
			Vector2(GRID_SIZE, GRID_SIZE),
			Vector2(0, GRID_SIZE)
		])
		tile_preview.z_index = 9999
		preview_root.add_child(tile_preview)
	var mouse_world: Vector2 = world.get_global_mouse_position()
	preview_cell = _world_to_cell(mouse_world)
	tile_preview.position = Vector2(float(preview_cell.x * GRID_SIZE), float(preview_cell.y * GRID_SIZE))
	preview_valid = _can_paint_tile(preview_cell)
	tile_preview.color = Color(0.45, 0.95, 0.55, 0.38) if preview_valid else Color(1.0, 0.20, 0.12, 0.36)

func _clear_tile_preview() -> void:
	if tile_preview != null and is_instance_valid(tile_preview):
		tile_preview.queue_free()
	tile_preview = null

func _place_asset(asset: Dictionary, cell: Vector2i, instance_id: String = "") -> Node2D:
	var id: String = instance_id
	if id == "":
		id = "%s_%d" % [asset.get("id", "garden_item"), Time.get_ticks_msec()]
	var node: Node2D = Node2D.new()
	node.name = "GardenItem_" + id
	node.position = _cell_to_anchor(cell, asset)
	node.z_index = int(node.position.y)
	node.set_meta("instance_id", id)
	node.set_meta("asset_id", String(asset.get("id", "")))
	node.set_meta("cell_x", cell.x)
	node.set_meta("cell_y", cell.y)
	node.set_meta("footprint", _asset_footprint(asset))

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = _load_texture(String(asset.get("texture_path", "")))
	sprite.centered = false
	sprite.position = _sprite_offset(asset)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.add_child(sprite)

	if bool(asset.get("collision", true)):
		var body: StaticBody2D = StaticBody2D.new()
		body.name = "Collision"
		body.collision_layer = 1
		body.collision_mask = 1
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		var footprint: Vector2i = _asset_footprint(asset)
		rect.size = Vector2(float(footprint.x * GRID_SIZE), float(footprint.y * GRID_SIZE))
		shape.shape = rect
		shape.position = Vector2(0, -float(footprint.y * GRID_SIZE) * 0.5)
		body.add_child(shape)
		node.add_child(body)

	object_root.add_child(node)
	placed_objects[id] = node
	_mark_occupied(id, asset, cell)
	return node

func _delete_object(node: Node2D) -> void:
	var instance_id: String = String(node.get_meta("instance_id", ""))
	_unmark_occupied(instance_id)
	placed_objects.erase(instance_id)
	node.queue_free()
	if status_label != null:
		status_label.text = "已删除。"

func _mark_occupied(instance_id: String, asset: Dictionary, cell: Vector2i) -> void:
	for occupied_cell in _cells_for(asset, cell):
		occupied_cells[occupied_cell] = instance_id

func _unmark_occupied(instance_id: String) -> void:
	var to_remove: Array = []
	for cell in occupied_cells.keys():
		if String(occupied_cells[cell]) == instance_id:
			to_remove.append(cell)
	for cell in to_remove:
		occupied_cells.erase(cell)

func _can_place(asset: Dictionary, cell: Vector2i) -> bool:
	for occupied_cell in _cells_for(asset, cell):
		var cell_rect: Rect2 = _cell_rect(occupied_cell)
		if not editable_rect.encloses(cell_rect):
			return false
		for blocked in blocked_rects:
			if blocked.intersects(cell_rect):
				return false
		if occupied_cells.has(occupied_cell):
			return false
	return true

func _can_paint_tile(cell: Vector2i) -> bool:
	var cell_rect: Rect2 = _cell_rect(cell)
	if not editable_rect.encloses(cell_rect):
		return false
	for blocked in blocked_rects:
		if blocked.intersects(cell_rect):
			return false
	return true

func _paint_tile(cell: Vector2i, tile: Dictionary) -> void:
	if tile_layer == null:
		return
	if bool(tile.get("erase", false)):
		tile_layer.erase_cell(cell)
		painted_tiles.erase(cell)
		return
	var source_id: int = int(tile.get("source_id", 0))
	var atlas: Vector2i = _tile_atlas(tile)
	tile_layer.set_cell(cell, source_id, atlas, 0)
	painted_tiles[cell] = String(tile.get("id", ""))

func _cells_for(asset: Dictionary, anchor_cell: Vector2i) -> Array[Vector2i]:
	var footprint: Vector2i = _asset_footprint(asset)
	var cells: Array[Vector2i] = []
	var start_x: int = anchor_cell.x - int(floor(float(footprint.x) / 2.0))
	var start_y: int = anchor_cell.y - footprint.y + 1
	for y in range(footprint.y):
		for x in range(footprint.x):
			cells.append(Vector2i(start_x + x, start_y + y))
	return cells

func _asset_footprint(asset: Dictionary) -> Vector2i:
	var raw: Variant = asset.get("footprint", Vector2i.ONE)
	if raw is Vector2i:
		return raw
	if raw is Vector2:
		return Vector2i(maxi(1, int(raw.x)), maxi(1, int(raw.y)))
	if raw is Array and raw.size() >= 2:
		return Vector2i(maxi(1, int(raw[0])), maxi(1, int(raw[1])))
	return Vector2i.ONE

func _world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(GRID_SIZE)), floori(pos.y / float(GRID_SIZE)))

func _cell_to_anchor(cell: Vector2i, asset: Dictionary) -> Vector2:
	var footprint: Vector2i = _asset_footprint(asset)
	var center_x: float = (float(cell.x) + 0.5) * float(GRID_SIZE)
	if footprint.x % 2 == 0:
		center_x += float(GRID_SIZE) * 0.5
	return Vector2(center_x, float(cell.y + 1) * float(GRID_SIZE))

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(float(cell.x * GRID_SIZE), float(cell.y * GRID_SIZE)), Vector2(GRID_SIZE, GRID_SIZE))

func _sprite_offset(asset: Dictionary) -> Vector2:
	var width: float = float(asset.get("width", GRID_SIZE))
	var height: float = float(asset.get("height", GRID_SIZE))
	return Vector2(-width * 0.5, -height)

func _object_at_mouse() -> Node2D:
	if object_root == null:
		return null
	var mouse_world: Vector2 = world.get_global_mouse_position()
	var found: Node2D = null
	var best_z: int = -1000000
	for node in placed_objects.values():
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		var item: Node2D = node as Node2D
		var asset_id: String = String(item.get_meta("asset_id", ""))
		var asset: Dictionary = assets_by_id.get(asset_id, {})
		if asset.is_empty():
			continue
		var rect: Rect2 = Rect2(item.position + _sprite_offset(asset), Vector2(float(asset.get("width", GRID_SIZE)), float(asset.get("height", GRID_SIZE))))
		if rect.has_point(mouse_world) and item.z_index >= best_z:
			found = item
			best_z = item.z_index
	return found

func _save_layout() -> void:
	var entries: Array = []
	for node in placed_objects.values():
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		entries.append({
			"instance_id": String(node.get_meta("instance_id", "")),
			"asset_id": String(node.get_meta("asset_id", "")),
			"cell": [int(node.get_meta("cell_x", 0)), int(node.get_meta("cell_y", 0))]
		})
	var tile_entries: Array = []
	for raw_cell in painted_tiles.keys():
		var cell: Vector2i = Vector2i(int(raw_cell.x), int(raw_cell.y))
		tile_entries.append({
			"tile_id": String(painted_tiles[cell]),
			"cell": [cell.x, cell.y]
		})
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"version": 2, "objects": entries, "tiles": tile_entries}, "\t"))

func _load_layout() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	for raw_tile_entry in parsed.get("tiles", []):
		if not (raw_tile_entry is Dictionary):
			continue
		var tile_entry: Dictionary = raw_tile_entry
		var tile_id: String = String(tile_entry.get("tile_id", ""))
		if not tiles_by_id.has(tile_id):
			continue
		var tile_cell_raw: Variant = tile_entry.get("cell", [0, 0])
		if not (tile_cell_raw is Array) or tile_cell_raw.size() < 2:
			continue
		var tile_cell: Vector2i = Vector2i(int(tile_cell_raw[0]), int(tile_cell_raw[1]))
		if _can_paint_tile(tile_cell):
			_paint_tile(tile_cell, tiles_by_id[tile_id])
	for raw_entry in parsed.get("objects", []):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var asset_id: String = String(entry.get("asset_id", ""))
		if not assets_by_id.has(asset_id):
			continue
		var cell_raw: Variant = entry.get("cell", [0, 0])
		if not (cell_raw is Array) or cell_raw.size() < 2:
			continue
		var asset: Dictionary = assets_by_id[asset_id]
		var cell: Vector2i = Vector2i(int(cell_raw[0]), int(cell_raw[1]))
		if _can_place(asset, cell):
			_place_asset(asset, cell, String(entry.get("instance_id", "")))

func _load_texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _make_tile_icon(tile: Dictionary) -> Texture2D:
	if bool(tile.get("erase", false)):
		var image: Image = Image.create(TILE_TEXTURE_SIZE, TILE_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.92, 0.86, 0.74, 1.0))
		for i in range(TILE_TEXTURE_SIZE):
			image.set_pixel(i, i, Color(0.70, 0.18, 0.12, 1.0))
			image.set_pixel(TILE_TEXTURE_SIZE - 1 - i, i, Color(0.70, 0.18, 0.12, 1.0))
		return ImageTexture.create_from_image(image)
	var texture: Texture2D = _load_texture(String(tile.get("texture", "")))
	if texture == null:
		return null
	var icon: AtlasTexture = AtlasTexture.new()
	icon.atlas = texture
	var atlas: Vector2i = _tile_atlas(tile)
	icon.region = Rect2(Vector2(float(atlas.x * TILE_TEXTURE_SIZE), float(atlas.y * TILE_TEXTURE_SIZE)), Vector2(TILE_TEXTURE_SIZE, TILE_TEXTURE_SIZE))
	return icon

func _tile_atlas(tile: Dictionary) -> Vector2i:
	var raw: Variant = tile.get("atlas", Vector2i.ZERO)
	if raw is Vector2i:
		return raw
	if raw is Vector2:
		return Vector2i(int(raw.x), int(raw.y))
	if raw is Array and raw.size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return Vector2i.ZERO
