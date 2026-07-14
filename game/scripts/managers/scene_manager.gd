extends Node

## 家庭花园场景和界面控制器。
const GAME_SIZE := Vector2(1280, 720)
const ANNA_ROOM_SCENE := "res://scenes/rooms/AnnaRoom.tscn"
const POND_AREA_SCENE := "res://scenes/pond/pond_area.tscn"
const FARM_SCENE := "res://scenes/Farm.tscn"
const DAY_NIGHT_CLOCK_UI_SCRIPT := preload("res://scripts/ui/day_night_clock_ui.gd")
const MEMORY_LINK_VISUALIZER_SCRIPT := preload("res://scripts/memory_links/memory_link_visualizer.gd")


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
	"flower": "res://assets/garden/memory_flowers.png",
	"wooden_sign": "res://assets/fishpond/items/wooden_sign.png",
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
	"icon_settings": "res://assets/ui/icons/icon_settings.png",
	"icon_build": "res://assets/ui/icons/icon_build.png",
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
	"fishing_goldfish": "res://assets/pond/fish/koi_fish/koi_fish_01/koi_fish_swim_right_01.png",
	"fishing_bottle": "res://assets/pond/bottle/bottle_float_01.png",
	"fishing_branch": "res://assets/pond/props/tree_branch.png",
	"fishing_rod": "res://assets/pond/props/fishing_rod.png",
	"fishing_bobber": "res://assets/pond/props/fishing_bobber.png",
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
	{"id": "father", "label": "爸爸的小屋", "room_label": "爸爸的房间", "asset": "house_father", "pos": Vector2(205, 160), "sign_pos": Vector2(205, 246), "height": 180.0, "hotspot_size": Vector2(86, 96)},
	{"id": "mother", "label": "妈妈的小屋", "room_label": "妈妈的房间", "asset": "house_mother", "pos": Vector2(1090, 160), "sign_pos": Vector2(1090, 246), "height": 230.0, "hotspot_size": Vector2(92, 100)},
	{"id": "player", "label": "佩琳的小屋", "room_label": "佩琳的房间", "asset": "house_player", "pos": Vector2(682, 160), "sign_pos": Vector2(682, 246), "height": 180.0, "hotspot_size": Vector2(92, 100)},
	{"id": "partner", "label": "路易的小屋", "room_label": "路易的房间", "asset": "house_partner", "pos": Vector2(370, 155), "sign_pos": Vector2(370, 246), "height": 180.0, "hotspot_size": Vector2(92, 100)},
]

const HOUSE_WINDOW_GLOWS := [
	{"center": Vector2(171, 84), "size": Vector2(22, 28)},
	{"center": Vector2(133, 154), "size": Vector2(34, 28)},
	{"center": Vector2(274, 137), "size": Vector2(20, 31)},
	{"center": Vector2(644, 84), "size": Vector2(22, 28)},
	{"center": Vector2(594, 156), "size": Vector2(20, 31)},
	{"center": Vector2(695, 156), "size": Vector2(20, 31)},
	{"center": Vector2(767, 151), "size": Vector2(34, 31)},
	{"center": Vector2(998, 156), "size": Vector2(24, 30)},
	{"center": Vector2(1167, 156), "size": Vector2(24, 30)}
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
		"label": "佩琳的房间",
		"asset": "room_anna",
		"foreground": "room_anna_fg",
		"spawn": Vector2(640, 560),
	},
}

const CHARACTER_DATA := [
	{"role": "girl", "label": "女儿", "default_name": "佩琳", "asset": "girl", "house_id": "player", "house_label": "佩琳的小屋", "npc_pos": Vector2(700, 405), "wander_radius": 90.0},
	{"role": "boy", "label": "伙伴", "default_name": "路易", "asset": "boy", "house_id": "partner", "house_label": "路易的小屋", "npc_pos": Vector2(805, 535), "wander_radius": 85.0},
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
var mailbox_badge: Sprite2D = null
var active_modal: Control = null
var map_ui: Control = null
var global_map_ui: Control = null
var pond_fishing_available := false
var pond_fishing_prompt: Label = null
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
var memory_link_visualizer: Node2D = null
var night_window_glow_root: Node2D = null
const SETTINGS_PATH := "user://family_garden_settings.json"
var settings_brightness := 1.0
var settings_day_night_enabled := true
var settings_music_volume := 0.85
var settings_sfx_volume := 0.85
var settings_master_muted := false
var settings_panel_labels: Dictionary = {}

func _load_cloud_data() -> void:
	if CloudManager == null:
		return

	_show_toast("Loading family garden...")
	var data: Dictionary = await CloudManager.load_family_data()
	MemoryManager.apply_cloud_data(data)
	cloud_load_finished = true
	MemoryManager.save_game()
	_refresh_world_chat_feed()


func setup(p_world: Node2D, p_ui_layer: CanvasLayer) -> void:
	world = p_world
	ui_layer = p_ui_layer
	MemoryManager.mailbox_alert_changed.connect(_on_mailbox_alert_changed)
	_load_settings()
	_apply_settings()
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if mode != "fishpond":
		return
	if active_modal != null and is_instance_valid(active_modal):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if pond_fishing_available:
			get_viewport().set_input_as_handled()
			_start_fishing_sequence()

func _build_ui() -> void:
	var root := Control.new()
	root.name = "UIRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	var header_panel := Panel.new()
	header_panel.name = "HeaderReadabilityPanel"
	header_panel.position = Vector2(10, 8)
	header_panel.size = Vector2(720, 70)
	header_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.08, 0.07, 0.055, 0.34)
	header_style.border_color = Color(0.50, 0.40, 0.28, 0.18)
	header_style.set_border_width_all(1)
	header_style.corner_radius_top_left = 8
	header_style.corner_radius_top_right = 8
	header_style.corner_radius_bottom_left = 8
	header_style.corner_radius_bottom_right = 8
	header_panel.add_theme_stylebox_override("panel", header_style)
	root.add_child(header_panel)

	var day_night_clock := TextureRect.new()
	day_night_clock.name = "DayNightClock"
	day_night_clock.set_script(DAY_NIGHT_CLOCK_UI_SCRIPT)
	day_night_clock.position = Vector2(GAME_SIZE.x - 136, 16)
	day_night_clock.size = Vector2(112, 124)
	day_night_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(day_night_clock)

	info_label = Label.new()
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.text = "家庭花园"
	info_label.position = Vector2(18, 14)
	info_label.size = Vector2(760, 32)
	info_label.add_theme_font_size_override("font_size", 20)
	_apply_header_label_style(info_label, true)
	root.add_child(info_label)

	var help := Label.new()
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.text = "WASD / 方向键：移动   |   E：互动   |   点击物体：互动"
	help.position = Vector2(18, 45)
	help.size = Vector2(920, 24)
	help.add_theme_font_size_override("font_size", 13)
	_apply_header_label_style(help, false)
	root.add_child(help)

	# 底部导航保持紧凑，避免遮住主画面。
	_add_button(root, "世界", Vector2(248, 672), Vector2(86, 32), "global_map")
	_add_button(root, "家树", Vector2(338, 672), Vector2(82, 32), "family_tree")
	_add_button(root, "地图", Vector2(430, 672), Vector2(76, 32), "travel_map")
	_add_button(root, "明信片", Vector2(516, 672), Vector2(120, 32), "MemoryManager.postcards")
	_add_world_chat_feed(root, Vector2(650, 604), Vector2(382, 60))
	world_chat_input = _add_world_chat_box(root, Vector2(650, 672), Vector2(300, 32))
	_add_button(root, "聊天", Vector2(958, 672), Vector2(74, 32), "world_chat_history")
	_add_button(root, "设置", Vector2(1038, 672), Vector2(98, 32), "settings")
	_refresh_world_chat_feed()

func _apply_header_label_style(label: Label, is_title: bool) -> void:
	label.add_theme_color_override("font_color", Color(0.94, 0.89, 0.78, 1.0) if is_title else Color(0.88, 0.83, 0.72, 0.95))
	label.add_theme_color_override("font_outline_color", Color(0.07, 0.055, 0.04, 0.88))
	label.add_theme_constant_override("outline_size", 3 if is_title else 2)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.015, 0.01, 0.62))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

func _add_button(root: Control, button_text: String, pos: Vector2, button_size: Vector2, action: String) -> Button:
	var button := Button.new()
	button.text = button_text
	button.position = pos
	button.size = button_size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(_on_ui_button.bind(action))
	_apply_button_style(button, action == "toggle_plant" and plant_mode)
	_fit_button_font(button, button_text, 13)
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
		world_chat_input.placeholder_text = "发送中..."

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
	title.text = "家庭留言"
	title.position = Vector2(34, 24)
	title.size = Vector2(470, 30)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(34, 70)
	scroll.size = Vector2(492, 360)
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
		return "无时间"
	return raw_time.replace("T", " ").replace("Z", "")

func _on_ui_button(action: String) -> void:
	match action:
		"family_tree":
			_open_family_tree_view()
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
		"settings":
			_open_settings_panel()
		"save":
			MemoryManager.save_game()
			_show_toast("已保存。")
		"back_garden":
			_show_garden()
		"reset":
			_show_toast("在线版本不能重置。")

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
	title.text = "你在花园里是谁？"
	title.position = Vector2(40, 28)
	title.size = Vector2(900, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "选择一个家庭成员作为自己，其他人会留在花园里。"
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
	name_input.placeholder_text = "你的名字"
	name_input.text = MemoryManager.player_display_name if MemoryManager.player_display_name != "" else "佩琳"
	name_input.position = Vector2(350, 140)
	name_input.size = Vector2(280, 38)
	panel.add_child(name_input)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(75, 205)
	grid.size = Vector2(830, 300)
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 18)
	panel.add_child(grid)

	for i in range(CHARACTER_DATA.size()):
		var role_data: Dictionary = CHARACTER_DATA[i]
		_add_role_card(grid, role_data, Vector2.ZERO, Vector2(185, 260), name_input)

func _add_role_card(parent: Control, role_data: Dictionary, pos: Vector2, card_size: Vector2, name_input: LineEdit) -> void:
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
	choose_btn.pressed.connect(_confirm_role_selection.bind(str(role_data.get("role", "girl")), name_input))
	vbox.add_child(choose_btn)

func _make_character_preview_texture(source: Texture2D) -> Texture2D:
	var atlas := AtlasTexture.new()
	var frame_w: float = float(source.get_width()) / 3.0
	var frame_h: float = float(source.get_height()) / 4.0
	atlas.atlas = source
	atlas.region = Rect2(Vector2(frame_w, 0.0), Vector2(frame_w, frame_h))
	return atlas


func _confirm_role_selection(role_key: String, name_input: LineEdit) -> void:
	MemoryManager.selected_role_key = role_key
	MemoryManager.player_display_name = name_input.text.strip_edges()
	if MemoryManager.player_display_name == "":
		MemoryManager.player_display_name = _default_name_for_role(role_key)
	MemoryManager.save_game()
	_close_active_panel()
	_show_garden()
	var canonical_role: String = CharacterDB.resolve(role_key)
	CloudManager.ensure_cloud_identity(canonical_role, MemoryManager.player_display_name)


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
		plant_button.text = "种植：开" if plant_mode else "种植：关"
		_apply_button_style(plant_button, plant_mode)

