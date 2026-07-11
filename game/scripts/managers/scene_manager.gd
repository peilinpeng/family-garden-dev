extends Node

## Family Garden 场景/UI 控制层（autoload 单例）。
## 持有 world/ui_layer 引用 + 全部场景构建、面板、植物、照片选择、场景切换。
## 由 main.gd 在 _ready 里 setup(world, ui_layer) 注入根节点；输入仍在 main.gd 处理。
## 从 main.gd 拆出，逻辑保持不变（增量 3 / feature/c-foundation）。

const GAME_SIZE := Vector2(1280, 720)
const ANNA_ROOM_SCENE := "res://scenes/rooms/AnnaRoom.tscn"  # 房间 .tscn 迁移样板（仅玩家房间）
const POND_AREA_SCENE := "res://scenes/pond/pond_area.tscn"
const FARM_SCENE := "res://scenes/Farm.tscn"
const DAY_NIGHT_CLOCK_UI_SCRIPT := preload("res://scripts/ui/day_night_clock_ui.gd")
const ROOM_SCENE_GENERATOR := preload("res://scripts/managers/room_scene_generator.gd")


const ASSETS := {
	"background": "res://assets/backgrounds/shared_garden.png",
	"travel_map": "res://assets/maps/travel_map.png",
	"globalmap_background": "res://assets/globalmap/background.png",
	"globalmap_farm": "res://assets/globalmap/farm.png",
	"globalmap_garden": "res://assets/globalmap/garden.png",
	"globalmap_house": "res://assets/globalmap/house.png",
	"globalmap_pond": "res://assets/globalmap/pond.png",
	"tree": "res://assets/garden/family_tree.png",
	"mailbox": "res://assets/garden/mailbox.png",
	"bench": "res://assets/garden/bench.png",
	"flower": "res://assets/garden/flower.png",
	"house_father": "res://assets/houses/house_father.png",
	"house_mother": "res://assets/houses/house_mother.png",
	"house_player": "res://assets/houses/house_player.png",
	"house_partner": "res://assets/houses/house_partner.png",
	"player": "res://assets/characters/girl.png",
	"father": "res://assets/characters/papa.png",
	"mother": "res://assets/characters/mama.png",
	"partner": "res://assets/characters/boy.png",
	"girl": "res://assets/characters/girl.png",
	"boy": "res://assets/characters/boy.png",
	"papa": "res://assets/characters/papa.png",
	"mama": "res://assets/characters/mama.png",
	"button_normal": "res://assets/ui/buttons/button_normal.png",
	"button_hover": "res://assets/ui/buttons/button_hover.png",
	"button_selected": "res://assets/ui/buttons/button_selected.png",
	"icon_map": "res://assets/ui/icons/icon_map.png",
	"icon_postcard": "res://assets/ui/icons/icon_postcard.png",
	"icon_mailbox": "res://assets/ui/icons/icon_mailbox.png",
	"icon_home": "res://assets/ui/icons/icon_home.png",
	"icon_tree": "res://assets/ui/icons/icon_tree.png",
	"icon_sign": "res://assets/ui/icons/icon_sign.png",
	"icon_save": "res://assets/ui/icons/icon_save.png",
	"icon_add": "res://assets/ui/icons/icon_add.png",
	"icon_delete": "res://assets/ui/icons/icon_delete.png",
	"icon_back": "res://assets/ui/icons/icon_back.png",
	"icon_close": "res://assets/ui/icons/icon_close.png",
	"icon_camera": "res://assets/ui/icons/icon_camera.png",
	"icon_letter": "res://assets/ui/icons/icon_letter.png",
	"icon_travel": "res://assets/ui/icons/icon_travel.png",
	"icon_pin": "res://assets/ui/icons/icon_pin.png",
	"mailbox_badge_dot": "res://assets/ui/badges/mailbox_badge_dot.png",
	"mailbox_badge_letter": "res://assets/ui/badges/mailbox_badge_letter.png",
	"pin_default": "res://assets/ui/pins/pin_default.png",
	"pin_saved": "res://assets/ui/pins/pin_saved.png",
	"pin_selected": "res://assets/ui/pins/pin_selected.png",
	"pin_new": "res://assets/ui/pins/pin_new.png",
	"pin_postcard": "res://assets/ui/pins/pin_postcard.png",
	"cat_sheet": "res://assets/animals/cat/cat_walk_sleep_sheet.png",
	"bird_sheet": "res://assets/animals/bird/bird_states_sheet.png",
	"dog_sheet": "res://assets/animals/dog/dog_states_sheet.png",
	"room_papa": "res://assets/rooms/papa_room.png",
	"room_mama": "res://assets/rooms/mama_room.png",
	"room_louis": "res://assets/rooms/louis_room.png",
	"room_anna": "res://assets/rooms/anna_room.png",
	"room_papa_fg": "res://assets/rooms/papa_room_fg.png",
	"room_mama_fg": "res://assets/rooms/mama_room_fg.png",
	"room_louis_fg": "res://assets/rooms/louis_room_fg.png",
	"room_anna_fg": "res://assets/rooms/anna_room_fg.png",
}

const HOUSE_DATA := [
	{"id": "father", "label": "爸爸的小屋", "asset": "house_father", "pos": Vector2(155, 124), "height": 180.0},
	{"id": "mother", "label": "妈妈的小屋", "asset": "house_mother", "pos": Vector2(1153, 145), "height": 230.0},
	{"id": "player", "label": "佩林的小屋", "asset": "house_player", "pos": Vector2(125, 600), "height": 180.0},
	{"id": "partner", "label": "路易的小屋", "asset": "house_partner", "pos": Vector2(126, 438), "height": 180.0},
]

const ROOM_DATA := {
	"father": {
		"label": "爸爸的房间",
		"asset": "room_papa",
		"foreground": "room_papa_fg",
		"spawn": Vector2(640, 575),
	},
	"mother": {
		"label": "妈妈的房间",
		"asset": "room_mama",
		"foreground": "room_mama_fg",
		"spawn": Vector2(640, 565),
	},
	"partner": {
		"label": "路易的房间",
		"asset": "room_louis",
		"foreground": "room_louis_fg",
		"spawn": Vector2(640, 560),
	},
	"player": {
		"label": "我的房间",
		"asset": "room_anna",
		"foreground": "room_anna_fg",
		"spawn": Vector2(640, 560),
	},
}

const CHARACTER_DATA := [
	{"role": "girl", "label": "女儿", "default_name": "佩林", "asset": "girl", "house_id": "player", "house_label": "佩林的小屋", "npc_pos": Vector2(700, 405), "wander_radius": 90.0},
	{"role": "boy", "label": "儿子", "default_name": "路易", "asset": "boy", "house_id": "partner", "house_label": "路易的小屋", "npc_pos": Vector2(805, 535), "wander_radius": 85.0},
	{"role": "papa", "label": "爸爸", "default_name": "爸爸", "asset": "papa", "house_id": "father", "house_label": "爸爸的小屋", "npc_pos": Vector2(765, 335), "wander_radius": 80.0},
	{"role": "mama", "label": "妈妈", "default_name": "妈妈", "asset": "mama", "house_id": "mother", "house_label": "妈妈的小屋", "npc_pos": Vector2(525, 365), "wander_radius": 80.0},
]

const ANIMAL_DATA := [
	{
		"id": "cat",
		"name": "Mimi",
		"asset": "cat_sheet",
		"pos": Vector2(250, 545),
		"height": 50.0,
		"hframes": 4,
		"vframes": 2,
		"wander_radius": 120.0,
		"move_speed": 15.0,
		"frames": {
			"idle": [0, 1],
			"walk": [0, 1, 2, 3],
			"sleep": [6, 7]
		}
	},
	{
		"id": "bird",
		"name": "Bluebird",
		"asset": "bird_sheet",
		"pos": Vector2(392, 142),
		"height": 42.0,
		"hframes": 3,
		"vframes": 2,
		"wander_radius": 75.0,
		"move_speed": 11.0,
		"frames": {
			"idle": [0, 1, 2],
			"walk": [0, 2, 5],
			"sleep": [3, 4]
		}
	},
	{
		"id": "dog",
		"name": "Biscuit",
		"asset": "dog_sheet",
		"pos": Vector2(330, 575),
		"height": 60.0,
		"hframes": 4,
		"vframes": 3,
		"wander_radius": 145.0,
		"move_speed": 17.0,
		"frames": {
			"idle": [0, 1],
			"walk": [2, 3, 4, 5],
			"sleep": [6, 7],
			"play": [8, 9, 10, 11]
		}
	},
]

var world: Node2D
var ui_layer: CanvasLayer
var ui_root: Control
var info_label: Label
var plant_button: Button
var world_chat_input: LineEdit = null
var world_chat_feed_panel: Panel = null
var world_chat_feed: Label = null
var world_chat_fade_tween: Tween = null
var plant_mode := false
var selected_plant_type := "tree"
var mode := "garden"
var player: CharacterBody2D
var plant_nodes: Dictionary = {}
var room_card: Panel = null
var gate4_guide_card: Panel = null
var mailbox_badge: Sprite2D = null
var active_modal: Control = null
var map_ui: Control = null
var global_map_ui: Control = null
var adding_place := false
var pending_place_position := Vector2.ZERO
var animal_nodes: Dictionary = {}
var cloud_load_finished: bool = false
var selected_photo_path: String = ""
var selected_photo_label: Label = null
var photo_file_dialog: FileDialog = null
var selected_photo_bytes: PackedByteArray = PackedByteArray()
var selected_photo_filename: String = ""
var selected_photo_content_type: String = ""
var selected_photo_from_web: bool = false
var web_photo_callback: Variant = null
var photo_texture_cache: Dictionary = {}
var active_ai_workflow: String = ""
var active_ai_status_label: Label = null
var _last_world_sync_toast_msec := -100000
var orientation_overlay: Control = null
var orientation_content: Control = null

func _load_cloud_data() -> void:
	if OS.has_environment("FAMILY_GARDEN_TEST"):
		cloud_load_finished = true
		return
	if CloudManager == null:
		return

	_show_toast("正在同步家庭花园...")
	var data: Dictionary = await CloudManager.load_family_data()
	MemoryManager.apply_cloud_data(data)
	cloud_load_finished = true
	MemoryManager.save_game()
	_refresh_world_chat_feed()

func _on_cloud_world_changed(event: Dictionary) -> void:
	var table := str(event.get("table", ""))
	_refresh_world_chat_feed(table == "messages")
	_refresh_visible_world_after_cloud(table)
	var now := Time.get_ticks_msec()
	if now - _last_world_sync_toast_msec < 2200:
		return
	_last_world_sync_toast_msec = now
	_show_toast(_cloud_world_toast(table))

func _refresh_visible_world_after_cloud(table: String) -> void:
	if table in ["memories", "nodes", "answers", "families"]:
		if mode == "garden":
			_refresh_current_memory_scene("garden")
		elif mode == "fishpond":
			_refresh_current_memory_scene("fishpond")
	if table in ["travel_places", "postcards", "mailbox_events"] and mode == "map":
		_show_travel_map()

func _cloud_world_toast(table: String) -> String:
	match table:
		"messages":
			return "家人的新留言已同步。"
		"travel_places", "postcards", "mailbox_events":
			return "家人的明信片已同步。"
		"inventories":
			return "共享仓已同步。"
		"farm_plots":
			return "家庭农场已同步。"
		"memories", "nodes", "answers", "families":
			return "家人的记忆已同步。"
		"rooms", "room_objects":
			return "家人的房间更新已同步。"
		_:
			return "家庭云端已同步。"


func setup(p_world: Node2D, p_ui_layer: CanvasLayer) -> void:
	world = p_world
	ui_layer = p_ui_layer
	MemoryManager.mailbox_alert_changed.connect(_on_mailbox_alert_changed)
	if CloudManager != null and CloudManager.has_signal("cloud_world_changed") \
		and not CloudManager.cloud_world_changed.is_connected(_on_cloud_world_changed):
		CloudManager.cloud_world_changed.connect(_on_cloud_world_changed)
	if not AIWorkflowManager.workflow_state_changed.is_connected(_on_ai_workflow_state_changed):
		AIWorkflowManager.workflow_state_changed.connect(_on_ai_workflow_state_changed)
	_build_ui()
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_update_viewport_layout):
		viewport.size_changed.connect(_update_viewport_layout)
	_update_viewport_layout()

func _build_ui() -> void:
	var root := Control.new()
	ui_root = root
	root.name = "UIRoot"
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = GAME_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	var day_night_clock := TextureRect.new()
	day_night_clock.name = "DayNightClock"
	day_night_clock.set_script(DAY_NIGHT_CLOCK_UI_SCRIPT)
	day_night_clock.position = Vector2(GAME_SIZE.x - 110, 12)
	day_night_clock.size = Vector2(112, 124)
	day_night_clock.scale = Vector2(0.78, 0.78)
	day_night_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(day_night_clock)

	info_label = Label.new()
	info_label.visible = false
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.text = "家庭花园"
	root.add_child(info_label)

	var dock := Panel.new()
	dock.name = "GardenNavigationDock"
	dock.position = Vector2(160, 666)
	dock.size = Vector2(960, 46)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_theme_stylebox_override("panel", _navigation_dock_style())
	root.add_child(dock)
	var nav_items := [
		["记忆", "create_memory", 100],
		["世界", "global_map", 94],
		["家谱", "family_tree", 94],
		["旅行", "travel_map", 94],
		["明信片", "MemoryManager.postcards", 110],
		["聊天", "world_chat_history", 94],
		["家人", "family_members", 94],
	]
	var nav_width := 0.0
	for item in nav_items:
		nav_width += float(item[2])
	nav_width += float(nav_items.size() - 1) * 8.0
	var nav_x := (dock.size.x - nav_width) * 0.5
	for item in nav_items:
		var nav_button := _add_button(dock, String(item[0]), Vector2(nav_x, 7), Vector2(float(item[2]), 32), String(item[1]))
		if String(item[1]) == "create_memory":
			_apply_button_style(nav_button, true)
		nav_x += float(item[2]) + 8.0
	_add_world_chat_feed(root, Vector2(428, 598), Vector2(424, 58))
	_refresh_world_chat_feed()
	_build_orientation_overlay(root)

func _navigation_dock_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.95, 0.82, 0.92)
	style.border_color = Color(0.43, 0.34, 0.23, 0.78)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.16, 0.11, 0.07, 0.20)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	return style

func _build_orientation_overlay(root: Control) -> void:
	orientation_overlay = Control.new()
	orientation_overlay.name = "PortraitOrientationOverlay"
	orientation_overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	orientation_overlay.size = GAME_SIZE
	orientation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	orientation_overlay.z_index = 4090
	root.add_child(orientation_overlay)

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.10, 0.17, 0.14, 0.98)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orientation_overlay.add_child(background)

	var content := VBoxContainer.new()
	orientation_content = content
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.position = Vector2(-260, -155)
	content.size = Vector2(520, 310)
	content.pivot_offset = content.size * 0.5
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	orientation_overlay.add_child(content)

	var brand := Label.new()
	brand.text = "FAMILY GARDEN · 家庭花园"
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_font_size_override("font_size", 22)
	brand.add_theme_color_override("font_color", Color(0.78, 0.88, 0.72, 0.92))
	content.add_child(brand)

	var rotate_icon := Label.new()
	rotate_icon.text = "↻"
	rotate_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_icon.add_theme_font_size_override("font_size", 72)
	rotate_icon.add_theme_color_override("font_color", Color(0.96, 0.87, 0.62, 1.0))
	content.add_child(rotate_icon)

	var title := Label.new()
	title.text = "请旋转手机"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88, 1.0))
	content.add_child(title)

	var hint := Label.new()
	hint.text = "横屏进入 Family Garden"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.78, 0.84, 0.78, 0.90))
	content.add_child(hint)

func _update_orientation_overlay() -> void:
	if orientation_overlay == null or not is_instance_valid(orientation_overlay):
		return
	var portrait := _is_portrait_size(get_viewport().get_visible_rect().size)
	orientation_overlay.visible = portrait
	if portrait and orientation_content != null and is_instance_valid(orientation_content):
		orientation_content.scale = Vector2(2.0, 2.0)

func _update_viewport_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var frame_margin := Vector2(
		maxf(0.0, (viewport_size.x - GAME_SIZE.x) * 0.5),
		maxf(0.0, (viewport_size.y - GAME_SIZE.y) * 0.5)
	)
	if world != null and is_instance_valid(world):
		world.position = frame_margin
	if ui_root != null and is_instance_valid(ui_root):
		ui_root.position = frame_margin
	if orientation_overlay != null and is_instance_valid(orientation_overlay):
		orientation_overlay.position = -frame_margin
		orientation_overlay.size = viewport_size
	_update_orientation_overlay()

func _is_portrait_size(viewport_size: Vector2) -> bool:
	return viewport_size.y > viewport_size.x

func _add_button(root: Control, button_text: String, pos: Vector2, button_size: Vector2, action: String) -> Button:
	var button := Button.new()
	button.text = button_text
	button.position = pos
	button.size = button_size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(_on_ui_button.bind(action))
	_apply_button_style(button, action == "toggle_plant" and plant_mode)
	_set_button_icon(button, _icon_key_for_action(action))
	root.add_child(button)
	return button

func _add_world_chat_box(root: Control, pos: Vector2, box_size: Vector2) -> LineEdit:
	var chat := LineEdit.new()
	chat.name = "WorldChatInput"
	chat.placeholder_text = "给家人留一句话..."
	chat.position = pos
	chat.size = box_size
	chat.mouse_filter = Control.MOUSE_FILTER_STOP
	chat.clear_button_enabled = true
	chat.add_theme_font_size_override("font_size", 13)
	chat.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16, 1.0))
	chat.add_theme_color_override("font_placeholder_color", Color(0.38, 0.31, 0.24, 0.68))
	var normal_style := _world_chat_input_style(false)
	var focus_style := _world_chat_input_style(true)
	chat.add_theme_stylebox_override("normal", normal_style)
	chat.add_theme_stylebox_override("focus", focus_style)
	chat.add_theme_stylebox_override("read_only", normal_style)
	chat.text_submitted.connect(_on_world_chat_submitted)
	root.add_child(chat)
	return chat

func _clear_gate4_guide() -> void:
	if gate4_guide_card != null and is_instance_valid(gate4_guide_card):
		gate4_guide_card.queue_free()
	gate4_guide_card = null

func _show_gate4_scene_guide(scene_id: String) -> void:
	_clear_gate4_guide()
	var panel := Panel.new()
	panel.name = "Gate4SceneGuide"
	gate4_guide_card = panel
	panel.position = Vector2(1012, 122) if scene_id == "room" else Vector2(20, 20)
	panel.size = Vector2(248, 92)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_guide_card_style(panel)
	if ui_root != null and is_instance_valid(ui_root):
		ui_root.add_child(panel)
	else:
		ui_layer.add_child(panel)

	var accent := ColorRect.new()
	accent.position = Vector2(12, 12)
	accent.size = Vector2(4, 68)
	accent.color = _gate4_guide_accent(scene_id)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent)

	var title := Label.new()
	title.text = _gate4_guide_title(scene_id)
	title.position = Vector2(28, 10)
	title.size = Vector2(202, 22)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.21, 0.18, 0.13, 0.96))
	panel.add_child(title)

	var body := Label.new()
	body.text = _gate4_guide_body(scene_id)
	body.position = Vector2(28, 36)
	body.size = Vector2(202, 40)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.33, 0.28, 0.21, 0.90))
	panel.add_child(body)


func _apply_guide_card_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.96, 0.84, 0.82)
	style.border_color = Color(0.54, 0.42, 0.28, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.15, 0.10, 0.06, 0.16)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", style)

func _gate4_guide_accent(scene_id: String) -> Color:
	match scene_id:
		"fishpond":
			return Color(0.35, 0.64, 0.72, 0.92)
		"room":
			return Color(0.72, 0.52, 0.34, 0.92)
		_:
			return Color(0.48, 0.68, 0.40, 0.92)

func _gate4_guide_title(scene_id: String) -> String:
	match scene_id:
		"fishpond":
			return "鱼塘今日"
		"room":
			return "我的 AI 房间"
		_:
			return "花园今日"

func _gate4_guide_body(scene_id: String) -> String:
	match scene_id:
		"fishpond":
			return "%d 只漂流瓶 · %d 段岸边记忆\n%d 根记忆藤蔓可回看" % [
				_demo_bottles.size(),
				_fishpond_memories.size(),
				MemoryManager.get_memory_links("fishpond").size(),
			]
		"room":
			var room := MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
			var object_count := 0 if room.is_empty() else MemoryManager.get_room_objects(String(room.get("id", ""))).size()
			return "%s\n%d 件 AI 摆放的物件" % [
				_room_theme_display_label(String(room.get("room_name", "还没有生成房间"))) if not room.is_empty() else "等待一张房间照片",
				object_count,
			]
		_:
			return "%d 段记忆 · %d 条藤蔓\n%d 位家人共同照料" % [
				_demo_memories.size(),
				MemoryManager.get_memory_links("garden").size(),
				int(MemoryManager.family_portrait.get("member_count", 0)),
			]

func _gate4_guide_footer(scene_id: String) -> String:
	match scene_id:
		"fishpond":
			return "水面会先醒来，问题随后抵达"
		"room":
			return "确认前只是预览，确认后才落入房间"
		_:
			return "发光的记忆和藤蔓都可以点击"

func _world_chat_input_style(focused: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.96, 0.86, 0.94) if focused else Color(1.0, 0.94, 0.82, 0.90)
	style.border_color = Color(0.56, 0.42, 0.27, 0.95) if focused else Color(0.60, 0.48, 0.33, 0.86)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _add_world_chat_feed(root: Control, pos: Vector2, feed_size: Vector2) -> Label:
	var panel := Panel.new()
	panel.name = "WorldChatPreview"
	panel.position = pos
	panel.size = feed_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0
	panel.visible = false
	panel.gui_input.connect(_on_world_chat_preview_input)
	panel.add_theme_stylebox_override("panel", _world_chat_preview_style())
	root.add_child(panel)
	world_chat_feed_panel = panel

	var feed := Label.new()
	feed.name = "WorldChatFeed"
	feed.position = Vector2(12, 8)
	feed.size = feed_size - Vector2(24, 14)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feed.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	feed.add_theme_font_size_override("font_size", 12)
	feed.add_theme_color_override("font_color", Color(0.24, 0.20, 0.15, 0.90))
	panel.add_child(feed)
	world_chat_feed = feed
	return feed

func _world_chat_preview_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.94, 0.78, 0.78)
	style.border_color = Color(0.52, 0.36, 0.20, 0.72)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _on_world_chat_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_open_world_chat_history_panel()

func _on_world_chat_submitted(submitted_text: String) -> void:
	var text := submitted_text.strip_edges()
	if text == "":
		return
	_send_world_chat_message(text)

func _send_world_chat_message(text: String) -> void:
	if world_chat_input != null and is_instance_valid(world_chat_input):
		world_chat_input.editable = false
		world_chat_input.text = ""
		world_chat_input.placeholder_text = "正在发送..."

	var author := _get_world_chat_author()
	var message_id := "message_" + str(Time.get_ticks_msec())
	if CloudManager != null:
		var cloud_message: Dictionary = await CloudManager.create_message(author, text, "")
		if not cloud_message.is_empty() and str(cloud_message.get("id", "")) != "":
			message_id = str(cloud_message.get("id", ""))

	var message := {
		"id": message_id,
		"author": author,
		"text": text,
		"created_at": Time.get_datetime_string_from_system(),
		"role": MemoryManager.selected_role_key
	}
	MemoryManager.garden_messages.append(message)
	MemoryManager.notify_family_activity()
	MemoryManager.save_game()
	_refresh_world_chat_feed(true)

	if world_chat_input != null and is_instance_valid(world_chat_input):
		world_chat_input.editable = true
		world_chat_input.placeholder_text = "给家人留一句话..."
		world_chat_input.grab_focus()
	_show_toast("留言已发送。")

func _get_world_chat_author() -> String:
	if GameIdentity != null and GameIdentity.is_ready() and str(GameIdentity.display_name).strip_edges() != "":
		return str(GameIdentity.display_name).strip_edges()
	if str(MemoryManager.player_display_name).strip_edges() != "":
		return str(MemoryManager.player_display_name).strip_edges()
	var role := str(MemoryManager.selected_role_key).strip_edges()
	if role != "":
		for character in CHARACTER_DATA:
			if str(character.get("role", "")) == role:
				return str(character.get("default_name", "家人"))
	return "家人"

