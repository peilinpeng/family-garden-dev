extends Node

## Family Garden 场景/UI 控制层（autoload 单例）。
## 持有 world/ui_layer 引用 + 全部场景构建、面板、植物、照片选择、场景切换。
## 由 main.gd 在 _ready 里 setup(world, ui_layer) 注入根节点；输入仍在 main.gd 处理。
## 从 main.gd 拆出，逻辑保持不变（增量 3 / feature/c-foundation）。

const GAME_SIZE := Vector2(1280, 720)
const ANNA_ROOM_SCENE := "res://scenes/rooms/AnnaRoom.tscn"  # 房间 .tscn 迁移样板（仅玩家房间）
const POND_AREA_SCENE := "res://scenes/pond/pond_area.tscn"
const FARM_SCENE := "res://scenes/Farm.tscn"
const KITCHEN_SCENE := "res://scenes/KitchenNew.tscn"
const GARDEN_TILED_SCENE := "res://scenes/GardenTiled.tscn"  # Phase B: 花园背景+TileMap 拼装(替代旧的整图背景)
const DAY_NIGHT_CLOCK_UI_SCRIPT := preload("res://scripts/ui/day_night_clock_ui.gd")


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
	"dialog_toast_panel": "res://assets/ui/dialog_toast_panel.png",
	"inventory_bg": "res://assets/ui/Inventory_Light_example_with_slots_2.png",
	"cursor_arrow": "res://assets/ui/cursors/cursor_arrow.png",
	"cursor_pointer": "res://assets/ui/cursors/cursor_pointer.png",
	# 下面这批已经导入项目、但还没有具体使用场景对接,先注册好 key 方便以后接:
	"speech_bubble": "res://assets/ui/speech_bubble_grey.png",
	"dialog_box_medium": "res://assets/ui/Dialouge UI/Premade dialog box medium.png",
	"dialog_box_big": "res://assets/ui/Dialouge UI/Premade dialog box  big.png",
	"emote_sheet": "res://assets/ui/Dialouge UI/Emotes/Teemo Basic emote animations sprite sheet.png",
	"play_button": "res://assets/ui/UI Big Play Button.png",
	"settings_buttons": "res://assets/ui/UI Settings Buttons.png",
	"square_buttons_small": "res://assets/ui/buttons/Small Square Buttons.png",
	"square_buttons_19x26": "res://assets/ui/buttons/Square Buttons 19x26.png",
	"square_buttons_26x19": "res://assets/ui/buttons/Square Buttons 26x19.png",
	"square_buttons_26x26": "res://assets/ui/buttons/Square Buttons 26x26.png",
	"icons_all": "res://assets/ui/icons/All Icons.png",
	"icons_weather": "res://assets/ui/icons/Weather_Icons_smal_freel.png",
	"icons_white": "res://assets/ui/icons/white icons.png",
	"icons_special": "res://assets/ui/icons/special icons/Special Icons.png",
	"icons_happy_sad": "res://assets/ui/icons/special icons/Small Happines-Sadness icons.png",
	"basic_pack_sheet": "res://assets/ui/Sprite sheet for Basic Pack.png",
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
	{"id": "father", "label": "Papa's Cottage", "asset": "house_father", "pos": Vector2(155, 124), "height": 180.0},
	{"id": "mother", "label": "Mama's Cottage", "asset": "house_mother", "pos": Vector2(1153, 145), "height": 230.0},
	{"id": "player", "label": "Peilin's Cottage", "asset": "house_player", "pos": Vector2(125, 600), "height": 180.0},
	{"id": "partner", "label": "Louis's Cottage", "asset": "house_partner", "pos": Vector2(126, 438), "height": 180.0},
]

const ROOM_DATA := {
	"father": {
		"label": "Papa's Room",
		"asset": "room_papa",
		"foreground": "room_papa_fg",
		"spawn": Vector2(640, 575),
	},
	"mother": {
		"label": "Mama's Room",
		"asset": "room_mama",
		"foreground": "room_mama_fg",
		"spawn": Vector2(640, 565),
	},
	"partner": {
		"label": "Louis's Room",
		"asset": "room_louis",
		"foreground": "room_louis_fg",
		"spawn": Vector2(640, 560),
	},
	"player": {
		"label": "Anna's Room",
		"asset": "room_anna",
		"foreground": "room_anna_fg",
		"spawn": Vector2(640, 560),
	},
}