func _show_garden(spawn_key: String = "default") -> void:
	_close_active_panel()
	_clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	mode = "garden"
	adding_place = false
	_clear_world()
	info_label.text = "家庭花园"
	AudioManager.play_music("garden")
	_add_background()
	_add_collision_zones()
	_add_garden_spawn_markers()
	_add_houses()
	_add_night_window_glows()
	_add_core_objects()
	_add_npcs()
	_add_animals()
	var spawn: Vector2 = ScenePortal.get_spawn("garden", spawn_key)
	_add_player(spawn)
	_rebuild_plants()
	_spawn_demo_memory_nodes()
	MemoryManager.maybe_recompute_family_portrait()
	_render_family_portrait()
	ScenePortal.build_portals("garden", world, _on_portal_travel)
	_setup_garden_builder()

var _demo_memories: Array = []
var _demo_bottles: Array = []
var _fishpond_memories: Array = []
var _room_objects: Array = []

var _travel_lock := false
const PORTAL_TRAVEL_COOLDOWN := 0.8

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
	if MemoryManager.get_nodes_for_scene("garden").is_empty():
		var uploaders := _demo_other_members()
		for i in range(3):
			var slot: Variant = SlotManager.allocate("garden", "memory_flower", "garden_seed_%d" % i)
			if slot == null:
				break
			var mem := MemoryManager.create_memory(AIClient.mock_memory_card(), "photo")
			if not uploaders.is_empty():
				mem["user_id"] = uploaders[i % uploaders.size()]  # 鏀逛笂浼犺€呬负鍒殑鎴愬憳
			MemoryManager.create_node(String(mem.get("id", "")), "garden", "memory_flower", String(slot.get("slot_id", "")))
		MemoryManager.save_game()  # 钀界洏鏀硅繃鐨?user_id
	_render_scene_nodes("garden", _demo_memories, _on_memory_clicked)
	_spawn_demo_memory_link()       # 鈮? 鏉¤蹇嗘椂鐢熸垚 mock 鍏宠仈锛堥樁娈? 鎹?cross-memory-link 鐪熻皟鐢級
	_render_memory_links("garden")
	print("[Stage1] garden memories=", _demo_memories.size(), " links=", MemoryManager.get_memory_links("garden").size())

func _spawn_demo_memory_link() -> void:
	if not MemoryManager.get_memory_links("garden").is_empty():
		return
	if _demo_memories.size() < 2:
		return
	var a := String(_demo_memories[0].get("memory_id", ""))
	var b := String(_demo_memories[-1].get("memory_id", ""))
	if a == "" or b == "" or a == b:
		return
	var link: Dictionary = AIClient.mock_link()  # 闃舵2 鎹?await AIClient.cross_memory_link(a, candidates)
	MemoryManager.create_memory_link(a, b, "garden",
		String(link.get("relation_type", "same_place")), String(link.get("question", "")))

func _render_memory_links(scene: String) -> void:
	if world == null or not is_instance_valid(world):
		return
	var existing := world.get_node_or_null("MemoryLinkRoot")
	if existing != null:
		existing.queue_free()
	memory_link_visualizer = null

	var node_map: Dictionary = {}
	for memory_entry in _demo_memories:
		if not (memory_entry is Dictionary):
			continue
		var row: Dictionary = memory_entry
		var memory_id: String = String(row.get("memory_id", ""))
		var live_node: Variant = row.get("node", null)
		if memory_id != "" and live_node is Node2D:
			node_map[memory_id] = live_node

	var links: Array = MemoryManager.get_memory_links(scene)
	if links.is_empty() or node_map.is_empty():
		return

	var visualizer := MEMORY_LINK_VISUALIZER_SCRIPT.new() as Node2D
	visualizer.name = "MemoryLinkRoot"
	world.add_child(visualizer)
	memory_link_visualizer = visualizer
	visualizer.call("setup", node_map, links)
	if visualizer.has_signal("link_clicked"):
		visualizer.connect("link_clicked", Callable(self, "_on_memory_link_clicked"))

func _render_family_portrait() -> void:
	if world == null or not is_instance_valid(world):
		return
	var existing := world.get_node_or_null("FamilyPortraitBoard")
	if existing != null:
		existing.queue_free()
	var fp: Dictionary = MemoryManager.family_portrait
	if int(fp.get("version", 0)) <= 0:
		return
	var board := Node2D.new()
	board.name = "FamilyPortraitBoard"
	board.position = Vector2(1210, 398)
	board.z_index = 4200
	var icon := Sprite2D.new()
	icon.texture = _safe_texture(str(ASSETS.get("icon_postcard", "")))
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2(-44, -8)
	icon.scale = Vector2.ONE * 0.72
	board.add_child(icon)
	var lbl := Label.new()
	lbl.text = "家庭画像 v%d\n%d 位成员 · %d 段记忆" % [int(fp.get("version", 0)), int(fp.get("member_count", 0)), int(fp.get("memory_count", 0))]
	lbl.position = Vector2(-22, -24)
	lbl.size = Vector2(126, 48)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.18, 0.13, 0.08, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(1.0, 0.92, 0.72, 0.85))
	lbl.add_theme_constant_override("outline_size", 1)
	board.add_child(lbl)
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(160, 66)
	shape.shape = rect
	area.add_child(shape)
	area.input_event.connect(func(_v: Node, e: InputEvent, _s: int) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_show_toast("家庭画像 v%d · %d 位成员 · %d 段记忆" % [int(fp.get("version", 0)), int(fp.get("member_count", 0)), int(fp.get("memory_count", 0))]))
	board.add_child(area)
	world.add_child(board)

func _memory_flower_pos(scene: String, memory_id: String) -> Vector2:
	for nd in MemoryManager.get_nodes_for_scene(scene):
		if String(nd.get("memory_id", "")) == memory_id and String(nd.get("node_type", "")) == "memory_flower":
			var slot := SlotManager.get_slot(scene, String(nd.get("slot_id", "")))
			if not slot.is_empty():
				var p: Variant = slot.get("pos", null)
				if p is Array and (p as Array).size() >= 2:
					return Vector2(float(p[0]), float(p[1]))
	return Vector2.INF

func _draw_link_line(a: Vector2, b: Vector2, question: String) -> void:
	var head := Vector2(0, -100)
	var arc := ((a + b) * 0.5 + head) + Vector2(0, -40)
	var line := Line2D.new()
	line.name = "MemoryLink"
	line.points = PackedVector2Array([a + head, arc, b + head])
	line.width = 1.0
	line.default_color = Color(0.46, 0.66, 0.36, 0.18)
	line.z_index = 5000
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	world.add_child(line)
	var mid := arc
	var area := Area2D.new()
	area.position = mid
	area.z_index = 5001
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	area.add_child(shape)
	var tag := Label.new()
	tag.text = "联系"
	tag.position = Vector2(-12, -16)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_font_size_override("font_size", 22)
	area.add_child(tag)
	area.input_event.connect(func(_v: Node, e: InputEvent, _s: int) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_show_toast("关联：" + question))
	world.add_child(area)

func _on_memory_link_clicked(_link_id: String, link: Dictionary) -> void:
	var question: String = String(link.get("question", ""))
	if question == "":
		question = "这两段记忆有一条温柔的联系。"
	_show_toast("记忆联系：" + question)

func _render_scene_nodes(scene: String, cache: Array, click_cb: Callable) -> void:
	for nd in MemoryManager.get_nodes_for_scene(scene):
		if String(nd.get("node_type", "")) == "memory_link":
			continue
		var node_id := String(nd.get("id", ""))
		var memory_id := String(nd.get("memory_id", ""))
		var slot_id := String(nd.get("slot_id", ""))
		var mem := MemoryManager.get_memory(memory_id)
		var card: Dictionary = mem.get("ai_card", {})
		SlotManager.occupy(scene, slot_id, node_id)
		var slot := SlotManager.get_slot(scene, slot_id)
		if slot.is_empty():
			continue
		var live := NodeFactory.make_memory_node(card, slot, click_cb.bind(node_id))
		var state := String(nd.get("state", "new"))
		if String(nd.get("node_type", "")) == "memory_flower":
			_add_memory_tag(live)
		live.scale = Vector2.ONE if state == "grown" else Vector2(0.55, 0.55)  # grown=宸插紑鑺?/ new=鑺辫嫗
		world.add_child(live)
		cache.append({
			"id": node_id, "memory_id": memory_id, "card": card,
			"state": state, "answer": MemoryManager.get_answer_for_memory(memory_id), "node": live
		})

# 记忆花和背景颜色接近，补一个轻量标签方便辨认。
func _add_memory_tag(node: Node2D) -> void:
	var tag := Label.new()
	tag.name = "DemoTag"
	tag.text = "记忆"
	tag.position = Vector2(-22, -126)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", Color(0.55, 0.20, 0.35, 0.95))
	node.add_child(tag)

func _find_demo_memory(mem_id: String) -> Dictionary:
	for m in _demo_memories:
		if String(m.get("id", "")) == mem_id:
			return m
	return {}

func _on_memory_clicked(mem_id: String) -> void:
	var mem := _find_demo_memory(mem_id)
	if not mem.is_empty():
		if memory_link_visualizer != null and is_instance_valid(memory_link_visualizer):
			memory_link_visualizer.call("set_selected_memory", String(mem.get("memory_id", "")))
		_open_memory_card(mem)

# 记忆卡片 UI：AI 推测使用浅色，家人确认后显示为正式记忆。
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

	var guess := Label.new()
	guess.text = "AI 推测：" + String(card.get("guess", "")) + "（等待家人确认）"
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
		input.placeholder_text = "这段记忆从哪里开始？"
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
		_show_toast("写点内容再回答吧。")
		return
	mem["answer"] = text
	mem["state"] = "grown"
	MemoryManager.answer_memory(String(mem.get("memory_id", "")), text)  # 鎸佷箙鍖栵細瀛?answer + 鏍囪妭鐐?grown + 瀛樻。
	var bumped := MemoryManager.register_cross_member_answer(String(mem.get("memory_id", "")), MemoryManager.selected_role_key)
	_close_active_panel()
	_grow_memory_node(mem.get("node"))
	if bumped:
		_update_season_overlay()
		_show_toast("记忆长大了，花园更繁茂了。")
	else:
		_show_toast("记忆长大了。")
	if MemoryManager.maybe_recompute_family_portrait():  # 鍙備笌鎴愬憳鍙樺寲 鈫?閲嶇敾瀹跺涵鐢诲儚鏈ㄧ墝
		_render_family_portrait()

func _season_cn(season: String) -> String:
	match season:
		"autumn": return "秋"
		"summer": return "夏"
		_: return "春"