func _refresh_world_chat_feed(show_preview: bool = false) -> void:
	if world_chat_feed == null or not is_instance_valid(world_chat_feed):
		return
	var recent: Array[String] = []
	var start_index := MemoryManager.garden_messages.size() - 3
	if start_index < 0:
		start_index = 0
	for i in range(start_index, MemoryManager.garden_messages.size()):
		var raw_message: Variant = MemoryManager.garden_messages[i]
		if not (raw_message is Dictionary):
			continue
		var message: Dictionary = raw_message
		var author := str(message.get("author", "家人"))
		var text := str(message.get("text", "")).strip_edges()
		if text == "":
			continue
		recent.append(author + ": " + text)
	world_chat_feed.text = "\n".join(recent)
	if show_preview and not recent.is_empty():
		_show_world_chat_preview()

func _show_world_chat_preview() -> void:
	if world_chat_feed_panel == null or not is_instance_valid(world_chat_feed_panel):
		return
	if world_chat_fade_tween != null and world_chat_fade_tween.is_valid():
		world_chat_fade_tween.kill()
	world_chat_feed_panel.visible = true
	world_chat_feed_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	world_chat_feed_panel.modulate.a = 1.0
	world_chat_fade_tween = create_tween()
	world_chat_fade_tween.tween_interval(5.0)
	world_chat_fade_tween.tween_property(world_chat_feed_panel, "modulate:a", 0.0, 1.2)
	world_chat_fade_tween.tween_callback(func() -> void:
		if world_chat_feed_panel != null and is_instance_valid(world_chat_feed_panel):
			world_chat_feed_panel.visible = false
			world_chat_feed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)

func _open_world_chat_history_panel() -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay

	var panel := Panel.new()
	panel.position = Vector2(360, 96)
	panel.size = Vector2(560, 520)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = "家庭聊天"
	title.position = Vector2(34, 24)
	title.size = Vector2(470, 30)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(34, 70)
	scroll.size = Vector2(492, 314)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	if MemoryManager.garden_messages.is_empty():
		var empty_label := Label.new()
		empty_label.text = "还没有留言。"
		empty_label.custom_minimum_size = Vector2(460, 48)
		empty_label.add_theme_font_size_override("font_size", 15)
		empty_label.add_theme_color_override("font_color", Color(0.34, 0.28, 0.22, 0.88))
		list.add_child(empty_label)
	else:
		for i in range(MemoryManager.garden_messages.size() - 1, -1, -1):
			var raw_message: Variant = MemoryManager.garden_messages[i]
			if raw_message is Dictionary:
				list.add_child(_make_world_chat_history_card(raw_message))

	world_chat_input = _add_world_chat_box(panel, Vector2(34, 400), Vector2(382, 38))
	var send := Button.new()
	send.text = "发送"
	send.position = Vector2(428, 400)
	send.size = Vector2(98, 38)
	send.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_style(send, true)
	_set_button_icon(send, "icon_letter")
	send.pressed.connect(func() -> void:
		if world_chat_input != null and is_instance_valid(world_chat_input):
			_on_world_chat_submitted(world_chat_input.text))
	panel.add_child(send)
	_add_panel_button(panel, "关闭", Vector2(218, 456), Vector2(124, 38), "close")

func _make_world_chat_history_card(message: Dictionary) -> Control:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(470, 78)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.95, 0.82, 0.82)
	style.border_color = Color(0.62, 0.48, 0.32, 0.70)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", style)

	var meta := Label.new()
	meta.text = str(message.get("author", "家人")) + "  |  " + _format_world_chat_time(str(message.get("created_at", "")))
	meta.position = Vector2(14, 10)
	meta.size = Vector2(442, 20)
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", Color(0.38, 0.31, 0.24, 0.86))
	card.add_child(meta)

	var body := Label.new()
	body.text = str(message.get("text", ""))
	body.position = Vector2(14, 32)
	body.size = Vector2(442, 38)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	card.add_child(body)
	return card

func _format_world_chat_time(raw_time: String) -> String:
	if raw_time == "":
		return "未记录时间"
	return raw_time.replace("T", " ").replace("Z", "")

func _on_ui_button(action: String) -> void:
	match action:
		"family_tree":
			_open_family_tree_panel()
		"family_members":
			_open_family_members_panel()
		"message_board":
			_open_message_board_panel()
		"role_select":
			_show_role_select()
		"toggle_plant":
			plant_mode = not plant_mode
			_update_plant_button()
		"global_map":
			_show_global_map()
		"travel_map":
			_show_travel_map()
		"MemoryManager.postcards":
			_open_postcards_panel()
		"world_chat_history":
			_open_world_chat_history_panel()
		"create_memory":
			_open_memory_creator()
		"save":
			MemoryManager.save_game()
			_show_toast("已保存。")
		"back_garden":
			_show_garden()
		"reset":
			_show_toast("线上版本已关闭重置。")

func _show_role_select() -> void:
	_close_active_panel()
	_clear_map_ui()
	_clear_world()
	mode = "role_select"
	info_label.text = "选择角色"
	_add_background()

	var overlay := _create_modal_overlay()
	active_modal = overlay

	var panel := Panel.new()
	panel.position = Vector2(150, 82)
	panel.size = Vector2(980, 550)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = "Family Garden · 家庭花园"
	title.position = Vector2(40, 28)
	title.size = Vector2(900, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "选择你的身份，和家人一起进入同一座花园。"
	subtitle.position = Vector2(70, 72)
	subtitle.size = Vector2(840, 28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.35, 0.29, 0.22, 0.88))
	panel.add_child(subtitle)

	var name_label := Label.new()
	name_label.text = "显示名字"
	name_label.position = Vector2(360, 112)
	name_label.size = Vector2(260, 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(name_label)

	var name_input := LineEdit.new()
	name_input.placeholder_text = "输入你的名字"
	name_input.text = MemoryManager.player_display_name if MemoryManager.player_display_name != "" else "佩林"
	name_input.position = Vector2(350, 140)
	name_input.size = Vector2(280, 38)
	panel.add_child(name_input)

	var family_label := Label.new()
	family_label.text = "家庭邀请码"
	family_label.position = Vector2(650, 112)
	family_label.size = Vector2(230, 22)
	family_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	family_label.add_theme_font_size_override("font_size", 15)
	family_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(family_label)

	var family_input := LineEdit.new()
	family_input.placeholder_text = "输入家庭邀请码"
	family_input.text = CloudManager.family_code() if CloudManager != null and CloudManager.has_method("family_code") else ""
	family_input.position = Vector2(630, 140)
	family_input.size = Vector2(270, 38)
	panel.add_child(family_input)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(75, 205)
	grid.size = Vector2(830, 300)
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 18)
	panel.add_child(grid)

	for i in range(CHARACTER_DATA.size()):
		var role_data: Dictionary = CHARACTER_DATA[i]
		_add_role_card(grid, role_data, Vector2.ZERO, Vector2(185, 260), name_input, family_input)

func _add_role_card(parent: Control, role_data: Dictionary, pos: Vector2, card_size: Vector2, name_input: LineEdit, family_input: LineEdit) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# If parent is an absolute-positioned panel, keep compatibility with the old pos argument.
	# If parent is a GridContainer, the container will ignore position and lay the card out cleanly.
	if parent is GridContainer:
		pass
	else:
		card.position = pos
		card.size = card_size

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(1.0, 0.94, 0.80, 0.96)
	card_style.border_color = Color(0.62, 0.44, 0.25, 1.0)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(14)
	card_style.shadow_color = Color(0.20, 0.12, 0.06, 0.20)
	card_style.shadow_size = 7
	card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 7)
	margin.add_child(vbox)

	var texture := _safe_texture(str(ASSETS.get(str(role_data.get("asset", "girl")), "")))
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(112, 118)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if texture:
		preview.texture = _make_character_preview_texture(texture)
	vbox.add_child(preview)

	var label := Label.new()
	label.text = str(role_data.get("label", "家人"))
	label.custom_minimum_size = Vector2(card_size.x - 34, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.25, 0.20, 0.15, 1.0))
	vbox.add_child(label)

	var default_name := Label.new()
	default_name.text = str(role_data.get("default_name", "家人"))
	default_name.custom_minimum_size = Vector2(card_size.x - 34, 20)
	default_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	default_name.add_theme_font_size_override("font_size", 13)
	default_name.add_theme_color_override("font_color", Color(0.42, 0.34, 0.25, 0.86))
	vbox.add_child(default_name)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 4)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var choose_btn := Button.new()
	choose_btn.text = "选择"
	choose_btn.custom_minimum_size = Vector2(112, 32)
	choose_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	choose_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_style(choose_btn, false)
	choose_btn.pressed.connect(_confirm_role_selection.bind(str(role_data.get("role", "girl")), name_input, family_input))
	vbox.add_child(choose_btn)

func _make_character_preview_texture(source: Texture2D) -> Texture2D:
	var atlas := AtlasTexture.new()
	var frame_w: float = float(source.get_width()) / 3.0
	var frame_h: float = float(source.get_height()) / 4.0
	atlas.atlas = source
	atlas.region = Rect2(Vector2(frame_w, 0.0), Vector2(frame_w, frame_h))
	return atlas


func _confirm_role_selection(role_key: String, name_input: LineEdit, family_input: LineEdit = null) -> void:
	MemoryManager.selected_role_key = role_key
	MemoryManager.player_display_name = name_input.text.strip_edges()
	if MemoryManager.player_display_name == "":
		MemoryManager.player_display_name = _default_name_for_role(role_key)
	MemoryManager.save_game()
	_close_active_panel()
	_show_garden()
	# 首次选角色时,若配置了 CloudBase 且本设备还没自助加入过,后台自动注册云身份
	# (不阻塞进花园;角色别名如 girl/papa 转成 CharacterDB 的规范值 player/father 再传)。
	var canonical_role: String = CharacterDB.resolve(role_key)
	var family_code := family_input.text.strip_edges() if family_input != null else ""
	CloudManager.ensure_cloud_identity(canonical_role, MemoryManager.player_display_name, family_code)


func _default_name_for_role(role_key: String) -> String:
	var role_data := _get_role_data(role_key)
	if role_data.is_empty():
		return "家人"
	return str(role_data.get("default_name", "家人"))


func _get_role_data(role_key: String) -> Dictionary:
	for role_data in CHARACTER_DATA:
		if str(role_data.get("role", "")) == role_key:
			return role_data
	return {}


func _current_player_asset_key() -> String:
	var role_data := _get_role_data(MemoryManager.selected_role_key)
	if role_data.is_empty():
		return "girl"
	return str(role_data.get("asset", "girl"))


func _update_plant_button() -> void:
	if plant_button:
		plant_button.text = "种植：开启" if plant_mode else "种植：关闭"
		_apply_button_style(plant_button, plant_mode)

func _show_garden(spawn_key: String = "default") -> void:
	_close_active_panel()
	_clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	_clear_gate4_guide()
	mode = "garden"
	adding_place = false
	_clear_world()
	info_label.text = "家庭花园"
	AudioManager.play_music("garden")
	_add_background()
	_add_collision_zones()
	_add_garden_spawn_markers()
	_add_houses()
	_add_core_objects()
	_add_npcs()
	_add_animals()
	var spawn: Vector2 = ScenePortal.get_spawn("garden", spawn_key)
	_add_player(spawn)
	_rebuild_plants()
	_spawn_demo_memory_nodes()
	MemoryManager.maybe_recompute_family_portrait()  # 进花园按当前成员/记忆数算一版画像
	_render_family_portrait()                         # 挂到入口木牌
	ScenePortal.build_portals("garden", world, _on_portal_travel)
	_show_gate4_scene_guide("garden")

# 场景层只负责渲染和交互；AI 生成、草稿确认和持久化由 AIClient / AIWorkflowManager / MemoryManager 处理。
# 这里缓存当前场景已渲染的节点 view model，离场后可由数据层重建。
var _demo_memories: Array = []

# 鱼塘漂流瓶当前场景 view model；已保存问题来自 MemoryManager，缺口由 AIWorkflowManager 后台补齐。
var _demo_bottles: Array = []
# 鱼塘岸边记忆缓存（回答漂流瓶后生成、已落库持久化）。结构同 _demo_memories。
var _fishpond_memories: Array = []
# 玩家房间已渲染的家具节点缓存（每项 { id(obj_id), object_type, node }）。
var _room_objects: Array = []

# 切场景防抖锁（docs/09 §14：切换期间锁输入 0.3–0.5s，防重复触发）。
var _travel_lock := false

# 其他家庭成员的 role key（≠当前玩家），用于把种子记忆归属给别人 → 玩家回答即跨成员互动。
func _demo_other_members() -> Array:
	var others: Array = []
	for role_data in CHARACTER_DATA:
		var rk := String(role_data.get("role", ""))
		if rk != "" and rk != MemoryManager.selected_role_key:
			others.append(rk)
	return others

func _spawn_demo_memory_nodes() -> void:
	_demo_memories.clear()
	SlotManager.load_scene("garden")
	# 兼容空存档：首次进入花园时写入 3 条演示种子记忆；之后统一从数据层渲染。
	if MemoryManager.get_nodes_for_scene("garden").is_empty():
		# 种子记忆归属给其他家庭成员（≠当前玩家），这样玩家回答它们才算"跨成员互动"，分季背景才会随之升温。
		var uploaders := _demo_other_members()
		for i in range(3):
			var slot: Variant = SlotManager.allocate("garden", "memory_flower", "garden_seed_%d" % i)
			if slot == null:
				break
			var mem := MemoryManager.create_memory(AIClient.mock_memory_card(), "photo")
			if not uploaders.is_empty():
				mem["user_id"] = uploaders[i % uploaders.size()]  # 改上传者为别的成员
			MemoryManager.create_node(String(mem.get("id", "")), "garden", "memory_flower", String(slot.get("slot_id", "")))
		MemoryManager.save_game()  # 落盘改过的 user_id
	# 统一从数据层渲染（首次/再次进入一致）。
	_render_scene_nodes("garden", _demo_memories, _on_memory_clicked)
	_spawn_demo_memory_link()       # 空存档演示种子没有真实关联时补一条藤蔓
	_render_memory_links("garden")  # 画连线
	print("[SceneManager] garden 记忆花 rendered=", _demo_memories.size(), " 连线=", MemoryManager.get_memory_links("garden").size())

# 兼容演示种子：没有任何关联时补一条演示藤蔓；真实新记忆的关联由 AIWorkflowManager 增量创建。
func _spawn_demo_memory_link() -> void:
	if not MemoryManager.get_memory_links("garden").is_empty():
		return
	if _demo_memories.size() < 2:
		return
	var a := String(_demo_memories[0].get("memory_id", ""))
	var b := String(_demo_memories[-1].get("memory_id", ""))  # 连最分散的一对，连线更清晰
	if a == "" or b == "" or a == b:
		return
	var link: Dictionary = AIClient.mock_link()  # 仅用于空存档演示种子；真实 link 已由 Gate 4 工作流生成。
	MemoryManager.create_memory_link(a, b, "garden",
		String(link.get("relation_type", "same_place")), String(link.get("question", "")))

# 画花园里所有记忆连线：两端取各自记忆花的落点，连一条藤蔓线 + 可点的关联问题。
func _render_memory_links(scene: String) -> void:
	for link in MemoryManager.get_memory_links(scene):
		var a := _memory_flower_pos(scene, String(link.get("memory_id", "")))
		var b := _memory_flower_pos(scene, String(link.get("linked_memory_id", "")))
		if a == Vector2.INF or b == Vector2.INF:
			continue
		_draw_link_line(a, b, link)

# 家庭画像落在右下角场景内的公告板上，不遮挡家庭树与人物。
func _render_family_portrait() -> void:
	if world == null or not is_instance_valid(world):
		return
	var existing := world.get_node_or_null("FamilyPortraitBoard")
	if existing != null:
		existing.queue_free()
	var fp: Dictionary = MemoryManager.family_portrait
	if int(fp.get("version", 0)) <= 0:
		return  # 还没有画像（无人参与）
	var board := Node2D.new()
	board.name = "FamilyPortraitBoard"
	board.position = Vector2(1174, 606)
	board.z_index = 610
	var panel := Panel.new()
	panel.position = Vector2(-58, -34)
	panel.size = Vector2(116, 68)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(1.0, 0.95, 0.80, 0.78)
	panel_style.border_color = Color(0.48, 0.34, 0.20, 0.76)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", panel_style)
	board.add_child(panel)
	var title := Label.new()
	title.text = "家庭画像"
	title.position = Vector2(10, 8)
	title.size = Vector2(96, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.25, 0.19, 0.13, 0.94))
	panel.add_child(title)
	var summary := Label.new()
	summary.text = "%d 位家人 · %d 段记忆" % [int(fp.get("member_count", 0)), int(fp.get("memory_count", 0))]
	summary.position = Vector2(8, 34)
	summary.size = Vector2(100, 18)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_theme_font_size_override("font_size", 10)
	summary.add_theme_color_override("font_color", Color(0.36, 0.28, 0.19, 0.86))
	panel.add_child(summary)
	var area := Area2D.new()
	area.name = "FamilyPortraitHotspot"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(124, 76)
	shape.shape = rect
	area.add_child(shape)
	area.mouse_entered.connect(func() -> void: panel.modulate = Color(1.05, 1.03, 0.96, 1.0))
	area.mouse_exited.connect(func() -> void: panel.modulate = Color.WHITE)
	area.input_event.connect(func(_v: Node, e: InputEvent, _s: int) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_show_toast("%d 位家人共同留下了 %d 段记忆。" % [int(fp.get("member_count", 0)), int(fp.get("memory_count", 0))]))
	board.add_child(area)
	world.add_child(board)

# 取某条记忆在该场景的记忆花落点（slot.pos）；找不到返回 Vector2.INF。
func _memory_flower_pos(scene: String, memory_id: String) -> Vector2:
	for nd in MemoryManager.get_nodes_for_scene(scene):
		if String(nd.get("memory_id", "")) == memory_id and String(nd.get("node_type", "")) == "memory_flower":
			var slot := SlotManager.get_slot(scene, String(nd.get("slot_id", "")))
			if not slot.is_empty():
				var p: Variant = slot.get("pos", null)
				if p is Array and (p as Array).size() >= 2:
					return Vector2(float(p[0]), float(p[1]))
	return Vector2.INF

