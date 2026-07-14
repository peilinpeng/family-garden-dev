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
const USE_GARDEN_TILED_AS_MAIN := false  # 正式主花园继续使用 shared_garden；TileMap 场景保留供独立搭建验收。
const CHARACTER_CREATOR_PANEL_SCRIPT := preload("res://scripts/ui/character_creator_panel.gd")
const LOOP_TWEEN_GUARD_INTERVAL := 0.05
const FISHPOND_PLAYER_VISUAL_SCALE := 1.35
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
	"player": "res://assets/characters/girl_2.png",
	"father": "res://assets/characters/papa.png",
	"mother": "res://assets/characters/mama.png",
	"partner": "res://assets/characters/boy.png",
	"girl": "res://assets/characters/girl_2.png",
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
	"icon_build": "res://assets/ui/icons/icon_build.png",
	"icon_settings": "res://assets/ui/icons/icon_settings.png",
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
	{"id": "father", "label": "爸爸的小屋", "room_label": "爸爸的房间", "asset": "house_father", "pos": Vector2(205, 160), "height": 180.0, "hotspot_size": Vector2(86, 96)},
	{"id": "mother", "label": "妈妈的小屋", "room_label": "妈妈的房间", "asset": "house_mother", "pos": Vector2(1090, 160), "height": 230.0, "hotspot_size": Vector2(92, 100)},
	{"id": "player", "label": "佩林的小屋", "room_label": "佩林的房间", "asset": "house_player", "pos": Vector2(682, 160), "height": 180.0, "hotspot_size": Vector2(92, 100)},
	{"id": "partner", "label": "路易的小屋", "room_label": "路易的房间", "asset": "house_partner", "pos": Vector2(370, 155), "height": 180.0, "hotspot_size": Vector2(92, 100)},
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

const GARDEN_ARCHIVES := {
	"flowers": {"title": "记忆花圃", "subtitle": "家人共同照料的日常片段", "slot_id": "garden_archive_flowers"},
	"photos": {"title": "家庭影像", "subtitle": "照片里留下的光和笑声", "slot_id": "garden_archive_photos"},
	"postcards": {"title": "远方来信", "subtitle": "旅途中寄回家的明信片", "slot_id": "garden_archive_postcards"},
}
const GARDEN_ARCHIVE_ORDER := ["flowers", "photos", "postcards"]

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
var day_night_clock_ui: Control = null
var world_chat_fade_tween: Tween = null
var _chat_panel_list: VBoxContainer = null   ## 打开的完整聊天面板的消息容器(发送后实时刷新)
var _chat_panel_scroll: ScrollContainer = null
var plant_mode := false
var selected_plant_type := "tree"
var mode := "garden"
var player: CharacterBody2D
var plant_nodes: Dictionary = {}
var room_card: Panel = null
var gate4_guide_card: Panel = null
var garden_guide_expanded := true
var mailbox_badge: Sprite2D = null
var active_modal: Control = null
var game_hud: GameHUD = null   ## 常驻 HUD(角色卡/图标导航/设置/背包),setup 时创建
var map_ui: Control = null
var global_map_ui: Control = null
var pond_fishing_available := false
var pond_fishing_prompt: Label = null
var adding_place := false
var _garden_controls_hint_shown := false
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
var _autosave_timer: Timer = null
var _current_spawn_key := "default"
var _current_room_id := ""
var _pending_resume_position := Vector2.ZERO
var _has_pending_resume_position := false

func _unhandled_input(event: InputEvent) -> void:
	if mode != "fishpond" or (active_modal != null and is_instance_valid(active_modal)):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if pond_fishing_available:
			get_viewport().set_input_as_handled()
			_start_fishing_sequence()

func _load_cloud_data() -> void:
	if OS.has_environment("FAMILY_GARDEN_TEST"):
		cloud_load_finished = true
		return
	if CloudManager == null:
		return
	if MemoryManager.selected_role_key == "":
		cloud_load_finished = true
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
		"farm_activity_log":
			return "农场告示牌已同步。"
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
	if _autosave_timer == null:
		_autosave_timer = Timer.new()
		_autosave_timer.name = "AutosaveTimer"
		_autosave_timer.wait_time = 5.0
		_autosave_timer.autostart = true
		_autosave_timer.timeout.connect(_on_autosave_timeout)
		add_child(_autosave_timer)
	_setup_custom_cursor()
	_build_ui()
	# 常驻 HUD 作为独立 CanvasLayer 挂到 main 根，切换场景时不重建。
	game_hud = GameHUD.new()
	ui_layer.get_parent().add_child(game_hud)
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_update_viewport_layout):
		viewport.size_changed.connect(_update_viewport_layout)
	_update_viewport_layout()

func _on_autosave_timeout() -> void:
	save_current_progress()

func save_current_progress() -> void:
	if MemoryManager.selected_role_key == "":
		return
	if not _is_autosavable_scene(mode):
		return
	if player == null or not is_instance_valid(player):
		return
	var scene_id := _current_autosave_scene_id()
	MemoryManager.update_autosave(scene_id, player.global_position, _current_spawn_key)

func restore_last_saved_scene() -> void:
	if not MemoryManager.has_resume_position():
		_show_garden()
		return
	var scene_id := MemoryManager.last_scene_id
	_pending_resume_position = MemoryManager.resume_position()
	_has_pending_resume_position = true
	if scene_id.begins_with("room:"):
		var room_id := scene_id.get_slice(":", 1)
		var room_data := _get_room_data(room_id)
		_enter_house(room_id, str(room_data.get("label", "房间")))
	else:
		match scene_id:
			"garden":
				_show_garden(MemoryManager.last_spawn_key)
			"farm":
				goto_scene("farm")
			"kitchen":
				goto_scene("kitchen")
			"fishpond", "pond":
				_build_fishpond(MemoryManager.last_spawn_key)
			"room":
				var room_data := _get_room_data("player")
				_enter_house("player", str(room_data.get("label", "我的房间")))
			_:
				_show_garden()
	call_deferred("_apply_pending_resume_position")

func reset_to_new_game() -> void:
	_has_pending_resume_position = false
	_current_spawn_key = "default"
	_current_room_id = ""
	player = null
	if game_hud != null and is_instance_valid(game_hud) and game_hud.has_open_panel():
		game_hud.close_current()
	_close_active_panel()
	_clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	_clear_world()
	MemoryManager.reset_to_new_game()
	if InventoryManager != null and InventoryManager.has_method("reset_to_new_game"):
		InventoryManager.reset_to_new_game()
	_show_role_select()
	_show_toast("存档已清除，已恢复初始状态。")

func _apply_pending_resume_position() -> void:
	if not _has_pending_resume_position:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if _has_pending_resume_position and player != null and is_instance_valid(player):
		player.global_position = _pending_resume_position
	_has_pending_resume_position = false

func _is_autosavable_scene(scene_id: String) -> bool:
	return scene_id in ["garden", "farm", "kitchen", "fishpond", "room"]

func _current_autosave_scene_id() -> String:
	if mode == "room":
		return "room:%s" % (_current_room_id if _current_room_id != "" else "player")
	return mode

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
	ui_root = root
	root.name = "UIRoot"
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = GAME_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	var day_night_clock := TextureRect.new()
	day_night_clock.name = "DayNightClock"
	day_night_clock.set_script(DAY_NIGHT_CLOCK_UI_SCRIPT)
	day_night_clock.position = Vector2(GAME_SIZE.x - 82, 10)
	day_night_clock.size = Vector2(112, 124)
	day_night_clock.scale = Vector2(0.58, 0.58)
	day_night_clock.modulate = Color(1.0, 1.0, 1.0, 0.92)
	day_night_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(day_night_clock)
	day_night_clock_ui = day_night_clock

	info_label = Label.new()
	info_label.visible = false
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.text = "家庭花园"
	root.add_child(info_label)

	# 操作说明改为首次进入时的短提示；聊天输入只在聊天面板内出现。
	# 这里只保留收到消息后的临时预览，不再永久占据底部花园画面。
	_add_world_chat_feed(root, Vector2(826, 580), Vector2(382, 60))
	world_chat_input = null
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
	panel.position = Vector2(1022, 116) if scene_id == "room" else (Vector2(16, 132) if scene_id == "garden" else Vector2(20, 20))
	panel.size = Vector2(226, 76) if scene_id == "room" else (Vector2(244, 184) if scene_id == "garden" and garden_guide_expanded else (Vector2(244, 44) if scene_id == "garden" else Vector2(248, 92)))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_guide_card_style(panel, scene_id)
	if ui_root != null and is_instance_valid(ui_root):
		ui_root.add_child(panel)
	else:
		ui_layer.add_child(panel)

	var accent := ColorRect.new()
	accent.position = Vector2(14, 14) if scene_id == "garden" and garden_guide_expanded else (Vector2(12, 10) if scene_id == "garden" else Vector2(12, 11))
	accent.size = Vector2(4, 156) if scene_id == "garden" and garden_guide_expanded else (Vector2(4, 24) if scene_id == "garden" else (Vector2(4, 54) if scene_id == "room" else Vector2(4, 68)))
	accent.color = _gate4_guide_accent(scene_id)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent)
	if scene_id == "garden":
		if garden_guide_expanded:
			_add_garden_guide_inset(panel)
			_add_garden_guide_title(panel)
			_add_garden_beginner_steps(panel)
			_add_garden_guide_toggle(panel, Vector2(206, 8), true)
		else:
			_add_garden_guide_compact(panel)
			_add_garden_guide_toggle(panel, Vector2(206, 8), false)
		return

	var title := Label.new()
	title.text = _gate4_guide_title(scene_id)
	title.position = Vector2(28, 8) if scene_id == "room" else Vector2(28, 10)
	title.size = Vector2(184, 21) if scene_id == "room" else Vector2(202, 22)
	title.add_theme_font_size_override("font_size", 14 if scene_id == "room" else 15)
	title.add_theme_color_override("font_color", Color(0.21, 0.18, 0.13, 0.96))
	panel.add_child(title)

	var body := Label.new()
	body.text = _gate4_guide_body(scene_id)
	body.position = Vector2(28, 31) if scene_id == "room" else Vector2(28, 36)
	body.size = Vector2(184, 36) if scene_id == "room" else Vector2(202, 40)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.33, 0.28, 0.21, 0.90))
	panel.add_child(body)


func _add_garden_guide_title(parent: Control) -> void:
	var title := Label.new()
	title.text = _gate4_guide_title("garden")
	title.position = Vector2(32, 10)
	title.size = Vector2(96, 24)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.21, 0.18, 0.13, 0.96))
	parent.add_child(title)


