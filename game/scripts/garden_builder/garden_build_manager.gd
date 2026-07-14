extends Node

signal build_mode_changed(active: bool)

const DATA_PATH := "res://assets/garden_builder/data/garden_assets.json"
const SAVE_PATH := "user://garden_layout_v1.json"
const GROUND_TILESET_PATH := "res://assets/garden/tileset/garden_ground_tileset.tres"
const GROUND_TILE_TEXTURE := "res://assets/garden/tileset/ground/Tileset_Ground.png"
const DIRT_TILE_TEXTURE := "res://assets/garden/tileset/ground/Tileset_Dirt.png"
const ROAD_TILE_TEXTURE := "res://assets/garden/tileset/ground/Tileset_Road.png"
const WATER_TILE_TEXTURE := "res://assets/garden/tileset/water/Tileset_Water.png"
const TerrainResolver = preload("res://scripts/garden_builder/terrain_autotile_resolver.gd")
const GRID_SIZE := 32
const TILE_TEXTURE_SIZE := 16
const SCENE_PREVIEW_Z_INDEX := 4095
const GROUND_DECOR_Z_INDEX := -50
const WALL_OBJECT_Z_INDEX := -40
const FOREGROUND_Z_INDEX := 4000

const CATEGORY_LABELS := {
	"ground_tiles": "地面",
	"path_tiles": "小路",
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
	"flowerbeds",
	"pots",
	"plants",
	"bridges",
	"furniture",
	"decorations",
	"tools"
]

const TILE_PALETTE := []

var world: Node2D = null
var ui_layer: CanvasLayer = null
var player: Node = null
var tile_layer: TileMapLayer = null
var water_layer: TileMapLayer = null
var object_root: Node2D = null
var preview_root: Node2D = null
var toolbar: PanelContainer = null
var toolbar_top_row: HBoxContainer = null
var toolbar_scroll: ScrollContainer = null
var toolbar_title: Label = null
var toolbar_collapse_button: Button = null
var asset_scroll_row: HBoxContainer = null
var status_label: Label = null
var preview_sprite: Sprite2D = null
var tile_preview: Sprite2D = null
var delete_preview: Polygon2D = null
var terrain_preview_root: Node2D = null
var build_active: bool = false
var toolbar_collapsed: bool = false
var delete_mode: bool = false
var active_tab: String = "terrain"
var selected_terrain_id: String = ""
var painting_active: bool = false
var paint_start_cell: Vector2i = Vector2i.ZERO
var paint_last_cell: Vector2i = Vector2i.ZERO
var paint_before: Dictionary = {}
var editable_rect: Rect2 = Rect2(Vector2(56, 272), Vector2(1168, 368))
var blocked_rects: Array[Rect2] = []

var assets: Array[Dictionary] = []
var assets_by_category: Dictionary = {}
var assets_by_id: Dictionary = {}
var tiles_by_id: Dictionary = {}
var tile_palette: Array[Dictionary] = []
var selected_asset: Dictionary = {}
var selected_tile: Dictionary = {}
var preview_cell: Vector2i = Vector2i.ZERO
var preview_valid: bool = false
var placed_objects: Dictionary = {}
var occupied_cells: Dictionary = {}
var terrain_cells: Dictionary = {}
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []

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
	if toolbar != null and is_instance_valid(toolbar):
		toolbar.queue_free()
	if preview_root != null and is_instance_valid(preview_root):
		preview_root.queue_free()
	if terrain_preview_root != null and is_instance_valid(terrain_preview_root):
		terrain_preview_root.queue_free()
	if object_root != null and is_instance_valid(object_root):
		object_root.queue_free()
	if tile_layer != null and is_instance_valid(tile_layer):
		tile_layer.queue_free()
	if water_layer != null and is_instance_valid(water_layer):
		water_layer.queue_free()
	toolbar = null
	toolbar_top_row = null
	toolbar_scroll = null
	toolbar_title = null
	toolbar_collapse_button = null
	asset_scroll_row = null
	status_label = null
	tile_layer = null
	water_layer = null
	preview_root = null
	object_root = null
	preview_sprite = null
	tile_preview = null
	delete_preview = null
	terrain_preview_root = null
	placed_objects.clear()
	occupied_cells.clear()
	terrain_cells.clear()
	undo_stack.clear()
	redo_stack.clear()
	selected_asset.clear()
	selected_tile.clear()
	selected_terrain_id = ""
	delete_mode = false
	painting_active = false
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
	tile_palette = _build_tile_palette()
	for raw_tile in tile_palette:
		var tile: Dictionary = raw_tile
		tiles_by_id[String(tile.get("id", ""))] = tile
	_register_legacy_tile_aliases()
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
		asset["display_scale"] = float(asset.get("display_scale", _display_scale_for_category(String(asset["category"]))))
		asset["footprint"] = _normalized_footprint(asset)
		assets.append(asset)
		assets_by_id[id] = asset
		var category: String = String(asset["category"])
		if not assets_by_category.has(category):
			assets_by_category[category] = []
		(assets_by_category[category] as Array).append(asset)
	_add_builtin_furniture_assets()
	for category in assets_by_category.keys():
		(assets_by_category[category] as Array).sort_custom(func(a, b) -> bool:
			return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))
		)

func _build_tile_palette() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_tile in TILE_PALETTE:
		var tile: Dictionary = raw_tile
		result.append(tile)
	_append_tiles_from_sheet(result, "ground", "地面", "ground_tiles", 0, GROUND_TILE_TEXTURE, 12, 10)
	_append_tiles_from_sheet(result, "path", "小路", "path_tiles", 1, ROAD_TILE_TEXTURE, 6, 12)
	return result