# 鐢熼暱鍔ㄧ敾锛氳姳鑻?鈫?寮€鏀撅紙鈮? 绉掞級銆傚崰浣嶅崟璐村浘鐢ㄧ缉鏀捐繎浼?seed鈫抌ud鈫抌loom銆?func _grow_memory_node(node: Variant) -> void:
func _grow_memory_node(node: Variant) -> void:
	if node == null or not is_instance_valid(node):
		return
	var n: Node2D = node
	if n.has_node("DemoTag"):
		n.get_node("DemoTag").queue_free()
	n.scale = Vector2(0.25, 0.25)
	var t := create_tween()
	t.tween_property(n, "scale", Vector2(0.7, 0.7), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "scale", Vector2(1.0, 1.0), 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# 鈹€鈹€ 鍏ㄥ眬瀵艰埅鍦板浘锛堝鑸〉 / World Map锛夆攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
const GLOBAL_MAP_REGIONS := [
	{"id": "farm", "asset": "globalmap_farm", "label": "农场", "target": "farm"},
	{"id": "garden", "asset": "globalmap_garden", "label": "花园", "target": "garden"},
	{"id": "house", "asset": "globalmap_house", "label": "房屋", "target": "house"},
	{"id": "pond", "asset": "globalmap_pond", "label": "池塘", "target": "fishpond"},
]

func _show_global_map() -> void:
	_close_active_panel()
	_clear_map_ui()
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

	var view := Control.new()
	view.name = "GlobalMapView"
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(view)
	ui_layer.move_child(view, 0)
	global_map_ui = view

	var fallback := ColorRect.new()
	fallback.name = "GlobalMapFallback"
	fallback.color = Color(0.80, 0.88, 0.70, 1.0)
	fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(fallback)

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
		_show_toast("世界地图素材还没有导入，请用 Godot 打开一次项目。")
	else:
		_show_toast("把鼠标移到地点上，点击即可进入。")

func _add_global_map_region(view: Control, region: Dictionary) -> bool:
	var tex := _safe_texture(ASSETS[str(region["asset"])])
	if tex == null:
		return false

	var img := tex.get_image()
	var pivot: Vector2 = tex.get_size() / 2.0
	if img != null:
		var used := img.get_used_rect()
		pivot = Vector2(used.position) + Vector2(used.size) / 2.0

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
	button.z_index = 10 if hovering else 0
	if is_instance_valid(shadow):
		shadow.z_index = 9 if hovering else 0

	if hovering:
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
	_show_toast("进入%s" % label_text)
	goto_scene(target)

# 鎶婁竴涓嚜鍖呭惈鐨勭紪杈戝櫒鍦烘櫙锛團arm.tscn / AnnaRoom.tscn锛夊祵杩涙寔涔呭寲鐨?world銆?# 杩欎簺鍦烘櫙鎸?1280脳720 灞忓箷鍧愭爣銆佸乏涓婅涓哄師鐐瑰埗浣滐紝鎵€浠ュ疄渚嬫斁鍦?(0,0)銆?func _build_embedded_scene(scene_key: String, scene_path: String, title: String, fallback_color: Color, add_player: bool) -> void:
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

	if add_player:
		_add_player(ScenePortal.get_spawn(scene_key, "default"))

# 鈹€鈹€ 閫氱敤鍦烘櫙鍒囨崲锛圫cenePortal 妗嗘灦锛夆攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
func goto_scene(target: String, spawn_key: String = "default") -> void:
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
			AudioManager.play_music("farm")
			_build_embedded_scene("farm", FARM_SCENE, "农场", Color(0.74, 0.62, 0.44, 1.0), false)
			ScenePortal.build_portals("farm", world, _on_portal_travel)
		"house":
			AudioManager.play_music("house")
			_build_embedded_scene("house", ANNA_ROOM_SCENE, "房屋", Color(0.66, 0.56, 0.44, 1.0), true)
		_:
			push_warning("[SceneManager] Unknown scene '%s', travel ignored." % target)

func _on_portal_travel(target: String, spawn_key: String) -> void:
	if _travel_lock:
		return
	var target_key := _portal_target_key(target)
	if target_key == "" or target_key == mode:
		return
	_travel_lock = true
	goto_scene(target, spawn_key)
	var timer := get_tree().create_timer(PORTAL_TRAVEL_COOLDOWN)
	timer.timeout.connect(func() -> void: _travel_lock = false)

func _portal_target_key(target: String) -> String:
	if target == "garden" or target == "res://scenes/Main.tscn":
		return "garden"
	if target == "fishpond" or target == "pond" or target == POND_AREA_SCENE:
		return "fishpond"
	if target == "farm" or target == FARM_SCENE:
		return "farm"
	if target == "room" or target == "house" or target == ANNA_ROOM_SCENE:
		return "room"
	return ""

# 閫氱敤鍦烘櫙鑳屾櫙锛氫紭鍏堣 manifest bg 鐪熷疄缇庢湳锛岀己鍥惧洖閫€绾壊锛坒allback_color锛夈€?func _add_scene_background(scene: String, fallback_color: Color) -> void:
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

# 鈹€鈹€ 鐖哥埜楸煎 fishpond 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
func _build_fishpond(spawn_key: String = "default") -> void:
	_close_active_panel()
	_clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	mode = "fishpond"
	adding_place = false
	plant_mode = false
	_update_plant_button()
	AudioManager.play_music("fishpond")
	_clear_world()
	info_label.text = "池塘"
	var pond_area: Node2D = null
	if ResourceLoader.exists(POND_AREA_SCENE):
		pond_area = (load(POND_AREA_SCENE) as PackedScene).instantiate() as Node2D
		if pond_area != null:
			pond_area.position = GAME_SIZE / 2.0
			world.add_child(pond_area)
	else:
		_add_scene_background("fishpond", Color(0.42, 0.62, 0.70, 1.0))
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
	_register_pond_fishing_spot(pond_area)
	_fishpond_memories.clear()
	_render_scene_nodes("fishpond", _fishpond_memories, _on_fishpond_memory_clicked)
	ScenePortal.build_portals("fishpond", world, _on_portal_travel)
	print("[Stage1] fishpond bottles=", _demo_bottles.size(), " shore memories=", _fishpond_memories.size(), " slot usage=", SlotManager.usage("fishpond"))

const SCENE_BOTTLE_QUESTION := "如果这个漂流瓶能带来爸爸的一句话，你希望里面写着什么？"
const POND_BOTTLE_LIMIT := 2
const FISHING_RESULTS := [
	{"id": "goldfish", "item_id": "fish_goldfish", "title": "金鱼", "body": "鱼线轻轻一沉，一条金色小鱼在桶边闪了一下。", "asset": "fishing_goldfish", "color": Color(0.96, 0.58, 0.18, 1.0)},
	{"id": "bottle", "title": "漂流瓶", "body": "你钓起一个小小的漂流瓶，瓶口还带着潮湿的水汽。", "asset": "fishing_bottle", "color": Color(0.28, 0.54, 0.72, 1.0)},
	{"id": "branch", "title": "树枝", "body": "这次钓上来的是一截树枝，像是从岸边慢慢漂来的。", "asset": "fishing_branch", "color": Color(0.45, 0.30, 0.16, 1.0)}
]

# 闃舵1 mock锛氬湪姘撮潰 slot 涓婄敓鎴愬彲鐐瑰嚮婕傛祦鐡躲€傜偣鍑?鈫?闂闈㈡澘 鈫?鍥炵瓟 鈫?宀歌竟鐢熻蹇嗚妭鐐广€?# 闂鏉ヨ嚜 AIClient锛坢ock锛岄樁娈? 鎹?generate-bottle-question 鐪熻皟鐢級銆?func _spawn_demo_bottles() -> void:
func _spawn_demo_bottles() -> void:
	_demo_bottles.clear()
	SlotManager.reset("fishpond")
	SlotManager.load_scene("fishpond")
	var questions: Array = AIClient.mock_bottle_questions()
	var spawned := 0
	for i in range(questions.size()):
		if spawned >= max(0, POND_BOTTLE_LIMIT - 1):
			break
		var slot: Variant = SlotManager.allocate("fishpond", "bottle", "bottle_%d" % i)
		if slot == null:
			break
		var bid := "bottle_%d" % i
		var card := {"node_type": "bottle", "suggested_scene": "fishpond"}
		var node := NodeFactory.make_memory_node(card, slot, _on_bottle_clicked.bind(bid))
		world.add_child(node)
		_demo_bottles.append({"id": bid, "question": String(questions[i]), "state": "floating", "answer": "", "node": node})
		spawned += 1

func _register_scene_message_bottle(pond_area: Node2D) -> void:
	if pond_area == null:
		return
	var bottle := pond_area.get_node_or_null("MessageBottle") as Area2D
	if bottle == null:
		return
	bottle.input_pickable = true
	if not bottle.input_event.is_connected(_on_scene_message_bottle_input):
		bottle.input_event.connect(_on_scene_message_bottle_input)
	if _find_demo_bottle("scene_bottle").is_empty() and _demo_bottles.size() < POND_BOTTLE_LIMIT:
		_demo_bottles.append({"id": "scene_bottle", "question": SCENE_BOTTLE_QUESTION, "state": "floating", "answer": "", "node": bottle})

func _on_scene_message_bottle_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_on_bottle_clicked("scene_bottle")

func _register_pond_fishing_spot(pond_area: Node2D) -> void:
	if pond_area == null:
		return
	var fishing_spot := pond_area.get_node_or_null("FishingSpot") as Area2D
	if fishing_spot == null:
		return
	pond_fishing_available = false
	_hide_pond_fishing_prompt()
	fishing_spot.monitoring = true
	fishing_spot.collision_mask = 1
	fishing_spot.input_pickable = true
	if not fishing_spot.body_entered.is_connected(_on_pond_fishing_spot_body_entered):
		fishing_spot.body_entered.connect(_on_pond_fishing_spot_body_entered)
	if not fishing_spot.body_exited.is_connected(_on_pond_fishing_spot_body_exited):
		fishing_spot.body_exited.connect(_on_pond_fishing_spot_body_exited)
	if not fishing_spot.input_event.is_connected(_on_pond_fishing_spot_input):
		fishing_spot.input_event.connect(_on_pond_fishing_spot_input)

func _on_pond_fishing_spot_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if active_modal != null and is_instance_valid(active_modal):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_start_fishing_sequence()

func _on_pond_fishing_spot_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	pond_fishing_available = true
	_show_pond_fishing_prompt()

func _on_pond_fishing_spot_body_exited(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	pond_fishing_available = false
	_hide_pond_fishing_prompt()

func _show_pond_fishing_prompt() -> void:
	if ui_layer == null:
		return
	if pond_fishing_prompt != null and is_instance_valid(pond_fishing_prompt):
		pond_fishing_prompt.visible = true
		return
	pond_fishing_prompt = Label.new()
	pond_fishing_prompt.name = "PondFishingPrompt"
	pond_fishing_prompt.text = "靠近钓鱼台，按 E 开始钓鱼"
	pond_fishing_prompt.position = Vector2(460, 616)
	pond_fishing_prompt.size = Vector2(360, 32)
	pond_fishing_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pond_fishing_prompt.add_theme_font_size_override("font_size", 18)
	pond_fishing_prompt.add_theme_color_override("font_color", Color(0.96, 0.90, 0.76, 1.0))
	pond_fishing_prompt.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.05, 0.92))
	pond_fishing_prompt.add_theme_constant_override("outline_size", 3)
	ui_layer.add_child(pond_fishing_prompt)

func _hide_pond_fishing_prompt() -> void:
	if pond_fishing_prompt != null and is_instance_valid(pond_fishing_prompt):
		pond_fishing_prompt.queue_free()
	pond_fishing_prompt = null