func _add_garden_guide_compact(parent: Control) -> void:
	var title := Label.new()
	title.text = "新手指引"
	title.position = Vector2(28, 8)
	title.size = Vector2(76, 24)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.21, 0.18, 0.13, 0.96))
	parent.add_child(title)

	var summary := Label.new()
	summary.text = "移动 · 建造 · 撤销"
	summary.position = Vector2(106, 10)
	summary.size = Vector2(92, 21)
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_theme_font_size_override("font_size", 11)
	summary.add_theme_color_override("font_color", Color(0.36, 0.30, 0.20, 0.86))
	parent.add_child(summary)

func _add_garden_beginner_steps(parent: Control) -> void:
	var guide := Label.new()
	guide.name = "GardenBeginnerSteps"
	guide.text = "WASD / 方向键    移动角色\nB / 底部锤子      开关建造\n左键拖动          绘制或摆放\nShift + 拖动      矩形铺地\nDelete            删除模式\nCtrl+Z / Ctrl+Y   撤销 / 重做"
	guide.position = Vector2(28, 44)
	guide.size = Vector2(198, 126)
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide.add_theme_font_size_override("font_size", 12)
	guide.add_theme_color_override("font_color", Color(0.31, 0.27, 0.19, 0.92))
	guide.add_theme_constant_override("line_spacing", 3)
	parent.add_child(guide)


func _add_family_portrait_compact(parent: Control) -> void:
	var fp: Dictionary = MemoryManager.family_portrait
	var members: Array = fp.get("members", [])
	if members.is_empty() and MemoryManager.selected_role_key != "":
		members = [MemoryManager.selected_role_key]
	var family_button := Panel.new()
	family_button.name = "FamilyPortraitMiniature"
	family_button.position = Vector2(252, 8)
	family_button.size = Vector2(32, 28)
	family_button.mouse_filter = Control.MOUSE_FILTER_STOP
	family_button.tooltip_text = "查看家庭成员"
	var family_style := StyleBoxFlat.new()
	family_style.bg_color = Color(0.80, 0.87, 0.63, 0.88)
	family_style.border_color = Color(0.43, 0.31, 0.19, 0.64)
	family_style.set_border_width_all(1)
	family_style.set_corner_radius_all(4)
	family_button.add_theme_stylebox_override("panel", family_style)
	parent.add_child(family_button)

	var count := Label.new()
	count.text = "%d人" % members.size()
	count.position = Vector2(2, 5)
	count.size = Vector2(28, 17)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_theme_font_size_override("font_size", 9)
	count.add_theme_color_override("font_color", Color(0.31, 0.26, 0.16, 0.88))
	family_button.add_child(count)
	family_button.mouse_entered.connect(func() -> void: family_button.modulate = Color(1.05, 1.03, 0.96, 1.0))
	family_button.mouse_exited.connect(func() -> void: family_button.modulate = Color.WHITE)
	family_button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_open_family_members_panel()
	)


func _add_garden_guide_toggle(parent: Control, pos: Vector2, expanded: bool) -> void:
	var toggle := Button.new()
	toggle.text = "-" if expanded else "+"
	toggle.position = pos
	toggle.size = Vector2(26, 28)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.tooltip_text = "收起新手指引" if expanded else "展开新手指引"
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.add_theme_color_override("font_color", Color(0.35, 0.29, 0.19, 0.90))
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.91, 0.87, 0.69, 0.52)
	normal_style.border_color = Color(0.48, 0.37, 0.23, 0.24)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(4)
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.83, 0.88, 0.65, 0.82)
	hover_style.border_color = Color(0.42, 0.52, 0.28, 0.55)
	toggle.add_theme_stylebox_override("normal", normal_style)
	toggle.add_theme_stylebox_override("hover", hover_style)
	toggle.add_theme_stylebox_override("pressed", hover_style)
	toggle.pressed.connect(_toggle_garden_guide)
	parent.add_child(toggle)


func _toggle_garden_guide() -> void:
	garden_guide_expanded = not garden_guide_expanded
	_show_gate4_scene_guide("garden")


func _add_garden_guide_inset(parent: Control) -> void:
	var inset := Panel.new()
	inset.position = Vector2(5, 5)
	inset.size = parent.size - Vector2(10, 10)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset_style := StyleBoxFlat.new()
	inset_style.bg_color = Color(0, 0, 0, 0)
	inset_style.border_color = Color(1.0, 0.98, 0.88, 0.54)
	inset_style.set_border_width_all(1)
	inset_style.set_corner_radius_all(6)
	inset.add_theme_stylebox_override("panel", inset_style)
	parent.add_child(inset)

	var title_rule := ColorRect.new()
	title_rule.position = Vector2(32, 36)
	title_rule.size = Vector2(190, 1)
	title_rule.color = Color(0.45, 0.58, 0.32, 0.42)
	title_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(title_rule)


func _add_garden_guide_stats(parent: Control) -> void:
	var stats := [
		{"value": _demo_memories.size(), "label": "段记忆"},
		{"value": MemoryManager.get_memory_links("garden").size(), "label": "条藤蔓"},
	]
	for index in range(stats.size()):
		var stat: Dictionary = stats[index]
		var card := Panel.new()
		card.position = Vector2(28 + index * 66, 46)
		card.size = Vector2(60, 46)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.94, 0.90, 0.73, 0.58)
		card_style.border_color = Color(0.53, 0.43, 0.27, 0.18)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(4)
		card.add_theme_stylebox_override("panel", card_style)
		parent.add_child(card)

		var value := Label.new()
		value.text = str(stat.get("value", 0))
		value.position = Vector2(4, 2)
		value.size = Vector2(52, 24)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value.add_theme_font_size_override("font_size", 17)
		value.add_theme_color_override("font_color", Color(0.25, 0.22, 0.15, 0.98))
		card.add_child(value)

		var caption := Label.new()
		caption.text = String(stat.get("label", ""))
		caption.position = Vector2(4, 25)
		caption.size = Vector2(52, 16)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_font_size_override("font_size", 10)
		caption.add_theme_color_override("font_color", Color(0.38, 0.32, 0.21, 0.82))
		card.add_child(caption)


func _apply_guide_card_style(panel: Panel, scene_id: String = "") -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.92, 0.78, 0.96) if scene_id == "garden" else (Color(0.97, 0.92, 0.82, 0.88) if scene_id == "room" else Color(1.0, 0.96, 0.84, 0.82))
	style.border_color = Color(0.42, 0.31, 0.20, 0.72) if scene_id == "garden" else (Color(0.45, 0.33, 0.25, 0.42) if scene_id == "room" else Color(0.54, 0.42, 0.28, 0.48))
	style.set_border_width_all(2 if scene_id == "garden" else 1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.15, 0.10, 0.06, 0.20 if scene_id == "garden" else 0.14)
	style.shadow_size = 5 if scene_id == "garden" else (3 if scene_id == "room" else 4)
	style.shadow_offset = Vector2(0, 3 if scene_id == "garden" else 2)
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
			return "新手指引"

func _gate4_guide_body(scene_id: String) -> String:
	match scene_id:
		"fishpond":
			return "%d 只漂流瓶 · 靠近钓鱼台按 E\n回答会收进主花园的记忆花园" % _demo_bottles.size()
		"room":
			var room := MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
			var object_count := 0 if room.is_empty() else MemoryManager.get_room_objects(String(room.get("id", ""))).size()
			return "%s · %d 件物件\n点击家具可调整位置" % [
				_room_theme_display_label(String(room.get("room_name", "还没有生成房间"))) if not room.is_empty() else "等待一张房间照片",
				object_count,
			]
		_:
			return "%d 段记忆\n%d 条藤蔓" % [
				_demo_memories.size(),
				MemoryManager.get_memory_links("garden").size(),
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
	_send_world_chat_message(submitted_text, world_chat_input)

## 发送世界聊天消息。source_input:发起发送的输入框(底部栏或聊天面板内嵌),发送期间禁用、
## 完成后清空并重新聚焦。回车键与 Send 按钮、聊天面板发送都走这里。
func _send_world_chat_message(raw_text: String, source_input: LineEdit = null) -> void:
	var text := raw_text.strip_edges()
	if text == "":
		return
	if source_input != null and is_instance_valid(source_input):
		source_input.editable = false
		source_input.text = ""
		source_input.placeholder_text = "正在发送..."

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
	_refresh_chat_panel_messages()
	if source_input != null and is_instance_valid(source_input):
		source_input.editable = true
		source_input.placeholder_text = "给家人留一句话..."
		source_input.grab_focus()
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

## 完整家庭聊天面板:滚动消息流(旧→新,气泡按自己/家人左右对齐)+ 内嵌输入框/发送。
## 底部栏"Chat"按钮或点消息预览都打开这里。发送后实时刷新并自动滚到底。
func _open_world_chat_history_panel() -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay

	var panel := Panel.new()
	panel.position = Vector2(340, 70)
	panel.size = Vector2(600, 580)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = "家庭聊天"
	title.position = Vector2(34, 22)
	title.size = Vector2(500, 32)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	# 消息流
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 66)
	scroll.size = Vector2(544, 436)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)
	_chat_panel_scroll = scroll

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(544, 0)
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	_chat_panel_list = list

	# 内嵌输入 + 发送
	var input := LineEdit.new()
	input.name = "ChatPanelInput"
	input.placeholder_text = "给家人留一句话..."
	input.position = Vector2(28, 514)
	input.size = Vector2(456, 40)
	input.mouse_filter = Control.MOUSE_FILTER_STOP
	input.add_theme_font_size_override("font_size", 14)
	input.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16, 1.0))
	panel.add_child(input)

	var send_btn := Button.new()
	send_btn.text = "发送"
	send_btn.position = Vector2(492, 514)
	send_btn.size = Vector2(80, 40)
	send_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_style(send_btn, false)
	send_btn.pressed.connect(func() -> void: _send_world_chat_message(input.text, input))
	panel.add_child(send_btn)
	input.text_submitted.connect(func(t: String) -> void: _send_world_chat_message(t, input))

	_refresh_chat_panel_messages()
	input.grab_focus()

## 重建聊天面板的消息气泡(打开时 + 每次发送后)。面板已关则安全跳过。
func _refresh_chat_panel_messages() -> void:
	if _chat_panel_list == null or not is_instance_valid(_chat_panel_list):
		return
	for c in _chat_panel_list.get_children():
		c.queue_free()
	if MemoryManager.garden_messages.is_empty():
		var empty := Label.new()
		empty.text = "还没有消息，发一条和家人打个招呼吧～"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.40, 0.33, 0.25, 0.85))
		_chat_panel_list.add_child(empty)
	else:
		for raw in MemoryManager.garden_messages:
			if raw is Dictionary:
				_chat_panel_list.add_child(_make_chat_bubble(raw))
	# 布局完成后滚到底(超大值自动夹到 max)
	if _chat_panel_scroll != null and is_instance_valid(_chat_panel_scroll):
		_chat_panel_scroll.set_deferred("scroll_vertical", 1000000)