func _append_tiles_from_sheet(result: Array[Dictionary], id_prefix: String, label_prefix: String, category: String, source_id: int, texture: String, columns: int, rows: int) -> void:
	for y in range(rows):
		for x in range(columns):
			var atlas: Vector2i = Vector2i(x, y)
			if not _tile_has_visible_pixels(texture, atlas):
				continue
			var tile_id: String = "%s_%02d_%02d" % [id_prefix, x, y]
			var tile_name: String = "%s %02d-%02d" % [label_prefix, y + 1, x + 1]
			result.append({
				"id": tile_id,
				"display_name": tile_name,
				"category": category,
				"source_id": source_id,
				"atlas": atlas,
				"texture": texture
			})

func _tile_has_visible_pixels(texture_path: String, atlas: Vector2i) -> bool:
	var texture: Texture2D = _load_texture(texture_path)
	if texture == null:
		return false
	var image: Image = texture.get_image()
	if image == null:
		return true
	var start_x: int = atlas.x * TILE_TEXTURE_SIZE
	var start_y: int = atlas.y * TILE_TEXTURE_SIZE
	if start_x + TILE_TEXTURE_SIZE > image.get_width() or start_y + TILE_TEXTURE_SIZE > image.get_height():
		return false
	for y in range(TILE_TEXTURE_SIZE):
		for x in range(TILE_TEXTURE_SIZE):
			if image.get_pixel(start_x + x, start_y + y).a > 0.01:
				return true
	return false

func _register_legacy_tile_aliases() -> void:
	_add_tile_alias("ground_grass_light", 0, Vector2i(0, 8))
	_add_tile_alias("ground_grass_dense", 0, Vector2i(1, 8))
	_add_tile_alias("ground_grass_flower", 0, Vector2i(2, 8))
	_add_tile_alias("ground_dirt", 0, Vector2i(0, 0))
	_add_tile_alias("path_stone_01", 1, Vector2i(0, 0))
	_add_tile_alias("path_stone_02", 1, Vector2i(1, 0))
	_add_tile_alias("path_edge_01", 1, Vector2i(2, 0))

func _add_tile_alias(alias_id: String, source_id: int, atlas: Vector2i) -> void:
	for raw_tile in tile_palette:
		var tile: Dictionary = raw_tile
		if int(tile.get("source_id", -1)) == source_id and _tile_atlas(tile) == atlas:
			var alias_tile: Dictionary = tile.duplicate(true)
			alias_tile["id"] = alias_id
			tiles_by_id[alias_id] = alias_tile
			return

func _normalize_category(category: String) -> String:
	if CATEGORY_LABELS.has(category):
		return category
	return "decorations"

func _tile_category_has(category: String) -> bool:
	for raw_tile in tile_palette:
		var tile: Dictionary = raw_tile
		if String(tile.get("category", "")) == category:
			return true
	return false

func _tiles_for_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_tile in tile_palette:
		var tile: Dictionary = raw_tile
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

func _display_scale_for_category(category: String) -> float:
	match category:
		"flowerbeds":
			return 0.78
		"plants":
			return 0.68
		"pots":
			return 0.50
		"furniture":
			return 0.68
		"decorations":
			return 0.75
		"tools":
			return 0.58
		_:
			return 1.0

func _add_builtin_furniture_assets() -> void:
	var builtin: Array[Dictionary] = [
		{"id": "builtin_bench_1", "display_name": "长椅 1", "texture_path": "res://assets/garden/tileset/props/Bench_1.png", "sort_order": -11},
		{"id": "builtin_bench_3", "display_name": "长椅 2", "texture_path": "res://assets/garden/tileset/props/Bench_3.png", "sort_order": -10},
		{"id": "builtin_table_medium", "display_name": "圆桌", "texture_path": "res://assets/garden/tileset/props/Table_Medium_1.png", "sort_order": -9},
		{"id": "builtin_barrel", "display_name": "木桶", "texture_path": "res://assets/garden/tileset/props/Barrel_Small_Empty.png", "sort_order": -8},
		{"id": "builtin_basket", "display_name": "篮子", "texture_path": "res://assets/garden/tileset/props/Basket_Empty.png", "sort_order": -7},
		{"id": "builtin_crate_large", "display_name": "大木箱", "texture_path": "res://assets/garden/tileset/props/Crate_Large_Empty.png", "sort_order": -6},
		{"id": "builtin_crate_medium", "display_name": "木箱", "texture_path": "res://assets/garden/tileset/props/Crate_Medium_Closed.png", "sort_order": -5},
		{"id": "builtin_lamp_post", "display_name": "庭院灯", "texture_path": "res://assets/garden/tileset/props/LampPost_3.png", "sort_order": -4},
		{"id": "builtin_sign_1", "display_name": "木牌 1", "texture_path": "res://assets/garden/tileset/props/Sign_1.png", "sort_order": -3},
		{"id": "builtin_sign_2", "display_name": "木牌 2", "texture_path": "res://assets/garden/tileset/props/Sign_2.png", "sort_order": -2},
		{"id": "builtin_bulletin_board", "display_name": "公告板", "texture_path": "res://assets/garden/tileset/props/BulletinBoard_1.png", "sort_order": -1}
	]
	for raw_entry in builtin:
		var entry: Dictionary = raw_entry
		var id: String = String(entry.get("id", ""))
		var texture_path: String = String(entry.get("texture_path", ""))
		if id == "" or assets_by_id.has(id) or texture_path == "" or not ResourceLoader.exists(texture_path):
			continue
		var texture: Texture2D = _load_texture(texture_path)
		if texture == null:
			continue
		entry["category"] = "furniture"
		entry["icon_path"] = texture_path
		entry["width"] = texture.get_width()
		entry["height"] = texture.get_height()
		# 这组原生 tileset 道具以 16px 美术像素制作，需要 2x 才与约 80px 高的角色协调。
		entry["display_scale"] = 2.0
		entry["footprint"] = _normalized_footprint(entry)
		entry["collision"] = true
		entry["y_sort"] = true
		entry["placement_layer"] = "prop"
		assets.append(entry)
		assets_by_id[id] = entry
		if not assets_by_category.has("furniture"):
			assets_by_category["furniture"] = []
		(assets_by_category["furniture"] as Array).append(entry)