func _start_fishing_sequence() -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay

	var panel := Panel.new()
	panel.position = Vector2(382, 136)
	panel.size = Vector2(516, 392)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)

	var title := Label.new()
	title.text = "正在钓鱼"
	title.position = Vector2(42, 28)
	title.size = Vector2(432, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.20, 0.24, 0.20, 1.0))
	panel.add_child(title)

	var water := ColorRect.new()
	water.position = Vector2(78, 168)
	water.size = Vector2(360, 34)
	water.color = Color(0.34, 0.64, 0.72, 0.42)
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(water)

	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.45, 0.36, 0.24, 0.78)
	line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = 1
	panel.add_child(line)

	var rod := TextureRect.new()
	rod.position = Vector2(118, 58)
	rod.size = Vector2(88, 172)
	rod.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rod.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rod.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rod.texture = _safe_texture(str(ASSETS.get("fishing_rod", "")))
	rod.pivot_offset = Vector2(rod.size.x * 0.46, rod.size.y * 0.86)
	rod.rotation = -0.08
	rod.z_index = 2
	rod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(rod)

	var bobber := TextureRect.new()
	bobber.position = Vector2(292, 139)
	bobber.size = Vector2(28, 54)
	bobber.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bobber.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bobber.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bobber.texture = _safe_texture(str(ASSETS.get("fishing_bobber", "")))
	bobber.z_index = 3
	bobber.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bobber)

	var hook_item := TextureRect.new()
	hook_item.position = bobber.position + Vector2(-12, 38)
	hook_item.size = Vector2(52, 52)
	hook_item.visible = false
	hook_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hook_item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hook_item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hook_item.z_index = 4
	hook_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hook_item)

	var update_fishing_line := func() -> void:
		if not is_instance_valid(line) or not is_instance_valid(rod) or not is_instance_valid(bobber):
			return
		var rod_tip_local := Vector2(rod.size.x * 0.76, rod.size.y * 0.05)
		var rod_tip := rod.position + rod.pivot_offset + (rod_tip_local - rod.pivot_offset).rotated(rod.rotation)
		var bobber_top := bobber.position + Vector2(bobber.size.x * 0.5, bobber.size.y * 0.12)
		line.points = PackedVector2Array([rod_tip, bobber_top])
		if is_instance_valid(hook_item):
			hook_item.position = bobber.position + Vector2(-12, 38)
	update_fishing_line.call()

	var ripple := ColorRect.new()
	ripple.position = Vector2(222, 166)
	ripple.size = Vector2(42, 8)
	ripple.color = Color(0.90, 1.0, 0.95, 0.38)
	ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(ripple)

	var status := Label.new()
	status.text = "等浮漂下沉，在绿色区域拉竿，越靠中间越容易钓到鱼"
	status.position = Vector2(58, 216)
	status.size = Vector2(400, 28)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 17)
	status.add_theme_color_override("font_color", Color(0.34, 0.29, 0.22, 1.0))
	panel.add_child(status)

	var track_back := Panel.new()
	track_back.position = Vector2(76, 258)
	track_back.size = Vector2(364, 26)
	track_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0.50, 0.36, 0.24, 0.22)
	track_style.border_color = Color(0.42, 0.30, 0.18, 0.55)
	track_style.set_border_width_all(1)
	track_style.set_corner_radius_all(6)
	track_back.add_theme_stylebox_override("panel", track_style)
	panel.add_child(track_back)

	var sweet_zone := ColorRect.new()
	sweet_zone.position = Vector2(202, 258)
	sweet_zone.size = Vector2(108, 26)
	sweet_zone.color = Color(0.54, 0.76, 0.44, 0.78)
	sweet_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sweet_zone)

	var marker := ColorRect.new()
	marker.position = Vector2(78, 252)
	marker.size = Vector2(8, 38)
	marker.color = Color(0.90, 0.28, 0.18, 1.0)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(marker)

	var pull_btn := Button.new()
	pull_btn.text = "拉竿"
	pull_btn.position = Vector2(198, 318)
	pull_btn.size = Vector2(120, 42)
	pull_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_style(pull_btn, false)
	panel.add_child(pull_btn)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(rod, "rotation", 0.03, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(bobber, "position", Vector2(326, 142), 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ripple, "scale", Vector2(1.35, 1.0), 0.32)
	tween.tween_method(func(_value: float) -> void: update_fishing_line.call(), 0.0, 1.0, 0.36)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		if is_instance_valid(status):
			status.text = "浮漂动了，准备拉竿"
	)
	tween.tween_interval(0.45)
	tween.set_parallel(true)
	tween.tween_property(bobber, "position:y", 130.0, 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ripple, "modulate:a", 0.12, 0.14)
	tween.tween_method(func(_value: float) -> void: update_fishing_line.call(), 0.0, 1.0, 0.16)
	tween.set_parallel(false)
	tween.set_parallel(true)
	tween.tween_property(bobber, "position:y", 154.0, 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_method(func(_value: float) -> void: update_fishing_line.call(), 0.0, 1.0, 0.16)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		if is_instance_valid(status):
			status.text = "有东西上钩了，点拉竿！"
	)

	var marker_tween := create_tween()
	marker_tween.set_loops()
	marker_tween.tween_property(marker, "position:x", 432.0, 1.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	marker_tween.tween_property(marker, "position:x", 78.0, 1.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	pull_btn.pressed.connect(func() -> void:
		if not is_instance_valid(marker):
			return
		pull_btn.disabled = true
		if is_instance_valid(marker_tween):
			marker_tween.kill()
		if is_instance_valid(tween):
			tween.kill()
		var marker_center := marker.position.x + marker.size.x * 0.5
		var target_center := sweet_zone.position.x + sweet_zone.size.x * 0.5
		var distance := absf(marker_center - target_center)
		var hit_zone := marker_center >= sweet_zone.position.x and marker_center <= sweet_zone.position.x + sweet_zone.size.x
		var score := clampf(1.0 - distance / 72.0, 0.0, 1.0) if hit_zone else 0.0
		var caught_result: Dictionary = {}
		var reel_success: bool = false
		if hit_zone:
			caught_result = _pick_fishing_result(score)
			reel_success = not caught_result.is_empty()
		if not hit_zone:
			status.text = "脱钩了，什么也没钓到"
		elif not reel_success:
			status.text = "鱼线一松，东西脱钩了"
		elif score >= 0.72:
			status.text = "时机很好，正在收线"
		else:
			status.text = "拉住了，慢慢收线"
		if is_instance_valid(hook_item):
			hook_item.visible = reel_success
			if reel_success:
				var asset_key: String = String(caught_result.get("asset", ""))
				hook_item.texture = _safe_texture(str(ASSETS.get(asset_key, "")))
				hook_item.size = Vector2(62, 42) if String(caught_result.get("id", "")) == "branch" else Vector2(52, 52)
				update_fishing_line.call()
		var finish_tween := create_tween()
		finish_tween.set_parallel(true)
		if reel_success:
			finish_tween.tween_property(bobber, "position", Vector2(204, 96), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
			finish_tween.tween_property(rod, "rotation", -0.22, 0.28).set_trans(Tween.TRANS_BACK)
			finish_tween.tween_method(func(_value: float) -> void: update_fishing_line.call(), 0.0, 1.0, 0.28)
		else:
			finish_tween.tween_property(bobber, "position", Vector2(332, 154), 0.18).set_trans(Tween.TRANS_SINE)
			finish_tween.tween_property(rod, "rotation", -0.04, 0.18).set_trans(Tween.TRANS_SINE)
			finish_tween.tween_method(func(_value: float) -> void: update_fishing_line.call(), 0.0, 1.0, 0.18)
		finish_tween.set_parallel(false)
		finish_tween.tween_interval(0.12)
		finish_tween.tween_callback(func() -> void:
			if reel_success:
				_open_fishing_result_panel(caught_result)
			else:
				_open_fishing_failed_panel()
		)
	)

func _pick_fishing_result(score: float) -> Dictionary:
	var escape_chance: float = 0.24
	if score < 0.45:
		escape_chance = 0.42
	elif score >= 0.82:
		escape_chance = 0.10
	if randf() < escape_chance:
		return {}
	var goldfish_chance: float = 0.28
	if score >= 0.82:
		goldfish_chance = 0.42
	elif score < 0.58:
		goldfish_chance = 0.18
	if randf() < goldfish_chance:
		return FISHING_RESULTS[0]
	if randf() < 0.45:
		return FISHING_RESULTS[1]
	return FISHING_RESULTS[2]

func _open_fishing_failed_panel() -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay

	var panel := Panel.new()
	panel.position = Vector2(402, 184)
	panel.size = Vector2(476, 274)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = "鱼脱钩了"
	title.position = Vector2(44, 48)
	title.size = Vector2(388, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.20, 0.24, 0.22, 1.0))
	panel.add_child(title)

	var body := Label.new()
	body.text = "拉竿时机偏了，鱼线松了一下，水面只剩一圈涟漪。"
	body.position = Vector2(62, 112)
	body.size = Vector2(352, 64)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.32, 0.27, 0.20, 1.0))
	panel.add_child(body)

	_add_panel_button(panel, "再试一次", Vector2(104, 204), Vector2(130, 40), "fish_again")
	_add_panel_button(panel, "收起鱼竿", Vector2(258, 204), Vector2(132, 40), "close")

func _open_fishing_result_panel(result: Dictionary = {}) -> void:
	_close_active_panel()
	if result.is_empty():
		_open_fishing_failed_panel()
		return
	_award_fishing_result(result)
	var result_color: Color = result.get("color", Color(0.5, 0.5, 0.5, 1.0))
	var overlay := _create_modal_overlay()
	active_modal = overlay

	var panel := Panel.new()
	panel.position = Vector2(292, 150)
	panel.size = Vector2(696, 420)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var icon_back := Panel.new()
	icon_back.position = Vector2(42, 82)
	icon_back.size = Vector2(150, 150)
	icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = result_color.lightened(0.35)
	icon_style.border_color = Color(0.52, 0.42, 0.28, 0.72)
	icon_style.set_border_width_all(2)
	icon_style.corner_radius_top_left = 8
	icon_style.corner_radius_top_right = 8
	icon_style.corner_radius_bottom_left = 8
	icon_style.corner_radius_bottom_right = 8
	icon_back.add_theme_stylebox_override("panel", icon_style)
	panel.add_child(icon_back)

	var result_icon := TextureRect.new()
	result_icon.position = Vector2(58, 98)
	result_icon.size = Vector2(118, 118)
	result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_icon.texture = _safe_texture(str(ASSETS.get(String(result.get("asset", "")), "")))
	panel.add_child(result_icon)

	var title := Label.new()
	title.text = "钓到了：" + String(result.get("title", "什么东西"))
	title.position = Vector2(228, 78)
	title.size = Vector2(382, 44)
	title.clip_text = true
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.18, 0.24, 0.22, 1.0))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "池塘收获"
	subtitle.position = Vector2(230, 126)
	subtitle.size = Vector2(280, 24)
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.48, 0.42, 0.32, 0.92))
	panel.add_child(subtitle)

	var body := Label.new()
	body.text = String(result.get("body", "鱼线从池塘里收了回来。"))
	body.position = Vector2(230, 166)
	body.size = Vector2(398, 118)
	body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	body.clip_text = true
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.25, 0.24, 0.20, 1.0))
	panel.add_child(body)

	if String(result.get("id", "")) == "bottle":
		_add_panel_button(panel, "打开", Vector2(282, 334), Vector2(132, 42), "open_caught_bottle")
	else:
		_add_panel_button(panel, "再钓一次", Vector2(190, 334), Vector2(150, 42), "fish_again")
		_add_panel_button(panel, "收下", Vector2(372, 334), Vector2(126, 42), "close")