const CHARACTER_DATA := [
	{"role": "girl", "label": "Girl", "default_name": "Peilin", "asset": "girl", "house_id": "player", "house_label": "Peilin's Cottage", "npc_pos": Vector2(700, 405), "wander_radius": 90.0},
	{"role": "boy", "label": "Boy", "default_name": "Louis", "asset": "boy", "house_id": "partner", "house_label": "Louis's Cottage", "npc_pos": Vector2(805, 535), "wander_radius": 85.0},
	{"role": "papa", "label": "Papa", "default_name": "Papa", "asset": "papa", "house_id": "father", "house_label": "Papa's Cottage", "npc_pos": Vector2(765, 335), "wander_radius": 80.0},
	{"role": "mama", "label": "Mama", "default_name": "Mama", "asset": "mama", "house_id": "mother", "house_label": "Mama's Cottage", "npc_pos": Vector2(525, 365), "wander_radius": 80.0},
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
	_setup_custom_cursor()
	_build_ui()

## 自定义猫爪鼠标指针(默认箭头 + 悬浮可点击时的指示手型),整局只需设一次。
func _setup_custom_cursor() -> void:
	var arrow := _safe_texture(str(ASSETS.get("cursor_arrow", "")))
	if arrow:
		Input.set_custom_mouse_cursor(arrow, Input.CURSOR_ARROW, Vector2(6, 4))
	var pointer := _safe_texture(str(ASSETS.get("cursor_pointer", "")))
	if pointer:
		Input.set_custom_mouse_cursor(pointer, Input.CURSOR_POINTING_HAND, Vector2(6, 4))

func _build_ui() -> void:
	var root := Control.new()
	root.name = "UIRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	var day_night_clock := TextureRect.new()
	day_night_clock.name = "DayNightClock"
	day_night_clock.set_script(DAY_NIGHT_CLOCK_UI_SCRIPT)
	day_night_clock.position = Vector2(GAME_SIZE.x - 136, 16)
	day_night_clock.size = Vector2(112, 124)
	day_night_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(day_night_clock)

	info_label = Label.new()
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.text = "Family Garden"
	info_label.position = Vector2(18, 14)
	info_label.size = Vector2(760, 32)
	info_label.add_theme_font_size_override("font_size", 20)
	info_label.add_theme_color_override("font_color", Color(0.20, 0.17, 0.13, 1.0))
	root.add_child(info_label)

	var help := Label.new()
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.text = "WASD / Arrow keys: move   |   Click objects: interact"
	help.position = Vector2(18, 45)
	help.size = Vector2(920, 24)
	help.add_theme_font_size_override("font_size", 13)
	help.modulate = Color(0.25, 0.22, 0.18, 0.85)
	root.add_child(help)

	# Bottom navigation. Kept compact and centered under the garden.
	_add_button(root, "World", Vector2(248, 672), Vector2(86, 32), "global_map")
	_add_button(root, "Tree", Vector2(338, 672), Vector2(82, 32), "family_tree")
	_add_button(root, "Map", Vector2(430, 672), Vector2(76, 32), "travel_map")
	_add_button(root, "Postcards", Vector2(516, 672), Vector2(120, 32), "MemoryManager.postcards")
	_add_world_chat_feed(root, Vector2(650, 604), Vector2(382, 60))
	world_chat_input = _add_world_chat_box(root, Vector2(650, 672), Vector2(300, 32))
	_add_button(root, "Chat", Vector2(958, 672), Vector2(74, 32), "world_chat_history")
	_refresh_world_chat_feed()

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
	chat.placeholder_text = "Send a family message..."
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
		world_chat_input.placeholder_text = "Sending..."

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
		world_chat_input.placeholder_text = "Send a family message..."
		world_chat_input.grab_focus()
	_show_toast("Message sent.")

func _get_world_chat_author() -> String:
	if GameIdentity != null and GameIdentity.is_ready() and str(GameIdentity.display_name).strip_edges() != "":
		return str(GameIdentity.display_name).strip_edges()
	if str(MemoryManager.player_display_name).strip_edges() != "":
		return str(MemoryManager.player_display_name).strip_edges()
	var role := str(MemoryManager.selected_role_key).strip_edges()
	if role != "":
		for character in CHARACTER_DATA:
			if str(character.get("role", "")) == role:
				return str(character.get("default_name", "Family"))
	return "Family"

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
		var author := str(message.get("author", "Family"))
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
	title.text = "World Chat"
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
		empty_label.text = "No messages yet."
		empty_label.custom_minimum_size = Vector2(460, 48)
		empty_label.add_theme_font_size_override("font_size", 15)
		empty_label.add_theme_color_override("font_color", Color(0.34, 0.28, 0.22, 0.88))
		list.add_child(empty_label)
	else:
		for i in range(MemoryManager.garden_messages.size() - 1, -1, -1):
			var raw_message: Variant = MemoryManager.garden_messages[i]
			if raw_message is Dictionary:
				list.add_child(_make_world_chat_history_card(raw_message))

	_add_panel_button(panel, "Close", Vector2(218, 456), Vector2(124, 38), "close")

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
	meta.text = str(message.get("author", "Family")) + "  |  " + _format_world_chat_time(str(message.get("created_at", "")))
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
		return "No time"
	return raw_time.replace("T", " ").replace("Z", "")

func _on_ui_button(action: String) -> void:
	match action:
		"family_tree":
			_open_family_tree_panel()
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
		"save":
			MemoryManager.save_game()
			_show_toast("Saved.")
		"back_garden":
			_show_garden()
		"reset":
			_show_toast("Reset is disabled in the online version.")

func _show_role_select() -> void:
	_close_active_panel()
	_clear_map_ui()
	_clear_world()
	mode = "role_select"
	info_label.text = "Choose your character"
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
	title.text = "Who are you in the garden?"
	title.position = Vector2(40, 28)
	title.size = Vector2(900, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose one family member as yourself. The others will stay in the garden as visitors."
	subtitle.position = Vector2(70, 72)
	subtitle.size = Vector2(840, 28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.35, 0.29, 0.22, 0.88))
	panel.add_child(subtitle)

	var name_label := Label.new()
	name_label.text = "Display name"
	name_label.position = Vector2(360, 112)
	name_label.size = Vector2(260, 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(name_label)

	var name_input := LineEdit.new()
	name_input.placeholder_text = "Your name"
	name_input.text = MemoryManager.player_display_name if MemoryManager.player_display_name != "" else "Peilin"
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
	label.text = str(role_data.get("label", "Family"))
	label.custom_minimum_size = Vector2(card_size.x - 34, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.25, 0.20, 0.15, 1.0))
	vbox.add_child(label)

	var default_name := Label.new()
	default_name.text = str(role_data.get("default_name", "Family"))
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
	choose_btn.text = "Choose"
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
	# 首次选角色时,若配置了 CloudBase 且本设备还没自助加入过,后台自动注册云身份
	# (不阻塞进花园;角色别名如 girl/papa 转成 CharacterDB 的规范值 player/father 再传)。
	var canonical_role: String = CharacterDB.resolve(role_key)
	CloudManager.ensure_cloud_identity(canonical_role, MemoryManager.player_display_name)


func _default_name_for_role(role_key: String) -> String:
	var role_data := _get_role_data(role_key)
	if role_data.is_empty():
		return "Family"
	return str(role_data.get("default_name", "Family"))


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
		plant_button.text = "Plant: ON" if plant_mode else "Plant: OFF"
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
	info_label.text = "Family Garden"
	AudioManager.play_music("garden")
	_add_background()
	# Phase B(花园 TileMap 改造):碰撞区/房子/核心物件热区/NPC 都是按旧整图背景手工调的坐标,
	# 跟新的 GardenTiled 布局对不上,先关掉;等新布局定稿后再照新坐标重建这几块。
	# _add_collision_zones()
	_add_garden_spawn_markers()
	# _add_houses()
	# _add_core_objects()
	# _add_npcs()
	_add_animals()
	var spawn: Vector2 = ScenePortal.get_spawn("garden", spawn_key)
	_add_player(spawn)
	_rebuild_plants()
	_spawn_demo_memory_nodes()
	MemoryManager.maybe_recompute_family_portrait()  # 进花园按当前成员/记忆数算一版画像
	_render_family_portrait()                         # 挂到入口木牌
	ScenePortal.build_portals("garden", world, _on_portal_travel)

# 记忆卡片 / 房间识别 / 漂流瓶问题 / 关联连线的 mock 已统一收到 AIClient（docs/04 接口）。
# 阶段2 真调用到位后只换 AIClient 实现层，本文件调用点不变。

# 阶段1 mock 演示用的记忆列表。真实流程将由 MemoryManager + AI 客户端填充并持久化。
# 每项：{ id, card, state(new/grown), answer, node }。当前不落库，离开花园后重置。
var _demo_memories: Array = []

# 鱼塘漂流瓶 demo 列表（mock-first，离场重置）。每项：{ id, question, state, answer, node }。
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
	# 首次进入：把 3 张演示卡片落库（create_memory + create_node）；之后统一从数据层读，实现持久化。
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
	_spawn_demo_memory_link()       # ≥2 条记忆时生成 mock 关联（阶段2 换 cross-memory-link 真调用）
	_render_memory_links("garden")  # 画连线
	print("[Stage1] garden 记忆花 rendered=", _demo_memories.size(), " 连线=", MemoryManager.get_memory_links("garden").size())

# 阶段1 mock：花园里 ≥2 条记忆且尚无连线时，给前两条造一条关联连线。
# 阶段2 换 cross-memory-link 接口：每上传新记忆增量算关联，relation_type/question 由 AI 给。
func _spawn_demo_memory_link() -> void:
	if not MemoryManager.get_memory_links("garden").is_empty():
		return
	if _demo_memories.size() < 2:
		return
	var a := String(_demo_memories[0].get("memory_id", ""))
	var b := String(_demo_memories[-1].get("memory_id", ""))  # 连最分散的一对，连线更清晰
	if a == "" or b == "" or a == b:
		return
	var link: Dictionary = AIClient.mock_link()  # 阶段2 换 await AIClient.cross_memory_link(a, candidates)
	MemoryManager.create_memory_link(a, b, "garden",
		String(link.get("relation_type", "same_place")), String(link.get("question", "")))

# 画花园里所有记忆连线：两端取各自记忆花的落点，连一条藤蔓线 + 可点的关联问题。
func _render_memory_links(scene: String) -> void:
	for link in MemoryManager.get_memory_links(scene):
		var a := _memory_flower_pos(scene, String(link.get("memory_id", "")))
		var b := _memory_flower_pos(scene, String(link.get("linked_memory_id", "")))
		if a == Vector2.INF or b == Vector2.INF:
			continue
		_draw_link_line(a, b, String(link.get("question", "")))

# 渲染家庭画像木牌（入口处）：占位画板 + 版本/成员/记忆数；版本变化时重画。
# 挂载点(645,200)为临时位置，待搭档定稿花园木牌位后校准。
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
	board.position = Vector2(645, 200)
	board.z_index = 4000  # 盖在家庭树之上，保证可见（临时）
	var sprite := Sprite2D.new()
	sprite.texture = _solid_texture(132, 92, Color(0.60, 0.44, 0.29, 1.0))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	board.add_child(sprite)
	var lbl := Label.new()
	lbl.text = "🖼️ 家庭画像 v%d\n%d 位家人 · %d 条记忆" % [int(fp.get("version", 0)), int(fp.get("member_count", 0)), int(fp.get("memory_count", 0))]
	lbl.position = Vector2(-58, -26)
	lbl.size = Vector2(116, 52)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	board.add_child(lbl)
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(132, 92)
	shape.shape = rect
	area.add_child(shape)
	area.input_event.connect(func(_v: Node, e: InputEvent, _s: int) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_show_toast("🖼️ 家庭画像 v%d · %d 位家人 · %d 条记忆" % [int(fp.get("version", 0)), int(fp.get("member_count", 0)), int(fp.get("memory_count", 0))]))
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

# 一条连线：两花之间拱起的藤蔓线（盖在记忆花之上，避免被花遮住）+ 中点可点的 🔗 关联问题。
func _draw_link_line(a: Vector2, b: Vector2, question: String) -> void:
	var head := Vector2(0, -100)  # 连到花头上方，越过花顶
	var arc := ((a + b) * 0.5 + head) + Vector2(0, -40)  # 中点再抬高 → 轻微拱形
	var line := Line2D.new()
	line.name = "MemoryLink"
	line.points = PackedVector2Array([a + head, arc, b + head])
	line.width = 4.0
	line.default_color = Color(0.46, 0.66, 0.36, 0.9)
	line.z_index = 5000  # 盖在记忆花(z=pos.y)之上，保证可见
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	world.add_child(line)
	# 中点：🔗 图标 + 可点区域，点击弹关联问题。
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
	tag.text = "🔗"
	tag.position = Vector2(-12, -16)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_font_size_override("font_size", 22)
	area.add_child(tag)
	area.input_event.connect(func(_v: Node, e: InputEvent, _s: int) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_show_toast("🔗 " + question))
	world.add_child(area)

# 从数据层渲染某场景已落库的节点：回填 slot 占用、按状态决定形态、装入交互缓存。
# cache 项：{ id(node_id), memory_id, card, state, answer, node }；click_cb 绑 node_id。
func _render_scene_nodes(scene: String, cache: Array, click_cb: Callable) -> void:
	for nd in MemoryManager.get_nodes_for_scene(scene):
		if String(nd.get("node_type", "")) == "memory_link":
			continue  # 连线节点不是落点物，由 _render_memory_links 单独画
		var node_id := String(nd.get("id", ""))
		var memory_id := String(nd.get("memory_id", ""))
		var slot_id := String(nd.get("slot_id", ""))
		var mem := MemoryManager.get_memory(memory_id)
		var card: Dictionary = mem.get("ai_card", {})
		SlotManager.occupy(scene, slot_id, node_id)  # 重入时回填占用，避免新分配撞位
		var slot := SlotManager.get_slot(scene, slot_id)
		if slot.is_empty():
			continue
		var live := NodeFactory.make_memory_node(card, slot, click_cb.bind(node_id))
		var state := String(nd.get("state", "new"))
		if String(nd.get("node_type", "")) == "memory_flower":
			_add_memory_tag(live)
		live.scale = Vector2.ONE if state == "grown" else Vector2(0.55, 0.55)  # grown=已开花 / new=花苞
		world.add_child(live)
		cache.append({
			"id": node_id, "memory_id": memory_id, "card": card,
			"state": state, "answer": MemoryManager.get_answer_for_memory(memory_id), "node": live
		})

# 占位美术与背景花相近，加一个轻量"记忆"标签便于辨认（真 3 态美术到位后移除）。
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

	# AI 推测：浅灰 + ✎ + 问号，明确区别于家人确认的事实（可见的诚实）。
	var guess := Label.new()
	guess.text = "✎ AI 推测：" + String(card.get("guess", "")) + "  ？（待家人确认）"
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
		_show_toast("记忆长大了 🌱 → 🌸 · 花园更繁茂了（%s）" % _season_cn(MemoryManager.garden_season()))
	else:
		_show_toast("记忆长大了 🌱 → 🌸")
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
		n.get_node("DemoTag").queue_free()
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
	# TextureButton 不走 _apply_button_style，点击音效单独补在这里。
	AudioManager.play_sfx("按钮")
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
		"kitchen":
			# KitchenNew.tscn 自带玩家（kitchen_new.gd 的 _spawn_player），不要再补一个。
			AudioManager.play_music("kitchen")
			_build_embedded_scene("kitchen", KITCHEN_SCENE, "厨房", Color(0.58, 0.66, 0.50, 1.0), false)
			ScenePortal.build_portals("kitchen", world, _on_portal_travel)
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
	_render_scene_nodes("fishpond", _fishpond_memories, func(_nid: String) -> void: _show_toast("一段鱼塘记忆 🌊"))
	ScenePortal.build_portals("fishpond", world, _on_portal_travel)
	print("[Stage1] fishpond bottles=", _demo_bottles.size(), " 岸边记忆=", _fishpond_memories.size(), " slot 用量=", SlotManager.usage("fishpond"))

const SCENE_BOTTLE_QUESTION := "如果这个漂流瓶能带来爸爸的一句话，你希望里面写着什么？"

# 阶段1 mock：在水面 slot 上生成可点击漂流瓶。点击 → 问题面板 → 回答 → 岸边生记忆节点。
# 问题来自 AIClient（mock，阶段2 换 generate-bottle-question 真调用）。
func _spawn_demo_bottles() -> void:
	_demo_bottles.clear()
	SlotManager.reset("fishpond")
	SlotManager.load_scene("fishpond")
	var questions: Array = AIClient.mock_bottle_questions()
	var spawned := 0
	for i in range(questions.size()):
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

	var title := Label.new()
	title.text = "🍶 漂来一个问题"
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
		input.placeholder_text = "写下你的回答…"
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
		ans_title.text = "你的回答（已生成记忆）"
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
		_show_toast("写点什么再回答吧～")
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
		var mem_node := NodeFactory.make_memory_node(card, slot, func() -> void: _show_toast("一段鱼塘记忆 🌊"))
		mem_node.scale = Vector2(0.25, 0.25)
		world.add_child(mem_node)
		_grow_memory_node(mem_node)
		# 同步进岸边记忆缓存，离场重入由 _render_scene_nodes 重建。
		_fishpond_memories.append({"id": String(mem.get("id", "")), "memory_id": String(mem.get("id", "")),
			"card": card, "state": "grown", "answer": text, "node": mem_node})
	_show_toast("漂流瓶被回答了 🍶 → 🌊")

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
	# Phase B(花园 TileMap 改造):有 GardenTiled.tscn 就用它(小屋固定底图 + 可画的地面/装饰
	# TileMapLayer),没有就退回旧的整图背景,避免半途改造中场景直接崩掉。
	if ResourceLoader.exists(GARDEN_TILED_SCENE):
		var tiled := (load(GARDEN_TILED_SCENE) as PackedScene).instantiate()
		tiled.name = "GardenTiled"
		world.add_child(tiled)
		_add_season_overlay()
		return

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
		"Family Tree",
		Vector2(190, 170),
		Vector2(0, 95)
	)
	# The mailbox is painted in the garden background. This invisible hotspot makes it interactive.
	_add_mailbox_hotspot(Vector2(402, 104), Vector2(120, 120))
	# The wooden board in the lower-right background acts as an invisible message-board button.
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
		var npc_asset_key := str(role_data.get("asset", "girl"))
		var npc_def: Dictionary = CharacterDB.get_def(npc_asset_key)
		var npc_frame_rects: Array = npc_def.get("frame_rects", [])
		var npc_scale := float(npc_def.get("scale", -1.0))
		var npc_body := _create_character(npc_name, ASSETS[npc_asset_key], npc_pos, false, 3, 4, npc_frame_rects, npc_scale)
		npc_body.name = "NPC_" + role_key
		npc_body.set_script(preload("res://scripts/npc_wander.gd"))
		npc_body.set("home_position", npc_pos)
		npc_body.set("wander_radius", float(role_data.get("wander_radius", 80.0)))
		npc_body.set("move_speed", 34.0)
		npc_body.set("walk_bounds", Rect2(Vector2(35, 100), Vector2(1210, 560)))
		npc_body.call_deferred("set_blocked_rects", _get_character_blocked_rects())
		npc_body.call_deferred("set_frame_rects", npc_frame_rects)
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
	# player.gd 的 apply_character() 是唯一处理 frame_rects(非等分网格精确裁切)的地方,
	# 这里补调一次,否则 girl 这种手工排版的图集会被上面_create_character 的均分网格逻辑切错。
	if player.has_method("apply_character"):
		player.apply_character(asset_key)
	player.name = "Player_" + MemoryManager.selected_role_key
	player.add_to_group("player")  # ScenePortal body_entered 仅认 player 组
	var parent := world if parent_override == null else parent_override
	parent.add_child(player)
	_add_online_status_badge(player, true)
	var parent_canvas := parent as CanvasItem
	if parent_canvas != null and parent_canvas.y_sort_enabled:
		var sort_origin_offset := 18.0
		player.position.y += sort_origin_offset
		for child in player.get_children():
			if child is Node2D:
				(child as Node2D).position.y -= sort_origin_offset
		player.z_index = 0