## 单条聊天气泡:自己发的靠右(暖绿),家人的靠左(米色);含作者 + 时间。
func _make_chat_bubble(message: Dictionary) -> Control:
	var is_self := str(message.get("role", "")) == str(MemoryManager.selected_role_key)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if is_self else Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.86, 0.93, 0.72, 0.96) if is_self else Color(1.0, 0.95, 0.82, 0.94)
	style.border_color = Color(0.58, 0.62, 0.36, 0.7) if is_self else Color(0.62, 0.48, 0.32, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	bubble.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	bubble.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	margin.add_child(vb)

	var meta := Label.new()
	meta.text = str(message.get("author", "家人")) + "  ·  " + _format_world_chat_time(str(message.get("created_at", "")))
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", Color(0.40, 0.33, 0.25, 0.85))
	vb.add_child(meta)

	var body := Label.new()
	body.text = str(message.get("text", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(320, 0)
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.20, 0.16, 0.12, 1.0))
	vb.add_child(body)

	if is_self:
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
	return row

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
		"world_chat_send":
			if world_chat_input != null and is_instance_valid(world_chat_input):
				_send_world_chat_message(world_chat_input.text, world_chat_input)
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
	_current_spawn_key = "default"
	_current_room_id = ""
	_set_hud_context(mode)
	info_label.text = "创建角色"
	_add_background()
	var overlay := _create_modal_overlay()
	active_modal = overlay
	var creator: Control = CHARACTER_CREATOR_PANEL_SCRIPT.new()
	overlay.add_child(creator)
	var family_code := CloudManager.family_code() if CloudManager != null and CloudManager.has_method("family_code") else ""
	creator.call("setup", MemoryManager.selected_role_key, MemoryManager.player_display_name, family_code, MemoryManager.character_appearance)
	creator.connect("confirmed", _confirm_character_creation)
	creator.connect("canceled", func() -> void:
		_close_active_panel()
		if MemoryManager.selected_role_key != "":
			_show_garden())

func _confirm_character_creation(role_key: String, display_name: String, family_code: String, appearance: Dictionary) -> void:
	MemoryManager.selected_role_key = role_key
	MemoryManager.player_display_name = display_name.strip_edges()
	AppearanceManager.set_current(appearance, role_key)
	_close_active_panel()
	if game_hud != null:
		game_hud.refresh_profile()
	_show_garden()
	if StoryManager.consume_quest_intro() and game_hud != null:
		game_hud.start_onboarding_guide()
	var canonical_role: String = CharacterDB.resolve(role_key)
	CloudManager.ensure_cloud_identity(canonical_role, MemoryManager.player_display_name, family_code)

## 旧四卡片选择器保留为兼容参考；新游戏入口使用上面的捏脸面板。
func _show_legacy_role_select() -> void:
	_close_active_panel()
	_clear_map_ui()
	_clear_world()
	mode = "role_select"
	_current_spawn_key = "default"
	_current_room_id = ""
	_set_hud_context(mode)
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

	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(112, 118)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 头像统一走 CharacterDB.avatar_texture:兼容等分网格与 girl_2 的非等分 frame_rects,
	# 不再用本地 3×4 均分裁切(对 girl_2 会切错)。
	preview.texture = CharacterDB.avatar_texture(str(role_data.get("role", "girl")))
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

func _confirm_role_selection(role_key: String, name_input: LineEdit, family_input: LineEdit = null) -> void:
	MemoryManager.selected_role_key = role_key
	MemoryManager.player_display_name = name_input.text.strip_edges()
	if MemoryManager.player_display_name == "":
		MemoryManager.player_display_name = _default_name_for_role(role_key)
	MemoryManager.save_game()
	_close_active_panel()
	if game_hud != null:
		game_hud.refresh_profile()   # 昵称/头像定了,刷新左上角色卡
	_show_garden()
	# 首次流程(开场→选角色→进花园)刚走完开场时,自动弹一次 Chapter 1 任务面板
	if StoryManager.consume_quest_intro() and game_hud != null:
		game_hud.start_onboarding_guide()
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
	var selected_id := CharacterDB.resolve(MemoryManager.selected_role_key) if CharacterDB != null else MemoryManager.selected_role_key
	var role_data := _get_role_data(MemoryManager.selected_role_key)
	if role_data.is_empty():
		for candidate in CHARACTER_DATA:
			var candidate_role := str(candidate.get("role", ""))
			var candidate_id := CharacterDB.resolve(candidate_role) if CharacterDB != null else candidate_role
			if candidate_id == selected_id:
				role_data = candidate
				break
	if role_data.is_empty():
		return "girl"
	return str(role_data.get("asset", "girl"))


## 角色贴图路径必须与 CharacterDB 中的帧配置来自同一个定义。
## 旧 ASSETS 别名仍保留给历史 UI 使用，但人物实例不再混用旧图与新版 frame_rects。
func _character_texture_path(role_key: String, fallback_path: String) -> String:
	if CharacterDB == null:
		return fallback_path
	var character_def: Dictionary = CharacterDB.get_def(role_key)
	var sheet := str(character_def.get("sheet", "")).strip_edges()
	if sheet == "":
		return fallback_path
	var configured_path := "res://assets/characters/%s.png" % sheet
	return configured_path if ResourceLoader.exists(configured_path) else fallback_path


func _update_plant_button() -> void:
	if plant_button:
		plant_button.text = "种植：开启" if plant_mode else "种植：关闭"
		_apply_button_style(plant_button, plant_mode)

func _show_garden(spawn_key: String = "default") -> void:
	save_current_progress()
	_close_active_panel()
	_clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	_clear_gate4_guide()
	mode = "garden"
	_current_spawn_key = spawn_key
	_current_room_id = ""
	_set_hud_context(mode)
	_focused_memory_id = ""
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
	MemoryManager.maybe_recompute_family_portrait()  # 进花园按当前成员/记忆数更新左上迷你合影
	_render_family_portrait()
	ScenePortal.build_portals("garden", world, _on_portal_travel)
	_setup_garden_builder()
	# 花园统计已合并到左上家庭状态卡，不再叠加第二张“花园今日”。
	if game_hud != null:
		game_hud.refresh_profile()
	if not _garden_controls_hint_shown:
		_garden_controls_hint_shown = true
		_show_toast("方向键 / WASD 移动 · 靠近家人或点击花园物件互动")

# 场景层只负责渲染和交互；AI 生成、草稿确认和持久化由 AIClient / AIWorkflowManager / MemoryManager 处理。
# 这里缓存当前场景已渲染的节点 view model，离场后可由数据层重建。
var _demo_memories: Array = []
var _focused_memory_id := ""
var _pending_memory_arrival_id := ""

# 鱼塘漂流瓶当前场景 view model；已保存问题来自 MemoryManager，缺口由 AIWorkflowManager 后台补齐。
var _demo_bottles: Array = []
# 兼容旧代码的空缓存；鱼塘不再渲染记忆花，旧数据进入主花园档案。
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
	_render_memory_links("garden")  # 默认保持安静，选中记忆后只画与它相关的藤蔓
	if _pending_memory_arrival_id != "":
		_play_memory_archive_arrival(_pending_memory_arrival_id)
		_pending_memory_arrival_id = ""
	print("[SceneManager] garden 记忆归档=", _demo_memories.size(), " 可见景观=", _garden_archive_count(), " 连线=", MemoryManager.get_memory_links("garden").size())

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

# 花园默认不铺开关系网；选中一段记忆后，只显示与它直接相关的藤蔓。
func _render_memory_links(scene: String) -> void:
	if scene == "garden" and _focused_memory_id == "":
		return
	for link in MemoryManager.get_memory_links(scene):
		if scene == "garden" and _focused_memory_id not in [
			String(link.get("memory_id", "")),
			String(link.get("linked_memory_id", "")),
		]:
			continue
		var a := _memory_flower_pos(scene, String(link.get("memory_id", "")))
		var b := _memory_flower_pos(scene, String(link.get("linked_memory_id", "")))
		if a == Vector2.INF or b == Vector2.INF:
			continue
		if scene == "garden" and a.distance_to(b) < 8.0:
			a += Vector2(-34, 0)
			b += Vector2(34, 0)
		_draw_link_line(a, b, link)

# 家庭画像进入左上状态卡，以实际角色组成迷你合影；右下木牌只保留留言板用途。
func _render_family_portrait() -> void:
	if world != null and is_instance_valid(world):
		var legacy_board := world.get_node_or_null("FamilyPortraitBoard")
		if legacy_board != null:
			legacy_board.queue_free()
	# 家庭成员入口已统一到 GameHUD 左上状态卡，指引面板不再重复渲染。

func _add_family_portrait_miniature(parent: Control) -> void:
	var fp: Dictionary = MemoryManager.family_portrait
	var members: Array = fp.get("members", []).duplicate()
	if members.is_empty() and MemoryManager.selected_role_key != "":
		members.append(MemoryManager.selected_role_key)
	var frame := Panel.new()
	frame.name = "FamilyPortraitMiniature"
	frame.position = Vector2(178, 14)
	frame.size = Vector2(132, 80)
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.tooltip_text = "查看家庭成员 · %d 位家人共同留下 %d 段记忆" % [
		members.size(),
		int(fp.get("memory_count", MemoryManager.memories.size())),
	]
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.89, 0.91, 0.71, 0.98)
	frame_style.border_color = Color(0.43, 0.31, 0.19, 0.92)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(4)
	frame_style.shadow_color = Color(0.18, 0.12, 0.07, 0.24)
	frame_style.shadow_size = 2
	frame_style.shadow_offset = Vector2(0, 2)
	frame.add_theme_stylebox_override("panel", frame_style)
	parent.add_child(frame)

	var sky := ColorRect.new()
	sky.position = Vector2(4, 4)
	sky.size = Vector2(124, 50)
	sky.color = Color(0.80, 0.89, 0.72, 0.92)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(sky)
	var ground := ColorRect.new()
	ground.position = Vector2(4, 54)
	ground.size = Vector2(124, 22)
	ground.color = Color(0.59, 0.72, 0.40, 0.90)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(ground)

	var caption_back := ColorRect.new()
	caption_back.position = Vector2(4, 4)
	caption_back.size = Vector2(124, 16)
	caption_back.color = Color(0.96, 0.92, 0.77, 0.88)
	caption_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(caption_back)
	var caption := Label.new()
	caption.text = "家人合影 · %d" % members.size()
	caption.position = Vector2(10, 3)
	caption.size = Vector2(112, 17)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 9)
	caption.add_theme_color_override("font_color", Color(0.32, 0.26, 0.16, 0.86))
	frame.add_child(caption)
	for pin_x in [9.0, 119.0]:
		var pin := ColorRect.new()
		pin.position = Vector2(pin_x, 8)
		pin.size = Vector2(4, 4)
		pin.color = Color(0.84, 0.50, 0.22, 0.96)
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(pin)

	var shown_count := mini(members.size(), 4)
	for index in range(shown_count):
		var texture := _family_portrait_frame_texture(String(members[index]))
		if texture == null:
			continue
		var avatar := Sprite2D.new()
		avatar.name = "FamilyAvatar_%d" % index
		avatar.texture = texture
		avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var x := 66.0 if shown_count == 1 else lerpf(24.0, 108.0, float(index) / float(shown_count - 1))
		avatar.position = Vector2(x, 54)
		avatar.scale = Vector2.ONE * (40.0 / float(texture.get_height()))
		frame.add_child(avatar)
	if shown_count == 0:
		var empty := Label.new()
		empty.text = "等待家人加入"
		empty.position = Vector2(8, 35)
		empty.size = Vector2(116, 20)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", Color(0.34, 0.28, 0.21, 0.78))
		frame.add_child(empty)
	frame.mouse_entered.connect(func() -> void: frame.modulate = Color(1.05, 1.03, 0.96, 1.0))
	frame.mouse_exited.connect(func() -> void: frame.modulate = Color.WHITE)
	frame.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_open_family_members_panel()
	)