# 一条连线：两花之间拱起的藤蔓线（盖在记忆花之上，避免被花遮住）+ 中点可点的关联详情。
func _draw_link_line(a: Vector2, b: Vector2, link: Dictionary) -> void:
	var head := Vector2(0, -72)
	var arc := ((a + b) * 0.5 + head) + Vector2(0, -18)
	var relation_type := String(link.get("relation_type", "same_theme"))
	var link_color := _memory_link_color(relation_type)
	var link_label := _memory_link_label(relation_type)
	var confidence := float(link.get("confidence", 1.0))
	var answered := MemoryManager.is_memory_link_answered(link)
	var alpha := clampf(0.34 + confidence * 0.20 + (0.12 if answered else 0.0), 0.34, 0.72)

	var shadow := Line2D.new()
	shadow.name = "MemoryLinkShadow"
	shadow.points = PackedVector2Array([a + head + Vector2(0, 4), arc + Vector2(0, 4), b + head + Vector2(0, 4)])
	shadow.width = 5.0
	shadow.default_color = Color(0.12, 0.10, 0.08, 0.12)
	shadow.z_index = 340
	shadow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	shadow.end_cap_mode = Line2D.LINE_CAP_ROUND
	shadow.joint_mode = Line2D.LINE_JOINT_ROUND
	world.add_child(shadow)

	var line := Line2D.new()
	line.name = "MemoryLink"
	line.points = PackedVector2Array([a + head, arc, b + head])
	line.width = 3.5 if answered else 3.0
	line.default_color = Color(link_color.r, link_color.g, link_color.b, alpha)
	line.z_index = 341
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	world.add_child(line)

	var pulse := Line2D.new()
	pulse.name = "MemoryLinkPulse"
	pulse.points = PackedVector2Array([a + head, arc, b + head])
	pulse.width = 1.5 if answered else 1.0
	pulse.default_color = Color(1.0, 0.96, 0.78, 0.62 if answered else 0.36)
	pulse.z_index = 342
	pulse.begin_cap_mode = Line2D.LINE_CAP_ROUND
	pulse.end_cap_mode = Line2D.LINE_CAP_ROUND
	pulse.joint_mode = Line2D.LINE_JOINT_ROUND
	world.add_child(pulse)
	if OS.get_environment("FG_CAPTURE_SCREENSHOTS") != "1":
		var pulse_tween := create_tween()
		pulse_tween.set_loops()
		pulse_tween.tween_property(pulse, "modulate:a", 0.28 if answered else 0.18, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tween.tween_property(pulse, "modulate:a", 0.90 if answered else 0.58, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_add_memory_link_leaf((a + head).lerp(arc, 0.56), link_color, -0.42, answered)
	_add_memory_link_leaf(arc.lerp(b + head, 0.44), link_color, 0.42, answered)

	var mid := arc
	var area := Area2D.new()
	area.name = "MemoryLinkHotspot"
	area.position = mid
	area.z_index = 343
	area.input_pickable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(104, 52)
	shape.shape = rect
	area.add_child(shape)

	var tag_panel := Panel.new()
	tag_panel.position = Vector2(-64, -54)
	tag_panel.size = Vector2(128, 34)
	tag_panel.visible = false
	tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = Color(0.92, 1.0, 0.84, 0.96) if answered else Color(1.0, 0.96, 0.82, 0.94)
	tag_style.border_color = Color(link_color.r, link_color.g, link_color.b, 0.95)
	tag_style.set_border_width_all(2)
	tag_style.set_corner_radius_all(5)
	tag_panel.add_theme_stylebox_override("panel", tag_style)
	area.add_child(tag_panel)

	var tag := Label.new()
	tag.text = link_label + (" · 已补写" if answered else " · 待补写")
	tag.position = Vector2(8, 7)
	tag.size = Vector2(112, 20)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(0.20, 0.17, 0.12, 0.96))
	tag_panel.add_child(tag)

	_add_memory_link_bloom(area, Vector2.ZERO, link_color)
	area.mouse_entered.connect(func() -> void: tag_panel.visible = true)
	area.mouse_exited.connect(func() -> void: tag_panel.visible = false)

	area.input_event.connect(func(_v: Node, e: InputEvent, _s: int) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_open_memory_link_panel(link))
	world.add_child(area)

func _add_memory_link_leaf(pos: Vector2, color: Color, rotation: float, answered: bool) -> void:
	var leaf := Polygon2D.new()
	leaf.name = "MemoryLinkLeaf"
	leaf.position = pos
	leaf.rotation = rotation
	leaf.z_index = 342
	leaf.polygon = PackedVector2Array([
		Vector2(0, -8),
		Vector2(12, -2),
		Vector2(0, 8),
		Vector2(-5, 0),
	])
	leaf.color = Color(color.r, color.g, color.b, 0.82 if answered else 0.56)
	world.add_child(leaf)

func _add_memory_link_bloom(parent: Node2D, pos: Vector2, color: Color) -> void:
	for i in range(5):
		var petal := Polygon2D.new()
		petal.name = "MemoryLinkBloomPetal"
		petal.position = pos
		petal.rotation = TAU * float(i) / 5.0
		petal.polygon = PackedVector2Array([
			Vector2(0, -10),
			Vector2(6, -2),
			Vector2(0, 4),
			Vector2(-6, -2),
		])
		petal.color = Color(1.0, 0.78, 0.58, 0.94)
		parent.add_child(petal)
	var center := Polygon2D.new()
	center.name = "MemoryLinkBloomCenter"
	center.position = pos
	center.polygon = PackedVector2Array([
		Vector2(0, -4),
		Vector2(4, 0),
		Vector2(0, 4),
		Vector2(-4, 0),
	])
	center.color = Color(color.r, color.g, color.b, 0.96)
	parent.add_child(center)

func _memory_link_color(relation_type: String) -> Color:
	match relation_type:
		"same_person":
			return Color(0.74, 0.38, 0.50, 1.0)
		"same_place":
			return Color(0.35, 0.55, 0.74, 1.0)
		"time_sequence":
			return Color(0.70, 0.55, 0.28, 1.0)
		"cause_effect":
			return Color(0.58, 0.45, 0.76, 1.0)
		"contrast":
			return Color(0.72, 0.46, 0.34, 1.0)
		_:
			return Color(0.46, 0.66, 0.36, 1.0)

func _memory_link_label(relation_type: String) -> String:
	match relation_type:
		"same_person":
			return "同一家人"
		"same_place":
			return "同一地点"
		"time_sequence":
			return "时间线索"
		"cause_effect":
			return "前因后果"
		"contrast":
			return "对照记忆"
		_:
			return "相似主题"

func _open_memory_link_panel(link: Dictionary) -> void:
	var live_link := MemoryManager.get_memory_link_by_id(String(link.get("id", "")))
	if live_link.is_empty():
		live_link = link
	var endpoints := MemoryManager.get_memory_link_endpoints(live_link)
	if not bool(endpoints.get("ok", false)):
		_show_toast("这条关联的记忆已经不存在。")
		return
	_close_active_panel()
	var memory_a: Dictionary = endpoints.get("memory_a", {})
	var memory_b: Dictionary = endpoints.get("memory_b", {})
	var card_a: Dictionary = memory_a.get("ai_card", {})
	var card_b: Dictionary = memory_b.get("ai_card", {})
	var relation_type := String(live_link.get("relation_type", "same_theme"))
	var relation_label := _memory_link_label(relation_type)
	var meta: Dictionary = live_link.get("generation_meta", {})
	var answered := MemoryManager.is_memory_link_answered(live_link)

	var overlay := _create_modal_overlay()
	active_modal = overlay
	var panel := Panel.new()
	panel.position = Vector2(250, 46)
	panel.size = Vector2(780, 628)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = "记忆藤蔓"
	title.position = Vector2(34, 24)
	title.size = Vector2(712, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var relation := Label.new()
	relation.text = "%s · 可信度 %d%% · %s" % [
		relation_label,
		roundi(float(live_link.get("confidence", 1.0)) * 100.0),
		"家人已补写" if answered else "等待家人补写",
	]
	relation.position = Vector2(34, 64)
	relation.size = Vector2(712, 24)
	relation.add_theme_font_size_override("font_size", 14)
	relation.add_theme_color_override("font_color", Color(0.34, 0.29, 0.22, 0.88))
	panel.add_child(relation)

	_add_memory_link_summary_card(panel, Vector2(34, 106), Vector2(306, 144), "记忆 A", card_a)
	_add_memory_link_summary_card(panel, Vector2(440, 106), Vector2(306, 144), "记忆 B", card_b)

	var vine := ColorRect.new()
	vine.position = Vector2(350, 174)
	vine.size = Vector2(80, 4)
	vine.color = Color(_memory_link_color(relation_type).r, _memory_link_color(relation_type).g, _memory_link_color(relation_type).b, 0.68)
	vine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vine)

	var bud := Panel.new()
	bud.position = Vector2(378, 162)
	bud.size = Vector2(26, 26)
	bud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bud_style := StyleBoxFlat.new()
	bud_style.bg_color = Color(0.92, 1.0, 0.82, 0.96) if answered else Color(1.0, 0.92, 0.72, 0.96)
	bud_style.border_color = Color(_memory_link_color(relation_type).r, _memory_link_color(relation_type).g, _memory_link_color(relation_type).b, 0.95)
	bud_style.set_border_width_all(2)
	bud_style.set_corner_radius_all(13)
	bud.add_theme_stylebox_override("panel", bud_style)
	panel.add_child(bud)

	var open_a := Button.new()
	open_a.text = "打开记忆 A"
	open_a.position = Vector2(118, 262)
	open_a.size = Vector2(138, 34)
	open_a.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_style(open_a, false)
	open_a.pressed.connect(_open_memory_from_link.bind(String(memory_a.get("id", ""))))
	panel.add_child(open_a)

	var open_b := Button.new()
	open_b.text = "打开记忆 B"
	open_b.position = Vector2(524, 262)
	open_b.size = Vector2(138, 34)
	open_b.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_style(open_b, false)
	open_b.pressed.connect(_open_memory_from_link.bind(String(memory_b.get("id", ""))))
	panel.add_child(open_b)

	var question_box := Panel.new()
	question_box.position = Vector2(34, 312)
	question_box.size = Vector2(712, 78)
	question_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_small_card_style(question_box)
	panel.add_child(question_box)

	var question_title := Label.new()
	question_title.text = "这根藤想问"
	question_title.position = Vector2(16, 10)
	question_title.size = Vector2(680, 18)
	question_title.add_theme_font_size_override("font_size", 12)
	question_title.add_theme_color_override("font_color", Color(0.44, 0.36, 0.26, 0.86))
	question_box.add_child(question_title)

	var question := Label.new()
	question.text = String(live_link.get("question", ""))
	question.position = Vector2(16, 30)
	question.size = Vector2(680, 38)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.add_theme_font_size_override("font_size", 15)
	question.add_theme_color_override("font_color", Color(0.18, 0.28, 0.22, 1.0))
	question_box.add_child(question)

	var answer_title := Label.new()
	answer_title.text = "家人的补写" if answered else "补上这段关系"
	answer_title.position = Vector2(34, 404)
	answer_title.size = Vector2(712, 22)
	answer_title.add_theme_font_size_override("font_size", 14)
	answer_title.add_theme_color_override("font_color", Color(0.28, 0.35, 0.24, 0.94))
	panel.add_child(answer_title)

	var answer_input := TextEdit.new()
	answer_input.text = String(live_link.get("followup_answer", ""))
	answer_input.placeholder_text = "写下这两段记忆之间还没有说完的话..."
	answer_input.position = Vector2(34, 430)
	answer_input.size = Vector2(712, 84)
	answer_input.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(answer_input)

	var status := _make_status_label(
		panel,
		Vector2(34, 520),
		Vector2(712, 24),
		"已保存的补写可以继续编辑。" if answered else "保存后，这根藤会在场景里点亮。"
	)

	var trace := Label.new()
	trace.text = "AI 来源：%s · 模型：%s · Prompt：%s" % [
		String(meta.get("source", meta.get("provider", "unknown"))),
		String(meta.get("model", "unknown")),
		String(meta.get("prompt_version", "unknown")),
	]
	trace.position = Vector2(34, 546)
	trace.size = Vector2(712, 22)
	trace.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trace.add_theme_font_size_override("font_size", 12)
	trace.add_theme_color_override("font_color", Color(0.43, 0.36, 0.28, 0.78))
	panel.add_child(trace)

	var save := Button.new()
	save.text = "更新补写" if answered else "保存补写"
	save.position = Vector2(242, 580)
	save.size = Vector2(140, 38)
	save.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_style(save, false)
	save.pressed.connect(_save_memory_link_followup.bind(String(live_link.get("id", "")), answer_input, save, status))
	panel.add_child(save)

	var close := Button.new()
	close.text = "关闭"
	close.position = Vector2(400, 580)
	close.size = Vector2(140, 40)
	close.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_style(close, false)
	close.pressed.connect(_close_active_panel)
	panel.add_child(close)

func _add_memory_link_summary_card(parent: Control, pos: Vector2, card_size: Vector2, heading: String, card: Dictionary) -> void:
	var box := Panel.new()
	box.position = pos
	box.size = card_size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_small_card_style(box)
	parent.add_child(box)

	var label := Label.new()
	label.text = heading
	label.position = Vector2(16, 12)
	label.size = Vector2(card_size.x - 32, 20)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.45, 0.36, 0.25, 0.86))
	box.add_child(label)

	var title := Label.new()
	title.text = String(card.get("title", "记忆"))
	title.position = Vector2(16, 38)
	title.size = Vector2(card_size.x - 32, 28)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.23, 0.18, 0.13, 1.0))
	box.add_child(title)

	var desc := Label.new()
	desc.text = String(card.get("description", ""))
	desc.position = Vector2(16, 76)
	desc.size = Vector2(card_size.x - 32, 72)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.32, 0.27, 0.21, 0.92))
	box.add_child(desc)

func _open_memory_from_link(memory_id: String) -> void:
	var mem := _find_rendered_memory_by_memory_id(memory_id)
	if mem.is_empty():
		_show_toast("这段记忆不在当前场景里。")
		return
	_open_memory_card(mem)

func _find_rendered_memory_by_memory_id(memory_id: String) -> Dictionary:
	for mem in _demo_memories:
		if String(mem.get("memory_id", "")) == memory_id:
			return mem
	for mem in _fishpond_memories:
		if String(mem.get("memory_id", "")) == memory_id:
			return mem
	return {}

func _save_memory_link_followup(link_id: String, input: TextEdit, button: Button, status: Label) -> void:
	var text := input.text.strip_edges()
	if text == "":
		_set_status(status, "先写一点补充，再保存。", true)
		return
	_set_button_busy(button, "正在保存...")
	_set_status(status, "正在把这段补写长到藤蔓上...")
	var result := MemoryManager.answer_memory_link(link_id, text)
	if not bool(result.get("ok", false)):
		_set_button_ready(button)
		_set_status(status, _result_error_message(result, "保存失败，请重试。"), true)
		return
	_refresh_memory_link_visuals(mode)
	var updated := bool(result.get("updated", false))
	_show_toast("记忆藤蔓已更新。" if updated else "记忆藤蔓已点亮。")
	_open_memory_link_panel(result.get("link", {}))

func _refresh_memory_link_visuals(scene: String) -> void:
	if world == null or not is_instance_valid(world):
		return
	_clear_memory_link_nodes()
	_render_memory_links(scene)

func _clear_memory_link_nodes() -> void:
	for child in world.get_children():
		var child_name := String(child.name)
		if child_name.begins_with("MemoryLink"):
			child.queue_free()

func _refresh_current_memory_scene(scene: String) -> void:
	if world == null or not is_instance_valid(world):
		return
	var cache := _demo_memories if scene == "garden" else _fishpond_memories
	for item in cache:
		if item is Dictionary:
			var live: Variant = item.get("node", null)
			if live != null and is_instance_valid(live):
				live.queue_free()
	cache.clear()
	for child in world.get_children():
		if child.is_in_group("world_memory_node"):
			child.queue_free()
	_clear_memory_link_nodes()
	SlotManager.reset(scene)
	if scene == "garden":
		_render_scene_nodes("garden", _demo_memories, _on_memory_clicked)
	else:
		_render_scene_nodes("fishpond", _fishpond_memories, func(_nid: String) -> void: _show_toast("一段鱼塘记忆"))
	_render_memory_links(scene)
	if scene == "garden":
		MemoryManager.maybe_recompute_family_portrait()
		_render_family_portrait()
	_show_gate4_scene_guide(scene)

# 从数据层渲染某场景已落库的节点：回填 slot 占用、按状态决定形态、装入交互缓存。
# cache 项：{ id(node_id), memory_id, card, state, answer, node }；click_cb 绑 node_id。
func _render_scene_nodes(scene: String, cache: Array, click_cb: Callable) -> void:
	var groups: Dictionary = {}
	for nd in MemoryManager.get_nodes_for_scene(scene):
		if String(nd.get("node_type", "")) == "memory_link":
			continue  # 连线节点不是落点物，由 _render_memory_links 单独画
		var slot_id := String(nd.get("slot_id", ""))
		if slot_id == "":
			continue
		if not groups.has(slot_id):
			groups[slot_id] = []
		(groups[slot_id] as Array).append(nd)
	for slot_id in groups:
		var stack: Array = groups[slot_id]
		if stack.is_empty():
			continue
		var slot := SlotManager.get_slot(scene, slot_id)
		if slot.is_empty():
			continue
		var items: Array = []
		var visual_state := "new"
		for raw_node in stack:
			if not (raw_node is Dictionary):
				continue
			var stored_node: Dictionary = raw_node
			var memory_id := String(stored_node.get("memory_id", ""))
			var mem := MemoryManager.get_memory(memory_id)
			var state := String(stored_node.get("state", "new"))
			if state == "grown":
				visual_state = "grown"
			items.append({
				"id": String(stored_node.get("id", "")),
				"memory_id": memory_id,
				"card": mem.get("ai_card", {}),
				"state": state,
				"answer": MemoryManager.get_answer_for_memory(memory_id),
				"node": null,
			})
		if items.is_empty():
			continue
		var representative: Dictionary = items[-1]
		var node_id := String(representative.get("id", ""))
		SlotManager.occupy(scene, String(slot_id), node_id)
		var on_click := click_cb.bind(node_id) if items.size() == 1 else _open_memory_cluster.bind(items)
		var live := NodeFactory.make_memory_node(representative.get("card", {}), slot, on_click, visual_state)
		live.add_to_group("world_memory_node")
		_add_memory_tag(live, visual_state)
		if items.size() > 1:
			_add_memory_cluster_badge(live, items.size())
		var target_scale := Vector2.ONE if visual_state == "grown" else Vector2(0.78, 0.78)
		live.scale = target_scale
		world.add_child(live)
		_animate_scene_node_arrival(live, target_scale)
		for item in items:
			(item as Dictionary)["node"] = live
			cache.append(item)

func _add_memory_cluster_badge(node: Node2D, count: int) -> void:
	var badge := Panel.new()
	badge.name = "MemoryClusterBadge"
	badge.position = Vector2(20, -108)
	badge.size = Vector2(34, 24)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.30, 0.43, 0.28, 0.94)
	style.border_color = Color(1.0, 0.93, 0.70, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	badge.add_theme_stylebox_override("panel", style)
	node.add_child(badge)
	var label := Label.new()
	label.text = "×%d" % count
	label.position = Vector2(4, 2)
	label.size = Vector2(26, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.84, 1.0))
	badge.add_child(label)

func _open_memory_cluster(items: Array) -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay
	var panel := Panel.new()
	panel.position = Vector2(360, 104)
	panel.size = Vector2(560, 512)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)
	var title := Label.new()
	title.text = "这一簇记忆"
	title.position = Vector2(34, 26)
	title.size = Vector2(470, 32)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "%d 段家庭记忆在这里一起开花" % items.size()
	subtitle.position = Vector2(34, 62)
	subtitle.size = Vector2(470, 24)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.38, 0.31, 0.23, 0.82))
	panel.add_child(subtitle)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(34, 104)
	scroll.size = Vector2(492, 322)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for raw_item in items:
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item
		var card: Dictionary = item.get("card", {})
		var row := Button.new()
		row.text = "%s\n%s" % [String(card.get("title", "一段家庭记忆")), "已回应" if String(item.get("state", "new")) == "grown" else "等待家人回应"]
		row.custom_minimum_size = Vector2(470, 68)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_button_style(row, String(item.get("state", "new")) == "grown")
		row.pressed.connect(_open_memory_card.bind(item))
		list.add_child(row)
	_add_panel_button(panel, "关闭", Vector2(218, 448), Vector2(124, 38), "close")

# 占位和正式美术都保留一个轻量状态标记，帮助玩家识别可互动的 AI 记忆。
func _add_memory_tag(node: Node2D, state: String) -> void:
	var tag := Label.new()
	tag.name = "DemoTag"
	tag.text = "已确认" if state == "grown" else "待回应"
	tag.visible = false
	tag.position = Vector2(-34, -112)
	tag.size = Vector2(68, 20)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_constant_override("outline_size", 3)
	tag.add_theme_color_override("font_outline_color", Color(1.0, 0.96, 0.82, 0.92))
	tag.add_theme_color_override("font_color", Color(0.24, 0.18, 0.13, 0.92))
	node.add_child(tag)
	var click_area := node.get_node_or_null("ClickArea") as Area2D
	if click_area != null:
		click_area.mouse_entered.connect(func() -> void: tag.visible = true)
		click_area.mouse_exited.connect(func() -> void: tag.visible = false)

func _animate_scene_node_arrival(node: Node2D, target_scale: Vector2) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.modulate.a = 0.0
	node.scale = target_scale * 0.82
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "scale", target_scale, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _find_demo_memory(mem_id: String) -> Dictionary:
	for m in _demo_memories:
		if String(m.get("id", "")) == mem_id:
			return m
	return {}

func _on_memory_clicked(mem_id: String) -> void:
	var mem := _find_demo_memory(mem_id)
	if not mem.is_empty():
		_open_memory_card(mem)

# 记忆卡片 UI —— "可见的诚实"：AI 推测=浅灰+问号；家人确认=正常深色。
func _open_memory_card(mem: Dictionary) -> void:
	_close_active_panel()
	var card: Dictionary = mem.get("card", {})
	var overlay := _create_modal_overlay()
	active_modal = overlay

	var panel := Panel.new()
	panel.position = Vector2(360, 120)
	panel.size = Vector2(560, 484)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = String(card.get("title", "记忆"))
	title.position = Vector2(34, 24)
	title.size = Vector2(490, 34)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var desc := Label.new()
	desc.text = String(card.get("description", ""))
	desc.position = Vector2(34, 68)
	desc.size = Vector2(492, 70)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(desc)

	# AI 推测保持浅灰与问号，明确区别于家人确认的事实（可见的诚实）。
	var guess := Label.new()
	guess.text = "AI 推测：" + String(card.get("guess", "")) + "  ？（待家人确认）"
	guess.position = Vector2(34, 144)
	guess.size = Vector2(492, 24)
	guess.add_theme_font_size_override("font_size", 13)
	guess.add_theme_color_override("font_color", Color(0.60, 0.57, 0.52, 1.0))
	panel.add_child(guess)

	var q := Label.new()
	q.text = String(card.get("question", ""))
	q.position = Vector2(34, 182)
	q.size = Vector2(492, 50)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.add_theme_font_size_override("font_size", 16)
	q.add_theme_color_override("font_color", Color(0.20, 0.30, 0.24, 1.0))
	panel.add_child(q)

	if String(mem.get("state", "new")) == "new":
		var input := TextEdit.new()
		input.placeholder_text = "写下你的回忆…"
		input.position = Vector2(34, 244)
		input.size = Vector2(492, 112)
		panel.add_child(input)
		_add_panel_button(panel, "取消", Vector2(150, 376), Vector2(120, 40), "close")
		var submit := Button.new()
		submit.text = "回答"
		submit.position = Vector2(290, 376)
		submit.size = Vector2(120, 40)
		submit.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_button_style(submit, false)
		submit.pressed.connect(_submit_memory_answer.bind(String(mem.get("id", "")), input))
		panel.add_child(submit)
	else:
		var ans_title := Label.new()
		ans_title.text = "家人的回答（已确认）"
		ans_title.position = Vector2(34, 244)
		ans_title.size = Vector2(492, 22)
		ans_title.add_theme_font_size_override("font_size", 13)
		ans_title.add_theme_color_override("font_color", Color(0.35, 0.45, 0.35, 1.0))
		panel.add_child(ans_title)
		var ans := Label.new()
		ans.text = String(mem.get("answer", ""))
		ans.position = Vector2(34, 270)
		ans.size = Vector2(492, 88)
		ans.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ans.add_theme_font_size_override("font_size", 16)
		ans.add_theme_color_override("font_color", Color(0.20, 0.17, 0.13, 1.0))
		panel.add_child(ans)
		_add_panel_button(panel, "关闭", Vector2(220, 376), Vector2(120, 40), "close")

func _submit_memory_answer(mem_id: String, input: TextEdit) -> void:
	var mem := _find_demo_memory(mem_id)
	if mem.is_empty():
		return
	var text: String = input.text.strip_edges()
	if text == "":
		_show_toast("写点什么再回答吧～")
		return
	mem["answer"] = text
	mem["state"] = "grown"
	MemoryManager.answer_memory(String(mem.get("memory_id", "")), text)  # 持久化：存 answer + 标节点 grown + 存档
	# 跨成员互动计数（回答别人上传的记忆）→ 升温则刷新分季背景。
	var bumped := MemoryManager.register_cross_member_answer(String(mem.get("memory_id", "")), MemoryManager.selected_role_key)
	_close_active_panel()
	_grow_memory_node(mem.get("node"))
	if bumped:
		_update_season_overlay()
		_show_toast("记忆开花了 · 花园更繁茂了（%s）" % _season_cn(MemoryManager.garden_season()))
	else:
		_show_toast("记忆开花了。")
	if MemoryManager.maybe_recompute_family_portrait():  # 参与成员变化 → 重画家庭画像木牌
		_render_family_portrait()

func _season_cn(season: String) -> String:
	match season:
		"autumn": return "秋"
		"summer": return "夏"
		_: return "春"

# 生长动画：花苞 → 开放（≤3 秒）。占位单贴图用缩放近似 seed→bud→bloom。
func _grow_memory_node(node: Variant) -> void:
	if node == null or not is_instance_valid(node):
		return
	var n: Node2D = node
	if n.has_node("DemoTag"):
		var tag := n.get_node("DemoTag") as Label
		tag.text = "已确认"
	NodeFactory.apply_memory_state(n, "grown")
	n.scale = Vector2(0.25, 0.25)
	var t := create_tween()
	t.tween_property(n, "scale", Vector2(0.7, 0.7), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "scale", Vector2(1.0, 1.0), 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ── 全局导航地图（导航页 / World Map）──────────────────────────────
# 一张拍平的世界插画，四个抠图图层正好压在底图对应区域上。鼠标悬浮时该图层
# 抬起（高亮 + 下方柔和阴影），点击进入对应场景（走统一入口 goto_scene）。
const GLOBAL_MAP_REGIONS := [
	{"id": "farm", "asset": "globalmap_farm", "label": "农场", "target": "farm"},
	{"id": "garden", "asset": "globalmap_garden", "label": "花园", "target": "garden"},
	{"id": "house", "asset": "globalmap_house", "label": "小屋", "target": "house"},
	{"id": "pond", "asset": "globalmap_pond", "label": "鱼塘", "target": "fishpond"},
]

func _show_global_map() -> void:
	_close_active_panel()
	_clear_map_ui()
	_clear_gate4_guide()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	mode = "global_map"
	adding_place = false
	plant_mode = false
	_update_plant_button()
	_clear_world()
	info_label.text = "世界地图"
	AudioManager.play_music("globalmap")
	AudioManager.play_sfx("打开地图")

	# 整张导航页放在 ui_layer（在 world 之上），但移到底部导航栏之后，保证那些按钮仍可点。
	var view := Control.new()
	view.name = "GlobalMapView"
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(view)
	ui_layer.move_child(view, 0)
	global_map_ui = view

	# 美术没导入时的柔色兜底。
	var fallback := ColorRect.new()
	fallback.name = "GlobalMapFallback"
	fallback.color = Color(0.80, 0.88, 0.70, 1.0)
	fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(fallback)

	# 拍平底图。
	var bg_tex := _safe_texture(ASSETS["globalmap_background"])
	if bg_tex:
		var bg := TextureRect.new()
		bg.name = "GlobalMapBackground"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.texture = bg_tex
		view.add_child(bg)

	var loaded := 0
	for region in GLOBAL_MAP_REGIONS:
		if _add_global_map_region(view, region):
			loaded += 1

	if loaded == 0:
		_show_toast("世界地图美术还没导入 — 用 Godot 打开一次项目即可。")
	else:
		_show_toast("把鼠标移到某个地点，点击即可进入。")

func _add_global_map_region(view: Control, region: Dictionary) -> bool:
	var tex := _safe_texture(ASSETS[str(region["asset"])])
	if tex == null:
		return false

	# 把缩放轴心放在抠图的视觉中心，悬浮“弹起”才是原地放大。
	var img := tex.get_image()
	var pivot: Vector2 = tex.get_size() / 2.0
	if img != null:
		var used := img.get_used_rect()
		pivot = Vector2(used.position) + Vector2(used.size) / 2.0

	# 柔和阴影：同一剪影模糊染黑，平时隐藏，悬浮时出现在图层正下方，模拟被"抬起"投下的影子。
	var shadow := TextureRect.new()
	shadow.name = "Shadow_" + str(region["id"])
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.texture = tex
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.0)
	shadow.pivot_offset = pivot
	var shadow_mat := ShaderMaterial.new()
	shadow_mat.shader = load("res://assets/shaders/soft_shadow_blur.gdshader")
	shadow.material = shadow_mat
	view.add_child(shadow)

	# 可交互抠图本体。click_mask 让只有画上像素的地方响应，透明处穿透到下面的图层。
	var button := TextureButton.new()
	button.name = "Region_" + str(region["id"])
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.texture_normal = tex
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pivot_offset = pivot
	view.add_child(button)

	var hotspot := Button.new()
	hotspot.name = "Hotspot_" + str(region["id"])
	hotspot.flat = true
	hotspot.text = ""
	hotspot.mouse_filter = Control.MOUSE_FILTER_STOP
	hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rect := Rect2(Vector2.ZERO, GAME_SIZE)
	if img != null:
		var used_rect := img.get_used_rect()
		rect = Rect2(Vector2(used_rect.position), Vector2(used_rect.size))
	hotspot.position = rect.position
	hotspot.size = rect.size
	view.add_child(hotspot)

	hotspot.mouse_entered.connect(_on_global_map_region_hover.bind(button, shadow, true))
	hotspot.mouse_exited.connect(_on_global_map_region_hover.bind(button, shadow, false))
	hotspot.pressed.connect(_on_global_map_region_pressed.bind(str(region["target"]), str(region["label"])))
	return true