func _create_character(label_text: String, path: String, pos: Vector2, controllable: bool, hframes: int = 3, vframes: int = 4, frame_rects: Array = [], scale_override: float = -1.0) -> CharacterBody2D:
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
		if frame_rects.size() > 0:
			# 非等分网格贴图(如 girl_2):按精确裁切矩形取帧,交给挂上去的行为脚本(npc_wander.gd
			# 等)逐帧切 region_rect,这里只摆一个初始的"朝下待机"帧(第 0 列,与 player.gd 的
			# IDLE_FRAME_INDEX 约定一致)。
			sprite.region_enabled = true
			sprite.hframes = 1
			sprite.vframes = 1
			var r0 = frame_rects[0]
			if r0 is Array and r0.size() >= 4:
				sprite.region_rect = Rect2(float(r0[0]), float(r0[1]), float(r0[2]), float(r0[3]))
			sprite.scale = Vector2.ONE * (scale_override if scale_override > 0.0 else 0.46)
		else:
			sprite.hframes = hframes
			sprite.vframes = vframes
			sprite.frame = 0
			var frame_height := float(texture.get_height()) / float(vframes)
			if frame_height > 0.0:
				sprite.scale = Vector2.ONE * (scale_override if scale_override > 0.0 else (82.0 / frame_height))
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

	mode = "room"
	adding_place = false
	_clear_world()
	plant_mode = false
	_update_plant_button()

	var room_info: Dictionary = _get_room_data(id)
	var room_label: String = str(room_info.get("label", label_text))
	info_label.text = room_label

	# 样板（增量迁移 §7）：玩家房间用编辑器场景 AnnaRoom.tscn（静态背景+碰撞），
	# 玩家/提示面板/返回流程仍复用代码。其他 3 间保持原过程化构建。
	if id == "player" and ResourceLoader.exists(ANNA_ROOM_SCENE):
		world.add_child((load(ANNA_ROOM_SCENE) as PackedScene).instantiate())
		_add_player(room_info.get("spawn", Vector2(640, 560)))
		_render_room("player")  # 渲染已落库的房间家具（关游戏重开仍在）
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
	sprite.z_index = 10000
	var scale_factor: float = minf(room_rect.size.x / float(texture.get_width()), room_rect.size.y / float(texture.get_height()))
	sprite.scale = Vector2.ONE * scale_factor
	world.add_child(sprite)