func _award_fishing_result(result: Dictionary) -> void:
	var result_id := String(result.get("id", ""))
	if result_id != "goldfish":
		return
	var item_id := String(result.get("item_id", "fish_goldfish"))
	var inv := get_node_or_null("/root/InventoryManager")
	if inv == null or not inv.has_method("give"):
		return
	var leftover: int = inv.give(item_id, 1)
	if leftover > 0:
		_show_toast("背包已满，金鱼没有放进去。")
	else:
		_show_toast("金鱼已放入背包。")

func _open_caught_bottle_content() -> void:
	var bid := "caught_bottle_" + str(Time.get_ticks_msec())
	var question := "瓶中的纸条写着：你希望家人记住这个夏天的哪一刻？"
	_demo_bottles.append({"id": bid, "question": question, "state": "floating", "answer": "", "node": null})
	_open_bottle_panel(_find_demo_bottle(bid))

func _find_demo_bottle(bid: String) -> Dictionary:
	for b in _demo_bottles:
		if String(b.get("id", "")) == bid:
			return b
	return {}

func _on_bottle_clicked(bid: String) -> void:
	var b := _find_demo_bottle(bid)
	if not b.is_empty():
		_open_bottle_panel(b)

# 漂流瓶问题面板：未回答时显示问题和输入框，已回答时显示答案。
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

	var title := Label.new()
	title.text = "漂流瓶里的问题"
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
		input.placeholder_text = "写下你的回答..."
		input.position = Vector2(34, 160)
		input.size = Vector2(492, 130)
		panel.add_child(input)
		_add_panel_button(panel, "取消", Vector2(150, 312), Vector2(120, 40), "close")
		var submit := Button.new()
		submit.text = "回答"
		submit.position = Vector2(290, 312)
		submit.size = Vector2(120, 40)
		submit.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_button_style(submit, false)
		submit.pressed.connect(_submit_bottle_answer.bind(String(b.get("id", "")), input))
		panel.add_child(submit)
	else:
		var ans_title := Label.new()
		ans_title.text = "你的回答（已保存为记忆）"
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

func _submit_bottle_answer(bid: String, input: TextEdit) -> void:
	var b := _find_demo_bottle(bid)
	if b.is_empty():
		return
	var text: String = input.text.strip_edges()
	if text == "":
		_show_toast("先写下一点内容。")
		return
	b["answer"] = text
	b["state"] = "opened"
	_close_active_panel()
	var slot: Variant = SlotManager.allocate("fishpond", "memory_flower", bid + "_mem")
	if slot != null:
		var card := {
			"title": "池塘记忆",
			"description": text,
			"memory_type": "father",
			"suggested_scene": "fishpond",
			"question": String(b.get("question", "")),
			"node_type": "memory_flower",
			"confidence": 1.0,
			"guess": "一段从池塘带回来的记忆。"
		}
		var mem := MemoryManager.create_memory(card, "bottle")
		var mem_id := String(mem.get("id", ""))
		MemoryManager.create_node(mem_id, "fishpond", "memory_flower", String(slot.get("slot_id", "")))
		MemoryManager.answer_memory(mem_id, text)
		var mem_node := NodeFactory.make_memory_node(card, slot, _on_fishpond_memory_clicked.bind(mem_id))
		mem_node.scale = Vector2(0.25, 0.25)
		world.add_child(mem_node)
		_grow_memory_node(mem_node)
		_fishpond_memories.append({"id": mem_id, "memory_id": mem_id, "card": card, "state": "grown", "answer": text, "node": mem_node})
	_show_toast("漂流瓶变成了一段池塘记忆。")

func _on_fishpond_memory_clicked(mem_id: String) -> void:
	for mem in _fishpond_memories:
		if String(mem.get("id", "")) == mem_id or String(mem.get("memory_id", "")) == mem_id:
			_open_memory_card(mem)
			return
	_show_toast("一段池塘记忆。")

func _clear_world() -> void:
	pond_fishing_available = false
	_hide_pond_fishing_prompt()
	for child in world.get_children():
		child.queue_free()
	plant_nodes.clear()
	memory_link_visualizer = null
	night_window_glow_root = null

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

# 鍒嗗姘涘洿鍙犲姞灞傦紙瀹跺涵鍏崇郴娓╁害璁★級锛氭寜璺ㄦ垚鍛樹簰鍔ㄦ暟鐫€鑹诧紝0鈫掓槬绋€鐤?/ 3-9鈫掑 / 10+鈫掔绻佽寕銆?# 鍗婇€忔槑鍙犲湪鑳屾櫙涔嬩笂銆佽蹇嗚姳涔嬩笅锛涙棤闇€鏂扮編鏈紝A 鐨勫垎瀛ｅ眰瀹氱鍚庡彲鏇挎崲涓虹湡灞傘€?func _add_season_overlay() -> void:
func _add_season_overlay() -> void:
	var overlay := ColorRect.new()
	overlay.name = "SeasonOverlay"
	overlay.position = Vector2.ZERO
	overlay.size = GAME_SIZE
	overlay.z_index = 1  # 鑳屾櫙(0)涔嬩笂銆佽蹇嗚姳(z=pos.y)涔嬩笅
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = _season_overlay_color(MemoryManager.garden_season())
	world.add_child(overlay)

# 璺ㄦ垚鍛樹簰鍔ㄦ暟鍙樺寲鍚庡疄鏃堕噸鐫€鑹诧紙涓嶉噸寤哄満鏅級銆?func _update_season_overlay() -> void:
func _update_season_overlay() -> void:
	if world == null or not is_instance_valid(world):
		return
	var ov := world.get_node_or_null("SeasonOverlay")
	if ov is ColorRect:
		(ov as ColorRect).color = _season_overlay_color(MemoryManager.garden_season())

func _season_overlay_color(season: String) -> Color:
	match season:
		"autumn":
			return Color(0.86, 0.52, 0.18, 0.20)  # 閲戦粍绻佽寕
		"summer":
			return Color(0.96, 0.80, 0.34, 0.12)
		_:
			return Color(0.45, 0.80, 0.50, 0.06)  # 娓呮柊绋€鐤?鏄?
func _add_garden_spawn_markers() -> void:
	var marker := Marker2D.new()
	marker.name = "GardenFromPondSpawnPoint"
	marker.position = ScenePortal.get_spawn("garden", "GardenFromPondSpawnPoint")
	world.add_child(marker)

func _add_core_objects() -> void:
	# The main garden artwork now includes the tree, buildings, mailbox, and board.
	# Keep these as invisible hotspots so interactions survive the background swap.
	_add_invisible_hotspot("family_tree", Vector2(520, 320), Vector2(180, 130), "tree", "家庭树")
	# The mailbox is painted in the garden background. This invisible hotspot makes it interactive.
	_add_mailbox_hotspot(Vector2(232, 172), Vector2(80, 80))
	# The wooden board in the lower-right background acts as an invisible message-board button.
	_add_message_board_hotspot(Vector2(1196, 456), Vector2(110, 120))

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
		_add_invisible_hotspot(
			"house_" + str(house["id"]),
			house["pos"],
			house.get("hotspot_size", Vector2(92, 92)),
			"house:" + str(house["id"]),
			str(house["label"])
		)
		_add_room_sign(house)

func _add_night_window_glows() -> void:
	if world == null or not is_instance_valid(world):
		return
	var existing := world.get_node_or_null("NightWindowGlowRoot")
	if existing != null:
		existing.queue_free()

	night_window_glow_root = Node2D.new()
	night_window_glow_root.name = "NightWindowGlowRoot"
	night_window_glow_root.z_as_relative = false
	night_window_glow_root.z_index = 3
	world.add_child(night_window_glow_root)

	for raw_glow in HOUSE_WINDOW_GLOWS:
		if not (raw_glow is Dictionary):
			continue
		var glow_data: Dictionary = raw_glow
		var center := Vector2.ZERO
		var size := Vector2(20, 24)
		var raw_center: Variant = glow_data.get("center", Vector2.ZERO)
		var raw_size: Variant = glow_data.get("size", Vector2(20, 24))
		if raw_center is Vector2:
			center = raw_center
		if raw_size is Vector2:
			size = raw_size
		_add_window_glow_rect(night_window_glow_root, center, size)

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock != null and clock.has_signal("phase_changed"):
		var callback := Callable(self, "_on_garden_phase_changed")
		if not clock.is_connected("phase_changed", callback):
			clock.connect("phase_changed", callback)
	_refresh_night_window_glows()

func _add_window_glow_rect(parent: Node2D, center: Vector2, size: Vector2) -> void:
	var outer := ColorRect.new()
	outer.position = center - size * 1.45
	outer.size = size * 2.9
	outer.color = Color(1.0, 0.72, 0.30, 0.10)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(outer)

	var mid := ColorRect.new()
	mid.position = center - size * 0.95
	mid.size = size * 1.9
	mid.color = Color(1.0, 0.82, 0.42, 0.18)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(mid)

	var core := ColorRect.new()
	core.position = center - size * 0.5
	core.size = size
	core.color = Color(1.0, 0.90, 0.55, 0.44)
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(core)

func _on_garden_phase_changed(_phase: String) -> void:
	_refresh_night_window_glows()

func _refresh_night_window_glows() -> void:
	if night_window_glow_root == null or not is_instance_valid(night_window_glow_root):
		return
	var phase := "day"
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock != null and clock.has_method("phase"):
		phase = String(clock.call("phase"))
	night_window_glow_root.visible = settings_day_night_enabled and phase == "night"

func _add_invisible_hotspot(node_name: String, pos: Vector2, hotspot_size: Vector2, action: String, label_text: String) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.position = pos
	root.z_index = int(pos.y)
	world.add_child(root)
	_add_click_area(root, hotspot_size, action, label_text)
	return root

func _add_room_sign(house: Dictionary) -> Node2D:
	var pos: Vector2 = house.get("sign_pos", house.get("pos", Vector2.ZERO) + Vector2(0, 82))
	var room_label := str(house.get("room_label", house.get("label", "房间")))
	var action := "house:" + str(house.get("id", ""))
	var root := Node2D.new()
	root.name = "RoomSign_" + str(house.get("id", "house"))
	root.position = pos
	root.z_index = int(pos.y) + 80
	world.add_child(root)

	var sign := Sprite2D.new()
	sign.texture = _safe_texture(str(ASSETS.get("wooden_sign", "")))
	sign.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sign.scale = Vector2.ONE * 1.08
	root.add_child(sign)

	var label := Label.new()
	label.text = room_label
	label.position = Vector2(-56, -38)
	label.size = Vector2(112, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", _fit_font_size_for_text(room_label, 13, 9, 6))
	label.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08, 1.0))
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.88, 0.62, 0.72))
	label.add_theme_constant_override("outline_size", 1)
	root.add_child(label)

	_add_click_area(root, Vector2(118, 88), action, str(house.get("label", room_label)), Vector2(0, -6))
	return root