func _on_global_map_region_hover(button: TextureButton, shadow: TextureRect, hovering: bool) -> void:
	if not is_instance_valid(button):
		return
	# 把悬浮的图层（连同阴影）抬到其它图层之上。
	button.z_index = 10 if hovering else 0
	if is_instance_valid(shadow):
		shadow.z_index = 9 if hovering else 0

	if hovering:
		# 悬浮时：图层整体上移(离开地图)+ 轻微放大 + 提亮，用回弹缓动做出"弹起"的体积感；
		# 阴影同步放大、下移、变模糊变深，靠位移差和模糊制造"离开桌面"的空间感。
		var lift := Vector2(0, -8)
		var t := create_tween().set_parallel(true)
		t.tween_property(button, "position", lift, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(button, "scale", Vector2(1.06, 1.06), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.chain().tween_property(button, "scale", Vector2(1.045, 1.045), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var tint := create_tween()
		tint.tween_property(button, "modulate", Color(1.18, 1.16, 1.1, 1.0), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tint.tween_property(button, "modulate", Color(1.10, 1.09, 1.05, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if is_instance_valid(shadow):
			var st := create_tween().set_parallel(true)
			st.tween_property(shadow, "scale", Vector2(1.10, 1.10), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			st.tween_property(shadow, "modulate", Color(0.0, 0.0, 0.0, 0.38), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			st.tween_property(shadow, "position", Vector2(12, 20), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(button, "position", Vector2.ZERO, 0.12)
		t.tween_property(button, "scale", Vector2.ONE, 0.12)
		t.tween_property(button, "modulate", Color(1, 1, 1, 1), 0.12)
		if is_instance_valid(shadow):
			t.tween_property(shadow, "scale", Vector2.ONE, 0.12)
			t.tween_property(shadow, "modulate", Color(0.0, 0.0, 0.0, 0.0), 0.12)
			t.tween_property(shadow, "position", Vector2.ZERO, 0.12)

func _on_global_map_region_pressed(target: String, label_text: String) -> void:
	_show_toast("进入%s…" % label_text)
	goto_scene(target)

# 把一个自包含的编辑器场景（Farm.tscn / AnnaRoom.tscn）嵌进持久化的 world。
# 这些场景按 1280×720 屏幕坐标、左上角为原点制作，所以实例放在 (0,0)。
func _build_embedded_scene(scene_key: String, scene_path: String, title: String, fallback_color: Color, add_player: bool) -> void:
	_close_active_panel()
	_clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	mode = scene_key
	adding_place = false
	plant_mode = false
	_update_plant_button()
	_clear_world()
	info_label.text = title

	var instance: Node = null
	if ResourceLoader.exists(scene_path):
		instance = (load(scene_path) as PackedScene).instantiate()
	if instance != null:
		if instance is Node2D:
			(instance as Node2D).position = Vector2.ZERO
		world.add_child(instance)
	else:
		_add_scene_background(scene_key, fallback_color)

	# 场景若不自带主控角色（如静态房间模板），补一个出生点上的玩家。
	if add_player:
		_add_player(ScenePortal.get_spawn(scene_key, "default"))

# ── 通用场景切换（ScenePortal 框架）────────────────────────────────
# 所有场景切换的唯一入口。target = garden/fishpond/...；spawn_key = 目标场景出生点。
func goto_scene(target: String, spawn_key: String = "default") -> void:
	AIClient.cancel_all()
	if target == POND_AREA_SCENE:
		_build_fishpond(spawn_key)
		return
	if target == "res://scenes/Main.tscn":
		_show_garden(spawn_key)
		return

	match target:
		"garden":
			_show_garden(spawn_key)
		"fishpond", "pond":
			_build_fishpond(spawn_key)
		"farm":
			# Farm.tscn 自带玩家（farm.gd 的 _spawn_player），不要再补一个。
			AudioManager.play_music("farm")
			_build_embedded_scene("farm", FARM_SCENE, "农场", Color(0.74, 0.62, 0.44, 1.0), false)
			ScenePortal.build_portals("farm", world, _on_portal_travel)
		"house":
			# AnnaRoom.tscn 是静态房间模板，需要补主控角色。
			AudioManager.play_music("house")
			_build_embedded_scene("house", ANNA_ROOM_SCENE, "小屋", Color(0.66, 0.56, 0.44, 1.0), true)
		_:
			push_warning("[SceneManager] 未知场景 '%s'，忽略切换" % target)

# ScenePortal 走入/点按触发的回调；带防抖锁防止刚进场就反复触发。
func _on_portal_travel(target: String, spawn_key: String) -> void:
	if _travel_lock:
		return
	_travel_lock = true
	goto_scene(target, spawn_key)
	var timer := get_tree().create_timer(0.4)
	timer.timeout.connect(func() -> void: _travel_lock = false)

# 通用场景背景：优先读 manifest bg 真实美术，缺图回退纯色（fallback_color）。
func _add_scene_background(scene: String, fallback_color: Color) -> void:
	var backdrop := Sprite2D.new()
	backdrop.name = "SceneBackdrop"
	backdrop.centered = true
	backdrop.position = GAME_SIZE / 2.0
	backdrop.z_index = -100
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg_path := "res://assets/%s/scene_%s_bg_01.png" % [scene, scene]
	if ResourceLoader.exists(bg_path):
		var tex: Texture2D = load(bg_path)
		backdrop.texture = tex
		var sx := GAME_SIZE.x / float(tex.get_width())
		var sy := GAME_SIZE.y / float(tex.get_height())
		backdrop.scale = Vector2(sx, sy)
	else:
		backdrop.texture = _solid_texture(int(GAME_SIZE.x), int(GAME_SIZE.y), fallback_color)
	world.add_child(backdrop)

# ── 爸爸鱼塘 fishpond ──────────────────────────────────────────────
func _build_fishpond(spawn_key: String = "default") -> void:
	_close_active_panel()
	_clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	_clear_gate4_guide()
	mode = "fishpond"
	adding_place = false
	plant_mode = false
	_update_plant_button()
	AudioManager.play_music("fishpond")
	_clear_world()
	info_label.text = "爸爸鱼塘"
	var pond_area: Node2D = null
	if ResourceLoader.exists(POND_AREA_SCENE):
		pond_area = (load(POND_AREA_SCENE) as PackedScene).instantiate() as Node2D
		if pond_area != null:
			pond_area.position = GAME_SIZE / 2.0
			world.add_child(pond_area)
	else:
		_add_scene_background("fishpond", Color(0.42, 0.62, 0.70, 1.0))  # 占位水色，等 A 出背景
	var spawn: Vector2 = ScenePortal.get_spawn("fishpond", spawn_key)
	var player_parent: Node = world
	var player_spawn := spawn
	if pond_area != null:
		var ysort_objects := pond_area.get_node_or_null("YSortObjects") as Node2D
		if ysort_objects != null:
			player_parent = ysort_objects
			player_spawn = ysort_objects.to_local(spawn)
	_add_player(player_spawn, player_parent)
	_spawn_demo_bottles()
	_register_scene_message_bottle(pond_area)
	# 重入时渲染已落库的岸边记忆（回答过的漂流瓶持久化的记忆，关游戏重开仍在）。
	_fishpond_memories.clear()
	_render_scene_nodes("fishpond", _fishpond_memories, func(_nid: String) -> void: _show_toast("一段鱼塘记忆"))
	_render_memory_links("fishpond")
	ScenePortal.build_portals("fishpond", world, _on_portal_travel)
	_show_gate4_scene_guide("fishpond")
	print("[SceneManager] fishpond bottles=", _demo_bottles.size(), " 岸边记忆=", _fishpond_memories.size(), " slot 用量=", SlotManager.usage("fishpond"))

const SCENE_BOTTLE_QUESTION := "如果这个漂流瓶能带来爸爸的一句话，你希望里面写着什么？"

# Gate 4：先同步渲染已落库漂流瓶，再后台补齐真实 AI 问题；进入场景不等待网络。
func _spawn_demo_bottles() -> void:
	_demo_bottles.clear()
	SlotManager.reset("fishpond")
	SlotManager.load_scene("fishpond")
	for bottle in MemoryManager.get_bottles():
		var slot_id := String(bottle.get("slot_id", ""))
		if slot_id == "":
			continue
		SlotManager.occupy("fishpond", slot_id, String(bottle.get("id", "")))
		_render_bottle_record(bottle)
	_generate_missing_bottles()

func _generate_missing_bottles() -> void:
	var bottles: Array = await AIWorkflowManager.ensure_bottles(2)
	if mode != "fishpond" or world == null or not is_instance_valid(world):
		return
	for bottle in bottles:
		var bid := String(bottle.get("id", ""))
		if not _demo_bottles.any(func(item): return String(item.get("id", "")) == bid):
			_render_bottle_record(bottle)
	_show_gate4_scene_guide("fishpond")

func _render_bottle_record(bottle: Dictionary) -> void:
	var slot := SlotManager.get_slot("fishpond", String(bottle.get("slot_id", "")))
	if slot.is_empty():
		return
	var bid := String(bottle.get("id", ""))
	var card := {"node_type": "bottle", "suggested_scene": "fishpond"}
	var node := NodeFactory.make_memory_node(card, slot, _on_bottle_clicked.bind(bid))
	world.add_child(node)
	var view_model := bottle.duplicate(true)
	view_model["node"] = node
	_demo_bottles.append(view_model)

func _register_scene_message_bottle(pond_area: Node2D) -> void:
	if pond_area == null:
		return
	var bottle := pond_area.get_node_or_null("MessageBottle") as Area2D
	if bottle == null:
		return
	bottle.input_pickable = true
	if not bottle.input_event.is_connected(_on_scene_message_bottle_input):
		bottle.input_event.connect(_on_scene_message_bottle_input)
	_demo_bottles.append({"id": "scene_bottle", "question": SCENE_BOTTLE_QUESTION, "state": "floating", "answer": "", "node": bottle})

func _on_scene_message_bottle_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_on_bottle_clicked("scene_bottle")

func _find_demo_bottle(bid: String) -> Dictionary:
	for b in _demo_bottles:
		if String(b.get("id", "")) == bid:
			return b
	return {}

func _on_bottle_clicked(bid: String) -> void:
	var b := _find_demo_bottle(bid)
	if not b.is_empty():
		_open_bottle_panel(b)

# 漂流瓶问题面板（复用记忆卡片样式）：未答=问题+回答框；已答=显示回答。
func _open_bottle_panel(b: Dictionary) -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay

	var panel := Panel.new()
	panel.position = Vector2(360, 150)
	panel.size = Vector2(560, 420)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var water_band := ColorRect.new()
	water_band.position = Vector2(0, 0)
	water_band.size = Vector2(560, 64)
	water_band.color = Color(0.72, 0.88, 0.88, 0.28)
	water_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(water_band)

	var title := Label.new()
	title.text = "漂来一个问题"
	title.position = Vector2(34, 24)
	title.size = Vector2(490, 34)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color(0.18, 0.30, 0.38, 1.0))
	panel.add_child(title)

	var q := Label.new()
	q.text = String(b.get("question", ""))
	q.position = Vector2(34, 76)
	q.size = Vector2(492, 70)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.add_theme_font_size_override("font_size", 17)
	q.add_theme_color_override("font_color", Color(0.20, 0.28, 0.26, 1.0))
	panel.add_child(q)

	if String(b.get("state", "floating")) == "floating":
		var input := TextEdit.new()
		input.placeholder_text = "写下这只漂流瓶带来的回忆..."
		input.position = Vector2(34, 160)
		input.size = Vector2(492, 130)
		panel.add_child(input)
		var status := _make_status_label(panel, Vector2(34, 294), Vector2(492, 22), "保存后，岸边会长出一朵新的记忆花。")
		_add_panel_button(panel, "取消", Vector2(150, 312), Vector2(120, 40), "close")
		var submit := Button.new()
		submit.text = "回答"
		submit.position = Vector2(290, 312)
		submit.size = Vector2(120, 40)
		submit.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_button_style(submit, false)
		submit.pressed.connect(_submit_bottle_answer.bind(String(b.get("id", "")), input, submit, status))
		panel.add_child(submit)
	else:
		var ans_title := Label.new()
		ans_title.text = "你的回答已经成为岸边记忆"
		ans_title.position = Vector2(34, 160)
		ans_title.size = Vector2(492, 22)
		ans_title.add_theme_font_size_override("font_size", 13)
		ans_title.add_theme_color_override("font_color", Color(0.30, 0.45, 0.42, 1.0))
		panel.add_child(ans_title)
		var ans := Label.new()
		ans.text = String(b.get("answer", ""))
		ans.position = Vector2(34, 186)
		ans.size = Vector2(492, 104)
		ans.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ans.add_theme_font_size_override("font_size", 16)
		ans.add_theme_color_override("font_color", Color(0.18, 0.22, 0.20, 1.0))
		panel.add_child(ans)
		_add_panel_button(panel, "关闭", Vector2(220, 312), Vector2(120, 40), "close")

func _submit_bottle_answer(bid: String, input: TextEdit, button: Button, status: Label) -> void:
	var b := _find_demo_bottle(bid)
	if b.is_empty():
		return
	var text: String = input.text.strip_edges()
	if text == "":
		_set_status(status, "写点什么再回答吧。", true)
		_show_toast("写点什么再回答吧～")
		return
	_set_button_busy(button, "正在保存...")
	_set_status(status, "正在把回答保存成岸边记忆...")
	if bid != "scene_bottle":
		var result: Dictionary = await AIWorkflowManager.answer_bottle(bid, text)
		if not bool(result.get("ok", false)):
			_set_button_ready(button, "重试回答")
			var message := _result_error_message(result, "回答保存失败。")
			_set_status(status, message, true)
			_show_toast(message)
			return
		_close_active_panel()
		_build_fishpond()
		_show_toast("这只漂流瓶已经保存过回答。" if bool(result.get("duplicate", false)) else "漂流瓶回答已保存。")
		return
	b["answer"] = text
	b["state"] = "opened"
	_close_active_panel()
	# 回答后在岸边 slot 生成一个记忆节点（漂流瓶 → 记忆），并落库持久化（关游戏重开仍在）。
	var slot: Variant = SlotManager.allocate("fishpond", "memory_flower", bid + "_mem")
	if slot != null:
		var card := {"title": "鱼塘的回忆", "description": text, "memory_type": "father",
			"suggested_scene": "fishpond", "question": String(b.get("question", "")),
			"node_type": "memory_flower", "confidence": 1.0, "guess": "与爸爸有关的记忆"}
		var mem := MemoryManager.create_memory(card, "bottle")
		MemoryManager.create_node(String(mem.get("id", "")), "fishpond", "memory_flower", String(slot.get("slot_id", "")))
		MemoryManager.answer_memory(String(mem.get("id", "")), text)  # 岸边记忆即已回答状态（标 grown + 存档）
		var mem_node := NodeFactory.make_memory_node(card, slot, func() -> void: _show_toast("一段鱼塘记忆"))
		mem_node.scale = Vector2(0.25, 0.25)
		world.add_child(mem_node)
		_grow_memory_node(mem_node)
		# 同步进岸边记忆缓存，离场重入由 _render_scene_nodes 重建。
		_fishpond_memories.append({"id": String(mem.get("id", "")), "memory_id": String(mem.get("id", "")),
			"card": card, "state": "grown", "answer": text, "node": mem_node})
	_show_toast("漂流瓶回答已成为岸边记忆。")

func _clear_world() -> void:
	for child in world.get_children():
		child.queue_free()
	plant_nodes.clear()

func _clear_map_ui() -> void:
	adding_place = false
	if map_ui != null and is_instance_valid(map_ui):
		map_ui.queue_free()
	map_ui = null
	_clear_global_map_ui()

func _clear_global_map_ui() -> void:
	if global_map_ui != null and is_instance_valid(global_map_ui):
		global_map_ui.queue_free()
	global_map_ui = null

func _add_background() -> void:
	var texture := _safe_texture(ASSETS["background"])
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.name = "SharedGardenBackground"
	sprite.centered = true
	sprite.position = GAME_SIZE / 2.0
	if texture:
		sprite.texture = texture
		var scale_factor = max(GAME_SIZE.x / float(texture.get_width()), GAME_SIZE.y / float(texture.get_height()))
		sprite.scale = Vector2.ONE * scale_factor
	else:
		sprite.texture = _solid_texture(1280, 720, Color(0.72, 0.86, 0.62, 1.0))
	world.add_child(sprite)
	_add_season_overlay()

# 分季氛围叠加层（家庭关系温度计）：按跨成员互动数着色，0→春稀疏 / 3-9→夏 / 10+→秋繁茂。
# 半透明叠在背景之上、记忆花之下；无需新美术，A 的分季层定稿后可替换为真层。
func _add_season_overlay() -> void:
	var overlay := ColorRect.new()
	overlay.name = "SeasonOverlay"
	overlay.position = Vector2.ZERO
	overlay.size = GAME_SIZE
	overlay.z_index = 1  # 背景(0)之上、记忆花(z=pos.y)之下
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = _season_overlay_color(MemoryManager.garden_season())
	world.add_child(overlay)

# 跨成员互动数变化后实时重着色（不重建场景）。
func _update_season_overlay() -> void:
	if world == null or not is_instance_valid(world):
		return
	var ov := world.get_node_or_null("SeasonOverlay")
	if ov is ColorRect:
		(ov as ColorRect).color = _season_overlay_color(MemoryManager.garden_season())

func _season_overlay_color(season: String) -> Color:
	match season:
		"autumn":
			return Color(0.86, 0.52, 0.18, 0.20)  # 金黄繁茂
		"summer":
			return Color(0.96, 0.80, 0.34, 0.12)  # 暖绿/夏
		_:
			return Color(0.45, 0.80, 0.50, 0.06)  # 清新稀疏/春

func _add_garden_spawn_markers() -> void:
	var marker := Marker2D.new()
	marker.name = "GardenFromPondSpawnPoint"
	marker.position = ScenePortal.get_spawn("garden", "GardenFromPondSpawnPoint")
	world.add_child(marker)

func _add_core_objects() -> void:
	_add_interactable_sprite(
		"family_tree",
		ASSETS["tree"],
			Vector2(645, 280),
			390.0,
			"tree",
			"家庭树",
			Vector2(190, 170),
			Vector2(0, 95)
		)
	# 邮箱画在花园背景里，这里用不可见热点补交互。
	_add_mailbox_hotspot(Vector2(402, 104), Vector2(120, 120))
	# 右下角木牌画在背景里，这里用不可见热点作为留言板按钮。
	_add_message_board_hotspot(Vector2(1162, 584), Vector2(190, 120))

func _add_mailbox_hotspot(pos: Vector2, hotspot_size: Vector2) -> void:
	var area := Area2D.new()
	area.name = "MailboxHotspot"
	area.position = pos
	area.z_index = 120
	area.input_pickable = true
	area.monitoring = true
	area.monitorable = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = hotspot_size
	shape.shape = rect
	area.add_child(shape)
	area.input_event.connect(_on_mailbox_hotspot_input)
	world.add_child(area)

	mailbox_badge = Sprite2D.new()
	mailbox_badge.name = "MailboxBadge"
	mailbox_badge.centered = true
	mailbox_badge.position = pos + Vector2(5, -10)
	mailbox_badge.z_index = 220
	mailbox_badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(mailbox_badge)
	_render_mailbox_badge()

func _on_mailbox_alert_changed(_state: String) -> void:
	_render_mailbox_badge()

func _render_mailbox_badge() -> void:
	if not is_instance_valid(mailbox_badge):
		return
	if MemoryManager.mailbox_alert_state == MemoryManager.MAILBOX_ALERT_NONE:
		mailbox_badge.visible = false
		return

	mailbox_badge.visible = true
	var badge_path: String = str(ASSETS["mailbox_badge_letter"] if MemoryManager.mailbox_alert_state == MemoryManager.MAILBOX_ALERT_LETTER else ASSETS["mailbox_badge_dot"])
	var badge_texture: Texture2D = _safe_texture(badge_path)
	if badge_texture:
		mailbox_badge.texture = badge_texture
		var target_height: float = 42.0 if MemoryManager.mailbox_alert_state == MemoryManager.MAILBOX_ALERT_LETTER else 28.0
		mailbox_badge.scale = Vector2.ONE * (target_height / float(badge_texture.get_height()))
	else:
		mailbox_badge.texture = _solid_texture(28, 28, Color(0.95, 0.10, 0.08, 1.0))
		mailbox_badge.scale = Vector2.ONE

func _on_mailbox_hotspot_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_open_mailbox_panel()

func _add_message_board_hotspot(pos: Vector2, hotspot_size: Vector2) -> void:
	var area := Area2D.new()
	area.name = "MessageBoardHotspot"
	area.position = pos
	area.z_index = 120
	area.input_pickable = true
	area.monitoring = true
	area.monitorable = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = hotspot_size
	shape.shape = rect
	area.add_child(shape)
	area.input_event.connect(_on_message_board_hotspot_input)
	world.add_child(area)

func _on_message_board_hotspot_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_open_message_board_panel()

func _add_houses() -> void:
	for house in HOUSE_DATA:
		_add_interactable_sprite(
			"house_" + str(house["id"]),
			ASSETS[str(house["asset"])],
			house["pos"],
			house["height"],
			"house:" + str(house["id"]),
			str(house["label"])
		)

func _add_npcs() -> void:
	for role_data in CHARACTER_DATA:
		var role_key := str(role_data.get("role", ""))
		if role_key == MemoryManager.selected_role_key:
			continue
		var npc_name := str(role_data.get("default_name", role_data.get("label", "Family")))
		var npc_pos: Vector2 = role_data.get("npc_pos", Vector2(720, 420))
		var npc_body := _create_character(npc_name, ASSETS[str(role_data.get("asset", "girl"))], npc_pos, false)
		npc_body.name = "NPC_" + role_key
		npc_body.set_script(preload("res://scripts/npc_wander.gd"))
		npc_body.set("home_position", npc_pos)
		npc_body.set("wander_radius", float(role_data.get("wander_radius", 80.0)))
		npc_body.set("move_speed", 34.0)
		npc_body.set("walk_bounds", Rect2(Vector2(35, 100), Vector2(1210, 560)))
		npc_body.call_deferred("set_blocked_rects", _get_character_blocked_rects())
		world.add_child(npc_body)
		_add_click_area(npc_body, Vector2(56, 72), "npc:" + role_key, npc_name)

func _add_animals() -> void:
	animal_nodes.clear()
	for animal_data in ANIMAL_DATA:
		var animal := preload("res://scripts/animal.gd").new()
		animal.setup({
			"id": str(animal_data.get("id", "animal")),
			"name": str(animal_data.get("name", "Animal")),
			"texture_path": ASSETS[str(animal_data.get("asset", ""))],
			"home_position": animal_data.get("pos", Vector2(640, 360)),
			"target_height": float(animal_data.get("height", 48.0)),
			"hframes": int(animal_data.get("hframes", 1)),
			"vframes": int(animal_data.get("vframes", 1)),
			"wander_radius": float(animal_data.get("wander_radius", 40.0)),
			"move_speed": float(animal_data.get("move_speed", 18.0)),
			"frames": animal_data.get("frames", {}),
			"bounds": _get_animal_bounds(),
			"blocked_rects": _get_animal_blocked_rects()
		})
		world.add_child(animal)
		animal_nodes[str(animal_data.get("id", "animal"))] = animal
		_add_click_area(
			animal,
			Vector2(float(animal_data.get("height", 48.0)) * 1.15, float(animal_data.get("height", 48.0)) * 0.9),
			"animal:" + str(animal_data.get("id", "animal")),
			str(animal_data.get("name", "Animal")),
			Vector2(0, -float(animal_data.get("height", 48.0)) * 0.18)
		)

func _get_animal_bounds() -> Rect2:
	# Animals may wander more naturally, but stay inside the garden play area.
	return Rect2(Vector2(45, 105), Vector2(1185, 545))

func _get_animal_blocked_rects() -> Array:
	# Approximate no-walk zones for animals: water, buildings, fences, tree trunk, dense flowerbeds.
	# These are deliberately a little larger than player collision, so animals avoid visually awkward areas.
	return [
		Rect2(Vector2(350, 420), Vector2(205, 115)), # left river curve
		Rect2(Vector2(500, 500), Vector2(145, 80)), # river lower left
		Rect2(Vector2(735, 500), Vector2(205, 85)), # river lower right
		Rect2(Vector2(845, 460), Vector2(145, 105)), # right river curve
		Rect2(Vector2(575, 305), Vector2(165, 165)), # family tree trunk/root
		Rect2(Vector2(230, 280), Vector2(210, 220)), # gazebo
		Rect2(Vector2(55, 35), Vector2(210, 190)), # upper-left house
		Rect2(Vector2(1040, 50), Vector2(210, 190)), # upper-right house
		Rect2(Vector2(35, 355), Vector2(205, 140)), # left middle house
		Rect2(Vector2(35, 515), Vector2(210, 170)), # left lower house
		Rect2(Vector2(900, 640), Vector2(350, 95)), # bottom fence / edge
		Rect2(Vector2(1085, 360), Vector2(95, 205)), # right fence area
		Rect2(Vector2(660, 80), Vector2(540, 70)), # upper fence
		Rect2(Vector2(430, 250), Vector2(135, 120)), # central flowerbed left
		Rect2(Vector2(765, 215), Vector2(290, 125)), # flowerbed / bench area
		Rect2(Vector2(910, 390), Vector2(210, 165)), # right flower garden
		Rect2(Vector2(375, 535), Vector2(155, 130)) # lower-left flower strip
	]

func _get_character_blocked_rects() -> Array:
	return [
		Rect2(Vector2(350, 420), Vector2(205, 115)),
		Rect2(Vector2(500, 500), Vector2(145, 80)),
		Rect2(Vector2(735, 500), Vector2(205, 85)),
		Rect2(Vector2(845, 460), Vector2(145, 105)),
		Rect2(Vector2(575, 305), Vector2(165, 165)),
		Rect2(Vector2(230, 280), Vector2(210, 220)),
		Rect2(Vector2(55, 35), Vector2(210, 190)),
		Rect2(Vector2(1040, 50), Vector2(210, 190)),
		Rect2(Vector2(35, 355), Vector2(205, 140)),
		Rect2(Vector2(35, 515), Vector2(210, 170)),
		Rect2(Vector2(900, 640), Vector2(350, 95)),
		Rect2(Vector2(1085, 360), Vector2(95, 205)),
		Rect2(Vector2(660, 80), Vector2(540, 70)),
	]

func _add_collision_zones() -> void:
	# MVP collision zones. They are intentionally approximate rectangles.
	# If a zone feels too restrictive, adjust its center/size here.
	_add_collision_rect("border_top", Vector2(640, -18), Vector2(1320, 36))
	_add_collision_rect("border_bottom", Vector2(640, 738), Vector2(1320, 36))
	_add_collision_rect("border_left", Vector2(-18, 360), Vector2(36, 760))
	_add_collision_rect("border_right", Vector2(1298, 360), Vector2(36, 760))

	# Water / bridge area: leave the bridge passable, block the main river curves.
	_add_collision_rect("water_left", Vector2(428, 470), Vector2(150, 110))
	_add_collision_rect("water_mid_left", Vector2(520, 530), Vector2(125, 58))
	_add_collision_rect("water_mid_right", Vector2(770, 530), Vector2(150, 60))
	_add_collision_rect("water_right", Vector2(895, 515), Vector2(120, 88))

	# Large objects. Character collision is only around feet, so these feel soft.
	_add_collision_rect("family_tree_trunk", Vector2(645, 375), Vector2(135, 120))
	_add_collision_rect("gazebo", Vector2(320, 395), Vector2(170, 175))

	# Houses. The visual sprites remain clickable; these bodies prevent walking through them.
	for house in HOUSE_DATA:
		var pos: Vector2 = house.get("pos", Vector2.ZERO)
		var height: float = float(house.get("height", 160.0))
		_add_collision_rect("house_collision_" + str(house.get("id", "house")), pos + Vector2(0, height * 0.10), Vector2(height * 0.86, height * 0.50))

	# A few fence / edge blocks. These are approximate and can be tuned later.
	_add_collision_rect("bottom_fence", Vector2(920, 655), Vector2(360, 70))
	_add_collision_rect("right_fence", Vector2(1122, 438), Vector2(52, 170))
	_add_collision_rect("upper_fence", Vector2(777, 97), Vector2(500, 50))

func _add_collision_rect(body_name: String, center: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = body_name
	body.position = center
	body.z_index = -20

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	world.add_child(body)
	return body

func _add_player(pos: Vector2, parent_override: Node = null) -> void:
	var asset_key := _current_player_asset_key()
	var display_name := MemoryManager.player_display_name if MemoryManager.player_display_name != "" else _default_name_for_role(MemoryManager.selected_role_key)
	# 角色贴图网格(hframes/vframes)以 CharacterDB/characters.json 为准,
	# 不同角色的行数可能不一样(如 girl 现在是 3x5,多一行待机眨眼帧)。
	var char_def: Dictionary = CharacterDB.get_def(asset_key)
	var char_hframes: int = int(char_def.get("hframes", 3))
	var char_vframes: int = int(char_def.get("vframes", 4))
	player = _create_character(display_name, ASSETS[asset_key], pos, true, char_hframes, char_vframes)
	player.name = "Player_" + MemoryManager.selected_role_key
	player.add_to_group("player")  # ScenePortal body_entered 仅认 player 组
	var parent := world if parent_override == null else parent_override
	parent.add_child(player)
	# player.gd 的 apply_character() 是唯一处理 frame_rects(非等分网格精确裁切)的地方。
	# 节点入树后再调用，避免从树外访问 /root/CharacterDB。
	if player.has_method("apply_character"):
		player.apply_character(asset_key)
	var parent_canvas := parent as CanvasItem
	if parent_canvas != null and parent_canvas.y_sort_enabled:
		var sort_origin_offset := 18.0
		player.position.y += sort_origin_offset
		for child in player.get_children():
			if child is Node2D:
				(child as Node2D).position.y -= sort_origin_offset
		player.z_index = 0


func _create_character(label_text: String, path: String, pos: Vector2, controllable: bool, hframes: int = 3, vframes: int = 4) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.position = pos
	body.z_index = int(pos.y)
	body.collision_layer = 1
	body.collision_mask = 1

	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.texture = _safe_texture("res://assets/characters/shadow.png")
	shadow.position = Vector2(0, 30)
	shadow.scale = Vector2(0.28, 0.16)
	shadow.modulate = Color(1, 1, 1, 0.8)
	body.add_child(shadow)

	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.name = "Sprite2D"
	var texture := _safe_texture(path)
	if texture:
		sprite.texture = texture
		sprite.hframes = hframes
		sprite.vframes = vframes
		sprite.frame = 0
		var frame_height := float(texture.get_height()) / float(vframes)
		if frame_height > 0.0:
			sprite.scale = Vector2.ONE * (82.0 / frame_height)
	else:
		sprite.texture = _solid_texture(32, 48, Color(0.92, 0.80, 0.62, 1.0))
		sprite.scale = Vector2(1.6, 1.6)
	body.add_child(sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 22)
	shape.shape = rect
	shape.position = Vector2(0, 18)
	body.add_child(shape)

	if controllable:
		body.set_script(preload("res://scripts/player.gd"))

	var name_label := Label.new()
	name_label.text = label_text
	name_label.visible = not controllable
	name_label.position = Vector2(-52, -66)
	name_label.size = Vector2(104, 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.z_as_relative = false
	name_label.z_index = 3900
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.add_theme_color_override("font_outline_color", Color(1.0, 0.96, 0.82, 0.92))
	name_label.add_theme_color_override("font_color", Color(0.20, 0.17, 0.13, 0.96))
	body.add_child(name_label)

	return body


func _add_online_status_badge(parent: Node2D, online: bool) -> void:
	var dot := Label.new()
	dot.name = "OnlineStatus"
	dot.text = "●"
	dot.position = Vector2(34, -79)
	dot.size = Vector2(20, 18)
	dot.z_as_relative = false
	dot.z_index = 3901
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_theme_font_size_override("font_size", 14)
	dot.add_theme_color_override("font_color", Color(0.22, 0.78, 0.36, 1.0) if online else Color(0.55, 0.52, 0.48, 0.88))
	parent.add_child(dot)

func _add_static_sprite(node_name: String, path: String, pos: Vector2, target_height: float) -> Sprite2D:
	var texture := _safe_texture(path)
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.name = node_name
	sprite.centered = true
	sprite.position = pos
	sprite.z_index = int(pos.y + target_height * 0.35)
	if texture:
		sprite.texture = texture
		var scale_factor := target_height / float(texture.get_height())
		sprite.scale = Vector2.ONE * scale_factor
	else:
		sprite.texture = _solid_texture(96, 64, Color(0.95, 0.83, 0.58, 1.0))
	world.add_child(sprite)
	return sprite

func _add_interactable_sprite(
	node_name: String,
	path: String,
	pos: Vector2,
	target_height: float,
	action: String,
	label_text: String,
	click_size: Vector2 = Vector2.ZERO,
	click_offset: Vector2 = Vector2.ZERO
) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.position = pos
	# Draw order is based on the object base: lower objects appear in front.
	root.z_index = int(pos.y + target_height * 0.35)
	world.add_child(root)

	var texture := _safe_texture(path)
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	var sprite_size := Vector2(80, 80)
	if texture:
		sprite.texture = texture
		var scale_factor := target_height / float(texture.get_height())
		sprite.scale = Vector2.ONE * scale_factor
		sprite_size = Vector2(texture.get_width() * scale_factor, texture.get_height() * scale_factor)
	else:
		sprite.texture = _solid_texture(120, 90, Color(0.94, 0.84, 0.64, 1.0))
		sprite_size = Vector2(120, 90)
	root.add_child(sprite)

	var final_click_size := click_size
	if final_click_size == Vector2.ZERO:
		final_click_size = sprite_size
	_add_click_area(root, final_click_size, action, label_text, click_offset)
	return root

func _add_click_area(parent: Node2D, area_size: Vector2, action: String, label_text: String, offset: Vector2 = Vector2.ZERO) -> void:
	var area := Area2D.new()
	area.name = "ClickArea"
	area.position = offset
	area.input_pickable = true
	area.monitoring = true
	area.monitorable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = area_size
	shape.shape = rect
	area.add_child(shape)
	area.input_event.connect(_on_interactable_input.bind(action, label_text))
	parent.add_child(area)

func _on_interactable_input(_viewport: Node, event: InputEvent, _shape_idx: int, action: String, label_text: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_handle_action(action, label_text)

func _handle_action(action: String, label_text: String) -> void:
	if action == "tree":
		_open_family_tree_panel()
	elif action.begins_with("house:"):
		var house_id := action.split(":")[1]
		_enter_house(house_id, label_text)
	elif action.begins_with("npc:"):
		var npc_id := action.split(":")[1]
		_open_npc_dialog(npc_id, label_text)
	elif action.begins_with("place:"):
		var place_id := action.split(":")[1]
		_open_postcard_for_place(place_id)
	elif action.begins_with("animal:"):
		var animal_id := action.split(":")[1]
		_open_animal_dialog(animal_id, label_text)

func _enter_house(id: String, label_text: String) -> void:
	_close_active_panel()
	_clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	_clear_gate4_guide()

	mode = "room"
	adding_place = false
	_clear_world()
	plant_mode = false
	_update_plant_button()

	var room_info: Dictionary = _get_room_data(id)
	var room_label: String = str(room_info.get("label", label_text))
	info_label.text = room_label

	var saved_room := MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
	if id == "player" and not saved_room.is_empty() and ROOM_SCENE_GENERATOR.has_scene_schema(saved_room):
		var rendered: Dictionary = ROOM_SCENE_GENERATOR.render_scene(saved_room, world)
		if bool(rendered.get("ok", false)):
			_add_player(ROOM_SCENE_GENERATOR.spawn_position(saved_room, room_info.get("spawn", Vector2(640, 560))))
			_render_room("player")
			_add_room_hint_panel(room_label, id)
			_show_gate4_scene_guide("room")
			return
		else:
			push_warning("[SceneManager] 语义房间渲染失败: " + str(rendered.get("errors", [])))

	# 样板（增量迁移 §7）：玩家房间用编辑器场景 AnnaRoom.tscn（静态背景+碰撞），
	# 玩家/提示面板/返回流程仍复用代码。其他 3 间保持原过程化构建。
	if id == "player" and ResourceLoader.exists(ANNA_ROOM_SCENE):
		world.add_child((load(ANNA_ROOM_SCENE) as PackedScene).instantiate())
		_add_player(room_info.get("spawn", Vector2(640, 560)))
		_render_room("player")  # 渲染已落库的房间家具（关游戏重开仍在）
		_add_room_hint_panel(room_label, id)
		_show_gate4_scene_guide("room")
		return

	var room_rect: Rect2 = _add_room_background(str(room_info.get("asset", "")))
	_add_room_collision_zones(id, room_rect)

	var spawn: Vector2 = room_info.get("spawn", Vector2(640, 560))
	_add_player(spawn)

	# Optional true occlusion layer:
	# If you later add assets/rooms/papa_room_fg.png etc., it will be drawn above the player.
	_add_room_foreground_if_exists(str(room_info.get("foreground", "")), room_rect)
	_add_room_hint_panel(room_label, id)
	if id == "player":
		_show_gate4_scene_guide("room")


func _get_room_data(house_id: String) -> Dictionary:
	if ROOM_DATA.has(house_id):
		return ROOM_DATA[house_id]

	return {
		"label": "Family Room",
		"asset": "",
		"foreground": "",
		"spawn": Vector2(640, 560),
	}


func _add_room_background(asset_key: String) -> Rect2:
	var backdrop := Sprite2D.new()
	backdrop.name = "RoomBackdrop"
	backdrop.texture = _solid_texture(int(GAME_SIZE.x), int(GAME_SIZE.y), Color(0.72, 0.66, 0.54, 1.0))
	backdrop.centered = true
	backdrop.position = GAME_SIZE / 2.0
	backdrop.z_index = -100
	world.add_child(backdrop)

	var texture := _safe_texture(str(ASSETS.get(asset_key, "")))
	var room_sprite := Sprite2D.new()
	room_sprite.name = "RoomBackground"
	room_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	room_sprite.centered = true
	room_sprite.position = GAME_SIZE / 2.0
	room_sprite.z_index = -80

	var room_rect := Rect2(Vector2.ZERO, GAME_SIZE)
	if texture:
		room_sprite.texture = texture
		var scale_factor: float = minf(GAME_SIZE.x / float(texture.get_width()), GAME_SIZE.y / float(texture.get_height()))
		room_sprite.scale = Vector2.ONE * scale_factor
		var displayed_size := Vector2(float(texture.get_width()), float(texture.get_height())) * scale_factor
		room_rect = Rect2((GAME_SIZE - displayed_size) * 0.5, displayed_size)
	else:
		room_sprite.texture = _solid_texture(1280, 720, Color(0.95, 0.89, 0.78, 1.0))

	world.add_child(room_sprite)
	return room_rect


func _add_room_foreground_if_exists(foreground_asset_key: String, room_rect: Rect2) -> void:
	var foreground_path := str(ASSETS.get(foreground_asset_key, ""))
	if foreground_path == "" or not ResourceLoader.exists(foreground_path):
		return

	var texture := _safe_texture(foreground_path)
	if texture == null:
		return

	var sprite := Sprite2D.new()
	sprite.name = "RoomForeground"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = room_rect.position + room_rect.size * 0.5
	sprite.z_index = 3900
	var scale_factor: float = minf(room_rect.size.x / float(texture.get_width()), room_rect.size.y / float(texture.get_height()))
	sprite.scale = Vector2.ONE * scale_factor
	world.add_child(sprite)


func _add_room_hint_panel(room_label: String, house_id: String) -> void:
	var is_player := house_id == "player"
	var panel := Panel.new()
	room_card = panel
	panel.position = Vector2(22, 86)
	panel.size = Vector2(292, 214 if is_player else 156)  # 玩家房间多一行"上传房间照片"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	ui_layer.add_child(panel)

	var title := Label.new()
	title.text = room_label
	title.position = Vector2(18, 14)
	title.size = Vector2(250, 28)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var body := Label.new()
	if is_player:
		var room := MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
		var object_count := 0 if room.is_empty() else MemoryManager.get_room_objects(String(room.get("id", ""))).size()
		var generated := "语义室内已生成" if not room.is_empty() and ROOM_SCENE_GENERATOR.has_scene_schema(room) else "%d 件物件已摆放" % object_count
		body.text = "拍一张房间照片，AI 会先给出可确认的布局草稿。\n当前：%s" % ("尚未生成 AI 房间" if room.is_empty() else generated)
	else:
		body.text = "在房间里走走看看，返回花园时会保留当前位置。"
	body.position = Vector2(18, 48)
	body.size = Vector2(250, 60 if is_player else 42)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color(0.36, 0.30, 0.23, 0.90))
	panel.add_child(body)

	var btn_y := 168 if is_player else 104
	if is_player:
		var room_action := "管理 AI 房间" if not MemoryManager.get_room_for_user(MemoryManager.selected_role_key).is_empty() else "照片生成房间"
		_add_panel_button(panel, room_action, Vector2(18, 122), Vector2(256, 34), "generate_room:" + house_id)
	_add_panel_button(panel, "便签", Vector2(18, btn_y), Vector2(78, 34), "house_note:" + house_id)
	_add_panel_button(panel, "明信片", Vector2(106, btn_y), Vector2(82, 34), "MemoryManager.postcards")
	_add_panel_button(panel, "返回", Vector2(198, btn_y), Vector2(76, 34), "back_garden")

# 上传房间照片 → 本地压缩 → 受控上传 → AI 草稿 → 用户确认后布局。
func _on_generate_room(house_id: String) -> void:
	if house_id != "player":
		return
	if not MemoryManager.get_room_for_user(MemoryManager.selected_role_key).is_empty():
		_open_room_management()
		return
	_open_room_photo_form()

func _open_room_management() -> void:
	_close_active_panel()
	var room := MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
	var overlay := _create_modal_overlay()
	active_modal = overlay
	var panel := Panel.new()
	panel.position = Vector2(370, 190)
	panel.size = Vector2(540, 330)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)
	var title := Label.new()
	title.text = "管理我的 AI 房间"
	title.position = Vector2(34, 26)
	title.size = Vector2(460, 34)
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)
	var summary := Label.new()
	var scene_badge := " · 语义室内" if ROOM_SCENE_GENERATOR.has_scene_schema(room) else ""
	summary.text = "%s · %s · %d 件家具%s" % [_room_theme_display_label(String(room.get("room_name", "我的房间"))), _room_style_display_label(String(room.get("style", ""))), MemoryManager.get_room_objects(String(room.get("id", ""))).size(), scene_badge]
	summary.position = Vector2(34, 82)
	summary.size = Vector2(470, 50)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(summary)
	var status := _make_status_label(panel, Vector2(34, 142), Vector2(470, 32), "换照片会先生成新预览，确认后才替换当前房间。")
	var reanalyze := Button.new()
	reanalyze.text = "换照片重新分析"
	reanalyze.position = Vector2(70, 188)
	reanalyze.size = Vector2(180, 42)
	_apply_button_style(reanalyze, false)
	reanalyze.pressed.connect(_open_room_photo_form)
	panel.add_child(reanalyze)
	var remove := Button.new()
	remove.text = "删除房间"
	remove.position = Vector2(290, 188)
	remove.size = Vector2(180, 42)
	_apply_button_style(remove, false)
	remove.pressed.connect(_delete_current_ai_room.bind(remove, status))
	panel.add_child(remove)

func _delete_current_ai_room(button: Button, status: Label) -> void:
	var room := MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
	if room.is_empty():
		return
	if not bool(button.get_meta("confirm_delete_room", false)):
		button.set_meta("confirm_delete_room", true)
		button.text = "再次点击删除"
		_set_status(status, "会删除 AI 房间、家具和关联照片；这个操作不能撤销。", true)
		return
	_set_button_busy(button, "正在删除...")
	_set_status(status, "正在删除房间和临时照片...")
	var source_id := String(room.get("source_memory_id", ""))
	var source := MemoryManager.get_memory(source_id)
	var upload_id := String(source.get("upload_id", ""))
	MemoryManager.delete_room(String(room.get("id", "")))
	if source_id != "":
		MemoryManager.delete_memory(source_id)
	if upload_id != "":
		await CloudManager.delete_ai_image(upload_id)
	_close_active_panel()
	_enter_house("player", "我的房间")
	_show_toast("AI 房间及照片已删除。")

func _open_room_photo_form() -> void:
	_reset_selected_photo_state()
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay
	var panel := Panel.new()
	panel.position = Vector2(330, 135)
	panel.size = Vector2(620, 450)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)
	var title := Label.new()
	title.text = "用照片生成我的房间"
	title.position = Vector2(34, 26)
	title.size = Vector2(550, 34)
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)
	var info := Label.new()
	info.text = "支持 JPEG、PNG、WebP，原图不超过 12 MB。确认布局前不会创建房间。"
	info.position = Vector2(34, 78)
	info.size = Vector2(550, 54)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(info)
	var choose := Button.new()
	choose.text = "选择房间照片"
	choose.position = Vector2(34, 160)
	choose.size = Vector2(180, 42)
	_apply_button_style(choose, false)
	choose.pressed.connect(_choose_photo_for_place)
	panel.add_child(choose)
	selected_photo_label = Label.new()
	selected_photo_label.text = "未选择照片"
	selected_photo_label.position = Vector2(230, 168)
	selected_photo_label.size = Vector2(350, 28)
	panel.add_child(selected_photo_label)
	var status := _make_status_label(panel, Vector2(34, 226), Vector2(550, 52), "选择照片后会先在本机压缩，再安全上传给 AI 分析。")
	var analyze := Button.new()
	analyze.text = "上传并分析"
	analyze.position = Vector2(210, 310)
	analyze.size = Vector2(200, 44)
	_apply_button_style(analyze, false)
	analyze.pressed.connect(_analyze_selected_room_photo.bind(analyze, status))
	panel.add_child(analyze)

func _analyze_selected_room_photo(button: Button, status: Label) -> void:
	var photo := _selected_gate4_photo()
	if (photo.get("bytes", PackedByteArray()) as PackedByteArray).is_empty():
		_set_status(status, "请先选择一张房间照片。", true)
		_show_toast("请先选择一张房间照片。")
		return
	_set_button_busy(button, "分析中...")
	_watch_ai_workflow("room", status, "正在准备房间照片...")
	var draft: Dictionary = await AIWorkflowManager.prepare_room_draft(photo.get("bytes", PackedByteArray()), String(photo.get("content_type", "")))
	if not bool(draft.get("ok", false)):
		_set_button_ready(button, "重试分析")
		var message := _result_error_message(draft, "房间分析失败。")
		_set_status(status, message, true)
		_show_toast(message)
		_clear_ai_workflow_watch(status)
		return
	_clear_ai_workflow_watch(status)
	_open_room_draft_preview(draft)

func _open_room_draft_preview(draft: Dictionary) -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay
	var panel := Panel.new()
	panel.position = Vector2(300, 82)
	panel.size = Vector2(680, 556)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)
	var analysis: Dictionary = draft.get("analysis", {})
	var title := Label.new()
	title.text = "语义房间预览" + (" · 示例回退布局" if bool(draft.get("used_fallback", false)) else "")
	title.position = Vector2(34, 24)
	title.size = Vector2(612, 34)
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)
	var description := Label.new()
	description.text = String(analysis.get("description", ""))
	description.position = Vector2(34, 74)
	description.size = Vector2(612, 64)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(description)
	var object_lines: Array[String] = []
	for object in draft.get("layout", {}).get("objects", []):
		object_lines.append("• %s → %s" % [_room_object_display_label(String(object.get("object_type", ""))), _zone_display_label(String(object.get("zone", "")))])
	if object_lines.is_empty():
		object_lines.append("没有可安全摆放的家具。")
	_add_room_preview_map(panel, Vector2(34, 154), Vector2(334, 210), draft.get("layout", {}).get("objects", []), draft.get("layout", {}).get("scene_schema", {}))
	var objects := Label.new()
	objects.text = "将摆放的家具\n" + "\n".join(object_lines)
	objects.position = Vector2(392, 154)
	objects.size = Vector2(254, 210)
	objects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objects.add_theme_font_size_override("font_size", 14)
	objects.add_theme_color_override("font_color", Color(0.28, 0.23, 0.17, 0.94))
	panel.add_child(objects)
	var meta: Dictionary = draft.get("generation_meta", {})
	var trace := Label.new()
	trace.text = "来源 %s · %s · %s" % [String(meta.get("source", "unknown")), String(meta.get("model", "unknown")), String(meta.get("prompt_version", "unknown"))]
	trace.position = Vector2(34, 382)
	trace.size = Vector2(612, 36)
	trace.add_theme_font_size_override("font_size", 12)
	panel.add_child(trace)
	var status := _make_status_label(panel, Vector2(34, 426), Vector2(612, 24), "这是预览草稿；确认后才会创建或替换可探索的语义房间。")
	var cancel := Button.new()
	cancel.text = "取消并清理照片"
	cancel.position = Vector2(86, 458)
	cancel.size = Vector2(180, 42)
	_apply_button_style(cancel, false)
	cancel.pressed.connect(_discard_draft_and_close.bind(draft))
	panel.add_child(cancel)
	var confirm := Button.new()
	confirm.text = "确认布局"
	confirm.position = Vector2(414, 458)
	confirm.size = Vector2(180, 42)
	_apply_button_style(confirm, false)
	confirm.pressed.connect(_commit_room_preview.bind(draft, confirm, status))
	panel.add_child(confirm)

func _add_room_preview_map(parent: Control, pos: Vector2, map_size: Vector2, objects: Array, schema: Dictionary = {}) -> void:
	var map := Panel.new()
	map.name = "RoomPreviewMap"
	map.position = pos
	map.size = map_size
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.94, 0.88, 0.76, 0.78)
	style.border_color = Color(0.55, 0.40, 0.26, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	map.add_theme_stylebox_override("panel", style)
	parent.add_child(map)
	if not schema.is_empty():
		_add_room_schema_preview(map, map_size, schema)
		return

	var zones := {
		"back_wall": Rect2(18, 14, 298, 28),
		"back_left": Rect2(28, 58, 82, 34),
		"back_center": Rect2(126, 58, 82, 34),
		"back_right": Rect2(224, 58, 82, 34),
		"left_side": Rect2(28, 110, 72, 44),
		"right_side": Rect2(234, 110, 72, 44),
		"front_left": Rect2(46, 168, 74, 28),
		"front_center": Rect2(130, 168, 74, 28),
		"front_right": Rect2(214, 168, 74, 28),
		"floor_center": Rect2(122, 112, 90, 40),
	}
	var zone_counts: Dictionary = {}
	for object in objects:
		var zone := String((object as Dictionary).get("zone", "")) if object is Dictionary else ""
		zone_counts[zone] = int(zone_counts.get(zone, 0)) + 1

	for zone_key in zones.keys():
		var rect: Rect2 = zones[zone_key]
		var tile := ColorRect.new()
		tile.position = rect.position
		tile.size = rect.size
		tile.color = Color(0.72, 0.60, 0.44, 0.22 + minf(0.28, float(zone_counts.get(zone_key, 0)) * 0.12))
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map.add_child(tile)
		if zone_counts.has(zone_key):
			var mark := Label.new()
			mark.text = str(zone_counts[zone_key])
			mark.position = rect.position + rect.size * 0.5 - Vector2(8, 10)
			mark.size = Vector2(16, 20)
			mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mark.add_theme_font_size_override("font_size", 13)
			mark.add_theme_color_override("font_color", Color(0.24, 0.18, 0.12, 0.95))
			map.add_child(mark)

	var title := Label.new()
	title.text = "布局小地图"
	title.position = Vector2(16, 184)
	title.size = Vector2(140, 18)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.42, 0.32, 0.22, 0.78))
	map.add_child(title)

func _add_room_schema_preview(map: Control, map_size: Vector2, schema: Dictionary) -> void:
	var grid: Array = schema.get("grid_size", [34, 22])
	var grid_size := Vector2(maxf(1.0, float(grid[0])), maxf(1.0, float(grid[1]))) if grid.size() >= 2 else Vector2(34, 22)
	var scale := minf((map_size.x - 28.0) / grid_size.x, (map_size.y - 34.0) / grid_size.y)
	var origin := Vector2(14, 12)
	var floor := ColorRect.new()
	floor.position = origin
	floor.size = grid_size * scale
	floor.color = Color(0.86, 0.72, 0.52, 0.42)
	floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(floor)
	var wall := ColorRect.new()
	wall.position = origin
	wall.size = Vector2(grid_size.x * scale, 2.0 * scale)
	wall.color = Color(0.56, 0.44, 0.34, 0.40)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(wall)
	for raw in schema.get("objects", []):
		if not (raw is Dictionary):
			continue
		var obj: Dictionary = raw
		var cell: Array = obj.get("cell", [0, 0])
		var size: Array = obj.get("size", [1, 1])
		if cell.size() < 2 or size.size() < 2:
			continue
		var marker := ColorRect.new()
		marker.position = origin + Vector2(float(cell[0]), float(cell[1])) * scale
		marker.size = Vector2(maxf(1.0, float(size[0]) * scale), maxf(1.0, float(size[1]) * scale))
		marker.color = _room_preview_color(String(obj.get("id", "")))
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map.add_child(marker)
	var title := Label.new()
	title.text = "语义网格"
	title.position = Vector2(16, 184)
	title.size = Vector2(140, 18)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.42, 0.32, 0.22, 0.78))
	map.add_child(title)