func _add_room_hint_panel(room_label: String, house_id: String) -> void:
	var is_player := house_id == "player"
	var panel := Panel.new()
	room_card = panel
	panel.position = Vector2(22, 86)
	panel.size = Vector2(292, 196 if is_player else 156)  # 玩家房间多一行"上传房间照片"
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
	body.text = "Walk around the room.
Use Back Garden to return."
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

# 上传房间照片 → AI 识别(AIClient，mock/真后端+回退) → 落库 + 布局 → 渲染。已生成则不重复。
func _on_generate_room(house_id: String) -> void:
	if house_id != "player":
		return
	if not MemoryManager.get_room_for_user(MemoryManager.selected_role_key).is_empty():
		_show_toast("房间已经布置过了 🏠")
		return
	var src := MemoryManager.create_memory({}, "room_photo")  # 房间照片来源记忆
	var image_url := String(src.get("image_url", ""))
	# Gate 4 接入真实选图/上传前，这个按钮仍明确保持 mock，不发送空 image_url 浪费请求。
	var analysis: Dictionary = AIClient.mock_room_analysis() if image_url == "" \
		else await AIClient.analyze_room_photo(image_url, String(src.get("id", "")))
	RoomLayoutManager.generate(analysis, String(src.get("id", "")))
	_render_room("player")
	_show_toast("房间生成好了 🛋️")