func _add_npcs() -> void:
	for role_data in CHARACTER_DATA:
		var role_key := str(role_data.get("role", ""))
		if role_key == MemoryManager.selected_role_key:
			continue
		var npc_name := str(role_data.get("default_name", role_data.get("label", "家人")))
		var npc_pos: Vector2 = role_data.get("npc_pos", Vector2(720, 420))
		var npc_body := _create_character(npc_name, ASSETS[str(role_data.get("asset", "girl"))], npc_pos, false, 3, 4, role_key)
		npc_body.name = "NPC_" + role_key
		npc_body.set_script(preload("res://scripts/npc_wander.gd"))
		npc_body.set("home_position", npc_pos)
		npc_body.set("wander_radius", float(role_data.get("wander_radius", 80.0)))
		npc_body.set("move_speed", 34.0)
		npc_body.set("walk_bounds", Rect2(Vector2(35, 100), Vector2(1210, 560)))
		npc_body.call_deferred("set_blocked_rects", _get_character_blocked_rects())
		world.add_child(npc_body)
		_add_online_status_badge(npc_body, false)
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
	return Rect2(Vector2(90, 305), Vector2(1100, 330))

func _get_animal_blocked_rects() -> Array:
	# Keep animals on the editable lawn of the new main garden background.
	return [
		Rect2(Vector2(0, 0), Vector2(1280, 275)), # houses, paths, and upper fence
		Rect2(Vector2(0, 650), Vector2(1280, 70)), # bottom fence / edge
		Rect2(Vector2(0, 235), Vector2(88, 445)), # left trees / edge
		Rect2(Vector2(1192, 235), Vector2(88, 445)), # right trees / edge
	]

func _get_character_blocked_rects() -> Array:
	return [
		Rect2(Vector2(0, 0), Vector2(1280, 260)),
		Rect2(Vector2(0, 670), Vector2(1280, 50)),
		Rect2(Vector2(0, 245), Vector2(74, 425)),
		Rect2(Vector2(1206, 245), Vector2(74, 425)),
	]

func _add_collision_zones() -> void:
	# Collision zones tuned for new_garden_basic.png. The center lawn stays open for DIY placement.
	_add_collision_rect("border_top", Vector2(640, -18), Vector2(1320, 36))
	_add_collision_rect("border_bottom", Vector2(640, 738), Vector2(1320, 36))
	_add_collision_rect("border_left", Vector2(-18, 360), Vector2(36, 760))
	_add_collision_rect("border_right", Vector2(1298, 360), Vector2(36, 760))

	_add_collision_rect("upper_houses_and_fence", Vector2(640, 130), Vector2(1280, 260))
	_add_collision_rect("bottom_fence", Vector2(640, 695), Vector2(1280, 50))
	_add_collision_rect("left_tree_edge", Vector2(36, 460), Vector2(72, 430))
	_add_collision_rect("right_tree_edge", Vector2(1244, 460), Vector2(72, 430))

func _setup_garden_builder() -> void:
	var builder := get_node_or_null("/root/GardenBuildManager")
	if builder == null or not builder.has_method("setup"):
		return
	var build_area := Rect2(Vector2(80, 300), Vector2(1120, 336))
	builder.call("setup", world, ui_layer, player, build_area, _get_garden_build_blocked_rects())

func _get_garden_build_blocked_rects() -> Array:
	return [
		Rect2(Vector2(0, 0), Vector2(1280, 286)),
		Rect2(Vector2(0, 652), Vector2(1280, 68)),
		Rect2(Vector2(0, 250), Vector2(86, 430)),
		Rect2(Vector2(1194, 250), Vector2(86, 430)),
	]

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
	var role_key := MemoryManager.selected_role_key if MemoryManager.selected_role_key != "" else "girl"
	var identity := get_node_or_null("/root/GameIdentity")
	if identity != null and identity.has_method("local_role"):
		role_key = String(identity.call("local_role", role_key))
	var display_name := MemoryManager.player_display_name if MemoryManager.player_display_name != "" else _default_name_for_role(MemoryManager.selected_role_key)
	player = preload("res://scenes/Player.tscn").instantiate()
	player.position = pos
	player.name = "Player_" + MemoryManager.selected_role_key
	player.add_to_group("player")
	var parent := world if parent_override == null else parent_override
	parent.add_child(player)
	if player.has_method("apply_character"):
		player.apply_character(role_key)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = display_name
	name_label.position = Vector2(-52, -78)
	name_label.size = Vector2(104, 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.z_as_relative = false
	name_label.z_index = 10000
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.20, 0.17, 0.13, 1.0))
	player.add_child(name_label)

	_add_online_status_badge(player, true)
	var parent_canvas := parent as CanvasItem
	if parent_canvas != null and parent_canvas.y_sort_enabled:
		var sort_origin_offset := 18.0
		player.position.y += sort_origin_offset
		for child in player.get_children():
			if child is Node2D:
				(child as Node2D).position.y -= sort_origin_offset
		player.z_index = 0


func _create_character(label_text: String, path: String, pos: Vector2, controllable: bool, hframes: int = 3, vframes: int = 4, role_key: String = "") -> CharacterBody2D:
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
	var texture: Texture2D = _safe_texture(path)
	var def: Dictionary = {}
	if role_key != "":
		var db: Node = get_node_or_null("/root/CharacterDB")
		if db != null and db.has_method("get_def"):
			def = db.call("get_def", role_key) as Dictionary
			if not def.is_empty():
				var db_texture: Texture2D = db.call("texture", role_key) as Texture2D
				if db_texture != null:
					texture = db_texture
				hframes = int(def.get("hframes", hframes))
				vframes = int(def.get("vframes", vframes))
	if texture:
		sprite.texture = texture
		sprite.hframes = hframes
		sprite.vframes = vframes
		sprite.frame = 0
		if not def.is_empty():
			sprite.scale = Vector2.ONE * float(def.get("scale", 0.32))
		else:
			var frame_height := float(texture.get_height()) / float(vframes)
			if frame_height > 0.0:
				sprite.scale = Vector2.ONE * (82.0 / frame_height)
	else:
		sprite.texture = _solid_texture(32, 48, Color(0.92, 0.80, 0.62, 1.0))
		sprite.scale = Vector2(1.6, 1.6)
	body.add_child(sprite)
	body.set_meta("sprite_hframes", hframes)
	body.set_meta("sprite_vframes", vframes)

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
	name_label.position = Vector2(-52, -78)
	name_label.size = Vector2(104, 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.z_as_relative = false
	name_label.z_index = 10000
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.20, 0.17, 0.13, 1.0))
	body.add_child(name_label)

	return body


func _add_online_status_badge(parent: Node2D, online: bool) -> void:
	var dot := Label.new()
	dot.name = "OnlineStatus"
	dot.text = "●"
	dot.position = Vector2(34, -79)
	dot.size = Vector2(20, 18)
	dot.z_as_relative = false
	dot.z_index = 10001
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
		_open_family_tree_view()
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

	mode = "room"
	adding_place = false
	_clear_world()
	plant_mode = false
	_update_plant_button()

	var room_info: Dictionary = _get_room_data(id)
	var room_label: String = str(room_info.get("label", label_text))
	info_label.text = room_label

	# 鏍锋澘锛堝閲忚縼绉?搂7锛夛細鐜╁鎴块棿鐢ㄧ紪杈戝櫒鍦烘櫙 AnnaRoom.tscn锛堥潤鎬佽儗鏅?纰版挒锛夛紝
	if id == "player" and ResourceLoader.exists(ANNA_ROOM_SCENE):
		world.add_child((load(ANNA_ROOM_SCENE) as PackedScene).instantiate())
		_add_player(room_info.get("spawn", Vector2(640, 560)))
		_render_room("player")
		_add_room_hint_panel(room_label, id)
		return

	var room_rect: Rect2 = _add_room_background(str(room_info.get("asset", "")))
	_add_room_collision_zones(id, room_rect)

	var spawn: Vector2 = room_info.get("spawn", Vector2(640, 560))
	_add_player(spawn)

	# Optional true occlusion layer:
	# If you later add assets/rooms/papa_room_fg.png etc., it will be drawn above the player.
	_add_room_foreground_if_exists(str(room_info.get("foreground", "")), room_rect)
	_add_room_hint_panel(room_label, id)


func _get_room_data(house_id: String) -> Dictionary:
	if ROOM_DATA.has(house_id):
		return ROOM_DATA[house_id]

	return {
		"label": "家庭房间",
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
	sprite.z_index = 10000
	var scale_factor: float = minf(room_rect.size.x / float(texture.get_width()), room_rect.size.y / float(texture.get_height()))
	sprite.scale = Vector2.ONE * scale_factor
	world.add_child(sprite)


func _add_room_hint_panel(room_label: String, house_id: String) -> void:
	var is_player := house_id == "player"
	var panel := Panel.new()
	room_card = panel
	panel.position = Vector2(22, 86)
	panel.size = Vector2(292, 196 if is_player else 156)  # 鐜╁鎴块棿澶氫竴琛?涓婁紶鎴块棿鐓х墖"
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
	body.text = "Walk around the room.\nUse Back Garden to return."
	body.position = Vector2(18, 48)
	body.size = Vector2(250, 42)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color(0.36, 0.30, 0.23, 0.90))
	panel.add_child(body)

	var btn_y := 150 if is_player else 104
	if is_player:
		_add_panel_button(panel, "上传房间照片(mock)", Vector2(18, 104), Vector2(256, 34), "generate_room:" + house_id)
	_add_panel_button(panel, "Note", Vector2(18, btn_y), Vector2(78, 34), "house_note:" + house_id)
	_add_panel_button(panel, "Cards", Vector2(106, btn_y), Vector2(82, 34), "MemoryManager.postcards")
	_add_panel_button(panel, "Back", Vector2(198, btn_y), Vector2(76, 34), "back_garden")

# 涓婁紶鎴块棿鐓х墖 鈫?AI 璇嗗埆(AIClient锛宮ock/鐪熷悗绔?鍥為€€) 鈫?钀藉簱 + 甯冨眬 鈫?娓叉煋銆傚凡鐢熸垚鍒欎笉閲嶅銆?func _on_generate_room(house_id: String) -> void:
func _on_generate_room(house_id: String) -> void:
	if house_id != "player":
		return
	if not MemoryManager.get_room_for_user(MemoryManager.selected_role_key).is_empty():
		_show_toast("房间已经布置过了。")
		return
	var src := MemoryManager.create_memory({}, "room_photo")  # 房间照片来源记忆
	var image_url := String(src.get("image_url", ""))
	var analysis: Dictionary = await AIClient.analyze_room_photo(image_url)  # 鐪熷悗绔紭鍏堬紝澶辫触鍥為€€ mock
	RoomLayoutManager.generate(analysis, String(src.get("id", "")))
	_render_room("player")
	_show_toast("房间已生成。")

# 娓叉煋鐜╁鎴块棿宸茶惤搴撶殑瀹跺叿锛堥噸鍏?閲嶅惎鍚庨噸寤猴級銆?func _render_room(house_id: String) -> void:
func _render_room(house_id: String) -> void:
	_room_objects.clear()
	if house_id != "player":
		return
	var room := MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
	if room.is_empty():
		return
	var n := RoomLayoutManager.render(String(room.get("id", "")), world, _on_room_object_clicked)
	print("[Stage1] room objects rendered=", n, " zone usage=", ZoneManager.usage("room"))