func _room_preview_color(object_id: String) -> Color:
	match object_id:
		"bed":
			return Color(0.58, 0.72, 0.86, 0.72)
		"desk":
			return Color(0.64, 0.46, 0.30, 0.72)
		"lamp":
			return Color(0.98, 0.78, 0.34, 0.76)
		"plant":
			return Color(0.42, 0.68, 0.40, 0.74)
		"photo_wall":
			return Color(0.74, 0.54, 0.86, 0.68)
		"chair":
			return Color(0.50, 0.60, 0.74, 0.72)
		_:
			return Color(0.74, 0.60, 0.42, 0.68)

func _room_object_display_label(object_type: String) -> String:
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
			return object_type

func _room_theme_display_label(theme_key: String) -> String:
	match theme_key:
		"study_corner":
			return "温暖学习角"
		"memory_corner":
			return "记忆角落"
		"cozy_bedroom":
			return "温暖卧室"
		_:
			return theme_key.replace("_", " ")

func _room_style_display_label(style_key: String) -> String:
	match style_key:
		"warm_cozy":
			return "温暖舒适"
		"minimal":
			return "简洁"
		"vintage":
			return "怀旧"
		_:
			return style_key.replace("_", " ")

func _zone_display_label(zone: String) -> String:
	match zone:
		"back_wall":
			return "后墙"
		"back_left":
			return "后左"
		"back_center":
			return "后中"
		"back_right":
			return "后右"
		"left_side":
			return "左侧"
		"right_side":
			return "右侧"
		"front_left":
			return "前左"
		"front_center":
			return "前中"
		"front_right":
			return "前右"
		"floor_center":
			return "地面中心"
		_:
			return zone