# 渲染玩家房间已落库的家具（重入/重启后重建）。
func _render_room(house_id: String) -> void:
	_room_objects.clear()
	if house_id != "player":
		return
	var room := MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
	if room.is_empty():
		return
	var n := RoomLayoutManager.render(String(room.get("id", "")), world, _on_room_object_clicked)
	print("[Stage1] room 家具 rendered=", n, " zone 用量=", ZoneManager.usage("room"))

func _on_room_object_clicked(obj_id: String) -> void:
	for o in MemoryManager.room_objects:
		if o is Dictionary and String(o.get("id", "")) == obj_id:
			_show_toast("这是 " + String(o.get("object_type", "物件")) + " 🪑")
			return
	_show_toast("房间里的物件 🪑")


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
	info_label.text = "Travel Map"
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
	title.text = "Add a Place"
	title.position = Vector2(34, 24)
	title.size = Vector2(492, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var name_label := Label.new()
	name_label.text = "City / place name"
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
	note_label.text = "Memory note"
	note_label.position = Vector2(34, 150)
	note_label.size = Vector2(492, 22)
	note_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(note_label)

	var note_input := TextEdit.new()
	note_input.placeholder_text = "A quiet memory from this place..."
	note_input.position = Vector2(34, 176)
	note_input.size = Vector2(492, 92)
	panel.add_child(note_input)

	var photo_label_title := Label.new()
	photo_label_title.text = "Photo"
	photo_label_title.position = Vector2(34, 286)
	photo_label_title.size = Vector2(492, 22)
	photo_label_title.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(photo_label_title)

	var choose_photo_button := Button.new()
	choose_photo_button.text = "Choose Photo"
	choose_photo_button.position = Vector2(34, 314)
	choose_photo_button.size = Vector2(150, 38)
	choose_photo_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_style(choose_photo_button, false)
	_set_button_icon(choose_photo_button, "icon_camera")
	choose_photo_button.pressed.connect(_choose_photo_for_place)
	panel.add_child(choose_photo_button)

	selected_photo_label = Label.new()
	selected_photo_label.text = "No photo selected"
	selected_photo_label.position = Vector2(198, 320)
	selected_photo_label.size = Vector2(328, 28)
	selected_photo_label.add_theme_font_size_override("font_size", 13)
	selected_photo_label.add_theme_color_override("font_color", Color(0.43, 0.35, 0.27, 0.95))
	panel.add_child(selected_photo_label)

	var hint := Label.new()
	hint.text = "Desktop uses FileDialog. Web uses browser photo picker."
	hint.position = Vector2(34, 360)
	hint.size = Vector2(492, 24)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.45, 0.38, 0.30, 0.75))
	panel.add_child(hint)

	_add_panel_button(panel, "Save Place", Vector2(126, 404), Vector2(140, 40), "save_new_place", [title_input, note_input])
	_add_panel_button(panel, "Cancel", Vector2(300, 404), Vector2(120, 40), "close")