func _normalized_footprint(asset: Dictionary) -> Vector2i:
	var raw: Variant = asset.get("footprint", [1, 1])
	var category: String = _normalize_category(String(asset.get("category", "decorations")))
	var display_scale: float = float(asset.get("display_scale", _display_scale_for_category(category)))
	var width: int = maxi(1, int(round(float(asset.get("width", GRID_SIZE)) * display_scale)))
	var height: int = maxi(1, int(round(float(asset.get("height", GRID_SIZE)) * display_scale)))
	var visual_footprint: Vector2i = Vector2i(maxi(1, ceili(float(width) / float(GRID_SIZE))), maxi(1, ceili(float(height) / float(GRID_SIZE))))
	if asset.has("footprint") and raw is Array and raw.size() >= 2:
		var declared: Vector2i = Vector2i(maxi(1, int(raw[0])), maxi(1, int(raw[1])))
		return Vector2i(maxi(declared.x, visual_footprint.x), maxi(declared.y, visual_footprint.y))
	return visual_footprint

func _ensure_roots() -> void:
	if world == null:
		return
	tile_layer = TileMapLayer.new()
	tile_layer.name = "GardenBuildGroundTiles"
	tile_layer.tile_set = _make_surface_tileset()
	tile_layer.scale = Vector2(2, 2)
	tile_layer.z_index = 2
	world.add_child(tile_layer)

	water_layer = TileMapLayer.new()
	water_layer.name = "GardenBuildWaterTerrain"
	water_layer.tile_set = _make_runtime_tileset(WATER_TILE_TEXTURE, 24, 13)
	water_layer.scale = Vector2(2, 2)
	water_layer.z_index = 3
	world.add_child(water_layer)

	object_root = Node2D.new()
	object_root.name = "GardenBuildObjects"
	# 花园角色与 NPC 已按脚底落点手动设置 z_index，这里不再叠加第二套 Y Sort。
	object_root.y_sort_enabled = false
	world.add_child(object_root)
	preview_root = Node2D.new()
	preview_root.name = "GardenBuildPreview"
	preview_root.z_as_relative = false
	preview_root.z_index = SCENE_PREVIEW_Z_INDEX
	world.add_child(preview_root)
	terrain_preview_root = Node2D.new()
	terrain_preview_root.name = "GardenTerrainPreview"
	terrain_preview_root.z_as_relative = false
	terrain_preview_root.z_index = SCENE_PREVIEW_Z_INDEX
	world.add_child(terrain_preview_root)

func _make_runtime_tileset(texture_path: String, columns: int, rows: int) -> TileSet:
	var tile_set: TileSet = TileSet.new()
	var texture: Texture2D = _load_texture(texture_path)
	if texture == null:
		return tile_set
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_TEXTURE_SIZE, TILE_TEXTURE_SIZE)
	for y in range(rows):
		for x in range(columns):
			source.create_tile(Vector2i(x, y))
	tile_set.add_source(source, 0)
	return tile_set

func _make_surface_tileset() -> TileSet:
	var tile_set: TileSet = TileSet.new()
	_add_tileset_source(tile_set, DIRT_TILE_TEXTURE, 0, 6, 14)
	_add_tileset_source(tile_set, ROAD_TILE_TEXTURE, 1, 6, 14)
	return tile_set

func _add_tileset_source(tile_set: TileSet, texture_path: String, source_id: int, columns: int, rows: int) -> void:
	var texture: Texture2D = _load_texture(texture_path)
	if texture == null:
		return
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_TEXTURE_SIZE, TILE_TEXTURE_SIZE)
	for y in range(rows):
		for x in range(columns):
			source.create_tile(Vector2i(x, y))
	tile_set.add_source(source, source_id)