func _commit_room_preview(draft: Dictionary, button: Button, status: Label) -> void:
	_set_button_busy(button, "正在保存...")
	_set_status(status, "正在写入房间和家具位置...")
	var result: Dictionary = await AIWorkflowManager.commit_room_draft(draft)
	if not bool(result.get("ok", false)):
		_set_button_ready(button, "确认布局")
		var message := _result_error_message(result, "房间保存失败。")
		_set_status(status, message, true)
		_show_toast(message)
		return
	_close_active_panel()
	_enter_house("player", "我的房间")
	_show_toast("房间生成好了。")

# 渲染玩家房间已落库的家具（重入/重启后重建）。
func _render_room(house_id: String) -> void:
	_room_objects.clear()
	if house_id != "player":
		return
	var room := MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
	if room.is_empty():
		return
	var n := RoomLayoutManager.render(String(room.get("id", "")), world, _on_room_object_clicked)
	print("[SceneManager] room 家具 rendered=", n, " zone 用量=", ZoneManager.usage("room"))

func _on_room_object_clicked(obj_id: String) -> void:
	for o in MemoryManager.room_objects:
		if o is Dictionary and String(o.get("id", "")) == obj_id:
			_open_room_object_editor(o)
			return
	_show_toast("房间里的物件")

func _open_room_object_editor(object: Dictionary) -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay
	var panel := Panel.new()
	panel.position = Vector2(400, 190)
	panel.size = Vector2(480, 350)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)
	var title := Label.new()
	title.text = "调整家具：" + String(object.get("object_type", "物件"))
	title.position = Vector2(30, 26)
	title.size = Vector2(400, 34)
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)
	var zone_select := OptionButton.new()
	zone_select.position = Vector2(30, 100)
	zone_select.size = Vector2(420, 40)
	var zones: Array = ["back_wall"] if String(object.get("object_type", "")) == "photo_wall" else AIContractValidator.ROOM_ZONES.filter(func(zone): return zone != "back_wall")
	for zone in zones:
		zone_select.add_item(String(zone))
		zone_select.set_item_metadata(zone_select.item_count - 1, String(zone))
		if String(zone) == String(object.get("zone", "")):
			zone_select.select(zone_select.item_count - 1)
	panel.add_child(zone_select)
	var status := _make_status_label(panel, Vector2(30, 154), Vector2(420, 34), "选择一个区域后保存；如果没有空位，可以换一个区域。")
	var move := Button.new()
	move.text = "移动到所选区域"
	move.position = Vector2(40, 210)
	move.size = Vector2(180, 42)
	_apply_button_style(move, false)
	move.pressed.connect(_move_room_object.bind(String(object.get("id", "")), zone_select, move, status))
	panel.add_child(move)
	var remove := Button.new()
	remove.text = "删除这件家具"
	remove.position = Vector2(260, 210)
	remove.size = Vector2(180, 42)
	_apply_button_style(remove, false)
	remove.pressed.connect(_delete_room_object.bind(String(object.get("id", "")), remove, status))
	panel.add_child(remove)

func _move_room_object(object_id: String, zone_select: OptionButton, button: Button, status: Label) -> void:
	_set_button_busy(button, "正在移动...")
	if not RoomLayoutManager.move_object(object_id, String(zone_select.get_selected_metadata())):
		_set_button_ready(button, "移动到所选区域")
		var message := "这个区域没有合适的空位，请换一个区域。"
		_set_status(status, message, true)
		_show_toast(message)
		return
	_close_active_panel()
	_enter_house("player", "我的房间")
	_show_toast("家具位置已更新。")

func _delete_room_object(object_id: String, button: Button, status: Label) -> void:
	if not bool(button.get_meta("confirm_delete_object", false)):
		button.set_meta("confirm_delete_object", true)
		button.text = "再次点击删除"
		_set_status(status, "会删除这件家具，房间里的其他家具不受影响。", true)
		return
	if MemoryManager.delete_room_object(object_id):
		_close_active_panel()
		_enter_house("player", "我的房间")
		_show_toast("家具已删除。")


func _add_room_collision_zones(room_id: String, room_rect: Rect2) -> void:
	# Block the empty area outside the visible room image.
	_add_room_outer_boundaries(room_rect)

	# Common wall strips inside the room.
	_add_room_block(room_rect, "room_top_wall", Rect2(Vector2(0.00, 0.00), Vector2(1.00, 0.08)))
	_add_room_block(room_rect, "room_bottom_wall", Rect2(Vector2(0.00, 0.965), Vector2(1.00, 0.04)))
	_add_room_block(room_rect, "room_left_wall", Rect2(Vector2(0.00, 0.00), Vector2(0.025, 1.00)))
	_add_room_block(room_rect, "room_right_wall", Rect2(Vector2(0.975, 0.00), Vector2(0.025, 1.00)))

	match room_id:
		"father":
			_add_room_block(room_rect, "papa_bed", Rect2(Vector2(0.05, 0.06), Vector2(0.35, 0.24)))
			_add_room_block(room_rect, "papa_shelf", Rect2(Vector2(0.45, 0.07), Vector2(0.38, 0.13)))
			_add_room_block(room_rect, "papa_bath", Rect2(Vector2(0.05, 0.70), Vector2(0.32, 0.22)))
			_add_room_block(room_rect, "papa_lower_furniture", Rect2(Vector2(0.55, 0.70), Vector2(0.35, 0.22)))
			_add_room_block(room_rect, "papa_side_stairs", Rect2(Vector2(0.44, 0.38), Vector2(0.12, 0.24)))
		"mother":
			_add_room_block(room_rect, "mama_bed", Rect2(Vector2(0.05, 0.05), Vector2(0.28, 0.25)))
			_add_room_block(room_rect, "mama_greenhouse", Rect2(Vector2(0.58, 0.04), Vector2(0.34, 0.28)))
			_add_room_block(room_rect, "mama_lower_bath", Rect2(Vector2(0.05, 0.70), Vector2(0.28, 0.22)))
			_add_room_block(room_rect, "mama_wardrobe", Rect2(Vector2(0.65, 0.45), Vector2(0.28, 0.22)))
		"partner":
			_add_room_block(room_rect, "louis_camera_wall", Rect2(Vector2(0.04, 0.06), Vector2(0.44, 0.22)))
			_add_room_block(room_rect, "louis_greenhouse", Rect2(Vector2(0.56, 0.05), Vector2(0.38, 0.24)))
			_add_room_block(room_rect, "louis_bed", Rect2(Vector2(0.04, 0.62), Vector2(0.30, 0.23)))
			_add_room_block(room_rect, "louis_bath", Rect2(Vector2(0.76, 0.62), Vector2(0.20, 0.25)))
		"player":
			_add_room_block(room_rect, "anna_study", Rect2(Vector2(0.04, 0.05), Vector2(0.38, 0.25)))
			_add_room_block(room_rect, "anna_bed", Rect2(Vector2(0.72, 0.06), Vector2(0.24, 0.25)))
			_add_room_block(room_rect, "anna_kitchen", Rect2(Vector2(0.04, 0.62), Vector2(0.32, 0.26)))
			_add_room_block(room_rect, "anna_sofa", Rect2(Vector2(0.68, 0.54), Vector2(0.27, 0.25)))
			_add_room_block(room_rect, "anna_stairs", Rect2(Vector2(0.42, 0.34), Vector2(0.17, 0.24)))
		_:
			pass


func _add_room_outer_boundaries(room_rect: Rect2) -> void:
	var margin: float = 80.0

	if room_rect.position.y > 0.0:
		_add_collision_rect("room_outside_top", Vector2(GAME_SIZE.x * 0.5, room_rect.position.y * 0.5), Vector2(GAME_SIZE.x + margin, room_rect.position.y + margin))

	var bottom_h: float = GAME_SIZE.y - room_rect.end.y
	if bottom_h > 0.0:
		_add_collision_rect("room_outside_bottom", Vector2(GAME_SIZE.x * 0.5, room_rect.end.y + bottom_h * 0.5), Vector2(GAME_SIZE.x + margin, bottom_h + margin))

	if room_rect.position.x > 0.0:
		_add_collision_rect("room_outside_left", Vector2(room_rect.position.x * 0.5, GAME_SIZE.y * 0.5), Vector2(room_rect.position.x + margin, GAME_SIZE.y + margin))

	var right_w: float = GAME_SIZE.x - room_rect.end.x
	if right_w > 0.0:
		_add_collision_rect("room_outside_right", Vector2(room_rect.end.x + right_w * 0.5, GAME_SIZE.y * 0.5), Vector2(right_w + margin, GAME_SIZE.y + margin))


func _add_room_block(room_rect: Rect2, block_name: String, normalized_rect: Rect2) -> void:
	var center := room_rect.position + Vector2(
		(normalized_rect.position.x + normalized_rect.size.x * 0.5) * room_rect.size.x,
		(normalized_rect.position.y + normalized_rect.size.y * 0.5) * room_rect.size.y
	)
	var size := Vector2(
		normalized_rect.size.x * room_rect.size.x,
		normalized_rect.size.y * room_rect.size.y
	)
	_add_collision_rect(block_name, center, size)


func _remove_room_card_and_back(card: Panel) -> void:
	if card != null and is_instance_valid(card):
		card.queue_free()
	room_card = null
	_show_garden()

func _show_travel_map() -> void:
	_close_active_panel()
	_clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	mode = "map"
	plant_mode = false
	_update_plant_button()
	_clear_world()
	info_label.text = "旅行地图"
	_add_travel_map_background()
	_rebuild_travel_pins()
	_build_map_ui()

func _add_travel_map_background() -> void:
	var texture := _safe_texture(ASSETS["travel_map"])
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.name = "TravelMapBackground"
	sprite.position = GAME_SIZE / 2.0
	if texture:
		sprite.texture = texture
		var scale_factor = max(GAME_SIZE.x / float(texture.get_width()), GAME_SIZE.y / float(texture.get_height()))
		sprite.scale = Vector2.ONE * scale_factor
	else:
		sprite.texture = _solid_texture(1280, 720, Color(0.80, 0.92, 0.92, 1.0))
	world.add_child(sprite)

func _build_map_ui() -> void:
	map_ui = Control.new()
	map_ui.name = "TravelMapUI"
	map_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(map_ui)

	var add_btn := Button.new()
	add_btn.text = "Add Place"
	add_btn.position = Vector2(1086, 24)
	add_btn.size = Vector2(130, 38)
	add_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_style(add_btn, false)
	_set_button_icon(add_btn, "icon_add")
	add_btn.pressed.connect(_start_add_place)
	map_ui.add_child(add_btn)

	var hint := Label.new()
	hint.text = "Add memories by placing a pin on the map."
	hint.position = Vector2(850, 68)
	hint.size = Vector2(390, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.25, 0.22, 0.18, 0.85))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_ui.add_child(hint)

func _start_add_place() -> void:
	_close_active_panel()
	adding_place = true
	_show_toast("Click a location on the travel map.")

func _open_add_place_form(pos: Vector2) -> void:
	adding_place = false
	pending_place_position = pos
	_reset_selected_photo_state()
	_close_active_panel()

	var overlay := _create_modal_overlay()
	active_modal = overlay
	var panel := Panel.new()
	panel.position = Vector2(360, 125)
	panel.size = Vector2(560, 470)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = "添加旅行地点"
	title.position = Vector2(34, 24)
	title.size = Vector2(492, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var name_label := Label.new()
	name_label.text = "城市 / 地点名"
	name_label.position = Vector2(34, 76)
	name_label.size = Vector2(492, 22)
	name_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(name_label)

	var title_input := LineEdit.new()
	title_input.placeholder_text = "Zurich, Paris, Shanghai..."
	title_input.position = Vector2(34, 102)
	title_input.size = Vector2(492, 36)
	panel.add_child(title_input)

	var note_label := Label.new()
	note_label.text = "记忆留言"
	note_label.position = Vector2(34, 150)
	note_label.size = Vector2(492, 22)
	note_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(note_label)

	var note_input := TextEdit.new()
	note_input.placeholder_text = "写下这个地方带回来的小记忆..."
	note_input.position = Vector2(34, 176)
	note_input.size = Vector2(492, 92)
	panel.add_child(note_input)

	var photo_label_title := Label.new()
	photo_label_title.text = "照片"
	photo_label_title.position = Vector2(34, 286)
	photo_label_title.size = Vector2(492, 22)
	photo_label_title.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(photo_label_title)

	var choose_photo_button := Button.new()
	choose_photo_button.text = "选择照片"
	choose_photo_button.position = Vector2(34, 314)
	choose_photo_button.size = Vector2(150, 38)
	choose_photo_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_style(choose_photo_button, false)
	_set_button_icon(choose_photo_button, "icon_camera")
	choose_photo_button.pressed.connect(_choose_photo_for_place)
	panel.add_child(choose_photo_button)

	selected_photo_label = Label.new()
	selected_photo_label.text = "未选择照片"
	selected_photo_label.position = Vector2(198, 320)
	selected_photo_label.size = Vector2(328, 28)
	selected_photo_label.add_theme_font_size_override("font_size", 13)
	selected_photo_label.add_theme_color_override("font_color", Color(0.43, 0.35, 0.27, 0.95))
	panel.add_child(selected_photo_label)

	var hint := Label.new()
	hint.text = "桌面端会打开文件选择器，Web 端会打开浏览器照片选择器。"
	hint.position = Vector2(34, 360)
	hint.size = Vector2(492, 24)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.45, 0.38, 0.30, 0.75))
	panel.add_child(hint)

	_add_panel_button(panel, "保存地点", Vector2(126, 404), Vector2(140, 40), "save_new_place", [title_input, note_input])
	_add_panel_button(panel, "取消", Vector2(300, 404), Vector2(120, 40), "close")

func _save_new_place(title_input: LineEdit, note_input: TextEdit) -> void:
	var place_title: String = title_input.text.strip_edges()
	if place_title == "":
		place_title = "未命名地点"
	var place_note: String = note_input.text.strip_edges()
	if place_note == "":
		place_note = "这个地方带回来一段小小的记忆。"

	var place_id: String = "place_" + str(Time.get_ticks_msec())
	var postcard_id: String = "postcard_" + str(Time.get_ticks_msec())
	var uploaded_photo_path: String = ""
	print("[FamilyGarden] Save place photo state: from_web=", selected_photo_from_web, " bytes=", selected_photo_bytes.size(), " path=", selected_photo_path, " name=", selected_photo_filename, " type=", selected_photo_content_type)

	if selected_photo_from_web and selected_photo_bytes.size() > 0:
		if CloudManager != null:
			_show_toast("正在上传照片...")
			uploaded_photo_path = await CloudManager.upload_photo_bytes_with_name(
				selected_photo_bytes,
				selected_photo_filename,
				place_title,
				selected_photo_content_type
			)
			if uploaded_photo_path == "":
				_show_toast("照片上传失败，将不带照片保存。")
			else:
				_show_toast("照片已上传。")
		else:
			_show_toast("云端尚未就绪，将不带照片保存。")
	elif selected_photo_path != "":
		if CloudManager != null:
			_show_toast("正在上传照片...")
			uploaded_photo_path = await CloudManager.upload_photo_from_path(selected_photo_path, place_title)
			if uploaded_photo_path == "":
				_show_toast("照片上传失败，将不带照片保存。")
			else:
				_show_toast("照片已上传。")
		else:
			_show_toast("云端尚未就绪，将不带照片保存。")

	if CloudManager != null:
		_show_toast("正在保存到家庭云端...")
		var created: Dictionary = await CloudManager.create_place_with_postcard(
			place_title,
			place_note,
			pending_place_position.x,
			pending_place_position.y,
			"",
			uploaded_photo_path
		)
		if created.has("place") and created["place"] is Dictionary:
			var cloud_place: Dictionary = created["place"]
			if str(cloud_place.get("id", "")) != "":
				place_id = str(cloud_place.get("id", ""))
			if str(cloud_place.get("photo_path", "")) != "":
				uploaded_photo_path = str(cloud_place.get("photo_path", ""))
		if created.has("postcard") and created["postcard"] is Dictionary:
			var cloud_postcard: Dictionary = created["postcard"]
			if str(cloud_postcard.get("id", "")) != "":
				postcard_id = str(cloud_postcard.get("id", ""))

	var place := {
		"id": place_id,
		"title": place_title,
		"note": place_note,
		"x": pending_place_position.x,
		"y": pending_place_position.y,
		"postcard_id": postcard_id,
		"created_by": MemoryManager.player_display_name,
		"role": MemoryManager.selected_role_key,
		"photo_path": uploaded_photo_path
	}
	MemoryManager.travel_places.append(place)

	var postcard := {
		"id": postcard_id,
		"place_id": place_id,
		"title": "来自%s的明信片" % place_title,
		"message": place_note,
		"is_new": true,
		"created_by": MemoryManager.player_display_name,
		"role": MemoryManager.selected_role_key,
		"photo_path": uploaded_photo_path
	}
	MemoryManager.postcards.append(postcard)
	MemoryManager.notify_new_postcard()
	MemoryManager.save_game()
	_reset_selected_photo_state()
	_close_active_panel()
	_show_travel_map()
	_show_toast("来自%s的新明信片已寄回花园。" % place_title)