func _on_room_object_clicked(obj_id: String) -> void:
	for o in MemoryManager.room_objects:
		if o is Dictionary and String(o.get("id", "")) == obj_id:
			_show_toast("这是 " + String(o.get("object_type", "物件")))
			return
	_show_toast("房间里的物件")


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
	add_btn.text = "添加地点"
	add_btn.position = Vector2(1086, 24)
	add_btn.size = Vector2(130, 38)
	add_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_style(add_btn, false)
	_set_button_icon(add_btn, "icon_add")
	add_btn.pressed.connect(_start_add_place)
	map_ui.add_child(add_btn)

	var hint := Label.new()
	hint.text = "在地图上放一个图钉，添加一段记忆。"
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
	_show_toast("在旅行地图上点击一个位置。")

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
	title.text = "添加地点"
	title.position = Vector2(34, 24)
	title.size = Vector2(492, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var name_label := Label.new()
	name_label.text = "城市 / 地点名称"
	name_label.position = Vector2(34, 76)
	name_label.size = Vector2(492, 22)
	name_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(name_label)

	var title_input := LineEdit.new()
	title_input.placeholder_text = "苏州、巴黎、上海..."
	title_input.position = Vector2(34, 102)
	title_input.size = Vector2(492, 36)
	panel.add_child(title_input)

	var note_label := Label.new()
	note_label.text = "记忆备注"
	note_label.position = Vector2(34, 150)
	note_label.size = Vector2(492, 22)
	note_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(note_label)

	var note_input := TextEdit.new()
	note_input.placeholder_text = "这个地方带来的一段安静记忆..."
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
	selected_photo_label.text = "还没有选择照片"
	selected_photo_label.position = Vector2(198, 320)
	selected_photo_label.size = Vector2(328, 28)
	selected_photo_label.add_theme_font_size_override("font_size", 13)
	selected_photo_label.add_theme_color_override("font_color", Color(0.43, 0.35, 0.27, 0.95))
	panel.add_child(selected_photo_label)

	var hint := Label.new()
	hint.text = "桌面版使用文件选择器；网页版使用浏览器照片选择器。"
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
		place_note = "一段小记忆从这个地方抵达了花园。"

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
			_show_toast("云端尚未准备好，将不带照片保存。")
	elif selected_photo_path != "":
		if CloudManager != null:
			_show_toast("正在上传照片...")
			uploaded_photo_path = await CloudManager.upload_photo_from_path(selected_photo_path, place_title)
			if uploaded_photo_path == "":
				_show_toast("照片上传失败，将不带照片保存。")
			else:
				_show_toast("照片已上传。")
		else:
			_show_toast("云端尚未准备好，将不带照片保存。")

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
		"title": "来自" + place_title + "的明信片",
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
	_show_toast("New postcard from " + place_title + ".")

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
	name_label.text = str(place.get("title", "地点"))
	name_label.position = Vector2(-50, 6)
	name_label.size = Vector2(100, 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.16, 0.25, 0.22, 1.0))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(name_label)

	_add_click_area(marker, Vector2(44, 54), "place:" + str(place.get("id", "")), str(place.get("title", "地点")), Vector2(0, 0))

func _open_postcard_for_place(place_id: String) -> void:
	var place := MemoryManager.find_place(place_id)
	if place.is_empty():
		return
	var postcard := MemoryManager.find_postcard_by_place(place_id)
	var title_text := str(postcard.get("title", "来自" + str(place.get("title", "地点")) + "的明信片"))
	var message := str(postcard.get("message", place.get("note", "一段小记忆。")))
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


func _on_place_photo_selected(path: String) -> void:
	selected_photo_path = path
	selected_photo_bytes = PackedByteArray()
	selected_photo_filename = path.get_file()
	selected_photo_content_type = _content_type_for_filename(selected_photo_filename)
	selected_photo_from_web = false

	if selected_photo_label != null and is_instance_valid(selected_photo_label):
		selected_photo_label.text = "已选择：" + selected_photo_filename

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

	_show_toast("从设备中选择一张照片...")

	if selected_photo_label != null and is_instance_valid(selected_photo_label):
		selected_photo_label.text = "从设备中选择一张照片..."

	var js_result = JavaScriptBridge.eval("""
		window.familyGardenChoosePhoto ? window.familyGardenChoosePhoto() : false;
	""", true)
	if not bool(js_result):
		_show_toast("照片选择器还没准备好，请再试一次。")


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
		selected_photo_label.text = "已选择：" + selected_photo_filename

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
	photo_status.text = "没有附加照片"
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

	_add_panel_button(panel, "删除", Vector2(96, 490), Vector2(120, 40), "delete_place:" + place_id)
	_add_panel_button(panel, "返回地图", Vector2(246, 490), Vector2(150, 40), "close")
	_add_panel_button(panel, "明信片", Vector2(426, 490), Vector2(130, 40), "MemoryManager.postcards")

	var clean_photo_path: String = photo_path.strip_edges()
	if clean_photo_path == "" or clean_photo_path.to_lower() in ["null", "<null>", "nil", "none"]:
		photo_status.text = "没有附加照片。"
	else:
		photo_status.text = "正在加载照片..."
		_load_photo_into_rect(clean_photo_path, photo_rect, photo_status)

func _load_photo_into_rect(photo_path: String, photo_rect: TextureRect, photo_status: Label) -> void:
	var clean_photo_path: String = photo_path.strip_edges()
	if clean_photo_path == "" or clean_photo_path.to_lower() in ["null", "<null>", "nil", "none"]:
		if is_instance_valid(photo_status):
			photo_status.text = "没有附加照片。"
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
			photo_status.text = "无法加载照片。"


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
			line = "咪咪慢慢眨了眨眼，可能会走两步，然后蜷起来睡一会儿。"
		"bird":
			line = "蓝色小鸟在花园边轻轻跳着，望着家庭树。"
		"dog":
			line = "饼干开心地晃了晃，然后趴下来打个小盹。"
	_show_cozy_panel(display_name, line, [{"text": "关闭", "action": "close"}])

func _open_message_board_panel() -> void:
	var body := "家人的留言贴在这里。\n\n"
	if MemoryManager.garden_messages.is_empty():
		body += "还没有留言。给家人留下第一句话吧。"
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
	title.text = "添加留言"
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
	author_input.placeholder_text = "佩琳、爸爸、妈妈..."
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
	message_input.placeholder_text = "给家人留一句小留言..."
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
		text = "有人在花园里留下了一句小留言。"

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
	_show_toast("New note added.")

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
	title.text = "明信片"
	title.position = Vector2(36, 26)
	title.size = Vector2(608, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "打开明信片，查看对应的记忆照片。"
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
		empty_label.text = "还没有明信片。打开旅行地图并添加一个地点，就会生成第一张明信片。"
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
	var message := str(postcard.get("message", "一段小记忆。"))
	var photo_path := str(postcard.get("photo_path", ""))

	if photo_path == "" and not place.is_empty():
		photo_path = str(place.get("photo_path", ""))

	_open_postcard_detail_panel(title_text, message, photo_path, place_id)


func _open_family_tree_view() -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay

	var panel := Panel.new()
	panel.position = Vector2(300, 64)
	panel.size = Vector2(680, 560)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = "家庭树"
	title.position = Vector2(34, 24)
	title.size = Vector2(320, 36)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.20, 0.15, 0.10, 1.0))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = _family_tree_summary_text()
	subtitle.position = Vector2(34, 62)
	subtitle.size = Vector2(600, 42)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.40, 0.32, 0.23, 0.95))
	panel.add_child(subtitle)

	var tree_icon := TextureRect.new()
	tree_icon.texture = _safe_texture(str(ASSETS.get("tree", "")))
	tree_icon.position = Vector2(258, 114)
	tree_icon.size = Vector2(164, 190)
	tree_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tree_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tree_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tree_icon.modulate = Color(1.0, 1.0, 1.0, 0.22)
	tree_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tree_icon)

	var trunk := ColorRect.new()
	trunk.position = Vector2(333, 248)
	trunk.size = Vector2(14, 168)
	trunk.color = Color(0.50, 0.31, 0.16, 0.62)
	trunk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(trunk)

	var root_glow := ColorRect.new()
	root_glow.position = Vector2(283, 402)
	root_glow.size = Vector2(116, 22)
	root_glow.color = Color(0.68, 0.86, 0.43, 0.25)
	root_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(root_glow)

	var card_positions: Dictionary = {
		"papa": Vector2(62, 150),
		"mama": Vector2(442, 150),
		"girl": Vector2(86, 346),
		"boy": Vector2(418, 346)
	}
	var branch_origin := Vector2(340, 274)
	_add_family_tree_branch(panel, branch_origin, Vector2(170, 218))
	_add_family_tree_branch(panel, branch_origin, Vector2(510, 218))
	_add_family_tree_branch(panel, Vector2(340, 356), Vector2(190, 394))
	_add_family_tree_branch(panel, Vector2(340, 356), Vector2(502, 394))

	for role_data in CHARACTER_DATA:
		var role_key: String = str(role_data.get("role", ""))
		if not card_positions.has(role_key):
			continue
		var member_pos := Vector2.ZERO
		var raw_member_pos: Variant = card_positions[role_key]
		if raw_member_pos is Vector2:
			member_pos = raw_member_pos
		_add_family_member_card(panel, role_data, member_pos)

	_add_panel_button(panel, "明信片", Vector2(190, 500), Vector2(130, 38), "MemoryManager.postcards")
	_add_panel_button(panel, "留言板", Vector2(340, 500), Vector2(130, 38), "message_board")

func _family_tree_summary_text() -> String:
	var participant_count: int = MemoryManager.participants().size()
	var memory_count: int = MemoryManager.memories.size()
	var postcard_count: int = MemoryManager.postcards.size()
	var warmth: int = MemoryManager.cross_member_interaction_count
	return "家人参与 %d 位 · 记忆 %d 段 · 明信片 %d 张 · 关系温度 %d" % [participant_count, memory_count, postcard_count, warmth]

func _add_family_tree_branch(parent: Control, from_pos: Vector2, to_pos: Vector2) -> void:
	var delta: Vector2 = to_pos - from_pos
	var branch := ColorRect.new()
	branch.position = from_pos
	branch.size = Vector2(delta.length(), 4)
	branch.pivot_offset = Vector2(0, 2)
	branch.rotation = delta.angle()
	branch.color = Color(0.48, 0.30, 0.16, 0.40)
	branch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(branch)