func _build_toolbar() -> void:
	if ui_layer == null:
		return

	toolbar = PanelContainer.new()
	toolbar.name = "GardenBuildToolbar"
	toolbar.visible = false
	toolbar.position = Vector2(120, 500)
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

	toolbar_top_row = HBoxContainer.new()
	toolbar_top_row.name = "ToolbarHeader"
	toolbar_top_row.add_theme_constant_override("separation", 8)
	root.add_child(toolbar_top_row)

	toolbar_title = Label.new()
	toolbar_title.name = "ToolbarTitle"
	toolbar_title.text = "花园建造"
	toolbar_title.custom_minimum_size = Vector2(118, 28)
	toolbar_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toolbar_title.add_theme_font_size_override("font_size", 18)
	toolbar_title.add_theme_color_override("font_color", Color(0.20, 0.16, 0.10, 1.0))
	toolbar_top_row.add_child(toolbar_title)

	var terrain_tab_button: Button = Button.new()
	terrain_tab_button.text = "铺地"
	terrain_tab_button.custom_minimum_size = Vector2(64, 30)
	terrain_tab_button.pressed.connect(func() -> void:
		_select_tab("terrain")
	)
	toolbar_top_row.add_child(terrain_tab_button)

	var objects_tab_button: Button = Button.new()
	objects_tab_button.text = "摆设"
	objects_tab_button.custom_minimum_size = Vector2(64, 30)
	objects_tab_button.pressed.connect(func() -> void:
		_select_tab("objects")
	)
	toolbar_top_row.add_child(objects_tab_button)

	for category_key in CATEGORY_ORDER:
		var key: String = String(category_key)
		if key == "ground_tiles" or key == "path_tiles":
			continue
		if not assets_by_category.has(key):
			continue
		var button: Button = Button.new()
		button.text = String(CATEGORY_LABELS.get(key, key))
		button.custom_minimum_size = Vector2(58, 30)
		button.pressed.connect(func() -> void:
			_select_category(key)
		)
		toolbar_top_row.add_child(button)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_top_row.add_child(spacer)

	var delete_button: Button = Button.new()
	delete_button.text = "删除"
	delete_button.tooltip_text = "切换删除模式"
	delete_button.custom_minimum_size = Vector2(64, 30)
	delete_button.pressed.connect(func() -> void:
		_toggle_delete_mode()
	)
	toolbar_top_row.add_child(delete_button)

	toolbar_collapse_button = Button.new()
	toolbar_collapse_button.name = "ToolbarCollapseButton"
	toolbar_collapse_button.text = "收起"
	toolbar_collapse_button.tooltip_text = "收起工具栏但保留当前建造工具"
	toolbar_collapse_button.custom_minimum_size = Vector2(64, 30)
	toolbar_collapse_button.pressed.connect(func() -> void:
		_set_toolbar_collapsed(not toolbar_collapsed)
	)
	toolbar_top_row.add_child(toolbar_collapse_button)

	var close_button: Button = Button.new()
	close_button.name = "ToolbarCloseButton"
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(64, 30)
	close_button.pressed.connect(func() -> void:
		_set_build_active(false)
	)
	toolbar_top_row.add_child(close_button)

	toolbar_scroll = ScrollContainer.new()
	toolbar_scroll.name = "ToolbarAssetScroll"
	toolbar_scroll.custom_minimum_size = Vector2(996, 78)
	toolbar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	toolbar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(toolbar_scroll)

	asset_scroll_row = HBoxContainer.new()
	asset_scroll_row.add_theme_constant_override("separation", 8)
	toolbar_scroll.add_child(asset_scroll_row)

	status_label = Label.new()
	status_label.text = "选择铺地材料后点击或拖动绘制；切到摆设后放置花盆、家具等物件。"
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(0.29, 0.22, 0.15, 1.0))
	root.add_child(status_label)

	_select_tab("terrain")
	_set_toolbar_collapsed(false)

func _set_toolbar_collapsed(collapsed: bool) -> void:
	toolbar_collapsed = collapsed
	if toolbar == null:
		return
	toolbar.position = Vector2(454, 604) if collapsed else Vector2(120, 500)
	toolbar.size = Vector2(372, 40) if collapsed else Vector2(1040, 146)
	if toolbar_scroll != null:
		toolbar_scroll.visible = not collapsed
	if status_label != null:
		status_label.visible = not collapsed
	if toolbar_title != null:
		toolbar_title.text = "花园建造（工具已保留）" if collapsed else "花园建造"
	if toolbar_collapse_button != null:
		toolbar_collapse_button.text = "展开" if collapsed else "收起"
	if toolbar_top_row != null:
		for child in toolbar_top_row.get_children():
			var control := child as Control
			if control == null:
				continue
			if control == toolbar_title or control == toolbar_collapse_button or String(control.name) == "ToolbarCloseButton":
				control.visible = true
			else:
				control.visible = not collapsed

func _select_tab(tab: String) -> void:
	active_tab = tab
	selected_asset.clear()
	selected_tile.clear()
	selected_terrain_id = ""
	delete_mode = false
	painting_active = false
	_clear_preview()
	_clear_tile_preview()
	_clear_delete_preview()
	_clear_terrain_preview()
	if tab == "terrain":
		_show_terrain_tools()
	else:
		_select_first_object_category()

func _select_first_object_category() -> void:
	for category_key in CATEGORY_ORDER:
		var key: String = String(category_key)
		if key == "ground_tiles" or key == "path_tiles":
			continue
		if assets_by_category.has(key):
			_select_category(key)
			return

func _show_terrain_tools() -> void:
	if asset_scroll_row == null:
		return
	for child in asset_scroll_row.get_children():
		child.queue_free()
	asset_scroll_row.add_child(_make_terrain_tool_button("dirt", "泥土地面"))
	asset_scroll_row.add_child(_make_terrain_tool_button("stone", "浅色石板"))
	asset_scroll_row.add_child(_make_terrain_tool_button("water", "水池"))
	asset_scroll_row.add_child(_make_terrain_tool_button("grass", "草地恢复"))
	if status_label != null:
		status_label.text = "铺地：左键点击或拖动绘制，Shift 拖动绘制矩形，右键取消，Ctrl+Z/Y 撤销重做。"