func _family_portrait_frame_texture(role_key: String) -> Texture2D:
	var source := CharacterDB.texture(role_key)
	var definition: Dictionary = CharacterDB.get_def(role_key)
	if source == null or definition.is_empty():
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	var rects: Array = definition.get("frame_rects", [])
	if rects.size() > 1 and rects[1] is Array and (rects[1] as Array).size() >= 4:
		var frame: Array = rects[1]
		atlas.region = Rect2(float(frame[0]), float(frame[1]), float(frame[2]), float(frame[3]))
		return atlas
	var hframes := maxi(1, int(definition.get("hframes", 3)))
	var vframes := maxi(1, int(definition.get("vframes", 4)))
	var cell_size := Vector2(float(source.get_width()) / float(hframes), float(source.get_height()) / float(vframes))
	atlas.region = Rect2(cell_size.x, 0, cell_size.x, cell_size.y)
	return atlas

# 花园记忆指向所属归档景观；其他场景仍沿用持久化 slot 落点。
func _memory_flower_pos(scene: String, memory_id: String) -> Vector2:
	for nd in MemoryManager.get_nodes_for_scene(scene):
		if String(nd.get("memory_id", "")) != memory_id or String(nd.get("node_type", "")) == "memory_link":
			continue
		if scene == "garden":
			var archive_key := NodeFactory.garden_archive_key(String(nd.get("node_type", "memory_flower")))
			return _garden_archive_position(archive_key)
		if String(nd.get("node_type", "")) == "memory_flower":
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
		pulse_tween.tween_interval(LOOP_TWEEN_GUARD_INTERVAL)

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
	if mode == "garden":
		_focused_memory_id = memory_id
		_refresh_memory_link_visuals("garden")
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
	var result := await AIWorkflowManager.save_memory_link_followup(link_id, text)
	if not bool(result.get("ok", false)):
		_set_button_ready(button)
		_set_status(status, _result_error_message(result, "保存失败，请重试。"), true)
		return
	_refresh_memory_link_visuals(mode)
	var updated := bool(result.get("updated", false))
	var link_message := "记忆藤蔓已更新。" if updated else "记忆藤蔓已点亮。"
	if bool(result.get("sync_pending", false)):
		link_message += " 已保存在本机，联网后会自动同步。"
	_show_toast(link_message)
	_open_memory_link_panel(result.get("link", {}))

func _refresh_memory_link_visuals(scene: String) -> void:
	if world == null or not is_instance_valid(world):
		return
	_clear_memory_link_nodes()
	_render_memory_links(scene)

func _clear_memory_focus() -> void:
	_focused_memory_id = ""
	if world != null and is_instance_valid(world):
		_clear_memory_link_nodes()

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
		_render_memory_links(scene)
	if scene == "garden":
		MemoryManager.maybe_recompute_family_portrait()
		_render_family_portrait()
	_show_gate4_scene_guide(scene)

# 从数据层渲染某场景已落库的节点：回填 slot 占用、按状态决定形态、装入交互缓存。
# cache 项：{ id(node_id), memory_id, card, state, answer, node }；click_cb 绑 node_id。
func _render_scene_nodes(scene: String, cache: Array, click_cb: Callable) -> void:
	if scene == "garden":
		_render_garden_archives(cache)
		return
	var groups: Dictionary = {}
	var scene_nodes: Array = MemoryManager.get_nodes_for_scene(scene)
	for raw_node in scene_nodes:
		if not (raw_node is Dictionary):
			continue
		var nd: Dictionary = raw_node
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

func _render_garden_archives(cache: Array) -> void:
	MemoryManager.migrate_fishpond_memories_to_garden()
	var archives := {
		"flowers": [],
		"photos": [],
		"postcards": [],
	}
	for raw_node in MemoryManager.get_nodes_for_scene("garden"):
		if not (raw_node is Dictionary):
			continue
		var stored_node: Dictionary = raw_node
		if String(stored_node.get("node_type", "")) == "memory_link":
			continue
		var memory_id := String(stored_node.get("memory_id", ""))
		var memory := MemoryManager.get_memory(memory_id)
		if memory.is_empty():
			continue
		var archive_key := NodeFactory.garden_archive_key(String(stored_node.get("node_type", "memory_flower")))
		var item := {
			"id": String(stored_node.get("id", "")),
			"memory_id": memory_id,
			"card": memory.get("ai_card", {}),
			"state": String(stored_node.get("state", "new")),
			"answer": MemoryManager.get_answer_for_memory(memory_id),
			"owner_id": String(memory.get("user_id", "")),
			"created_at": String(memory.get("created_at", stored_node.get("created_at", ""))),
			"input_type": String(memory.get("input_type", "text")),
			"archive_key": archive_key,
			"node": null,
		}
		(archives[archive_key] as Array).append(item)

	for raw_key in GARDEN_ARCHIVE_ORDER:
		var archive_key := String(raw_key)
		var items: Array = archives.get(archive_key, [])
		if items.is_empty():
			continue
		items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("created_at", "")) > String(b.get("created_at", "")))
		var visual_state := "new"
		for item in items:
			if String((item as Dictionary).get("state", "new")) == "grown":
				visual_state = "grown"
				break
		var slot := SlotManager.get_slot("garden", String(GARDEN_ARCHIVES[archive_key].get("slot_id", "")))
		if slot.is_empty():
			continue
		var live := NodeFactory.make_memory_archive(
			archive_key,
			slot,
			_open_memory_archive.bind(archive_key, items),
			visual_state
		)
		live.add_to_group("world_memory_node")
		live.scale = Vector2.ONE
		_add_garden_archive_caption(live, archive_key, items.size())
		world.add_child(live)
		for item in items:
			(item as Dictionary)["node"] = live
			cache.append(item)

func _garden_archive_position(archive_key: String) -> Vector2:
	var archive: Dictionary = GARDEN_ARCHIVES.get(archive_key, GARDEN_ARCHIVES["flowers"])
	var slot := SlotManager.get_slot("garden", String(archive.get("slot_id", "")))
	var pos: Variant = slot.get("pos", [930, 548])
	if pos is Array and (pos as Array).size() >= 2:
		return Vector2(float(pos[0]), float(pos[1]))
	return Vector2(930, 548)

func _garden_archive_count() -> int:
	var keys := {}
	for item in _demo_memories:
		if item is Dictionary:
			keys[String(item.get("archive_key", "flowers"))] = true
	return keys.size()

func _add_garden_archive_caption(node: Node2D, archive_key: String, count: int) -> void:
	var archive: Dictionary = GARDEN_ARCHIVES.get(archive_key, {})
	var caption := Panel.new()
	caption.name = "ArchiveCaption"
	caption.position = Vector2(-68, -132 if archive_key == "flowers" else -108)
	caption.size = Vector2(136, 42)
	caption.visible = false
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.96, 0.82, 0.96)
	style.border_color = Color(0.42, 0.52, 0.30, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	caption.add_theme_stylebox_override("panel", style)
	node.add_child(caption)
	var title := Label.new()
	title.text = String(archive.get("title", "记忆"))
	title.position = Vector2(8, 4)
	title.size = Vector2(120, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.24, 0.19, 0.13, 0.96))
	caption.add_child(title)
	var summary := Label.new()
	summary.text = "%d 段记忆" % count
	summary.position = Vector2(8, 21)
	summary.size = Vector2(120, 16)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_theme_font_size_override("font_size", 10)
	summary.add_theme_color_override("font_color", Color(0.34, 0.30, 0.22, 0.84))
	caption.add_child(summary)
	var click_area := node.get_node_or_null("ClickArea") as Area2D
	if click_area != null:
		var hover_glow := node.get_node_or_null("ArchiveHoverGlow") as CanvasItem
		click_area.mouse_entered.connect(func() -> void:
			caption.visible = true
			if hover_glow != null:
				hover_glow.visible = true
		)
		click_area.mouse_exited.connect(func() -> void:
			caption.visible = false
			if hover_glow != null:
				hover_glow.visible = false
		)

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