func _save_new_place(title_input: LineEdit, note_input: TextEdit) -> void:
	var place_title: String = title_input.text.strip_edges()
	if place_title == "":
		place_title = "Untitled Place"
	var place_note: String = note_input.text.strip_edges()
	if place_note == "":
		place_note = "A small memory arrived from this place."

	var place_id: String = "place_" + str(Time.get_ticks_msec())
	var postcard_id: String = "postcard_" + str(Time.get_ticks_msec())
	var uploaded_photo_path: String = ""
	print("[FamilyGarden] Save place photo state: from_web=", selected_photo_from_web, " bytes=", selected_photo_bytes.size(), " path=", selected_photo_path, " name=", selected_photo_filename, " type=", selected_photo_content_type)

	if selected_photo_from_web and selected_photo_bytes.size() > 0:
		if CloudManager != null:
			_show_toast("Uploading photo...")
			uploaded_photo_path = await CloudManager.upload_photo_bytes_with_name(
				selected_photo_bytes,
				selected_photo_filename,
				place_title,
				selected_photo_content_type
			)
			if uploaded_photo_path == "":
				_show_toast("Photo upload failed. Saving without photo.")
			else:
				_show_toast("Photo uploaded.")
		else:
			_show_toast("Cloud is not ready. Saving without photo.")
	elif selected_photo_path != "":
		if CloudManager != null:
			_show_toast("Uploading photo...")
			uploaded_photo_path = await CloudManager.upload_photo_from_path(selected_photo_path, place_title)
			if uploaded_photo_path == "":
				_show_toast("Photo upload failed. Saving without photo.")
			else:
				_show_toast("Photo uploaded.")
		else:
			_show_toast("Cloud is not ready. Saving without photo.")

	if CloudManager != null:
		_show_toast("Saving to family cloud...")
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
		"title": "Postcard from " + place_title,
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
	var title_text := str(postcard.get("title", "Postcard from " + str(place.get("title", "Place"))))
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
	photo_file_dialog.title = "Choose a photo"
	photo_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	photo_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	photo_file_dialog.filters = PackedStringArray([
		"*.png, *.jpg, *.jpeg, *.webp ; Image Files"
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
		selected_photo_label.text = "Selected: " + selected_photo_filename

	_show_toast("Photo selected: " + selected_photo_filename)


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

	_show_toast("Choose a photo from your device...")

	if selected_photo_label != null and is_instance_valid(selected_photo_label):
		selected_photo_label.text = "Choose a photo from your device..."

	var js_result = JavaScriptBridge.eval("""
		window.familyGardenChoosePhoto ? window.familyGardenChoosePhoto() : false;
	""", true)
	if not bool(js_result):
		_show_toast("Photo picker is not ready. Please try again.")


func _on_web_photo_selected(args: Array) -> void:
	if args.size() < 3:
		_show_toast("Photo selection failed.")
		return

	var base64_text: String = str(args[0])
	var file_name: String = str(args[1])
	var content_type: String = str(args[2])

	var bytes: PackedByteArray = Marshalls.base64_to_raw(base64_text)
	if bytes.is_empty():
		_show_toast("Could not read selected photo.")
		return

	selected_photo_bytes = bytes
	selected_photo_filename = file_name
	selected_photo_content_type = content_type
	selected_photo_path = ""
	selected_photo_from_web = true
	print("[FamilyGarden] Web photo received by Godot: ", selected_photo_filename, " bytes=", selected_photo_bytes.size(), " type=", selected_photo_content_type)

	if selected_photo_label != null and is_instance_valid(selected_photo_label):
		selected_photo_label.text = "Selected: " + selected_photo_filename

	_show_toast("Photo selected: " + selected_photo_filename)

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
	photo_status.text = "No photo attached"
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
	_add_panel_button(panel, "Delete", Vector2(96, 490), Vector2(120, 40), "delete_place:" + place_id)
	_add_panel_button(panel, "Back to Map", Vector2(246, 490), Vector2(150, 40), "close")
	_add_panel_button(panel, "Postcards", Vector2(426, 490), Vector2(130, 40), "MemoryManager.postcards")

	var clean_photo_path: String = photo_path.strip_edges()
	if clean_photo_path == "" or clean_photo_path.to_lower() in ["null", "<null>", "nil", "none"]:
		photo_status.text = "No photo attached."
	else:
		photo_status.text = "Loading photo..."
		_load_photo_into_rect(clean_photo_path, photo_rect, photo_status)

func _load_photo_into_rect(photo_path: String, photo_rect: TextureRect, photo_status: Label) -> void:
	var clean_photo_path: String = photo_path.strip_edges()
	if clean_photo_path == "" or clean_photo_path.to_lower() in ["null", "<null>", "nil", "none"]:
		if is_instance_valid(photo_status):
			photo_status.text = "No photo attached."
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
		photo_status.text = "Loading photo..."

	var texture: Texture2D = await _download_photo_texture(photo_url)
	if texture != null:
		photo_texture_cache[photo_url] = texture
		if is_instance_valid(photo_rect):
			photo_rect.texture = texture
		if is_instance_valid(photo_status):
			photo_status.visible = false
	else:
		if is_instance_valid(photo_status):
			photo_status.text = "Could not load photo."


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
		_show_toast("Place deleted.")

func _open_animal_dialog(animal_id: String, display_name: String) -> void:
	var line := "A tiny garden friend is resting here."
	match animal_id:
		"cat":
			line = "Mimi blinks slowly. She may walk a little, then curl up for a nap."
		"bird":
			line = "The bluebird hops softly near the garden and watches the family tree."
		"dog":
			line = "Biscuit wiggles happily, then flops down for a tiny nap."
	_show_cozy_panel(display_name, line, [{"text": "Close", "action": "close"}])

func _open_message_board_panel() -> void:
	var body := "Family notes are pinned here.\n\n"
	if MemoryManager.garden_messages.is_empty():
		body += "No notes yet. Add the first small message for the family."
	else:
		for message in MemoryManager.garden_messages:
			body += "• " + str(message.get("author", "Family")) + ": " + str(message.get("text", "")) + "\n\n"
	_show_cozy_panel(
		"Message Board",
		body,
		[
			{"text": "+ Note", "action": "add_message"},
			{"text": "Close", "action": "close"}
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
	title.text = "Add a Note"
	title.position = Vector2(30, 24)
	title.size = Vector2(440, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var author_label := Label.new()
	author_label.text = "From"
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
	message_label.text = "Message"
	message_label.position = Vector2(32, 154)
	message_label.size = Vector2(420, 22)
	message_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(message_label)

	var message_input := TextEdit.new()
	message_input.placeholder_text = "Leave a small note for the family..."
	message_input.position = Vector2(32, 180)
	message_input.size = Vector2(430, 90)
	panel.add_child(message_input)

	_add_panel_button(panel, "Save Note", Vector2(96, 296), Vector2(130, 40), "save_new_message", [author_input, message_input])
	_add_panel_button(panel, "Cancel", Vector2(274, 296), Vector2(120, 40), "message_board")

func _save_new_message(author_input: LineEdit, message_input: TextEdit) -> void:
	var author: String = author_input.text.strip_edges()
	if author == "":
		author = "Family"
	var text: String = message_input.text.strip_edges()
	if text == "":
		text = "A small note was left in the garden."

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
	title.text = "Postcards"
	title.position = Vector2(36, 26)
	title.size = Vector2(608, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Open a postcard to view its memory photo."
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
		empty_label.text = "No MemoryManager.postcards yet. Open the Travel Map and add a place to create the first one."
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
			var badge := "NEW · " if bool(postcard.get("is_new", false)) else ""
			var has_photo := str(postcard.get("photo_path", "")) != ""
			var photo_label := "Photo attached · " if has_photo else "No photo · "
			card_title.text = badge + photo_label + str(postcard.get("title", "Postcard"))
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
			open_button.text = "Open"
			open_button.position = Vector2(462, 29)
			open_button.size = Vector2(86, 36)
			open_button.mouse_filter = Control.MOUSE_FILTER_STOP
			_apply_button_style(open_button, false)
			_set_button_icon(open_button, "icon_postcard")
			open_button.pressed.connect(_open_postcard_detail_from_id.bind(postcard_id))
			card.add_child(open_button)

	_add_panel_button(panel, "Travel Map", Vector2(96, 520), Vector2(150, 40), "travel_map")
	_add_panel_button(panel, "Close", Vector2(432, 520), Vector2(150, 40), "close")
	MemoryManager.mark_postcards_read()
	MemoryManager.save_game()


func _open_postcard_detail_from_id(postcard_id: String) -> void:
	var postcard := MemoryManager.find_postcard(postcard_id)
	if postcard.is_empty():
		_show_toast("Postcard not found.")
		return

	var place_id: String = str(postcard.get("place_id", ""))
	var place := MemoryManager.find_place(place_id)
	var title_text := str(postcard.get("title", "Postcard"))
	var message := str(postcard.get("message", "A small memory."))
	var photo_path := str(postcard.get("photo_path", ""))

	if photo_path == "" and not place.is_empty():
		photo_path = str(place.get("photo_path", ""))

	_open_postcard_detail_panel(title_text, message, photo_path, place_id)


func _open_family_tree_panel() -> void:
	var body := "This tree grows with family memories.\n\nFamily members:\n"
	for role_data in CHARACTER_DATA:
		var role_key := str(role_data.get("role", ""))
		var member_name := MemoryManager.player_display_name if role_key == MemoryManager.selected_role_key else str(role_data.get("default_name", role_data.get("label", "Family")))
		var status := "online" if role_key == MemoryManager.selected_role_key else "offline"
		body += "• " + member_name + " — " + status + "\n"
	body += "\nPostcards on the tree:\n"
	if MemoryManager.postcards.is_empty():
		body += "• No MemoryManager.postcards yet. Open the Travel Map to send one.\n"
	else:
		for postcard in MemoryManager.postcards:
			body += "• " + str(postcard.get("title", "Postcard")) + "\n"
	_show_cozy_panel(
		"Family Tree",
		body,
		[
			{"text": "Postcards", "action": "MemoryManager.postcards"},
			{"text": "Board", "action": "message_board"},
			{"text": "Close", "action": "close"}
		]
	)

func _open_mailbox_panel() -> void:
	var unread_count: int = MemoryManager.count_unread_postcards()
	var body := ""
	if unread_count > 0:
		body = "New mail has arrived.\n\n"
		for postcard in MemoryManager.postcards:
			if bool(postcard.get("is_new", false)):
				body += "• " + str(postcard.get("title", "New postcard")) + "\n"
	else:
		body = "No new mail right now.\n\nAdd a place on the Travel Map to send a new postcard to the garden."
	MemoryManager.mark_postcards_read(false)
	MemoryManager.clear_mailbox_alert()
	if CloudManager != null:
		await CloudManager.mark_mailbox_read()
	MemoryManager.save_game()
	_show_cozy_panel(
		"Mailbox",
		body,
		[
			{"text": "View Postcards", "action": "MemoryManager.postcards"},
			{"text": "Travel Map", "action": "travel_map"},
			{"text": "Close", "action": "close"}
		]
	)

func _open_npc_dialog(npc_id: String, display_name: String) -> void:
	var line := "It's peaceful in the garden today."
	match npc_id:
		"papa":
			line = "The garden looks peaceful today. It feels good to see everyone here."
		"mama":
			line = "The flowers are growing beautifully. This place feels like a small home."
		"boy":
			line = "I found a quiet corner here. Maybe we can leave a postcard together."
		"girl":
			line = "I brought a small memory back to the garden."
	_show_cozy_panel(display_name, line, [{"text": "Close", "action": "close"}])

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
	# 所有走这个统一样式函数的 Button 都顺带接上点击音效；toggle 类按钮(如种植开关)会
	# 反复调用 _apply_button_style 刷新选中态样式，用 is_connected 防止重复挂信号导致连响多次。
	if not button.pressed.is_connected(_play_button_click_sfx):
		button.pressed.connect(_play_button_click_sfx)

func _play_button_click_sfx() -> void:
	AudioManager.play_sfx("按钮")

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
	if active_modal != null and is_instance_valid(active_modal):
		active_modal.queue_free()
	active_modal = null
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
			return "A warm little room for Papa. Books, coffee, and family MemoryManager.postcards will live here."
		"mother":
			return "A gentle cottage for flowers, notes, and quiet family memories."
		"player":
			return "Peilin's cottage keeps travel notes, photos, and small discoveries from the road."
		"partner":
			return "Louis's cottage is waiting for shared MemoryManager.postcards and soft garden visits."
	return "A small family cottage."

func _show_toast(toast_text: String) -> void:
	info_label.text = "Family Garden   —   " + toast_text

func _safe_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _solid_texture(width: int, height: int, color: Color) -> Texture2D:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