func _make_terrain_tool_button(terrain_id: String, label_text: String) -> Button:
	var button: Button = Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(118, 66)
	button.tooltip_text = label_text
	button.icon = _make_terrain_tool_icon(terrain_id)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.90, 0.72, 0.96)
	style.border_color = Color(0.48, 0.32, 0.16, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.pressed.connect(func() -> void:
		_select_terrain(terrain_id)
	)
	return button

func _make_terrain_tool_icon(terrain_id: String) -> Texture2D:
	match terrain_id:
		"dirt":
			return _make_atlas_icon(DIRT_TILE_TEXTURE, _terrain_icon_atlas("dirt", Vector2i(0, 8)))
		"stone":
			return _make_atlas_icon(ROAD_TILE_TEXTURE, _terrain_icon_atlas("stone", Vector2i(0, 8)))
		"water":
			return _make_atlas_icon(WATER_TILE_TEXTURE, _terrain_icon_atlas("water", Vector2i(2, 1)))
		"grass":
			return _make_atlas_icon(GROUND_TILE_TEXTURE, Vector2i(0, 8))
		_:
			return null

func _terrain_icon_atlas(terrain_id: String, fallback: Vector2i) -> Vector2i:
	var resolved: Dictionary = TerrainResolver.resolve(terrain_id, 15)
	var raw_atlas: Variant = resolved.get("atlas", fallback)
	if raw_atlas is Vector2i:
		return raw_atlas
	if raw_atlas is Vector2:
		return Vector2i(int(raw_atlas.x), int(raw_atlas.y))
	return fallback

func _make_atlas_icon(texture_path: String, atlas: Vector2i) -> Texture2D:
	var texture: Texture2D = _load_texture(texture_path)
	if texture == null:
		return null
	var icon: AtlasTexture = AtlasTexture.new()
	icon.atlas = texture
	icon.region = Rect2(Vector2(float(atlas.x * TILE_TEXTURE_SIZE), float(atlas.y * TILE_TEXTURE_SIZE)), Vector2(TILE_TEXTURE_SIZE, TILE_TEXTURE_SIZE))
	return icon

func _select_terrain(terrain_id: String) -> void:
	active_tab = "terrain"
	selected_terrain_id = terrain_id
	selected_asset.clear()
	selected_tile.clear()
	delete_mode = false
	_clear_preview()
	_clear_tile_preview()
	_clear_delete_preview()
	_update_terrain_preview()
	if status_label != null:
		status_label.text = "已选择：%s。左键绘制，Shift 拖动矩形，右键取消。" % _terrain_label(terrain_id)

func _terrain_label(terrain_id: String) -> String:
	match terrain_id:
		"dirt":
			return "泥土地面"
		"stone":
			return "浅色石板"
		"water":
			return "水池"
		"grass":
			return "草地恢复"
		_:
			return terrain_id

func _select_category(category: String) -> void:
	if asset_scroll_row == null:
		return
	active_tab = "objects"
	selected_terrain_id = ""
	for child in asset_scroll_row.get_children():
		child.queue_free()
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
		var action_text: String = "选择素材后在草坪点击放置。"
		status_label.text = "当前分类：%s。%s" % [CATEGORY_LABELS.get(category, category), action_text]

func _select_asset(asset: Dictionary) -> void:
	active_tab = "objects"
	selected_asset = asset.duplicate(true)
	selected_tile.clear()
	selected_terrain_id = ""
	delete_mode = false
	_clear_delete_preview()
	_clear_tile_preview()
	_clear_terrain_preview()
	_update_preview_sprite()
	_update_preview()
	if status_label != null:
		status_label.text = "已选择：%s。左键放置，右键取消，删除键可切换删除模式。" % selected_asset.get("display_name", "素材")

func _select_tile(tile: Dictionary) -> void:
	selected_tile = tile.duplicate(true)
	selected_asset.clear()
	delete_mode = false
	_clear_delete_preview()
	_clear_preview()
	_update_tile_preview()
	if status_label != null:
		var verb: String = "擦除" if bool(selected_tile.get("erase", false)) else "铺设"
		status_label.text = "已选择：%s。左键%s瓦片，右键取消。" % [selected_tile.get("display_name", "瓦片"), verb]

func _toggle_delete_mode() -> void:
	delete_mode = not delete_mode
	selected_asset.clear()
	selected_tile.clear()
	selected_terrain_id = ""
	painting_active = false
	_clear_preview()
	_clear_tile_preview()
	_clear_terrain_preview()
	if delete_mode:
		_update_delete_preview()
	else:
		_clear_delete_preview()
	if status_label != null:
		status_label.text = "删除模式：悬停高亮，点击物件或地面瓦片删除。" if delete_mode else "删除模式已关闭。"

func _set_build_active(active: bool) -> void:
	build_active = active
	if toolbar != null:
		toolbar.visible = active
	if not active:
		delete_mode = false
		selected_asset.clear()
		selected_tile.clear()
		selected_terrain_id = ""
		painting_active = false
		_clear_preview()
		_clear_tile_preview()
		_clear_delete_preview()
		_clear_terrain_preview()
	if player != null and is_instance_valid(player) and player.has_method("set_movement_locked"):
		player.call("set_movement_locked", active)
	set_process(active)
	emit_signal("build_mode_changed", active)

func toggle_build_mode() -> void:
	_set_build_active(not build_active)

func is_build_mode_active() -> bool:
	return build_active

func _unhandled_input(event: InputEvent) -> void:
	if world == null:
		return
	if event.is_action_pressed("garden_build_toggle"):
		_set_build_active(not build_active)
		get_viewport().set_input_as_handled()
		return
	if not build_active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed:
		if event.keycode == KEY_Z:
			_undo_terrain()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_Y:
			_redo_terrain()
			get_viewport().set_input_as_handled()
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
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		if painting_active:
			_update_terrain_stroke(_world_to_cell(world.get_global_mouse_position()), motion_event.shift_pressed)
			get_viewport().set_input_as_handled()
			return
		_update_preview()
		_update_terrain_preview()
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_cancel_current_action()
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if selected_terrain_id != "" and active_tab == "terrain":
				var cell: Vector2i = _world_to_cell(world.get_global_mouse_position())
				if mouse_event.pressed:
					_begin_terrain_stroke(cell)
					_update_terrain_stroke(cell, mouse_event.shift_pressed)
				else:
					_finish_terrain_stroke()
				get_viewport().set_input_as_handled()
				return
			if mouse_event.pressed and _handle_left_click():
				get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if build_active and not selected_asset.is_empty():
		_update_preview()
	if build_active and not selected_tile.is_empty():
		_update_tile_preview()
	if build_active and delete_mode:
		_update_delete_preview()
	if build_active and selected_terrain_id != "" and not painting_active:
		_update_terrain_preview()

func _cancel_current_action() -> void:
	selected_asset.clear()
	selected_tile.clear()
	selected_terrain_id = ""
	delete_mode = false
	painting_active = false
	_clear_preview()
	_clear_tile_preview()
	_clear_delete_preview()
	_clear_terrain_preview()
	if status_label != null:
		status_label.text = "已取消。选择铺地材料或摆设商品继续布置花园。"

func _begin_terrain_stroke(cell: Vector2i) -> void:
	painting_active = true
	paint_start_cell = cell
	paint_last_cell = cell
	paint_before.clear()

func _update_terrain_stroke(cell: Vector2i, rectangular: bool) -> void:
	if selected_terrain_id == "":
		return
	if rectangular:
		_clear_terrain_preview()
		for paint_cell in _rect_cells(paint_start_cell, cell):
			_preview_terrain_cell(paint_cell, _can_paint_tile(paint_cell))
		return
	for paint_cell in _line_cells(paint_last_cell, cell):
		_apply_terrain_cell(paint_cell, selected_terrain_id, true)
	paint_last_cell = cell

func _finish_terrain_stroke() -> void:
	if not painting_active:
		return
	if Input.is_key_pressed(KEY_SHIFT):
		for paint_cell in _rect_cells(paint_start_cell, _world_to_cell(world.get_global_mouse_position())):
			_apply_terrain_cell(paint_cell, selected_terrain_id, true)
	painting_active = false
	_clear_terrain_preview()
	_push_terrain_command()
	_save_layout()

func _apply_terrain_cell(cell: Vector2i, terrain_id: String, track_undo: bool) -> void:
	if not _can_paint_tile(cell):
		return
	if track_undo and not paint_before.has(cell):
		paint_before[cell] = String(terrain_cells.get(cell, "grass"))
	if terrain_id == "grass":
		terrain_cells.erase(cell)
	else:
		terrain_cells[cell] = terrain_id
	_render_terrain_around(cell)

func _push_terrain_command() -> void:
	if paint_before.is_empty():
		return
	var before: Dictionary = {}
	var after: Dictionary = {}
	for raw_cell in paint_before.keys():
		var cell: Vector2i = raw_cell
		var old_id: String = String(paint_before[cell])
		var new_id: String = String(terrain_cells.get(cell, "grass"))
		if old_id == new_id:
			continue
		before[cell] = old_id
		after[cell] = new_id
	if before.is_empty():
		return
	undo_stack.append({"before": before, "after": after})
	redo_stack.clear()
	paint_before.clear()

func _undo_terrain() -> void:
	if undo_stack.is_empty():
		return
	var command: Dictionary = undo_stack.pop_back()
	_apply_terrain_snapshot(command.get("before", {}))
	redo_stack.append(command)
	_save_layout()

func _redo_terrain() -> void:
	if redo_stack.is_empty():
		return
	var command: Dictionary = redo_stack.pop_back()
	_apply_terrain_snapshot(command.get("after", {}))
	undo_stack.append(command)
	_save_layout()

func _apply_terrain_snapshot(snapshot: Dictionary) -> void:
	for raw_cell in snapshot.keys():
		var cell: Vector2i = raw_cell
		var terrain_id: String = String(snapshot[cell])
		if terrain_id == "grass":
			terrain_cells.erase(cell)
		else:
			terrain_cells[cell] = terrain_id
	for raw_cell in snapshot.keys():
		var cell: Vector2i = raw_cell
		_render_terrain_around(cell)

func _line_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dx: int = abs(to_cell.x - from_cell.x)
	var dy: int = abs(to_cell.y - from_cell.y)
	var steps: int = maxi(dx, dy)
	if steps == 0:
		return [from_cell]
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var cell: Vector2i = Vector2i(roundi(lerpf(float(from_cell.x), float(to_cell.x), t)), roundi(lerpf(float(from_cell.y), float(to_cell.y), t)))
		if not result.has(cell):
			result.append(cell)
	return result

func _rect_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			result.append(Vector2i(x, y))
	return result

func _update_terrain_preview() -> void:
	if selected_terrain_id == "" or terrain_preview_root == null or world == null:
		return
	_clear_terrain_preview()
	var cell: Vector2i = _world_to_cell(world.get_global_mouse_position())
	_preview_terrain_cell(cell, _can_paint_tile(cell))

func _preview_terrain_cell(cell: Vector2i, valid: bool) -> void:
	if terrain_preview_root == null:
		return
	var preview: Polygon2D = Polygon2D.new()
	preview.position = Vector2(float(cell.x * GRID_SIZE), float(cell.y * GRID_SIZE))
	preview.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(GRID_SIZE, 0),
		Vector2(GRID_SIZE, GRID_SIZE),
		Vector2(0, GRID_SIZE)
	])
	preview.color = Color(0.30, 0.95, 0.36, 0.34) if valid else Color(1.0, 0.18, 0.12, 0.34)
	terrain_preview_root.add_child(preview)