func _open_memory_archive(archive_key: String, items: Array) -> void:
	_clear_memory_focus()
	_close_active_panel()
	var archive: Dictionary = GARDEN_ARCHIVES.get(archive_key, GARDEN_ARCHIVES["flowers"])
	var overlay := _create_modal_overlay()
	active_modal = overlay
	var panel := Panel.new()
	panel.position = Vector2(260, 60)
	panel.size = Vector2(760, 600)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = String(archive.get("title", "家庭记忆"))
	title.position = Vector2(36, 24)
	title.size = Vector2(650, 36)
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "%s · 共 %d 段" % [String(archive.get("subtitle", "")), items.size()]
	subtitle.position = Vector2(36, 64)
	subtitle.size = Vector2(650, 24)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.38, 0.31, 0.23, 0.82))
	panel.add_child(subtitle)

	var filter_bar := Panel.new()
	filter_bar.position = Vector2(34, 102)
	filter_bar.size = Vector2(692, 68)
	filter_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filter_bar.add_theme_stylebox_override("panel", _archive_filter_bar_style())
	panel.add_child(filter_bar)

	var member_label := Label.new()
	member_label.text = "家人"
	member_label.position = Vector2(14, 7)
	member_label.size = Vector2(196, 18)
	member_label.add_theme_font_size_override("font_size", 11)
	member_label.add_theme_color_override("font_color", Color(0.36, 0.29, 0.21, 0.88))
	filter_bar.add_child(member_label)
	var member_select := OptionButton.new()
	member_select.position = Vector2(12, 27)
	member_select.size = Vector2(210, 34)
	member_select.add_item("全部家人")
	member_select.set_item_metadata(0, "")
	_apply_button_style(member_select, false)
	var owners := {}
	for raw_item in items:
		if raw_item is Dictionary:
			var owner_id := String(raw_item.get("owner_id", ""))
			if owner_id != "":
				owners[owner_id] = _role_display_name(owner_id)
	var owner_ids: Array = owners.keys()
	owner_ids.sort()
	for owner_id in owner_ids:
		member_select.add_item(String(owners[owner_id]))
		member_select.set_item_metadata(member_select.item_count - 1, String(owner_id))
	filter_bar.add_child(member_select)

	var state_label := Label.new()
	state_label.text = "状态"
	state_label.position = Vector2(244, 7)
	state_label.size = Vector2(196, 18)
	state_label.add_theme_font_size_override("font_size", 11)
	state_label.add_theme_color_override("font_color", Color(0.36, 0.29, 0.21, 0.88))
	filter_bar.add_child(state_label)
	var state_select := OptionButton.new()
	state_select.position = Vector2(242, 27)
	state_select.size = Vector2(190, 34)
	for state_item in [["全部状态", ""], ["等待回应", "new"], ["已经开花", "grown"]]:
		state_select.add_item(String(state_item[0]))
		state_select.set_item_metadata(state_select.item_count - 1, String(state_item[1]))
	_apply_button_style(state_select, false)
	filter_bar.add_child(state_select)

	var order_note := Label.new()
	order_note.text = "最新记忆优先"
	order_note.position = Vector2(458, 27)
	order_note.size = Vector2(216, 34)
	order_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	order_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	order_note.add_theme_font_size_override("font_size", 11)
	order_note.add_theme_color_override("font_color", Color(0.43, 0.37, 0.29, 0.68))
	filter_bar.add_child(order_note)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(34, 184)
	scroll.size = Vector2(692, 352)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	var empty_label := Label.new()
	empty_label.text = "这个筛选下还没有内容。换个条件看看吧。"
	empty_label.position = Vector2(44, 316)
	empty_label.size = Vector2(672, 40)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.visible = false
	empty_label.add_theme_font_size_override("font_size", 13)
	empty_label.add_theme_color_override("font_color", Color(0.43, 0.36, 0.27, 0.74))
	panel.add_child(empty_label)

	var refresh := func(_index: int = 0) -> void:
		_populate_memory_archive_list(list, empty_label, items, member_select, state_select, archive_key)
	member_select.item_selected.connect(refresh)
	state_select.item_selected.connect(refresh)
	refresh.call()

	var footer := Label.new()
	footer.text = "点击任意卡片查看完整内容与记忆关联"
	footer.position = Vector2(34, 552)
	footer.size = Vector2(692, 24)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.43, 0.36, 0.27, 0.64))
	panel.add_child(footer)

func _populate_memory_archive_list(list: VBoxContainer, empty_label: Label, items: Array, member_select: OptionButton, state_select: OptionButton, archive_key: String = "flowers") -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var owner_filter := String(member_select.get_selected_metadata())
	var state_filter := String(state_select.get_selected_metadata())
	var visible_count := 0
	for raw_item in items:
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item
		if owner_filter != "" and String(item.get("owner_id", "")) != owner_filter:
			continue
		if state_filter != "" and String(item.get("state", "new")) != state_filter:
			continue
		var card: Dictionary = item.get("card", {})
		var owner_id := String(item.get("owner_id", ""))
		var owner_name := _role_display_name(owner_id) if owner_id != "" else "家人"
		var created_at := String(item.get("created_at", ""))
		var date_text := created_at.left(10) if created_at.length() >= 10 else "未记录日期"
		var is_grown := String(item.get("state", "new")) == "grown"
		var state_text := "已开花" if is_grown else "待回应"
		var link_count := MemoryManager.count_memory_links_for_memory(String(item.get("memory_id", "")), "garden")
		var row := Panel.new()
		row.custom_minimum_size = Vector2(664, 78)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_stylebox_override("panel", _archive_row_style(is_grown))
		list.add_child(row)

		var icon_panel := Panel.new()
		icon_panel.position = Vector2(12, 13)
		icon_panel.size = Vector2(52, 52)
		icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_panel.add_theme_stylebox_override("panel", _archive_icon_style(archive_key))
		row.add_child(icon_panel)
		var icon := TextureRect.new()
		icon.position = Vector2(9, 9)
		icon.size = Vector2(34, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_key := "icon_camera" if archive_key == "photos" else ("icon_postcard" if archive_key == "postcards" else "icon_tree")
		icon.texture = _safe_texture(str(ASSETS.get(icon_key, "")))
		icon_panel.add_child(icon)

		var item_title := Label.new()
		item_title.text = String(card.get("title", "一段家庭记忆")).strip_edges()
		if item_title.text == "":
			item_title.text = "一段家庭记忆"
		item_title.position = Vector2(78, 11)
		item_title.size = Vector2(448, 25)
		item_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		item_title.add_theme_font_size_override("font_size", 15)
		item_title.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 0.98))
		item_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(item_title)

		var relation_text := " · %d 条关联" % link_count if link_count > 0 else ""
		var metadata := Label.new()
		metadata.text = "%s · %s%s" % [owner_name, date_text, relation_text]
		metadata.position = Vector2(78, 42)
		metadata.size = Vector2(448, 20)
		metadata.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		metadata.add_theme_font_size_override("font_size", 12)
		metadata.add_theme_color_override("font_color", Color(0.43, 0.35, 0.27, 0.82))
		metadata.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(metadata)

		var status_panel := Panel.new()
		status_panel.position = Vector2(548, 23)
		status_panel.size = Vector2(92, 32)
		status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_panel.add_theme_stylebox_override("panel", _archive_status_style(is_grown))
		row.add_child(status_panel)
		var status_label := Label.new()
		status_label.text = state_text
		status_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_label.add_theme_font_size_override("font_size", 11)
		status_label.add_theme_color_override("font_color", Color(0.27, 0.28, 0.17, 0.94) if is_grown else Color(0.48, 0.33, 0.17, 0.94))
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_panel.add_child(status_label)

		var hit := Button.new()
		hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hit.text = ""
		hit.flat = true
		hit.focus_mode = Control.FOCUS_ALL
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.tooltip_text = item_title.text
		hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		hit.add_theme_stylebox_override("hover", _archive_row_hover_style())
		hit.add_theme_stylebox_override("pressed", _archive_row_pressed_style())
		hit.add_theme_stylebox_override("focus", _archive_row_hover_style())
		hit.pressed.connect(_open_memory_archive_item.bind(item))
		row.add_child(hit)
		visible_count += 1
	empty_label.visible = visible_count == 0


func _archive_filter_bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.94, 0.88, 0.72, 0.42)
	style.border_color = Color(0.56, 0.43, 0.28, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style


func _archive_row_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.975, 0.90, 0.92)
	style.border_color = Color(0.48, 0.58, 0.31, 0.48) if active else Color(0.62, 0.48, 0.31, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	style.shadow_color = Color(0.18, 0.12, 0.07, 0.11)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style


func _archive_icon_style(archive_key: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.92, 0.84, 0.66, 0.72) if archive_key == "photos" else Color(0.86, 0.89, 0.72, 0.72)
	style.border_color = Color(0.57, 0.43, 0.28, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	return style


func _archive_status_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.80, 0.87, 0.63, 0.78) if active else Color(0.94, 0.82, 0.60, 0.72)
	style.border_color = Color(0.43, 0.54, 0.29, 0.40) if active else Color(0.62, 0.44, 0.24, 0.38)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func _archive_row_hover_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.94, 0.72, 0.16)
	style.border_color = Color(0.80, 0.58, 0.30, 0.76)
	style.set_border_width_all(2)
	style.set_corner_radius_all(11)
	return style


func _archive_row_pressed_style() -> StyleBoxFlat:
	var style := _archive_row_hover_style()
	style.bg_color = Color(0.82, 0.88, 0.66, 0.24)
	return style

func _open_memory_archive_item(item: Dictionary) -> void:
	_focused_memory_id = String(item.get("memory_id", ""))
	_refresh_memory_link_visuals("garden")
	_open_memory_card(item)

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

func _play_memory_archive_arrival(memory_id: String) -> void:
	var item := _find_rendered_memory_by_memory_id(memory_id)
	if item.is_empty() or world == null or not is_instance_valid(world):
		return
	var target := _garden_archive_position(String(item.get("archive_key", "flowers")))
	var bloom := NodeFactory.make_memory_node(
		{"node_type": "memory_flower", "suggested_scene": "garden"},
		{"slot_id": "arrival", "pos": [640, 490]},
		Callable(),
		"new"
	)
	bloom.name = "MemoryArrivalBloom"
	bloom.z_index = 620
	bloom.scale = Vector2(0.34, 0.34)
	bloom.modulate.a = 0.0
	world.add_child(bloom)
	var tween := create_tween()
	tween.tween_property(bloom, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bloom, "scale", Vector2(0.78, 0.78), 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.42)
	tween.tween_property(bloom, "position", target, 0.86).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(bloom, "scale", Vector2(0.30, 0.30), 0.86).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(bloom, "modulate:a", 0.0, 0.72).set_delay(0.14)
	tween.finished.connect(bloom.queue_free)