func _add_family_member_card(parent: Control, role_data: Dictionary, pos: Vector2) -> void:
	var role_key: String = str(role_data.get("role", ""))
	var is_current: bool = role_key == MemoryManager.selected_role_key
	var card := Panel.new()
	card.position = pos
	card.size = Vector2(172, 104)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_small_card_style(card)
	parent.add_child(card)

	var portrait := TextureRect.new()
	portrait.texture = _safe_texture(str(ASSETS.get(str(role_data.get("asset", "girl")), "")))
	portrait.position = Vector2(10, 12)
	portrait.size = Vector2(50, 64)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(portrait)

	var name_label := Label.new()
	name_label.text = _family_member_name(role_data)
	name_label.position = Vector2(68, 12)
	name_label.size = Vector2(90, 24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.add_theme_font_size_override("font_size", _fit_font_size_for_text(name_label.text, 15, 11, 5))
	name_label.add_theme_color_override("font_color", Color(0.22, 0.16, 0.11, 1.0))
	card.add_child(name_label)

	var role_label := Label.new()
	role_label.text = str(role_data.get("label", "家人")) + (" · 当前" if is_current else "")
	role_label.position = Vector2(68, 38)
	role_label.size = Vector2(94, 20)
	role_label.add_theme_font_size_override("font_size", 12)
	role_label.add_theme_color_override("font_color", Color(0.48, 0.38, 0.26, 0.95))
	card.add_child(role_label)

	var stat := Label.new()
	stat.text = "记忆 %d · 回答 %d" % [_memory_count_for_role(role_key), _answer_count_for_role(role_key)]
	stat.position = Vector2(12, 78)
	stat.size = Vector2(148, 20)
	stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat.add_theme_font_size_override("font_size", 12)
	stat.add_theme_color_override("font_color", Color(0.32, 0.42, 0.24, 0.95))
	card.add_child(stat)

func _family_member_name(role_data: Dictionary) -> String:
	var role_key: String = str(role_data.get("role", ""))
	if role_key == MemoryManager.selected_role_key and str(MemoryManager.player_display_name).strip_edges() != "":
		return str(MemoryManager.player_display_name).strip_edges()
	return str(role_data.get("default_name", role_data.get("label", "家人")))

func _memory_count_for_role(role_key: String) -> int:
	var count: int = 0
	for raw_memory in MemoryManager.memories:
		if raw_memory is Dictionary:
			var memory: Dictionary = raw_memory
			if str(memory.get("user_id", "")) == role_key:
				count += 1
	return count

func _answer_count_for_role(role_key: String) -> int:
	var count: int = 0
	for raw_answer in MemoryManager.answers:
		if raw_answer is Dictionary:
			var answer: Dictionary = raw_answer
			if str(answer.get("user_id", "")) == role_key:
				count += 1
	return count

func _open_family_tree_panel() -> void:
	var body := "这棵树会随着家人的记忆一起生长。\n\n家庭成员：\n"
	for role_data in CHARACTER_DATA:
		var role_key := str(role_data.get("role", ""))
		var member_name := MemoryManager.player_display_name if role_key == MemoryManager.selected_role_key else str(role_data.get("default_name", role_data.get("label", "家人")))
		var status := "在线" if role_key == MemoryManager.selected_role_key else "离线"
		body += "• " + member_name + " - " + status + "\n"
	body += "\n树上的明信片：\n"
	if MemoryManager.postcards.is_empty():
		body += "• 还没有明信片。打开旅行地图寄出一张吧。\n"
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

func _open_mailbox_panel() -> void:
	var unread_count: int = MemoryManager.count_unread_postcards()
	var body := ""
	if unread_count > 0:
		body = "有新邮件到了。\n\n"
		for postcard in MemoryManager.postcards:
			if bool(postcard.get("is_new", false)):
				body += "• " + str(postcard.get("title", "新明信片")) + "\n"
	else:
		body = "现在没有新邮件。\n\n在旅行地图添加地点，就能给花园寄来新的明信片。"
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
	var line := "今天花园里很安静。"
	match npc_id:
		"papa":
			line = "今天花园很安静，看到大家都在这里真好。"
		"mama":
			line = "花开得很好，这里像一个小小的家。"
		"boy":
			line = "我找到一个安静的角落，也许我们可以一起留下一张明信片。"
		"girl":
			line = "我把一段小记忆带回了花园。"
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
	close_btn.text = "X"
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

func _open_settings_panel() -> void:
	_close_active_panel()
	settings_panel_labels.clear()
	var overlay := _create_modal_overlay()
	active_modal = overlay

	var panel := Panel.new()
	panel.position = Vector2(390, 92)
	panel.size = Vector2(500, 508)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = "设置"
	title.position = Vector2(34, 26)
	title.size = Vector2(420, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "调整画面、昼夜循环和声音。"
	subtitle.position = Vector2(34, 62)
	subtitle.size = Vector2(420, 24)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.43, 0.35, 0.27, 0.88))
	panel.add_child(subtitle)

	_add_settings_slider(panel, "brightness", "亮度", Vector2(42, 118), 55.0, 145.0, settings_brightness * 100.0, 1.0)
	_add_settings_toggle(panel, "day_night", "昼夜循环", Vector2(42, 180), settings_day_night_enabled)
	_add_settings_slider(panel, "music", "音乐音量", Vector2(42, 242), 0.0, 100.0, settings_music_volume * 100.0, 1.0)
	_add_settings_slider(panel, "sfx", "音效音量", Vector2(42, 304), 0.0, 100.0, settings_sfx_volume * 100.0, 1.0)
	_add_settings_toggle(panel, "mute", "静音", Vector2(42, 366), settings_master_muted)

	_add_panel_button(panel, "重置", Vector2(118, 438), Vector2(112, 38), "settings_reset")
	_add_panel_button(panel, "关闭", Vector2(270, 438), Vector2(112, 38), "close")
	_refresh_settings_labels()

func _add_settings_slider(parent: Control, key: String, _label_text: String, pos: Vector2, min_value: float, max_value: float, value: float, step: float) -> void:
	var label := Label.new()
	label.name = key + "_label"
	label.position = pos
	label.size = Vector2(410, 22)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 1.0))
	parent.add_child(label)
	settings_panel_labels[key] = label

	var slider := HSlider.new()
	slider.name = key + "_slider"
	slider.position = pos + Vector2(0, 28)
	slider.size = Vector2(410, 24)
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.value_changed.connect(_on_settings_slider_changed.bind(key))
	parent.add_child(slider)

func _add_settings_toggle(parent: Control, key: String, label_text: String, pos: Vector2, pressed: bool) -> void:
	var toggle := CheckButton.new()
	toggle.name = key + "_toggle"
	toggle.text = label_text
	toggle.position = pos
	toggle.size = Vector2(410, 38)
	toggle.button_pressed = pressed
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.add_theme_font_size_override("font_size", 15)
	toggle.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 1.0))
	toggle.toggled.connect(_on_settings_toggle_changed.bind(key))
	parent.add_child(toggle)

func _on_settings_slider_changed(value: float, key: String) -> void:
	match key:
		"brightness":
			settings_brightness = value / 100.0
		"music":
			settings_music_volume = value / 100.0
		"sfx":
			settings_sfx_volume = value / 100.0
	_apply_settings()
	_refresh_settings_labels()
	_save_settings()

func _on_settings_toggle_changed(pressed: bool, key: String) -> void:
	match key:
		"day_night":
			settings_day_night_enabled = pressed
		"mute":
			settings_master_muted = pressed
	_apply_settings()
	_save_settings()

func _refresh_settings_labels() -> void:
	if settings_panel_labels.has("brightness") and is_instance_valid(settings_panel_labels["brightness"]):
		(settings_panel_labels["brightness"] as Label).text = "亮度  %d%%" % int(round(settings_brightness * 100.0))
	if settings_panel_labels.has("music") and is_instance_valid(settings_panel_labels["music"]):
		(settings_panel_labels["music"] as Label).text = "音乐音量  %d%%" % int(round(settings_music_volume * 100.0))
	if settings_panel_labels.has("sfx") and is_instance_valid(settings_panel_labels["sfx"]):
		(settings_panel_labels["sfx"] as Label).text = "音效音量  %d%%" % int(round(settings_sfx_volume * 100.0))

func _reset_settings() -> void:
	settings_brightness = 1.0
	settings_day_night_enabled = true
	settings_music_volume = 0.85
	settings_sfx_volume = 0.85
	settings_master_muted = false
	_apply_settings()
	_save_settings()
	_open_settings_panel()
	_show_toast("设置已重置。")

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	settings_brightness = clampf(float(data.get("brightness", settings_brightness)), 0.55, 1.45)
	settings_day_night_enabled = bool(data.get("day_night_enabled", settings_day_night_enabled))
	settings_music_volume = clampf(float(data.get("music_volume", settings_music_volume)), 0.0, 1.0)
	settings_sfx_volume = clampf(float(data.get("sfx_volume", settings_sfx_volume)), 0.0, 1.0)
	settings_master_muted = bool(data.get("master_muted", settings_master_muted))

func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	var data := {
		"brightness": settings_brightness,
		"day_night_enabled": settings_day_night_enabled,
		"music_volume": settings_music_volume,
		"sfx_volume": settings_sfx_volume,
		"master_muted": settings_master_muted
	}
	file.store_string(JSON.stringify(data, "\t"))

func _apply_settings() -> void:
	var clock := get_node_or_null("/root/GameClock")
	if clock != null:
		if clock.has_method("set_brightness"):
			clock.call("set_brightness", settings_brightness)
		if clock.has_method("set_day_night_enabled"):
			clock.call("set_day_night_enabled", settings_day_night_enabled)
	_refresh_night_window_glows()
	_set_audio_bus_volume("Music", settings_music_volume)
	_set_audio_bus_volume("SFX", settings_sfx_volume)
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx != -1:
		AudioServer.set_bus_mute(master_idx, settings_master_muted)

func _set_audio_bus_volume(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var linear := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))

func _add_panel_button(parent: Control, button_text: String, pos: Vector2, button_size: Vector2, action: String, args: Array = []) -> Button:
	var button := Button.new()
	button.text = button_text
	button.position = pos
	button.size = button_size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_button_style(button, false)
	_fit_button_font(button, button_text, 13)
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
		"family_tree", "plant_tree":
			return "icon_tree"
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
		"settings":
			return "icon_settings"
		"fish_again":
			return "icon_add"
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

func _fit_button_font(button: Button, text: String, max_size: int = 13) -> void:
	button.add_theme_font_size_override("font_size", _fit_font_size_for_text(text, max_size, 10, 5))

func _fit_font_size_for_text(text: String, max_size: int, min_size: int, chars_at_max: int) -> int:
	var count: int = text.length()
	if count <= chars_at_max:
		return max_size
	var extra: int = count - chars_at_max
	return maxi(min_size, max_size - int(ceil(float(extra) * 0.85)))

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
	elif action == "settings":
		_open_settings_panel()
	elif action == "settings_reset":
		_reset_settings()
	elif action == "fish_again":
		_start_fishing_sequence()
	elif action == "open_caught_bottle":
		_open_caught_bottle_content()
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
	if active_modal != null and is_instance_valid(active_modal):
		active_modal.queue_free()
	active_modal = null
	if memory_link_visualizer != null and is_instance_valid(memory_link_visualizer):
		memory_link_visualizer.call("set_selected_memory", "")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__familyGardenRemovePhotoInput && window.__familyGardenRemovePhotoInput();", true)

func _add_plant(pos: Vector2, plant_type: String, existing_id: String = "") -> void:
	var item_id := existing_id if existing_id != "" else "plant_" + str(Time.get_ticks_msec())
	var item_data := {"id": item_id, "type": plant_type, "position": pos}
	var texture := _safe_texture("res://assets/garden/" + plant_type + ".png")
	var item := preload("res://scripts/placeable_item.gd").new()
	item.setup(item_data, texture)
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
			return "爸爸温暖的小房间。这里会放书、咖啡和家人的明信片。"
		"mother":
			return "妈妈的小屋里会收着花、留言和安静的家庭记忆。"
		"player":
			return "佩琳的小屋收藏旅行笔记、照片和路上的小发现。"
		"partner":
			return "路易的小屋等待着共享明信片和温柔的花园来访。"
	return "一间小小的家庭小屋。"

func _show_toast(toast_text: String) -> void:
	info_label.text = "家庭花园 - " + toast_text

func _safe_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _solid_texture(width: int, height: int, color: Color) -> Texture2D:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