func _clear_terrain_preview() -> void:
	if terrain_preview_root == null:
		return
	for raw_child in terrain_preview_root.get_children():
		var child: Node = raw_child as Node
		if child != null:
			child.queue_free()

func _handle_left_click() -> bool:
	if delete_mode:
		var target: Node2D = _object_at_mouse()
		if target != null:
			_delete_object(target)
			_save_layout()
			return true
		var mouse_cell: Vector2i = _world_to_cell(world.get_global_mouse_position())
		if terrain_cells.has(mouse_cell):
			_apply_terrain_cell(mouse_cell, "grass", false)
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
	var display_scale: float = _asset_display_scale(selected_asset)
	preview_sprite.scale = Vector2(display_scale, display_scale)
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
	# 最高层级由预览根节点统一持有；子节点保持 0，避免超出 CanvasItem 的有效范围。
	preview_sprite.z_index = 0
	preview_valid = _can_place(selected_asset, preview_cell)
	preview_sprite.modulate = Color(0.50, 1.0, 0.50, 0.64) if preview_valid else Color(1.0, 0.28, 0.22, 0.58)

func _update_tile_preview() -> void:
	if selected_tile.is_empty() or preview_root == null or world == null:
		return
	if tile_preview == null or not is_instance_valid(tile_preview):
		tile_preview = Sprite2D.new()
		tile_preview.name = "TilePreview"
		tile_preview.centered = false
		tile_preview.scale = Vector2(2.0, 2.0)
		tile_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tile_preview.z_index = 0
		preview_root.add_child(tile_preview)
	tile_preview.texture = _make_tile_icon(selected_tile)
	var mouse_world: Vector2 = world.get_global_mouse_position()
	preview_cell = _world_to_cell(mouse_world)
	tile_preview.position = Vector2(float(preview_cell.x * GRID_SIZE), float(preview_cell.y * GRID_SIZE))
	preview_valid = _can_paint_tile(preview_cell)
	tile_preview.modulate = Color(0.50, 1.0, 0.55, 0.72) if preview_valid else Color(1.0, 0.24, 0.16, 0.58)