func _pulse_memory_archive(node: Variant) -> void:
	if node == null or not is_instance_valid(node):
		return
	var archive: Node2D = node
	var tween := create_tween()
	tween.tween_property(archive, "scale", Vector2(1.08, 1.08), 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(archive, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	var result := await AIWorkflowManager.save_memory_answer(String(mem.get("memory_id", "")), text)
	if not bool(result.get("ok", false)):
		_show_toast(_result_error_message(result, "回答保存失败。"))
		return
	mem["answer"] = text
	mem["state"] = "grown"
	# 跨成员互动计数（回答别人上传的记忆）→ 升温则刷新分季背景。
	var bumped := MemoryManager.register_cross_member_answer(String(mem.get("memory_id", "")), MemoryManager.selected_role_key)
	_close_active_panel()
	if mode == "garden":
		_pulse_memory_archive(mem.get("node"))
	else:
		_grow_memory_node(mem.get("node"))
	if bumped:
		_update_season_overlay()
		var season_message := "记忆开花了 · 花园更繁茂了（%s）" % _season_cn(MemoryManager.garden_season())
		if bool(result.get("sync_pending", false)):
			season_message += " · 联网后自动同步"
		_show_toast(season_message)
	else:
		_show_toast("记忆开花了。已保存在本机，联网后会自动同步。" if bool(result.get("sync_pending", false)) else "记忆开花了。")
	if MemoryManager.maybe_recompute_family_portrait():  # 参与成员变化 → 重画家庭画像木牌
		_render_family_portrait()

func _season_cn(season: String) -> String:
	match season:
		"autumn": return "秋"
		"summer": return "夏"
		_: return "春"

# 生长动画：花苞 → 开放（≤3 秒）。占位单贴图用缩放近似 seed→bud→bloom。
func _grow_memory_node(node: Variant, target_scale: Vector2 = Vector2.ONE) -> void:
	if node == null or not is_instance_valid(node):
		return
	var n: Node2D = node
	if n.has_node("DemoTag"):
		var tag := n.get_node("DemoTag") as Label
		tag.text = "已确认"
	NodeFactory.apply_memory_state(n, "grown")
	n.scale = target_scale * 0.25
	var t := create_tween()
	t.tween_property(n, "scale", target_scale * 0.7, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "scale", target_scale, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	save_current_progress()
	_close_active_panel()
	_clear_map_ui()
	_clear_gate4_guide()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	mode = "global_map"
	_current_spawn_key = "default"
	_current_room_id = ""
	_set_hud_context(mode)
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
	if target == "house":
		_show_house_destination_panel()
		return
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
	_current_spawn_key = "default"
	_current_room_id = ""
	_set_hud_context(mode)
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
	save_current_progress()
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
			_show_house_destination_panel()
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
	save_current_progress()
	_close_active_panel()
	_clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	_clear_gate4_guide()
	mode = "fishpond"
	_current_spawn_key = spawn_key
	_current_room_id = ""
	_set_hud_context(mode)
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
	_scale_fishpond_player_visual()
	_spawn_demo_bottles()
	_register_scene_message_bottle(pond_area)
	_register_pond_fishing_spot(pond_area)
	# 旧版鱼塘记忆花迁移到主花园；鱼塘只保留漂流瓶与钓鱼交互。
	var migrated_memories := MemoryManager.migrate_fishpond_memories_to_garden()
	_fishpond_memories.clear()
	ScenePortal.build_portals("fishpond", world, _on_portal_travel)
	_show_gate4_scene_guide("fishpond")
	print("[SceneManager] fishpond bottles=", _demo_bottles.size(), " 已迁移主花园记忆=", migrated_memories)

func _scale_fishpond_player_visual() -> void:
	if player == null or not is_instance_valid(player):
		return
	var sprite := player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.scale *= FISHPOND_PLAYER_VISUAL_SCALE
	var shadow := player.get_node_or_null("Shadow") as Sprite2D
	if shadow != null:
		shadow.scale *= 1.15
	var name_label := player.get_node_or_null("NameLabel") as Label
	if name_label != null:
		name_label.position.y = -84.0

const SCENE_BOTTLE_QUESTION := "如果这个漂流瓶能带来爸爸的一句话，你希望里面写着什么？"
const FISHING_RESULTS := [
	{"id": "goldfish", "item_id": "fish_goldfish", "title": "金鱼", "body": "一尾闪闪发亮的金鱼，已经放进背包。", "asset": "fishing_goldfish", "color": Color(0.96, 0.58, 0.18, 1.0)},
	{"id": "bottle", "title": "漂流瓶", "body": "瓶中的纸条写着：今天的风很好，希望你那里也是。", "asset": "fishing_bottle", "color": Color(0.28, 0.54, 0.72, 1.0)},
	{"id": "branch", "title": "树枝", "body": "只是一根被水冲来的树枝，再试一次吧。", "asset": "fishing_branch", "color": Color(0.45, 0.30, 0.16, 1.0)},
]

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
	# 第二章第一次有效拉竿必定带回漂流瓶，避免主线被随机结果卡住。
	if StoryManager != null and not StoryManager.is_task_done("first_bottle"):
		return FISHING_RESULTS[1]
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
	if StoryManager != null and StoryManager.has_method("record_fishing_result"):
		StoryManager.record_fishing_result(result_id)
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
	_demo_bottles.append({"id": bid, "question": "河流送来一张远方的纸条。", "state": "opened", "answer": "今天的风很好，希望你那里也是。", "node": null})
	if StoryManager != null and StoryManager.has_method("record_fishing_result"):
		StoryManager.record_fishing_result("bottle_opened")
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
		var status := _make_status_label(panel, Vector2(34, 294), Vector2(492, 22), "保存后，主花园会收下一朵新的记忆花。")
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
		ans_title.text = "你的回答已经收进主花园"
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
	if text.length() > 2000:
		_set_status(status, "回答不能超过 2000 个字符。", true)
		return
	_set_button_busy(button, "正在保存...")
	_set_status(status, "正在把回答保存到主花园...")
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
		var bottle_message := "这只漂流瓶已经保存过回答。" if bool(result.get("duplicate", false)) else "漂流瓶回答已保存。"
		if bool(result.get("sync_pending", false)):
			bottle_message += " 已保存在本机，联网后会自动同步。"
		_show_toast(bottle_message)
		return
	var moderation := await AIClient.moderate_user_content([text], "bottle_answer")
	if String(moderation.get("state", "")) != AIClient.STATE_SUCCESS:
		_set_button_ready(button, "重试回答")
		var moderation_message := String(moderation.get("error", {}).get("message", "内容暂时无法通过安全检查。"))
		_set_status(status, moderation_message, true)
		_show_toast(moderation_message)
		return
	b["answer"] = text
	b["state"] = "opened"
	_close_active_panel()
	# 漂流瓶只产生主花园记忆；池塘场景不再实例化记忆花。
	var card := {"title": "鱼塘的回忆", "description": text, "memory_type": "father",
		"suggested_scene": "garden", "question": String(b.get("question", "")),
		"node_type": "memory_flower", "confidence": 1.0, "guess": "与爸爸有关的记忆"}
	var mem := MemoryManager.create_memory(card, "bottle")
	MemoryManager.create_node(String(mem.get("id", "")), "garden", "memory_flower", "garden_archive_flowers")
	MemoryManager.answer_memory(String(mem.get("id", "")), text)
	_show_toast("漂流瓶回答已收进主花园的记忆花园。")

func _clear_world() -> void:
	pond_fishing_available = false
	_hide_pond_fishing_prompt()
	var garden_builder := get_node_or_null("/root/GardenBuildManager")
	if garden_builder != null and garden_builder.has_method("teardown"):
		garden_builder.call("teardown")
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
	# 主花园不能再由“文件是否存在”隐式决定，否则搭档提交一个试验场景就会替换正式入口。
	# TileMap 版本继续完整保留；未来完成坐标、碰撞与交互验收后，只需显式切换此开关。
	if USE_GARDEN_TILED_AS_MAIN and ResourceLoader.exists(GARDEN_TILED_SCENE):
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
	# 新主花园背景已经包含建筑与邮箱，场景层只补交互热点，避免重复叠图。
	_add_invisible_hotspot("family_tree", Vector2(520, 320), Vector2(180, 130), "tree", "家庭树")
	_add_mailbox_hotspot(Vector2(232, 172), Vector2(80, 80))
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

func _add_invisible_hotspot(node_name: String, pos: Vector2, hotspot_size: Vector2, action: String, label_text: String) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.position = pos
	root.z_index = int(pos.y)
	world.add_child(root)
	_add_click_area(root, hotspot_size, action, label_text)
	return root

func _add_npcs() -> void:
	var selected_id := CharacterDB.resolve(MemoryManager.selected_role_key) if CharacterDB != null else MemoryManager.selected_role_key
	for role_data in CHARACTER_DATA:
		var role_key := str(role_data.get("role", ""))
		var role_id := CharacterDB.resolve(role_key) if CharacterDB != null else role_key
		if role_id == selected_id:
			continue
		var npc_name := str(role_data.get("default_name", role_data.get("label", "Family")))
		var npc_pos: Vector2 = role_data.get("npc_pos", Vector2(720, 420))
		var npc_asset_key := str(role_data.get("asset", "girl"))
		var npc_def: Dictionary = CharacterDB.get_def(npc_asset_key)
		var npc_frame_rects: Array = npc_def.get("frame_rects", [])
		var npc_scale := float(npc_def.get("scale", -1.0))
		var npc_hframes := maxi(1, int(npc_def.get("hframes", 3)))
		var npc_vframes := maxi(1, int(npc_def.get("vframes", 4)))
		var npc_texture_path := _character_texture_path(npc_asset_key, str(ASSETS.get(npc_asset_key, "")))
		var npc_body := _create_character(npc_name, npc_texture_path, npc_pos, false, npc_hframes, npc_vframes, npc_frame_rects, npc_scale)
		npc_body.name = "NPC_" + role_key
		npc_body.set_script(preload("res://scripts/npc_wander.gd"))
		npc_body.set_meta("sprite_hframes", npc_hframes)
		npc_body.set_meta("sprite_vframes", npc_vframes)
		npc_body.set("home_position", npc_pos)
		npc_body.set("wander_radius", float(role_data.get("wander_radius", 80.0)))
		npc_body.set("move_speed", 34.0)
		npc_body.set("walk_bounds", Rect2(Vector2(35, 100), Vector2(1210, 560)))
		# 这两个 setter 不依赖 _ready，立即注入可避免 NPC 第一帧仍按 1×1 网格取帧。
		npc_body.call("set_blocked_rects", _get_character_blocked_rects())
		npc_body.call("set_frame_rects", npc_frame_rects)
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
	return Rect2(Vector2(90, 305), Vector2(1100, 330))

func _get_animal_blocked_rects() -> Array:
	return [
		Rect2(Vector2(0, 0), Vector2(1280, 275)),
		Rect2(Vector2(0, 650), Vector2(1280, 70)),
		Rect2(Vector2(0, 235), Vector2(88, 445)),
		Rect2(Vector2(1192, 235), Vector2(88, 445)),
	]

func _get_character_blocked_rects() -> Array:
	return [
		Rect2(Vector2(0, 0), Vector2(1280, 260)),
		Rect2(Vector2(0, 670), Vector2(1280, 50)),
		Rect2(Vector2(0, 245), Vector2(74, 425)),
		Rect2(Vector2(1206, 245), Vector2(74, 425)),
	]

func _add_collision_zones() -> void:
	# 与新主花园背景对齐：上方住宅、四周树篱不可走，中部草坪留给 DIY。
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
	# 向栅栏方向开放额外两行 32px 网格；首个完整可画格由 y=320 提前到 y=256。
	var build_area := Rect2(Vector2(80, 236), Vector2(1120, 400))
	builder.call("setup", world, ui_layer, player, build_area, _get_garden_build_blocked_rects())

func _get_garden_build_blocked_rects() -> Array:
	return [
		Rect2(Vector2(0, 0), Vector2(1280, 250)),
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
	var asset_key := _current_player_asset_key()
	var display_name := MemoryManager.player_display_name if MemoryManager.player_display_name != "" else _default_name_for_role(MemoryManager.selected_role_key)
	# 角色贴图网格(hframes/vframes)以 CharacterDB/characters.json 为准,
	# 不同角色的行数可能不一样(如 girl 现在是 3x5,多一行待机眨眼帧)。
	var char_def: Dictionary = CharacterDB.get_def(asset_key)
	var char_hframes: int = int(char_def.get("hframes", 3))
	var char_vframes: int = int(char_def.get("vframes", 4))
	var player_texture_path := _character_texture_path(asset_key, str(ASSETS.get(asset_key, "")))
	player = _create_character(display_name, player_texture_path, pos, true, char_hframes, char_vframes)
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
			# 等)逐帧切 region_rect,这里只摆一个初始的"朝下站立"帧(中间列,与 player.gd 的
			# IDLE_FRAME_INDEX=1 约定一致)。
			sprite.region_enabled = true
			sprite.hframes = 1
			sprite.vframes = 1
			sprite.frame = 0
			var r0 = frame_rects[1] if frame_rects.size() > 1 else frame_rects[0]   # 中间列=站立帧
			if r0 is Array and r0.size() >= 4:
				sprite.region_rect = Rect2(float(r0[0]), float(r0[1]), float(r0[2]), float(r0[3]))
			sprite.scale = Vector2.ONE * (scale_override if scale_override > 0.0 else 0.46)
			# 精确裁切帧以中心为原点；阴影应落在帧底部的脚底，而不是沿用旧角色的固定 30px。
			shadow.position.y = sprite.region_rect.size.y * sprite.scale.y * 0.5
		else:
			sprite.hframes = hframes
			sprite.vframes = vframes
			sprite.frame = 1   # 第 0 行中间列=站立帧(两脚并拢)
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
	name_label.name = "NameLabel"
	name_label.text = label_text
	# NPC 名字由 npc_wander 按玩家距离淡入，避免花园中央长期堆叠文字。
	name_label.visible = false
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
	dot.visible = false
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

func _show_house_destination_panel() -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay

	var panel := Panel.new()
	panel.position = Vector2(360, 132)
	panel.size = Vector2(560, 456)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title := Label.new()
	title.text = "进入小屋"
	title.position = Vector2(34, 28)
	title.size = Vector2(470, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var body := Label.new()
	body.text = "选择要去的室内区域。"
	body.position = Vector2(36, 72)
	body.size = Vector2(480, 26)
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.38, 0.31, 0.24, 0.9))
	panel.add_child(body)

	var kitchen := _add_panel_button(panel, "厨房", Vector2(40, 118), Vector2(480, 48), "enter_kitchen")
	_apply_button_style(kitchen, true)

	var room_buttons := [
		{"text": "我的房间", "action": "enter_room:player"},
		{"text": "爸爸的房间", "action": "enter_room:father"},
		{"text": "妈妈的房间", "action": "enter_room:mother"},
		{"text": "路易的房间", "action": "enter_room:partner"},
	]
	for i in range(room_buttons.size()):
		var item: Dictionary = room_buttons[i]
		var col := i % 2
		var row := int(i / 2)
		_add_panel_button(
			panel,
			str(item.get("text", "")),
			Vector2(40 + col * 250, 188 + row * 66),
			Vector2(230, 46),
			str(item.get("action", "close"))
		)

	_add_panel_button(panel, "关闭", Vector2(214, 350), Vector2(132, 40), "close")

func _enter_house(id: String, label_text: String) -> void:
	save_current_progress()
	_close_active_panel()
	_clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	_clear_gate4_guide()

	mode = "room"
	_current_spawn_key = "default"
	_current_room_id = id
	_set_hud_context(mode)
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
	panel.position = Vector2(24, 76)
	panel.size = Vector2(278, 184 if is_player else 146)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_room_card_style(panel)
	ui_layer.add_child(panel)

	var accent := ColorRect.new()
	accent.position = Vector2(0, 14)
	accent.size = Vector2(4, 42)
	accent.color = Color(0.63, 0.43, 0.27, 0.92)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent)

	var title := Label.new()
	title.text = room_label
	title.position = Vector2(18, 11)
	title.size = Vector2(242, 27)
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var body := Label.new()
	if is_player:
		var room := MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
		var object_count := 0 if room.is_empty() else MemoryManager.get_room_objects(String(room.get("id", ""))).size()
		var generated := "AI 布局已生成 · %d 件物件" % object_count if not room.is_empty() and ROOM_SCENE_GENERATOR.has_scene_schema(room) else "%d 件物件已摆放" % object_count
		body.text = "照片生成可确认的布局草稿\n%s" % ("还没有生成 AI 房间" if room.is_empty() else generated)
	else:
		body.text = "在房间里走走看看，返回花园时会保留当前位置。"
	body.position = Vector2(18, 41)
	body.size = Vector2(242, 43 if is_player else 40)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.36, 0.30, 0.23, 0.90))
	panel.add_child(body)

	var btn_y := 144 if is_player else 94
	if is_player:
		var room_action := "管理 AI 房间" if not MemoryManager.get_room_for_user(MemoryManager.selected_role_key).is_empty() else "照片生成房间"
		var primary := _add_panel_button(panel, room_action, Vector2(18, 92), Vector2(242, 34), "generate_room:" + house_id)
		_apply_button_style(primary, true)
	_add_panel_button(panel, "便签", Vector2(18, btn_y), Vector2(72, 30), "house_note:" + house_id)
	_add_panel_button(panel, "明信片", Vector2(98, btn_y), Vector2(78, 30), "MemoryManager.postcards")
	_add_panel_button(panel, "返回", Vector2(184, btn_y), Vector2(76, 30), "back_garden")