func _rebuild_travel_pins() -> void:
	for place in MemoryManager.travel_places:
		_add_travel_pin(place)

func _add_travel_pin(place: Dictionary) -> void:
	var marker := Node2D.new()
	marker.name = "Pin_" + str(place.get("id", ""))
	marker.position = Vector2(float(place.get("x", 640)), float(place.get("y", 360)))
	marker.z_index = 50
	world.add_child(marker)

	var pin_texture := _safe_texture(_pin_asset_for_place(place))
	if pin_texture:
		var pin_sprite := Sprite2D.new()
		pin_sprite.texture = pin_texture
		pin_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pin_sprite.centered = true
		pin_sprite.position = Vector2(0, -16)
		var pin_scale := 44.0 / float(pin_texture.get_height())
		pin_sprite.scale = Vector2.ONE * pin_scale
		marker.add_child(pin_sprite)
	else:
		var pin := Label.new()
		pin.text = "●"
		pin.position = Vector2(-10, -22)
		pin.size = Vector2(28, 28)
		pin.add_theme_font_size_override("font_size", 26)
		pin.add_theme_color_override("font_color", Color(0.88, 0.22, 0.18, 1.0))
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.add_child(pin)

	var name_label := Label.new()
	name_label.text = str(place.get("title", "Place"))
	name_label.position = Vector2(-50, 6)
	name_label.size = Vector2(100, 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.16, 0.25, 0.22, 1.0))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(name_label)

	_add_click_area(marker, Vector2(44, 54), "place:" + str(place.get("id", "")), str(place.get("title", "Place")), Vector2(0, 0))

func _open_postcard_for_place(place_id: String) -> void:
	var place := MemoryManager.find_place(place_id)
	if place.is_empty():
		return
	var postcard := MemoryManager.find_postcard_by_place(place_id)
	var title_text := str(postcard.get("title", "来自%s的明信片" % str(place.get("title", "地点"))))
	var message := str(postcard.get("message", place.get("note", "A small memory.")))
	var photo_path := str(postcard.get("photo_path", ""))
	if photo_path == "":
		photo_path = str(place.get("photo_path", ""))
	_open_postcard_detail_panel(title_text, message, photo_path, place_id)

func _choose_photo_for_place() -> void:
	if OS.has_feature("web"):
		_choose_photo_for_place_web()
		return

	if photo_file_dialog != null and is_instance_valid(photo_file_dialog):
		photo_file_dialog.queue_free()

	photo_file_dialog = FileDialog.new()
	photo_file_dialog.title = "选择照片"
	photo_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	photo_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	photo_file_dialog.filters = PackedStringArray([
		"*.png, *.jpg, *.jpeg, *.webp ; 图片文件"
	])
	photo_file_dialog.file_selected.connect(_on_place_photo_selected)
	ui_layer.add_child(photo_file_dialog)
	photo_file_dialog.popup_centered(Vector2i(900, 620))

func _selected_gate4_photo() -> Dictionary:
	var bytes := selected_photo_bytes
	if bytes.is_empty() and selected_photo_path != "":
		bytes = FileAccess.get_file_as_bytes(selected_photo_path)
	return {
		"bytes": bytes,
		"content_type": selected_photo_content_type if selected_photo_content_type != "" else _content_type_for_filename(selected_photo_filename),
		"filename": selected_photo_filename,
	}

func _open_memory_creator(preserve_selection: bool = false, initial_text: String = "") -> void:
	if not preserve_selection:
		_reset_selected_photo_state()
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay
	var panel := Panel.new()
	panel.position = Vector2(290, 70)
	panel.size = Vector2(700, 590)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = "创建一段家庭记忆"
	title.position = Vector2(34, 24)
	title.size = Vector2(620, 36)
	title.add_theme_font_size_override("font_size", 26)
	panel.add_child(title)

	var hint := Label.new()
	hint.text = "可以只写文字、只选照片，或图文一起提交。生成草稿前不会保存记忆。"
	hint.position = Vector2(34, 66)
	hint.size = Vector2(620, 40)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(hint)

	var text_input := TextEdit.new()
	text_input.name = "MemoryTextInput"
	text_input.placeholder_text = "例如：今天和家人一起种了一棵树……"
	text_input.text = initial_text
	text_input.position = Vector2(34, 118)
	text_input.size = Vector2(632, 190)
	panel.add_child(text_input)

	var choose := Button.new()
	choose.text = "选择照片（可选）"
	choose.position = Vector2(34, 330)
	choose.size = Vector2(180, 40)
	_apply_button_style(choose, false)
	choose.pressed.connect(_choose_photo_for_place)
	panel.add_child(choose)
	selected_photo_label = Label.new()
	selected_photo_label.text = "未选择照片" if selected_photo_filename == "" else "已选择：" + selected_photo_filename
	selected_photo_label.position = Vector2(230, 338)
	selected_photo_label.size = Vector2(420, 28)
	panel.add_child(selected_photo_label)

	var privacy := Label.new()
	privacy.text = "照片会先在本机压缩并去除元数据，再上传到家庭隔离的 CloudBase 路径。"
	privacy.position = Vector2(34, 390)
	privacy.size = Vector2(632, 44)
	privacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	privacy.add_theme_font_size_override("font_size", 13)
	panel.add_child(privacy)

	var status := _make_status_label(panel, Vector2(34, 438), Vector2(632, 30), "确认草稿前不会创建记忆。")

	var generate := Button.new()
	generate.text = "生成可编辑草稿"
	generate.position = Vector2(250, 476)
	generate.size = Vector2(200, 44)
	_apply_button_style(generate, false)
	generate.pressed.connect(_generate_memory_draft.bind(text_input, generate, status))
	panel.add_child(generate)

func _generate_memory_draft(text_input: TextEdit, button: Button, status: Label) -> void:
	var photo := _selected_gate4_photo()
	if text_input.text.strip_edges() == "" and (photo.get("bytes", PackedByteArray()) as PackedByteArray).is_empty():
		_set_status(status, "先写一段文字，或选择一张照片。", true)
		_show_toast("请先写文字或选择照片。")
		return
	_set_button_busy(button, "正在生成...")
	_watch_ai_workflow("memory", status, "正在准备输入...")
	var draft: Dictionary = await AIWorkflowManager.prepare_memory_draft(text_input.text, photo.get("bytes", PackedByteArray()), String(photo.get("content_type", "")))
	if not bool(draft.get("ok", false)):
		_set_button_ready(button, "重试生成")
		var message := _result_error_message(draft, "生成失败，请重试。")
		_set_status(status, message, true)
		_show_toast(message)
		_clear_ai_workflow_watch(status)
		return
	_clear_ai_workflow_watch(status)
	_open_memory_draft_preview(draft)

func _open_memory_draft_preview(draft: Dictionary) -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay
	var panel := Panel.new()
	panel.position = Vector2(260, 46)
	panel.size = Vector2(760, 628)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var heading := Label.new()
	heading.text = "记忆卡草稿" + (" · 已使用安全回退" if bool(draft.get("used_fallback", false)) else " · AI 已生成")
	heading.position = Vector2(34, 20)
	heading.size = Vector2(690, 34)
	heading.add_theme_font_size_override("font_size", 24)
	panel.add_child(heading)
	var card: Dictionary = draft.get("card", {})

	var title_label := Label.new()
	title_label.text = "标题"
	title_label.position = Vector2(34, 58)
	title_label.size = Vector2(692, 20)
	title_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(title_label)
	var title_input := LineEdit.new()
	title_input.text = String(card.get("title", ""))
	title_input.position = Vector2(34, 82)
	title_input.size = Vector2(692, 38)
	panel.add_child(title_input)

	var description_label := Label.new()
	description_label.text = "描述"
	description_label.position = Vector2(34, 126)
	description_label.size = Vector2(692, 20)
	description_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(description_label)
	var description_input := TextEdit.new()
	description_input.text = String(card.get("description", ""))
	description_input.position = Vector2(34, 150)
	description_input.size = Vector2(692, 112)
	panel.add_child(description_input)

	var question_label := Label.new()
	question_label.text = "想追问家人的问题"
	question_label.position = Vector2(34, 278)
	question_label.size = Vector2(692, 20)
	question_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(question_label)
	var question_input := TextEdit.new()
	question_input.text = String(card.get("question", ""))
	question_input.position = Vector2(34, 302)
	question_input.size = Vector2(692, 86)
	panel.add_child(question_input)
	var scene_label := Label.new()
	scene_label.text = "放到哪里"
	scene_label.position = Vector2(34, 410)
	scene_label.size = Vector2(100, 28)
	panel.add_child(scene_label)
	var scene_select := OptionButton.new()
	scene_select.position = Vector2(140, 404)
	scene_select.size = Vector2(220, 38)
	scene_select.add_item("家庭花园", 0)
	scene_select.set_item_metadata(0, "garden")
	scene_select.add_item("爸爸鱼塘", 1)
	scene_select.set_item_metadata(1, "fishpond")
	if String(card.get("suggested_scene", "garden")) == "fishpond":
		scene_select.select(1)
	panel.add_child(scene_select)
	var source := Label.new()
	var meta: Dictionary = draft.get("generation_meta", {})
	source.text = "来源：%s · 模型：%s · Prompt：%s" % [String(meta.get("source", "unknown")), String(meta.get("model", "unknown")), String(meta.get("prompt_version", "unknown"))]
	source.position = Vector2(34, 462)
	source.size = Vector2(692, 48)
	source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source.add_theme_font_size_override("font_size", 12)
	panel.add_child(source)
	var status := _make_status_label(panel, Vector2(34, 514), Vector2(692, 22), "可以先修改草稿；只有点击确认才会写入花园。")
	var cancel := Button.new()
	cancel.text = "取消并清理照片"
	cancel.position = Vector2(116, 542)
	cancel.size = Vector2(170, 42)
	_apply_button_style(cancel, false)
	cancel.pressed.connect(_discard_draft_and_close.bind(draft))
	panel.add_child(cancel)
	var confirm := Button.new()
	confirm.text = "确认创建"
	confirm.position = Vector2(474, 542)
	confirm.size = Vector2(170, 42)
	_apply_button_style(confirm, false)
	confirm.pressed.connect(_commit_memory_preview.bind(draft, card, title_input, description_input, question_input, scene_select, confirm, status))
	panel.add_child(confirm)

func _commit_memory_preview(draft: Dictionary, original_card: Dictionary, title_input: LineEdit, description_input: TextEdit, question_input: TextEdit, scene_select: OptionButton, button: Button, status: Label) -> void:
	var card := original_card.duplicate(true)
	card["title"] = title_input.text.strip_edges()
	card["description"] = description_input.text.strip_edges()
	card["question"] = question_input.text.strip_edges()
	card["suggested_scene"] = String(scene_select.get_selected_metadata())
	if String(card.get("title", "")).strip_edges() == "":
		_set_status(status, "标题不能为空。", true)
		return
	if String(card.get("description", "")).strip_edges() == "":
		_set_status(status, "描述不能为空。", true)
		return
	if String(card.get("question", "")).strip_edges() == "":
		_set_status(status, "请保留一个想追问家人的问题。", true)
		return
	_set_button_busy(button, "正在保存...")
	_set_status(status, "正在写入记忆，并计算可能的关联...")
	var result: Dictionary = await AIWorkflowManager.commit_memory_draft(draft, card)
	if not bool(result.get("ok", false)):
		_set_button_ready(button, "确认创建")
		var message := _result_error_message(result, "保存失败。")
		_set_status(status, message, true)
		_show_toast(message)
		return
	_close_active_panel()
	var scene := String(card.get("suggested_scene", "garden"))
	var saved_memory: Dictionary = result.get("memory", {})
	var link_count := MemoryManager.count_memory_links_for_memory(String(saved_memory.get("id", "")), scene)
	var link_text := "，发现 %d 条记忆关联" % link_count if link_count > 0 else ""
	_show_toast("记忆已保存到%s%s。" % [("爸爸鱼塘" if scene == "fishpond" else "家庭花园"), link_text])
	if scene == "garden":
		_show_garden()


func _on_place_photo_selected(path: String) -> void:
	selected_photo_path = path
	selected_photo_bytes = PackedByteArray()
	selected_photo_filename = path.get_file()
	selected_photo_content_type = _content_type_for_filename(selected_photo_filename)
	selected_photo_from_web = false

	if selected_photo_label != null and is_instance_valid(selected_photo_label):
		var bytes := FileAccess.get_file_as_bytes(selected_photo_path)
		selected_photo_label.text = "已选择：" + selected_photo_filename + "（" + _format_file_size(bytes.size()) + "）"

	_show_toast("已选择照片：" + selected_photo_filename)


func _setup_web_photo_bridge() -> void:
	if not OS.has_feature("web"):
		return

	var photo_picker_js := """
(function () {
	if (window.__familyGardenPhotoBridgeReady) {
		return;
	}

	window.__familyGardenPhotoBridgeReady = true;
	window.__familyGardenPhotoOverlayInput = null;

	window.__familyGardenRemovePhotoInput = function () {
		var oldInput = window.__familyGardenPhotoOverlayInput || document.getElementById("family-garden-photo-input");
		if (oldInput && oldInput.parentNode) {
			oldInput.parentNode.removeChild(oldInput);
		}
		window.__familyGardenPhotoOverlayInput = null;
	};

	window.__familyGardenCreatePhotoInput = function () {
		window.__familyGardenRemovePhotoInput();

		var input = document.createElement("input");
		input.id = "family-garden-photo-input";
		input.type = "file";
		input.accept = "image/png,image/jpeg,image/webp";

		/*
			The full-window invisible input is a fallback for browsers that block
			programmatic input.click() from a WebAssembly/Godot event. If click() works,
			the picker opens immediately. If it is blocked, the next user tap/click will
			hit this native input.
		*/
		input.style.position = "fixed";
		input.style.left = "0";
		input.style.top = "0";
		input.style.width = "100vw";
		input.style.height = "100vh";
		input.style.opacity = "0.001";
		input.style.zIndex = "2147483647";
		input.style.cursor = "pointer";
		input.style.pointerEvents = "auto";

			input.addEventListener("change", function () {
				var file = input.files && input.files.length > 0 ? input.files[0] : null;
				if (!file) {
					window.__familyGardenRemovePhotoInput();
					return;
			}

			console.log("[FamilyGarden] Photo chosen:", file.name, file.type, file.size);

			var reader = new FileReader();

			reader.onload = function () {
				var bytes = new Uint8Array(reader.result);
				var chunkSize = 0x8000;
				var binary = "";

				for (var i = 0; i < bytes.length; i += chunkSize) {
					var chunk = bytes.subarray(i, i + chunkSize);
					binary += String.fromCharCode.apply(null, chunk);
				}

				var base64 = btoa(binary);

				if (window.__familyGardenPhotoPicked) {
					console.log("[FamilyGarden] Sending photo to Godot callback");
					window.__familyGardenPhotoPicked(
						base64,
						file.name || "photo.jpg",
						file.type || "image/jpeg"
					);
				} else {
					console.error("[FamilyGarden] Godot photo callback is missing");
				}

				window.__familyGardenRemovePhotoInput();
			};

			reader.onerror = function () {
				console.error("[FamilyGarden] Photo read failed", reader.error);
				window.__familyGardenRemovePhotoInput();
			};

				reader.readAsArrayBuffer(file);
			});

			input.addEventListener("cancel", function () {
				window.__familyGardenRemovePhotoInput();
			});

			document.body.appendChild(input);
			window.__familyGardenPhotoOverlayInput = input;
		return input;
	};

	window.familyGardenChoosePhoto = function () {
		if (!window.__familyGardenPhotoPicked) {
			console.error("[FamilyGarden] Photo callback is not ready");
			return false;
		}

		var input = window.__familyGardenCreatePhotoInput();
		try {
			input.click();
		} catch (e) {
			console.warn("[FamilyGarden] input.click() was blocked; click once more to open picker", e);
		}
		return true;
	};
})();
"""
	JavaScriptBridge.eval(photo_picker_js, true)

	if web_photo_callback == null:
		web_photo_callback = JavaScriptBridge.create_callback(_on_web_photo_selected)

	var js_window = JavaScriptBridge.get_interface("window")
	if js_window != null:
		js_window["__familyGardenPhotoPicked"] = web_photo_callback


func _choose_photo_for_place_web() -> void:
	if web_photo_callback == null:
		_setup_web_photo_bridge()

	_show_toast("请选择设备中的照片...")

	if selected_photo_label != null and is_instance_valid(selected_photo_label):
		selected_photo_label.text = "请选择设备中的照片..."

	var js_result = JavaScriptBridge.eval("""
		window.familyGardenChoosePhoto ? window.familyGardenChoosePhoto() : false;
	""", true)
	if not bool(js_result):
		_show_toast("照片选择器还没准备好，请重试。")


func _on_web_photo_selected(args: Array) -> void:
	if args.size() < 3:
		_show_toast("照片选择失败。")
		return

	var base64_text: String = str(args[0])
	var file_name: String = str(args[1])
	var content_type: String = str(args[2])

	var bytes: PackedByteArray = Marshalls.base64_to_raw(base64_text)
	if bytes.is_empty():
		_show_toast("无法读取所选照片。")
		return

	selected_photo_bytes = bytes
	selected_photo_filename = file_name
	selected_photo_content_type = content_type
	selected_photo_path = ""
	selected_photo_from_web = true
	print("[FamilyGarden] Web photo received by Godot: ", selected_photo_filename, " bytes=", selected_photo_bytes.size(), " type=", selected_photo_content_type)

	if selected_photo_label != null and is_instance_valid(selected_photo_label):
		selected_photo_label.text = "已选择：" + selected_photo_filename + "（" + _format_file_size(selected_photo_bytes.size()) + "）"

	_show_toast("已选择照片：" + selected_photo_filename)

func _reset_selected_photo_state() -> void:
	selected_photo_path = ""
	selected_photo_bytes = PackedByteArray()
	selected_photo_filename = ""
	selected_photo_content_type = ""
	selected_photo_from_web = false
	selected_photo_label = null


func _content_type_for_filename(file_name: String) -> String:
	var ext: String = file_name.get_extension().to_lower()
	match ext:
		"png":
			return "image/png"
		"webp":
			return "image/webp"
		"jpg", "jpeg":
			return "image/jpeg"
		_:
			return "application/octet-stream"