func _clear_tile_preview() -> void:
	if tile_preview != null and is_instance_valid(tile_preview):
		tile_preview.queue_free()
	tile_preview = null

func _update_delete_preview() -> void:
	if preview_root == null or world == null:
		return
	if delete_preview == null or not is_instance_valid(delete_preview):
		delete_preview = Polygon2D.new()
		delete_preview.name = "DeletePreview"
		delete_preview.z_index = 0
		delete_preview.color = Color(1.0, 0.18, 0.12, 0.34)
		preview_root.add_child(delete_preview)
	var target: Node2D = _object_at_mouse()
	if target != null:
		var asset_id: String = String(target.get_meta("asset_id", ""))
		var asset: Dictionary = assets_by_id.get(asset_id, {})
		if asset.is_empty():
			delete_preview.visible = false
			return
		var rect_pos: Vector2 = target.position + _sprite_offset(asset)
		var rect_size: Vector2 = _asset_display_size(asset)
		delete_preview.position = rect_pos
		delete_preview.polygon = PackedVector2Array([
			Vector2.ZERO,
			Vector2(rect_size.x, 0.0),
			rect_size,
			Vector2(0.0, rect_size.y)
		])
		delete_preview.visible = true
		return
	var mouse_cell: Vector2i = _world_to_cell(world.get_global_mouse_position())
	if terrain_cells.has(mouse_cell):
		delete_preview.position = Vector2(float(mouse_cell.x * GRID_SIZE), float(mouse_cell.y * GRID_SIZE))
		delete_preview.polygon = PackedVector2Array([
			Vector2.ZERO,
			Vector2(GRID_SIZE, 0),
			Vector2(GRID_SIZE, GRID_SIZE),
			Vector2(0, GRID_SIZE)
		])
		delete_preview.visible = true
		return
	delete_preview.visible = false

func _clear_delete_preview() -> void:
	if delete_preview != null and is_instance_valid(delete_preview):
		delete_preview.queue_free()
	delete_preview = null

func _place_asset(asset: Dictionary, cell: Vector2i, instance_id: String = "") -> Node2D:
	var id: String = instance_id
	if id == "":
		id = "%s_%d" % [asset.get("id", "garden_item"), Time.get_ticks_msec()]
	var node: Node2D = Node2D.new()
	node.name = "GardenItem_" + id
	node.position = _cell_to_anchor(cell, asset)
	node.z_as_relative = false
	node.z_index = _asset_z_index(asset, node.position)
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
	var display_scale: float = _asset_display_scale(asset)
	sprite.scale = Vector2(display_scale, display_scale)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.add_child(sprite)

	var collision_rect: Rect2 = _asset_collision_rect(asset)
	if collision_rect.size.x > 0.0 and collision_rect.size.y > 0.0:
		var body: StaticBody2D = StaticBody2D.new()
		body.name = "Collision"
		body.collision_layer = 1
		body.collision_mask = 0
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = collision_rect.size
		shape.shape = rect
		shape.position = collision_rect.position + collision_rect.size * 0.5
		body.add_child(shape)
		node.add_child(body)

	object_root.add_child(node)
	placed_objects[id] = node
	_mark_occupied(id, asset, cell)
	return node

func _asset_z_index(asset: Dictionary, anchor: Vector2) -> int:
	var placement_layer: String = String(asset.get("placement_layer", "prop")).to_lower()
	var z_rule: String = String(asset.get("z_rule", "")).to_lower()
	if placement_layer in ["ground", "ground_decor"] or z_rule == "ground_decor":
		return GROUND_DECOR_Z_INDEX
	if placement_layer in ["wall", "wall_object"] or z_rule == "wall":
		return WALL_OBJECT_Z_INDEX
	if placement_layer == "foreground" or z_rule == "foreground":
		return FOREGROUND_Z_INDEX
	return int(anchor.y)

func _asset_collision_rect(asset: Dictionary) -> Rect2:
	if not bool(asset.get("collision", true)) or bool(asset.get("walkable", false)):
		return Rect2()
	var configured: Variant = asset.get("collision_rect", null)
	if configured is Array:
		var configured_values: Array = configured
		if configured_values.size() < 4:
			return Rect2()
		var configured_rect: Rect2 = Rect2(
			Vector2(float(configured_values[0]), float(configured_values[1])),
			Vector2(maxf(0.0, float(configured_values[2])), maxf(0.0, float(configured_values[3])))
		)
		return configured_rect

	# 资产统一以底部中心为落点；兜底碰撞只覆盖实体底座，不阻挡透明区、叶片和高处装饰。
	var display_size: Vector2 = _asset_display_size(asset)
	var category: String = _normalize_category(String(asset.get("category", "decorations")))
	var width_ratio: float = 0.62
	var height_ratio: float = 0.24
	var max_height: float = 24.0
	match category:
		"flowerbeds":
			width_ratio = 0.82
			height_ratio = 0.28
			max_height = 30.0
		"plants":
			width_ratio = 0.34
			height_ratio = 0.18
			max_height = 18.0
		"pots":
			width_ratio = 0.58
			height_ratio = 0.22
			max_height = 20.0
		"furniture", "bridges":
			width_ratio = 0.80
			height_ratio = 0.32
			max_height = 32.0
		"tools":
			width_ratio = 0.50
			height_ratio = 0.18
			max_height = 16.0
	var collision_width: float = clampf(display_size.x * width_ratio, 12.0, display_size.x)
	var collision_height: float = clampf(display_size.y * height_ratio, 10.0, minf(max_height, display_size.y))
	return Rect2(Vector2(-collision_width * 0.5, -collision_height), Vector2(collision_width, collision_height))

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
		if not _asset_allows_surface(asset, _surface_for_cell(occupied_cell)):
			return false
	return true