func _apply_room_card_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.94, 0.84, 0.94)
	style.border_color = Color(0.48, 0.33, 0.23, 0.72)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.shadow_color = Color(0.16, 0.10, 0.07, 0.18)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)

# 上传房间照片 → 本地压缩 → 受控上传 → AI 草稿 → 用户确认后布局。
func _on_generate_room(house_id: String) -> void:
	if house_id != "player":
		return
	if not MemoryManager.get_room_for_user(MemoryManager.selected_role_key).is_empty():
		_open_room_management()
		return
	if StoryManager != null and StoryManager.current_chapter() == 3:
		_open_first_room_brief_form()
		return
	_open_room_photo_form()

func _open_first_room_brief_form() -> void:
	_close_active_panel()
	var overlay := _create_modal_overlay()
	active_modal = overlay
	var panel := Panel.new()
	panel.position = Vector2(330, 125)
	panel.size = Vector2(620, 470)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)
	var title := Label.new()
	title.text = "生成第一间记忆房间"
	title.position = Vector2(34, 28)
	title.size = Vector2(550, 36)
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)
	var sources := Label.new()
	sources.text = "可用记忆：花园照片、第一顿料理、河边木桥、第一张明信片、第一朵记忆花"
	sources.position = Vector2(34, 78)
	sources.size = Vector2(550, 54)
	sources.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sources.add_theme_font_size_override("font_size", 14)
	sources.add_theme_color_override("font_color", Color(0.48, 0.39, 0.27, 1.0))
	panel.add_child(sources)
	var prompt := TextEdit.new()
	prompt.placeholder_text = "例如：一个有河边晚风感觉的小厨房，温暖、安静，窗边放着一朵花。"
	prompt.text = "一个有河边晚风感觉的小厨房，温暖、安静，窗边放着一朵花。"
	prompt.position = Vector2(34, 145)
	prompt.size = Vector2(552, 150)
	panel.add_child(prompt)
	var status := _make_status_label(panel, Vector2(34, 310), Vector2(552, 46), "首次生成会使用少量主线记忆，之后仍可继续布置。")
	var generate := Button.new()
	generate.text = "生成房间"
	generate.position = Vector2(215, 382)
	generate.size = Vector2(190, 44)
	_apply_button_style(generate, true)
	generate.pressed.connect(_generate_first_room_from_brief.bind(prompt, generate, status))
	panel.add_child(generate)