func _open_postcard_detail_panel(title_text: String, message: String, photo_path: String, place_id: String) -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay

	var panel := Panel.new()
	panel.position = Vector2(320, 80)
	panel.size = Vector2(640, 560)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(36, 26)
	title.size = Vector2(520, 34)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var photo_frame := Panel.new()
	photo_frame.position = Vector2(36, 78)
	photo_frame.size = Vector2(568, 250)
	photo_frame.clip_contents = true
	_apply_small_card_style(photo_frame)
	panel.add_child(photo_frame)

	var photo_rect := TextureRect.new()
	photo_rect.position = Vector2(12, 12)
	photo_rect.size = Vector2(544, 226)
	photo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	photo_frame.add_child(photo_rect)

	var photo_status := Label.new()
	photo_status.text = "未附加照片。"
	photo_status.position = Vector2(20, 108)
	photo_status.size = Vector2(528, 28)
	photo_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	photo_status.add_theme_color_override("font_color", Color(0.45, 0.37, 0.28, 0.78))
	photo_frame.add_child(photo_status)

	var body := RichTextLabel.new()
	body.text = message
	body.position = Vector2(36, 350)
	body.size = Vector2(568, 110)
	body.fit_content = false
	body.scroll_active = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.fit_content = false
	body.scroll_active = true
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("default_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(body)

	# Add all controls before loading the photo, so the user can close the panel while the image is loading.
	_add_panel_button(panel, "删除", Vector2(96, 490), Vector2(120, 40), "delete_place:" + place_id)
	_add_panel_button(panel, "返回地图", Vector2(246, 490), Vector2(150, 40), "close")
	_add_panel_button(panel, "明信片", Vector2(426, 490), Vector2(130, 40), "MemoryManager.postcards")

	var clean_photo_path: String = photo_path.strip_edges()
	if clean_photo_path == "" or clean_photo_path.to_lower() in ["null", "<null>", "nil", "none"]:
		photo_status.text = "未附加照片。"
	else:
		photo_status.text = "正在加载照片..."
		_load_photo_into_rect(clean_photo_path, photo_rect, photo_status)

func _load_photo_into_rect(photo_path: String, photo_rect: TextureRect, photo_status: Label) -> void:
	var clean_photo_path: String = photo_path.strip_edges()
	if clean_photo_path == "" or clean_photo_path.to_lower() in ["null", "<null>", "nil", "none"]:
		if is_instance_valid(photo_status):
			photo_status.text = "未附加照片。"
		return

	if is_instance_valid(photo_rect):
		photo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var photo_url: String = _photo_public_url(clean_photo_path)

	if photo_texture_cache.has(photo_url):
		var cached_texture: Texture2D = photo_texture_cache[photo_url]
		if is_instance_valid(photo_rect):
			photo_rect.texture = cached_texture
		if is_instance_valid(photo_status):
			photo_status.visible = false
		return

	if is_instance_valid(photo_status):
		photo_status.text = "正在加载照片..."

	var texture: Texture2D = await _download_photo_texture(photo_url)
	if texture != null:
		photo_texture_cache[photo_url] = texture
		if is_instance_valid(photo_rect):
			photo_rect.texture = texture
		if is_instance_valid(photo_status):
			photo_status.visible = false
	else:
		if is_instance_valid(photo_status):
			photo_status.text = "照片加载失败。"


func _photo_public_url(photo_path: String) -> String:
	if photo_path.begins_with("http://") or photo_path.begins_with("https://"):
		return photo_path

	if CloudManager != null:
		return CloudManager.public_url_from_photo_path(photo_path)

	return photo_path


func _download_photo_texture(url: String) -> Texture2D:
	if url == "":
		return null

	if photo_texture_cache.has(url):
		return photo_texture_cache[url]

	var request := HTTPRequest.new()
	add_child(request)

	var err := request.request(url)
	if err != OK:
		request.queue_free()
		return null

	var response: Array = await request.request_completed
	request.queue_free()

	var result_code: int = int(response[0])
	var status_code: int = int(response[1])
	if result_code != HTTPRequest.RESULT_SUCCESS or status_code < 200 or status_code >= 300:
		return null

	var bytes: PackedByteArray = response[3]
	var image := Image.new()
	var load_err: int = image.load_png_from_buffer(bytes)

	if load_err != OK:
		load_err = image.load_jpg_from_buffer(bytes)

	if load_err != OK:
		load_err = image.load_webp_from_buffer(bytes)

	if load_err != OK:
		return null

	var texture := ImageTexture.create_from_image(image)
	photo_texture_cache[url] = texture
	return texture


func _pin_asset_for_place(place: Dictionary) -> String:
	var postcard := MemoryManager.find_postcard_by_place(str(place.get("id", "")))
	if not postcard.is_empty() and bool(postcard.get("is_new", false)):
		return ASSETS["pin_postcard"]
	return ASSETS["pin_saved"] if ResourceLoader.exists(ASSETS["pin_saved"]) else ASSETS["pin_default"]

func _delete_place(place_id: String) -> void:
	if CloudManager != null and not place_id.begins_with("place_"):
		await CloudManager.delete_place_and_postcards(place_id)

	MemoryManager.travel_places = MemoryManager.travel_places.filter(func(place): return str(place.get("id", "")) != place_id)
	MemoryManager.postcards = MemoryManager.postcards.filter(func(postcard): return str(postcard.get("place_id", "")) != place_id)
	if MemoryManager.count_unread_postcards() > 0:
		MemoryManager.set_mailbox_alert(MemoryManager.MAILBOX_ALERT_LETTER)
	elif MemoryManager.mailbox_alert_state == MemoryManager.MAILBOX_ALERT_LETTER:
		MemoryManager.clear_mailbox_alert()
	MemoryManager.save_game()
	_close_active_panel()
	if mode == "map":
		_show_travel_map()
	else:
		_show_toast("地点已删除。")

func _open_animal_dialog(animal_id: String, display_name: String) -> void:
	var line := "花园里的小伙伴正在这里休息。"
	match animal_id:
		"cat":
			line = "Mimi 慢慢眨了眨眼，走几步，又准备蜷起来打个小盹。"
		"bird":
			line = "蓝色小鸟在花园边轻轻跳着，望着家庭树。"
		"dog":
			line = "Biscuit 开心地晃了晃，然后趴下来休息一会儿。"
	_show_cozy_panel(display_name, line, [{"text": "关闭", "action": "close"}])

func _open_message_board_panel() -> void:
	var body := "家人的留言都贴在这里。\n\n"
	if MemoryManager.garden_messages.is_empty():
		body += "还没有留言。给家人写下第一句话吧。"
	else:
		for message in MemoryManager.garden_messages:
			body += "• " + str(message.get("author", "家人")) + ": " + str(message.get("text", "")) + "\n\n"
	_show_cozy_panel(
		"留言板",
		body,
		[
			{"text": "+ 留言", "action": "add_message"},
			{"text": "关闭", "action": "close"}
		]
	)

func _open_add_message_form() -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay

	var panel := Panel.new()
	panel.position = Vector2(390, 170)
	panel.size = Vector2(500, 360)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = "新增留言"
	title.position = Vector2(30, 24)
	title.size = Vector2(440, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var author_label := Label.new()
	author_label.text = "来自"
	author_label.position = Vector2(32, 78)
	author_label.size = Vector2(420, 22)
	author_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(author_label)

	var author_input := LineEdit.new()
	author_input.placeholder_text = "Peilin, Papa, Mama..."
	author_input.text = MemoryManager.player_display_name if MemoryManager.player_display_name != "" else _default_name_for_role(MemoryManager.selected_role_key)
	author_input.position = Vector2(32, 104)
	author_input.size = Vector2(430, 36)
	panel.add_child(author_input)

	var message_label := Label.new()
	message_label.text = "留言"
	message_label.position = Vector2(32, 154)
	message_label.size = Vector2(420, 22)
	message_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(message_label)

	var message_input := TextEdit.new()
	message_input.placeholder_text = "给家人留一句小小的话..."
	message_input.position = Vector2(32, 180)
	message_input.size = Vector2(430, 90)
	panel.add_child(message_input)

	_add_panel_button(panel, "保存留言", Vector2(96, 296), Vector2(130, 40), "save_new_message", [author_input, message_input])
	_add_panel_button(panel, "取消", Vector2(274, 296), Vector2(120, 40), "message_board")

func _save_new_message(author_input: LineEdit, message_input: TextEdit) -> void:
	var author: String = author_input.text.strip_edges()
	if author == "":
		author = "家人"
	var text: String = message_input.text.strip_edges()
	if text == "":
		text = "花园里留下了一句小小的话。"

	var message_id: String = "message_" + str(Time.get_ticks_msec())
	if CloudManager != null:
		var cloud_message: Dictionary = await CloudManager.create_message(author, text, "")
		if not cloud_message.is_empty() and str(cloud_message.get("id", "")) != "":
			message_id = str(cloud_message.get("id", ""))

	var message := {
		"id": message_id,
		"author": author,
		"text": text,
		"created_at": Time.get_datetime_string_from_system(),
		"role": MemoryManager.selected_role_key
	}
	MemoryManager.garden_messages.append(message)
	MemoryManager.notify_family_activity()
	MemoryManager.save_game()
	_refresh_world_chat_feed()
	_open_message_board_panel()
	_show_toast("新留言已保存。")

func _open_postcards_panel() -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay

	var panel := Panel.new()
	panel.position = Vector2(300, 72)
	panel.size = Vector2(680, 590)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = "家庭明信片"
	title.position = Vector2(36, 26)
	title.size = Vector2(608, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "打开明信片，查看它带回来的照片和记忆。"
	subtitle.position = Vector2(36, 62)
	subtitle.size = Vector2(608, 24)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.43, 0.35, 0.27, 0.88))
	panel.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(36, 98)
	scroll.size = Vector2(608, 390)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	if MemoryManager.postcards.is_empty():
		var empty_label := Label.new()
		empty_label.text = "还没有明信片。打开旅行地图，添加一个地点，就能寄回第一张。"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.custom_minimum_size = Vector2(570, 90)
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
		list.add_child(empty_label)
	else:
		for postcard in MemoryManager.postcards:
			if not (postcard is Dictionary):
				continue

			var postcard_id: String = str(postcard.get("id", ""))
			var card := Panel.new()
			card.custom_minimum_size = Vector2(570, 96)
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			_apply_small_card_style(card)
			list.add_child(card)

			var card_title := Label.new()
			var badge := "新 · " if bool(postcard.get("is_new", false)) else ""
			var has_photo := str(postcard.get("photo_path", "")) != ""
			var photo_label := "有照片 · " if has_photo else "无照片 · "
			card_title.text = badge + photo_label + str(postcard.get("title", "明信片"))
			card_title.position = Vector2(18, 12)
			card_title.size = Vector2(420, 26)
			card_title.add_theme_font_size_override("font_size", 16)
			card_title.add_theme_color_override("font_color", Color(0.24, 0.20, 0.15, 1.0))
			card.add_child(card_title)

			var card_body := Label.new()
			card_body.text = str(postcard.get("message", ""))
			card_body.position = Vector2(18, 40)
			card_body.size = Vector2(420, 42)
			card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card_body.add_theme_font_size_override("font_size", 13)
			card_body.add_theme_color_override("font_color", Color(0.43, 0.35, 0.27, 0.92))
			card.add_child(card_body)

			var open_button := Button.new()
			open_button.text = "打开"
			open_button.position = Vector2(462, 29)
			open_button.size = Vector2(86, 36)
			open_button.mouse_filter = Control.MOUSE_FILTER_STOP
			_apply_button_style(open_button, false)
			_set_button_icon(open_button, "icon_postcard")
			open_button.pressed.connect(_open_postcard_detail_from_id.bind(postcard_id))
			card.add_child(open_button)

	_add_panel_button(panel, "旅行地图", Vector2(96, 520), Vector2(150, 40), "travel_map")
	_add_panel_button(panel, "关闭", Vector2(432, 520), Vector2(150, 40), "close")
	MemoryManager.mark_postcards_read()
	MemoryManager.save_game()


func _open_postcard_detail_from_id(postcard_id: String) -> void:
	var postcard := MemoryManager.find_postcard(postcard_id)
	if postcard.is_empty():
		_show_toast("没有找到这张明信片。")
		return

	var place_id: String = str(postcard.get("place_id", ""))
	var place := MemoryManager.find_place(place_id)
	var title_text := str(postcard.get("title", "明信片"))
	var message := str(postcard.get("message", "一段小小的记忆。"))
	var photo_path := str(postcard.get("photo_path", ""))

	if photo_path == "" and not place.is_empty():
		photo_path = str(place.get("photo_path", ""))

	_open_postcard_detail_panel(title_text, message, photo_path, place_id)


func _open_family_tree_panel() -> void:
	var body := "这棵树会随着家庭记忆一起长大。\n\n家庭成员：\n"
	for role_data in CHARACTER_DATA:
		var role_key := str(role_data.get("role", ""))
		var member_name := MemoryManager.player_display_name if role_key == MemoryManager.selected_role_key else str(role_data.get("default_name", role_data.get("label", "家人")))
		var status := "当前玩家" if role_key == MemoryManager.selected_role_key else "花园访客"
		body += "• " + member_name + " — " + status + "\n"
	body += "\n树上的明信片：\n"
	if MemoryManager.postcards.is_empty():
		body += "• 还没有明信片。打开旅行地图寄回一张吧。\n"
	else:
		for postcard in MemoryManager.postcards:
			body += "• " + str(postcard.get("title", "明信片")) + "\n"
	_show_cozy_panel(
		"家庭树",
		body,
		[
			{"text": "明信片", "action": "MemoryManager.postcards"},
			{"text": "留言板", "action": "message_board"},
			{"text": "关闭", "action": "close"}
		]
	)

func _open_family_members_panel() -> void:
	var family_code := CloudManager.family_code() if CloudManager != null and CloudManager.has_method("family_code") else ""
	var members: Array = []
	if CloudManager != null and CloudManager.has_method("list_family_members"):
		members = await CloudManager.list_family_members()
	var online := _online_family_members()
	var body := "家庭邀请码：" + (family_code if family_code != "" else "离线家庭") + "\n\n"
	if members.is_empty():
		body += "还没有从云端同步到家庭成员。\n"
		if GameIdentity != null and GameIdentity.is_ready():
			members.append({
				"member_id": GameIdentity.member_id,
				"role": GameIdentity.role,
				"display_name": GameIdentity.display_name,
			})
		else:
			members.append({
				"member_id": "local",
				"role": MemoryManager.selected_role_key,
				"display_name": MemoryManager.player_display_name,
			})
	body += "家庭成员：\n"
	for raw in members:
		if not (raw is Dictionary):
			continue
		var member: Dictionary = raw
		var member_id := str(member.get("member_id", ""))
		var display_name := str(member.get("display_name", "")).strip_edges()
		if display_name == "":
			display_name = _role_display_name(str(member.get("role", "")))
		var role := _role_display_name(str(member.get("role", "")))
		var online_text := "在线" if online.has(member_id) else "离线"
		var scene_text := ""
		if online.has(member_id):
			var peer: Dictionary = online[member_id]
			scene_text = " · " + _scene_display_name(str(peer.get("scene_id", "")))
		body += "• %s（%s） — %s%s\n" % [display_name, role, online_text, scene_text]
	body += "\n同一成员在多台设备同时进入时，会优先显示最新连接；旧连接会自动退出。"
	_show_cozy_panel(
		"家庭成员",
		body,
		[
			{"text": "留言板", "action": "message_board"},
			{"text": "家庭树", "action": "family_tree"},
			{"text": "关闭", "action": "close"}
		]
	)

func _online_family_members() -> Dictionary:
	var result: Dictionary = {}
	if GameIdentity != null and GameIdentity.is_ready():
		result[GameIdentity.member_id] = {
			"member_id": GameIdentity.member_id,
			"role": GameIdentity.role,
			"display_name": GameIdentity.display_name,
			"scene_id": mode,
		}
	if PresenceChannel != null and PresenceChannel.has_method("peers"):
		for raw_peer in PresenceChannel.peers():
			if raw_peer is Dictionary:
				var peer: Dictionary = raw_peer
				var member_id := str(peer.get("member_id", ""))
				if member_id != "":
					result[member_id] = peer
	return result

func _role_display_name(role_key: String) -> String:
	var resolved := CharacterDB.resolve(role_key) if CharacterDB != null else role_key
	if CharacterDB != null:
		return CharacterDB.display_name(resolved)
	return resolved

func _scene_display_name(scene_id: String) -> String:
	match scene_id:
		"farm":
			return "农场"
		"garden":
			return "花园"
		"fishpond":
			return "鱼塘"
		"room":
			return "房间"
		_:
			return "花园"

func _open_mailbox_panel() -> void:
	var unread_count: int = MemoryManager.count_unread_postcards()
	var body := ""
	if unread_count > 0:
		body = "有新的家人来信。\n\n"
		for postcard in MemoryManager.postcards:
			if bool(postcard.get("is_new", false)):
				body += "• " + str(postcard.get("title", "新明信片")) + "\n"
	else:
		body = "现在没有新来信。\n\n在旅行地图添加地点，就能寄一张新的明信片回花园。"
	MemoryManager.mark_postcards_read(false)
	MemoryManager.clear_mailbox_alert()
	if CloudManager != null:
		await CloudManager.mark_mailbox_read()
	MemoryManager.save_game()
	_show_cozy_panel(
		"邮箱",
		body,
		[
			{"text": "查看明信片", "action": "MemoryManager.postcards"},
			{"text": "旅行地图", "action": "travel_map"},
			{"text": "关闭", "action": "close"}
		]
	)

func _open_npc_dialog(npc_id: String, display_name: String) -> void:
	var line := "今天的花园很安静。"
	match npc_id:
		"papa":
			line = "今天花园很安静，能在这里看到大家，感觉很好。"
		"mama":
			line = "花开得很好，这里像一个小小的家。"
		"boy":
			line = "我找到一个很安静的角落。也许我们可以一起留下一张明信片。"
		"girl":
			line = "我把一段小小的记忆带回了花园。"
	_show_cozy_panel(display_name, line, [{"text": "关闭", "action": "close"}])

func _show_cozy_panel(panel_title: String, body_text: String, buttons: Array) -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay

	var panel := Panel.new()
	panel.position = Vector2(380, 150)
	panel.size = Vector2(520, 380)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = panel_title
	title.position = Vector2(34, 28)
	title.size = Vector2(450, 36)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var body := RichTextLabel.new()
	body.text = body_text
	body.position = Vector2(34, 82)
	body.size = Vector2(452, 200)
	body.fit_content = false
	body.scroll_active = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.bbcode_enabled = false
	body.add_theme_font_size_override("normal_font_size", 16)
	body.add_theme_color_override("default_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(body)

	var button_count: int = buttons.size()
	var gap: int = 14
	var button_width: int = 128
	var total_width: float = float(button_count * button_width + max(0, button_count - 1) * gap)
	var start_x: float = (520.0 - total_width) / 2.0
	for i in range(button_count):
		var button_data: Dictionary = buttons[i]
		_add_panel_button(panel, str(button_data.get("text", "OK")), Vector2(start_x + i * 142, 310), Vector2(128, 40), str(button_data.get("action", "close")))

func _add_panel_close_button(panel: Panel) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	if panel.has_node("PanelCloseButton"):
		return

	var close_btn := Button.new()
	close_btn.name = "PanelCloseButton"
	close_btn.text = "×"
	close_btn.size = Vector2(34, 30)
	close_btn.position = Vector2(maxf(8.0, panel.size.x - 46.0), 12)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.focus_mode = Control.FOCUS_NONE
	_apply_button_style(close_btn, false)
	close_btn.pressed.connect(_close_active_panel)
	panel.add_child(close_btn)

func _create_modal_overlay() -> Control:
	var overlay := Control.new()
	overlay.name = "CozyModalOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.10, 0.08, 0.06, 0.20)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	return overlay

func _make_status_label(parent: Control, pos: Vector2, label_size: Vector2, text: String = "") -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.36, 0.30, 0.23, 0.88))
	parent.add_child(label)
	return label

func _set_status(label: Label, text: String, is_error: bool = false) -> void:
	if label == null or not is_instance_valid(label):
		return
	label.text = text
	label.add_theme_color_override(
		"font_color",
		Color(0.68, 0.18, 0.14, 0.96) if is_error else Color(0.34, 0.28, 0.21, 0.90)
	)

func _set_button_busy(button: Button, busy_text: String) -> void:
	if button == null or not is_instance_valid(button):
		return
	if not button.has_meta("ready_text"):
		button.set_meta("ready_text", button.text)
	button.disabled = true
	button.text = busy_text

func _set_button_ready(button: Button, ready_text: String = "") -> void:
	if button == null or not is_instance_valid(button):
		return
	button.disabled = false
	if ready_text != "":
		button.text = ready_text
	elif button.has_meta("ready_text"):
		button.text = String(button.get_meta("ready_text"))

func _result_error_message(result: Dictionary, fallback: String) -> String:
	var error: Variant = result.get("error", {})
	if error is Dictionary:
		var message := String((error as Dictionary).get("message", "")).strip_edges()
		if message != "":
			return message
	return fallback

func _watch_ai_workflow(workflow: String, status_label: Label, initial_text: String) -> void:
	active_ai_workflow = workflow
	active_ai_status_label = status_label
	_set_status(status_label, initial_text)

func _clear_ai_workflow_watch(status_label: Label = null) -> void:
	if status_label != null and active_ai_status_label != status_label:
		return
	active_ai_workflow = ""
	active_ai_status_label = null

func _on_ai_workflow_state_changed(workflow: String, state: String, detail: Dictionary) -> void:
	if workflow == "links" and state == "complete":
		var created := int(detail.get("created", 0))
		if created > 0 and mode == "garden":
			_refresh_current_memory_scene("garden")
			_show_toast("%d 条记忆藤蔓已长出。" % created)
		return
	if workflow != active_ai_workflow:
		return
	if active_ai_status_label == null or not is_instance_valid(active_ai_status_label):
		return
	var message := ""
	match state:
		"preparing_image":
			message = "正在压缩照片并移除元数据..."
		"uploading":
			message = "正在安全上传照片..."
		"generating":
			message = "AI 正在整理记忆草稿..."
		"analyzing":
			message = "AI 正在识别房间照片..."
		"draft_ready":
			message = "草稿已生成，请先预览再确认。"
		"committed":
			message = "正在完成保存..."
		"complete":
			message = "处理完成。"
		_:
			message = "正在处理..."
	if detail.has("output_bytes"):
		message += " 上传大小 " + _format_file_size(int(detail.get("output_bytes", 0))) + "。"
	_set_status(active_ai_status_label, message)

func _discard_draft_and_close(draft: Dictionary) -> void:
	await AIWorkflowManager.discard_draft(draft)
	_close_active_panel()
	_show_toast("已取消，本次草稿不会保存。")

func _format_file_size(byte_count: int) -> String:
	if byte_count >= 1024 * 1024:
		return "%.1f MB" % (float(byte_count) / float(1024 * 1024))
	if byte_count >= 1024:
		return "%.1f KB" % (float(byte_count) / 1024.0)
	return "%d B" % byte_count

func _apply_small_card_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.96, 0.86, 0.92)
	style.border_color = Color(0.64, 0.48, 0.30, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.20, 0.14, 0.08, 0.16)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)


func _apply_panel_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.95, 0.82, 0.96)
	style.border_color = Color(0.60, 0.43, 0.25, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.20, 0.12, 0.06, 0.22)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)

func _add_panel_button(parent: Control, button_text: String, pos: Vector2, button_size: Vector2, action: String, args: Array = []) -> Button:
	var button := Button.new()
	button.text = button_text
	button.position = pos
	button.size = button_size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_style(button, false)
	_set_button_icon(button, _icon_key_for_action(action))
	if action == "save_new_place" and args.size() >= 2:
		button.pressed.connect(_save_new_place.bind(args[0], args[1]))
	elif action == "save_new_message" and args.size() >= 2:
		button.pressed.connect(_save_new_message.bind(args[0], args[1]))
	else:
		button.pressed.connect(_on_panel_button.bind(action))
	parent.add_child(button)
	return button

func _set_button_icon(button: Button, asset_key: String) -> void:
	if asset_key == "":
		return
	var path := str(ASSETS.get(asset_key, ""))
	var texture := _safe_texture(path)
	if texture:
		button.icon = texture
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _icon_key_for_action(action: String) -> String:
	if action.begins_with("open_postcard"):
		return "icon_postcard"
	if action.begins_with("delete_place"):
		return "icon_delete"
	if action.begins_with("house_note"):
		return "icon_letter"
	match action:
		"create_memory":
			return "icon_add"
		"global_map":
			return "icon_map"
		"family_tree", "plant_tree":
			return "icon_tree"
		"family_members":
			return "icon_home"
		"world_chat_history":
			return "icon_letter"
		"message_board", "add_message", "plant_sign":
			return "icon_sign"
		"toggle_plant":
			return "icon_add"
		"travel_map":
			return "icon_map"
		"MemoryManager.postcards":
			return "icon_postcard"
		"role_select":
			return "icon_home"
		"save", "save_new_place", "save_new_message":
			return "icon_save"
		"back_garden":
			return "icon_back"
		"close":
			return "icon_close"
		_: return ""

func _apply_button_style(button: Button, selected: bool = false) -> void:
	var normal_style := _button_style("button_selected" if selected else "button_normal", Color(1.0, 0.92, 0.74, 0.92), Color(0.58, 0.45, 0.30, 1.0))
	var hover_style := _button_style("button_hover", Color(1.0, 0.96, 0.82, 0.96), Color(0.60, 0.48, 0.32, 1.0))
	var pressed_style := _button_style("button_selected", Color(0.86, 0.92, 0.72, 0.98), Color(0.45, 0.58, 0.40, 1.0))
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.22, 0.17, 0.12, 1.0))

func _button_style(asset_key: String, fallback_color: Color, border_color: Color) -> StyleBox:
	var texture := _safe_texture(str(ASSETS.get(asset_key, "")))
	if texture:
		var tex_style := StyleBoxTexture.new()
		tex_style.texture = texture
		return tex_style
	var style := StyleBoxFlat.new()
	style.bg_color = fallback_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _on_panel_button(action: String) -> void:
	if action == "close":
		_close_active_panel()
	elif action == "travel_map":
		_show_travel_map()
	elif action == "MemoryManager.postcards":
		_open_postcards_panel()
	elif action == "message_board":
		_open_message_board_panel()
	elif action == "add_message":
		_open_add_message_form()
	elif action == "back_garden":
		_show_garden()
	elif action.begins_with("open_postcard:"):
		_open_postcard_detail_from_id(action.split(":")[1])
	elif action.begins_with("delete_place:"):
		_delete_place(action.split(":")[1])
	elif action.begins_with("house_note:"):
		_open_add_message_form()
	elif action.begins_with("house_photos:"):
		_open_postcards_panel()
	elif action.begins_with("generate_room:"):
		_on_generate_room(action.split(":")[1])

func _close_active_panel() -> void:
	_clear_ai_workflow_watch()
	if active_modal != null and is_instance_valid(active_modal):
		active_modal.queue_free()
	active_modal = null
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__familyGardenRemovePhotoInput && window.__familyGardenRemovePhotoInput();", true)

func _add_plant(pos: Vector2, plant_type: String, existing_id: String = "") -> void:
	var item_id := existing_id if existing_id != "" else "plant_" + str(Time.get_ticks_msec())
	var item_data := {"id": item_id, "type": plant_type, "position": pos}
	var texture_path := "res://assets/garden/" + plant_type + ".png"
	if not ResourceLoader.exists(texture_path):
		match plant_type:
			"flower":
				texture_path = "res://assets/pond/decorations/flower_bed.png"
			"tree":
				texture_path = "res://assets/garden/family_tree.png"
			_:
				texture_path = "res://assets/pond/decorations/flower_bed.png"
	var texture := _safe_texture(texture_path)
	var item := preload("res://scripts/placeable_item.gd").new()
	item.setup(item_data, texture)
	item.z_index = int(pos.y)
	item.item_deleted.connect(_on_plant_deleted)
	item.item_moved.connect(_on_plant_moved)
	world.add_child(item)
	plant_nodes[item_id] = item

	if existing_id == "":
		MemoryManager.plants.append({"id": item_id, "type": plant_type, "x": pos.x, "y": pos.y})

func _rebuild_plants() -> void:
	for plant in MemoryManager.plants:
		_add_plant(Vector2(float(plant.get("x", 640)), float(plant.get("y", 360))), str(plant.get("type", "flower")), str(plant.get("id", "")))

func _on_plant_deleted(item_id: String) -> void:
	if plant_nodes.has(item_id):
		plant_nodes[item_id].queue_free()
		plant_nodes.erase(item_id)
	MemoryManager.plants = MemoryManager.plants.filter(func(p): return str(p.get("id", "")) != item_id)
	MemoryManager.save_game()
	_show_toast("Removed.")

func _on_plant_moved(item_id: String, new_position: Vector2) -> void:
	for p in MemoryManager.plants:
		if str(p.get("id", "")) == item_id:
			p["x"] = new_position.x
			p["y"] = new_position.y
			break
	MemoryManager.save_game()

func _get_house_intro(id: String) -> String:
	match id:
		"father":
			return "爸爸温暖的小房间。书、咖啡和家人的明信片都会慢慢住进来。"
		"mother":
			return "一个适合花、留言和安静家庭记忆的小屋。"
		"player":
			return "这里收藏旅行笔记、照片和路上的小发现。"
		"partner":
			return "这里等着家人共享明信片，也等着温柔的花园拜访。"
	return "一间小小的家庭房间。"

func _show_toast(toast_text: String) -> void:
	info_label.text = "家庭花园   —   " + toast_text

func _safe_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _solid_texture(width: int, height: int, color: Color) -> Texture2D:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