func _can_paint_tile(cell: Vector2i) -> bool:
	var cell_rect: Rect2 = _cell_rect(cell)
	if not editable_rect.encloses(cell_rect):
		return false
	for blocked in blocked_rects:
		if blocked.intersects(cell_rect):
			return false
	if occupied_cells.has(cell):
		return false
	return true

func _surface_for_cell(cell: Vector2i) -> String:
	var terrain_id: String = String(terrain_cells.get(cell, "grass"))
	if terrain_id == "stone":
		return "stone_path"
	return terrain_id

func _asset_allows_surface(asset: Dictionary, surface: String) -> bool:
	var blocked_value: Variant = asset.get("blocked_surfaces", [])
	if blocked_value is Array:
		for raw_blocked in blocked_value:
			if String(raw_blocked) == surface:
				return false
	var allowed_value: Variant = asset.get("allowed_surfaces", [])
	if allowed_value is Array and not (allowed_value as Array).is_empty():
		for raw_allowed in allowed_value:
			if String(raw_allowed) == surface:
				return true
		return false
	return surface != "water"

func _render_terrain_around(cell: Vector2i) -> void:
	for affected in TerrainResolver.affected_cells(cell):
		_render_terrain_cell(affected)

func _render_terrain_cell(cell: Vector2i) -> void:
	if tile_layer == null:
		return
	var terrain_id: String = String(terrain_cells.get(cell, "grass"))
	if terrain_id == "grass":
		tile_layer.erase_cell(cell)
		if water_layer != null:
			water_layer.erase_cell(cell)
		return
	var resolved: Dictionary = TerrainResolver.resolve_cell(terrain_id, cell, terrain_cells)
	var atlas_value: Variant = resolved.get("atlas", Vector2i.ZERO)
	var atlas: Vector2i = atlas_value if atlas_value is Vector2i else Vector2i.ZERO
	var source_id: int = int(resolved.get("source_id", 0))
	if String(resolved.get("layer", "")) == "water":
		tile_layer.erase_cell(cell)
		if water_layer != null:
			water_layer.set_cell(cell, source_id, atlas, 0)
		return
	if water_layer != null:
		water_layer.erase_cell(cell)
	tile_layer.set_cell(cell, source_id, atlas, 0)

func _paint_tile(cell: Vector2i, tile: Dictionary) -> void:
	if tile_layer == null:
		return
	if bool(tile.get("erase", false)):
		_apply_terrain_cell(cell, "grass", false)
		return
	var source_id: int = int(tile.get("source_id", 0))
	var terrain_id: String = "stone" if source_id == 1 else "dirt"
	_apply_terrain_cell(cell, terrain_id, false)

func _erase_tile(cell: Vector2i) -> void:
	_apply_terrain_cell(cell, "grass", false)
	if status_label != null:
		status_label.text = "地面瓦片已删除。"

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
	var display_size: Vector2 = _asset_display_size(asset)
	return Vector2(-display_size.x * 0.5, -display_size.y)

func _asset_display_scale(asset: Dictionary) -> float:
	var category: String = _normalize_category(String(asset.get("category", "decorations")))
	return float(asset.get("display_scale", _display_scale_for_category(category)))

func _asset_display_size(asset: Dictionary) -> Vector2:
	var display_scale: float = _asset_display_scale(asset)
	return Vector2(float(asset.get("width", GRID_SIZE)) * display_scale, float(asset.get("height", GRID_SIZE)) * display_scale)

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
		var rect: Rect2 = Rect2(item.position + _sprite_offset(asset), _asset_display_size(asset))
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
	var terrain_by_type: Dictionary = {"dirt": [], "stone": [], "water": []}
	for raw_cell in terrain_cells.keys():
		var cell: Vector2i = raw_cell
		var terrain_id: String = String(terrain_cells[cell])
		if terrain_by_type.has(terrain_id):
			(terrain_by_type[terrain_id] as Array).append([cell.x, cell.y])
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"version": 3, "scene_id": "main_garden", "terrain_cells": terrain_by_type, "placed_objects": entries, "objects": entries}, "\t"))

func _load_layout() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	if parsed.has("terrain_cells"):
		_load_semantic_terrain(parsed.get("terrain_cells", {}))
	else:
		_migrate_legacy_tiles(parsed.get("tiles", []))
	for raw_entry in parsed.get("placed_objects", parsed.get("objects", [])):
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

func _load_semantic_terrain(raw_terrain: Variant) -> void:
	if not (raw_terrain is Dictionary):
		return
	var terrain_dict: Dictionary = raw_terrain
	for raw_terrain_id in ["dirt", "stone", "water"]:
		var terrain_id: String = String(raw_terrain_id)
		var cells_value: Variant = terrain_dict.get(terrain_id, [])
		if not (cells_value is Array):
			continue
		for raw_cell in cells_value:
			if not (raw_cell is Array) or raw_cell.size() < 2:
				continue
			var cell: Vector2i = Vector2i(int(raw_cell[0]), int(raw_cell[1]))
			if _can_paint_tile(cell):
				terrain_cells[cell] = terrain_id
	for raw_cell in terrain_cells.keys():
		var cell: Vector2i = raw_cell
		_render_terrain_around(cell)

func _migrate_legacy_tiles(raw_tiles: Variant) -> void:
	if not (raw_tiles is Array):
		return
	for raw_tile_entry in raw_tiles:
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