func _generate_first_room_from_brief(prompt: TextEdit, button: Button, status: Label) -> void:
	var description := prompt.text.strip_edges()
	if description == "":
		_set_status(status, "先写一句你想要的房间感觉。", true)
		return
	_set_button_busy(button, "正在生成...")
	_set_status(status, "正在把第一段花园生活整理成房间...")
	await get_tree().create_timer(0.45).timeout
	var analysis := AIClient.mock_room_analysis()
	analysis["room_type"] = "kitchen_corner"
	analysis["style"] = "warm_cozy"
	analysis["suggested_room_theme"] = "memory_corner"
	analysis["description"] = description.left(240)
	analysis["objects"] = [
		{"object_type": "desk", "zone": "back_left"},
		{"object_type": "lamp", "zone": "back_right"},
		{"object_type": "photo_wall", "zone": "back_wall"},
		{"object_type": "plant", "zone": "right_side"},
		{"object_type": "chair", "zone": "front_left"},
	]
	var room := RoomLayoutManager.generate(analysis, "first_memory_flower", "story:first_room", {
		"source": "mock",
		"provider": "story_memory",
		"model": "first-room-layout",
		"prompt_version": "chapter3-v1",
		"memory_sources": ["garden_photo", "first_dish", "bridge_place", "first_postcard", "first_memory_flower"],
	})
	if room.is_empty():
		_set_button_ready(button, "重新生成")
		_set_status(status, "房间布局没有生成成功，请再试一次。", true)
		return
	_close_active_panel()
	_enter_house("player", "我的房间")
	_show_toast("第一间记忆房间已经生成，可以继续移动和摆放物件。")

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
	MemoryManager.delete_room(String(room.get("id", "")))
	if source_id != "":
		MemoryManager.delete_memory(source_id)
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
	panel.position = Vector2(250, 64)
	panel.size = Vector2(780, 592)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)
	var analysis: Dictionary = draft.get("analysis", {})

	var title := Label.new()
	title.name = "RoomDraftTitle"
	title.text = "语义房间预览" + (" · 示例回退布局" if bool(draft.get("used_fallback", false)) else "")
	title.position = Vector2(34, 24)
	title.size = Vector2(666, 34)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.25, 0.20, 0.14, 1.0))
	panel.add_child(title)

	var description_card := Panel.new()
	description_card.name = "RoomDraftDescriptionCard"
	description_card.position = Vector2(34, 72)
	description_card.size = Vector2(712, 84)
	description_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var description_style := StyleBoxFlat.new()
	description_style.bg_color = Color(1.0, 0.92, 0.72, 0.42)
	description_style.border_color = Color(0.72, 0.52, 0.30, 0.42)
	description_style.set_border_width_all(1)
	description_style.set_corner_radius_all(9)
	description_card.add_theme_stylebox_override("panel", description_style)
	panel.add_child(description_card)

	var description := Label.new()
	description.name = "RoomDraftDescription"
	description.text = String(analysis.get("description", ""))
	if description.text.strip_edges() == "":
		description.text = "AI 已完成房间结构识别，请检查下方的家具与摆放区域。"
	description.position = Vector2(16, 12)
	description.size = Vector2(680, 60)
	description.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	description.max_lines_visible = 3
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", Color(0.33, 0.27, 0.20, 0.94))
	description_card.add_child(description)

	var layout: Dictionary = draft.get("layout", {})
	var layout_objects: Array = layout.get("objects", [])
	var object_lines: Array[String] = []
	for object in layout_objects:
		object_lines.append("• %s → %s" % [_room_object_display_label(String(object.get("object_type", ""))), _zone_display_label(String(object.get("zone", "")))])
	if object_lines.is_empty():
		object_lines.append("没有可安全摆放的家具。")

	_add_room_preview_map(panel, Vector2(34, 176), Vector2(414, 246), layout_objects, layout.get("scene_schema", {}))

	var objects_card := Panel.new()
	objects_card.name = "RoomDraftObjectCard"
	objects_card.position = Vector2(466, 176)
	objects_card.size = Vector2(280, 246)
	objects_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var objects_style := StyleBoxFlat.new()
	objects_style.bg_color = Color(1.0, 0.96, 0.84, 0.76)
	objects_style.border_color = Color(0.61, 0.45, 0.28, 0.48)
	objects_style.set_border_width_all(1)
	objects_style.set_corner_radius_all(9)
	objects_card.add_theme_stylebox_override("panel", objects_style)
	panel.add_child(objects_card)

	var objects_title := Label.new()
	objects_title.text = "家具清单 · %d 件" % layout_objects.size()
	objects_title.position = Vector2(16, 13)
	objects_title.size = Vector2(248, 26)
	objects_title.add_theme_font_size_override("font_size", 15)
	objects_title.add_theme_color_override("font_color", Color(0.31, 0.24, 0.17, 1.0))
	objects_card.add_child(objects_title)

	var objects_scroll := ScrollContainer.new()
	objects_scroll.name = "RoomDraftObjectScroll"
	objects_scroll.position = Vector2(12, 48)
	objects_scroll.size = Vector2(256, 184)
	objects_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	objects_card.add_child(objects_scroll)

	var objects_list := VBoxContainer.new()
	objects_list.name = "RoomDraftObjectList"
	objects_list.custom_minimum_size = Vector2(236, 0)
	objects_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objects_list.add_theme_constant_override("separation", 8)
	objects_scroll.add_child(objects_list)
	for line in object_lines:
		var object_label := Label.new()
		object_label.text = line
		object_label.custom_minimum_size = Vector2(232, 26)
		object_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		object_label.add_theme_font_size_override("font_size", 14)
		object_label.add_theme_color_override("font_color", Color(0.32, 0.26, 0.19, 0.94))
		objects_list.add_child(object_label)

	var meta: Dictionary = draft.get("generation_meta", {})
	var ai_badge := Panel.new()
	ai_badge.name = "RoomDraftAIBadge"
	ai_badge.position = Vector2(34, 440)
	ai_badge.size = Vector2(712, 38)
	ai_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.82, 0.90, 0.68, 0.36)
	badge_style.border_color = Color(0.45, 0.58, 0.34, 0.48)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(8)
	ai_badge.add_theme_stylebox_override("panel", badge_style)
	panel.add_child(ai_badge)

	var attribution := Label.new()
	attribution.name = "RoomDraftAIAttribution"
	attribution.text = "由 %s 生成" % _room_ai_display_label(meta)
	attribution.position = Vector2(14, 8)
	attribution.size = Vector2(330, 22)
	attribution.add_theme_font_size_override("font_size", 12)
	attribution.add_theme_color_override("font_color", Color(0.27, 0.40, 0.23, 0.96))
	ai_badge.add_child(attribution)

	var safety_hint := Label.new()
	safety_hint.text = "家具坐标由游戏安全布局生成"
	safety_hint.position = Vector2(356, 8)
	safety_hint.size = Vector2(340, 22)
	safety_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	safety_hint.add_theme_font_size_override("font_size", 12)
	safety_hint.add_theme_color_override("font_color", Color(0.38, 0.34, 0.27, 0.80))
	ai_badge.add_child(safety_hint)

	var status := _make_status_label(panel, Vector2(34, 492), Vector2(712, 28), "这是预览草稿；确认后才会创建或替换可探索的语义房间。")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cancel := Button.new()
	cancel.text = "放弃草稿"
	cancel.position = Vector2(166, 532)
	cancel.size = Vector2(190, 42)
	_apply_button_style(cancel, false)
	cancel.pressed.connect(_discard_draft_and_close.bind(draft))
	panel.add_child(cancel)
	var confirm := Button.new()
	confirm.text = "确认布局"
	confirm.position = Vector2(424, 532)
	confirm.size = Vector2(190, 42)
	_apply_button_style(confirm, true)
	confirm.pressed.connect(_commit_room_preview.bind(draft, confirm, status))
	panel.add_child(confirm)

func _room_ai_display_label(meta: Dictionary) -> String:
	var model := String(meta.get("model", "")).strip_edges()
	var source := String(meta.get("source", "")).strip_edges().to_lower()
	if source == "mock" or model.to_lower().contains("mock"):
		return "本地模拟 AI"
	match model.to_lower():
		"hy-vision-2.0-instruct":
			return "腾讯混元 HY Vision 2.0"
		"hunyuan-vision":
			return "腾讯混元视觉模型"
		"":
			return "AI"
		_:
			return model

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
	_show_toast("房间生成好了，联网后会自动同步。" if bool(result.get("sync_pending", false)) else "房间生成好了。")

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
	save_current_progress()
	_close_active_panel()
	_clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	mode = "map"
	_current_spawn_key = "default"
	_current_room_id = ""
	_set_hud_context(mode)
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

	var back_btn := Button.new()
	back_btn.text = "返回花园"
	back_btn.position = Vector2(24, 24)
	back_btn.size = Vector2(126, 38)
	back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_style(back_btn, false)
	_set_button_icon(back_btn, "icon_back")
	back_btn.pressed.connect(func() -> void: _show_garden())
	map_ui.add_child(back_btn)

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
	if StoryManager != null and StoryManager.has_method("record_place_and_postcard"):
		StoryManager.record_place_and_postcard(place, postcard)
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
	scene_select.select(0)
	scene_select.disabled = true
	scene_select.tooltip_text = "记忆花统一陈列在主花园"
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
	var saved_message := "记忆已保存到%s%s。" % [("爸爸鱼塘" if scene == "fishpond" else "家庭花园"), link_text]
	if bool(result.get("sync_pending", false)):
		saved_message += " 已保存在本机，联网后会自动同步。"
	_show_toast(saved_message)
	if scene == "garden":
		_pending_memory_arrival_id = String(saved_memory.get("id", ""))
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
		"fish_again":
			return "icon_add"
		"open_caught_bottle":
			return "icon_letter"
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
	elif action == "fish_again":
		_start_fishing_sequence()
	elif action == "open_caught_bottle":
		_open_caught_bottle_content()
	elif action == "back_garden":
		_show_garden()
	elif action == "enter_kitchen":
		_close_active_panel()
		_show_toast("进入厨房…")
		goto_scene("kitchen")
	elif action.begins_with("enter_room:"):
		var house_id := action.split(":")[1]
		var room_info: Dictionary = _get_room_data(house_id)
		_enter_house(house_id, str(room_info.get("label", "房间")))
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
	_chat_panel_list = null   ## 聊天面板随 overlay 一起释放,清引用避免悬空
	_chat_panel_scroll = null
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__familyGardenRemovePhotoInput && window.__familyGardenRemovePhotoInput();", true)

# ---- 供 GameHUD 图标导航接回的 public 包装(转调现有打开逻辑,不重写业务)----
func open_global_map() -> void:
	_show_global_map()

func open_travel_map() -> void:
	_show_travel_map()

func open_memory_creator() -> void:
	_open_memory_creator()

func open_world_chat() -> void:
	_open_world_chat_history_panel()

func open_family_tree() -> void:
	_open_family_tree_panel()

func open_family_members() -> void:
	_open_family_members_panel()

func open_postcards() -> void:
	_open_postcards_panel()

func _set_hud_context(scene_id: String) -> void:
	if game_hud != null and is_instance_valid(game_hud):
		game_hud.set_context(scene_id)
	if day_night_clock_ui != null and is_instance_valid(day_night_clock_ui):
		day_night_clock_ui.visible = scene_id != "" and scene_id != "role_select"

## 打开 HUD 主面板时锁玩家移动(避免面板开着还能 WASD 走位/触发场景交互),关闭时解锁。
## 复用 player.gd 已有的 set_movement_locked(渐隐切场景也用它)。
func set_player_input_locked(locked: bool) -> void:
	if player != null and is_instance_valid(player) and player.has_method("set_movement_locked"):
		player.set_movement_locked(locked)

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
	if info_label == null or not is_instance_valid(info_label):
		return   # UI 尚未构建(如启动早期的任务信号),静默跳过
	info_label.text = "家庭花园   —   " + toast_text

func _safe_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _solid_texture(width: int, height: int, color: Color) -> Texture2D:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
