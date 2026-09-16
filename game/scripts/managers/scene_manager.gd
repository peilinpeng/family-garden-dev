extends Node

## Family Garden 场景/UI 兼容门面（autoload 单例）。
## 持有共享运行状态、生命周期与原有 API；业务实现位于 scripts/scene_runtime/。
## 由 main.gd 在 _ready 里 setup(world, ui_layer) 注入根节点；输入仍在 main.gd 处理。
## 内部模块是本节点的普通子节点，不增加 autoload，也不复制可变状态。

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
	"globalmap_familygarden_sign": "res://assets/globalmap/familygarden.png",
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
const FAMILY_TREE_TEXTURE_PATTERN := "res://assets/garden/family_tree/stage_%d.png"
## 幼苗应低于成年角色，之后逐级长高；最终形态保持原定尺寸。
const FAMILY_TREE_DISPLAY_SCALES := [0.11, 0.115, 0.135, 0.16, 0.19]
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
	{"role": "grandfather", "label": "爷爷（外公）", "default_name": "爷爷", "asset": "grandfather", "house_id": "father", "house_label": "爷爷的小屋", "npc_pos": Vector2(865, 385), "wander_radius": 76.0},
	{"role": "grandmother", "label": "奶奶（外婆）", "default_name": "奶奶", "asset": "grandmother", "house_id": "mother", "house_label": "奶奶的小屋", "npc_pos": Vector2(435, 430), "wander_radius": 76.0},
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
var _demo_memories: Array = []
var _focused_memory_id := ""
var _pending_memory_arrival_id := ""
var _demo_bottles: Array = []
var _fishpond_memories: Array = []
var _room_objects: Array = []
var _travel_lock := false
const GLOBAL_MAP_REGIONS := [
	{"id": "farm", "asset": "globalmap_farm", "label": "农场", "target": "farm"},
	{"id": "garden", "asset": "globalmap_garden", "label": "花园", "target": "garden"},
	{"id": "house", "asset": "globalmap_house", "label": "小屋", "target": "house"},
	{"id": "pond", "asset": "globalmap_pond", "label": "鱼塘", "target": "fishpond"},
]
const GLOBAL_MAP_DECORATIONS := [
	{"id": "familygarden_sign", "asset": "globalmap_familygarden_sign"},
]
const SCENE_BOTTLE_QUESTION := "如果这个漂流瓶能带来爸爸的一句话，你希望里面写着什么？"
const FISHING_RESULTS := [
	{"id": "goldfish", "item_id": "fish_goldfish", "title": "金鱼", "body": "一尾闪闪发亮的金鱼，已经放进背包。", "asset": "fishing_goldfish", "color": Color(0.96, 0.58, 0.18, 1.0)},
	{"id": "bottle", "title": "漂流瓶", "body": "瓶中的纸条写着：今天的风很好，希望你那里也是。", "asset": "fishing_bottle", "color": Color(0.28, 0.54, 0.72, 1.0)},
	{"id": "branch", "title": "树枝", "body": "只是一根被水冲来的树枝，再试一次吧。", "asset": "fishing_branch", "color": Color(0.45, 0.30, 0.16, 1.0)},
]

const SCENE_UI_CONTROLLER_SCRIPT := preload("res://scripts/scene_runtime/scene_ui_controller.gd")
const WORLD_CHAT_CONTROLLER_SCRIPT := preload("res://scripts/scene_runtime/world_chat_controller.gd")
const GARDEN_SCENE_CONTROLLER_SCRIPT := preload("res://scripts/scene_runtime/garden_scene_controller.gd")
const MEMORY_SCENE_CONTROLLER_SCRIPT := preload("res://scripts/scene_runtime/memory_scene_controller.gd")
const SCENE_NAVIGATION_CONTROLLER_SCRIPT := preload("res://scripts/scene_runtime/scene_navigation_controller.gd")
const FISHPOND_SCENE_CONTROLLER_SCRIPT := preload("res://scripts/scene_runtime/fishpond_scene_controller.gd")
const ROOM_SCENE_CONTROLLER_SCRIPT := preload("res://scripts/scene_runtime/room_scene_controller.gd")
const TRAVEL_SCENE_CONTROLLER_SCRIPT := preload("res://scripts/scene_runtime/travel_scene_controller.gd")
const FAMILY_SOCIAL_CONTROLLER_SCRIPT := preload("res://scripts/scene_runtime/family_social_controller.gd")

var _scene_ui_controller: Node = null
var _world_chat_controller: Node = null
var _garden_scene_controller: Node = null
var _memory_scene_controller: Node = null
var _scene_navigation_controller: Node = null
var _fishpond_scene_controller: Node = null
var _room_scene_controller: Node = null
var _travel_scene_controller: Node = null
var _family_social_controller: Node = null

func _ready() -> void:
	_ensure_runtime_modules()

func _ensure_runtime_modules() -> void:
	if _scene_ui_controller == null:
		_scene_ui_controller = SCENE_UI_CONTROLLER_SCRIPT.new(self)
		_scene_ui_controller.name = "SceneUiController"
		add_child(_scene_ui_controller)
	if _world_chat_controller == null:
		_world_chat_controller = WORLD_CHAT_CONTROLLER_SCRIPT.new(self)
		_world_chat_controller.name = "WorldChatController"
		add_child(_world_chat_controller)
	if _garden_scene_controller == null:
		_garden_scene_controller = GARDEN_SCENE_CONTROLLER_SCRIPT.new(self)
		_garden_scene_controller.name = "GardenSceneController"
		add_child(_garden_scene_controller)
	if _memory_scene_controller == null:
		_memory_scene_controller = MEMORY_SCENE_CONTROLLER_SCRIPT.new(self)
		_memory_scene_controller.name = "MemorySceneController"
		add_child(_memory_scene_controller)
	if _scene_navigation_controller == null:
		_scene_navigation_controller = SCENE_NAVIGATION_CONTROLLER_SCRIPT.new(self)
		_scene_navigation_controller.name = "SceneNavigationController"
		add_child(_scene_navigation_controller)
	if _fishpond_scene_controller == null:
		_fishpond_scene_controller = FISHPOND_SCENE_CONTROLLER_SCRIPT.new(self)
		_fishpond_scene_controller.name = "FishpondSceneController"
		add_child(_fishpond_scene_controller)
	if _room_scene_controller == null:
		_room_scene_controller = ROOM_SCENE_CONTROLLER_SCRIPT.new(self)
		_room_scene_controller.name = "RoomSceneController"
		add_child(_room_scene_controller)
	if _travel_scene_controller == null:
		_travel_scene_controller = TRAVEL_SCENE_CONTROLLER_SCRIPT.new(self)
		_travel_scene_controller.name = "TravelSceneController"
		add_child(_travel_scene_controller)
	if _family_social_controller == null:
		_family_social_controller = FAMILY_SOCIAL_CONTROLLER_SCRIPT.new(self)
		_family_social_controller.name = "FamilySocialController"
		add_child(_family_social_controller)

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
		"farm_plots", "farm_livestock":
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
	_ensure_runtime_modules()
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
	_ensure_runtime_modules()
	_scene_ui_controller._setup_custom_cursor()

func _build_ui() -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._build_ui()

func _navigation_dock_style() -> StyleBoxFlat:
	_ensure_runtime_modules()
	return _scene_ui_controller._navigation_dock_style()

func _build_orientation_overlay(root: Control) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._build_orientation_overlay(root)

func _update_orientation_overlay() -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._update_orientation_overlay()

func _update_viewport_layout() -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._update_viewport_layout()

func _is_portrait_size(viewport_size: Vector2) -> bool:
	_ensure_runtime_modules()
	return _scene_ui_controller._is_portrait_size(viewport_size)

func _add_button(root: Control, button_text: String, pos: Vector2, button_size: Vector2, action: String) -> Button:
	_ensure_runtime_modules()
	return _scene_ui_controller._add_button(root, button_text, pos, button_size, action)

func _add_world_chat_box(root: Control, pos: Vector2, box_size: Vector2) -> LineEdit:
	_ensure_runtime_modules()
	return _scene_ui_controller._add_world_chat_box(root, pos, box_size)

func _clear_gate4_guide() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._clear_gate4_guide()

func _show_gate4_scene_guide(scene_id: String) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._show_gate4_scene_guide(scene_id)

func _add_garden_guide_title(parent: Control) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_garden_guide_title(parent)

func _add_garden_guide_compact(parent: Control) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_garden_guide_compact(parent)

func _add_garden_beginner_steps(parent: Control) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_garden_beginner_steps(parent)

func _add_family_portrait_compact(parent: Control) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_family_portrait_compact(parent)

func _add_garden_guide_toggle(parent: Control, pos: Vector2, expanded: bool) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_garden_guide_toggle(parent, pos, expanded)

func _toggle_garden_guide() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._toggle_garden_guide()

func _add_garden_guide_inset(parent: Control) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_garden_guide_inset(parent)

func _add_garden_guide_stats(parent: Control) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_garden_guide_stats(parent)

func _apply_guide_card_style(panel: Panel, scene_id: String = "") -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._apply_guide_card_style(panel, scene_id)

func _gate4_guide_accent(scene_id: String) -> Color:
	_ensure_runtime_modules()
	return _garden_scene_controller._gate4_guide_accent(scene_id)

func _gate4_guide_title(scene_id: String) -> String:
	_ensure_runtime_modules()
	return _garden_scene_controller._gate4_guide_title(scene_id)

func _gate4_guide_body(scene_id: String) -> String:
	_ensure_runtime_modules()
	return _garden_scene_controller._gate4_guide_body(scene_id)

func _gate4_guide_footer(scene_id: String) -> String:
	_ensure_runtime_modules()
	return _garden_scene_controller._gate4_guide_footer(scene_id)

func _world_chat_input_style(focused: bool) -> StyleBoxFlat:
	_ensure_runtime_modules()
	return _world_chat_controller._world_chat_input_style(focused)

func _add_world_chat_feed(root: Control, pos: Vector2, feed_size: Vector2) -> Label:
	_ensure_runtime_modules()
	return _world_chat_controller._add_world_chat_feed(root, pos, feed_size)

func _world_chat_preview_style() -> StyleBoxFlat:
	_ensure_runtime_modules()
	return _world_chat_controller._world_chat_preview_style()

func _on_world_chat_preview_input(event: InputEvent) -> void:
	_ensure_runtime_modules()
	_world_chat_controller._on_world_chat_preview_input(event)

func _on_world_chat_submitted(submitted_text: String) -> void:
	_ensure_runtime_modules()
	_world_chat_controller._on_world_chat_submitted(submitted_text)

func _send_world_chat_message(raw_text: String, source_input: LineEdit = null) -> void:
	_ensure_runtime_modules()
	await _world_chat_controller._send_world_chat_message(raw_text, source_input)

func _get_world_chat_author() -> String:
	_ensure_runtime_modules()
	return _world_chat_controller._get_world_chat_author()

func _refresh_world_chat_feed(show_preview: bool = false) -> void:
	_ensure_runtime_modules()
	_world_chat_controller._refresh_world_chat_feed(show_preview)

func _show_world_chat_preview() -> void:
	_ensure_runtime_modules()
	_world_chat_controller._show_world_chat_preview()

func _open_world_chat_history_panel() -> void:
	_ensure_runtime_modules()
	_world_chat_controller._open_world_chat_history_panel()

func _refresh_chat_panel_messages() -> void:
	_ensure_runtime_modules()
	_world_chat_controller._refresh_chat_panel_messages()

func _make_chat_bubble(message: Dictionary) -> Control:
	_ensure_runtime_modules()
	return _world_chat_controller._make_chat_bubble(message)

func _format_world_chat_time(raw_time: String) -> String:
	_ensure_runtime_modules()
	return _world_chat_controller._format_world_chat_time(raw_time)

func _on_ui_button(action: String) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._on_ui_button(action)

func _show_role_select() -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._show_role_select()

func _confirm_character_creation(role_key: String, display_name: String, family_code: String, appearance: Dictionary) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._confirm_character_creation(role_key, display_name, family_code, appearance)

func _show_legacy_role_select() -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._show_legacy_role_select()

func _add_role_card(parent: Control, role_data: Dictionary, pos: Vector2, card_size: Vector2, name_input: LineEdit, family_input: LineEdit) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._add_role_card(parent, role_data, pos, card_size, name_input, family_input)

func _confirm_role_selection(role_key: String, name_input: LineEdit, family_input: LineEdit = null) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._confirm_role_selection(role_key, name_input, family_input)

func _default_name_for_role(role_key: String) -> String:
	_ensure_runtime_modules()
	return _scene_ui_controller._default_name_for_role(role_key)

func _get_role_data(role_key: String) -> Dictionary:
	_ensure_runtime_modules()
	return _scene_ui_controller._get_role_data(role_key)

func _current_player_asset_key() -> String:
	_ensure_runtime_modules()
	return _scene_ui_controller._current_player_asset_key()

func _character_texture_path(role_key: String, fallback_path: String) -> String:
	_ensure_runtime_modules()
	return _scene_ui_controller._character_texture_path(role_key, fallback_path)

func _update_plant_button() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._update_plant_button()

func _show_garden(spawn_key: String = "default") -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._show_garden(spawn_key)

func _demo_other_members() -> Array:
	_ensure_runtime_modules()
	return _memory_scene_controller._demo_other_members()

func _spawn_demo_memory_nodes() -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._spawn_demo_memory_nodes()

func _spawn_demo_memory_link() -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._spawn_demo_memory_link()

func _render_memory_links(scene: String) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._render_memory_links(scene)

func _render_family_portrait() -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._render_family_portrait()

func _add_family_portrait_miniature(parent: Control) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._add_family_portrait_miniature(parent)

func _family_portrait_frame_texture(role_key: String) -> Texture2D:
	_ensure_runtime_modules()
	return _memory_scene_controller._family_portrait_frame_texture(role_key)

func _memory_flower_pos(scene: String, memory_id: String) -> Vector2:
	_ensure_runtime_modules()
	return _memory_scene_controller._memory_flower_pos(scene, memory_id)

func _draw_link_line(a: Vector2, b: Vector2, link: Dictionary) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._draw_link_line(a, b, link)

func _add_memory_link_leaf(pos: Vector2, color: Color, rotation: float, answered: bool) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._add_memory_link_leaf(pos, color, rotation, answered)

func _add_memory_link_bloom(parent: Node2D, pos: Vector2, color: Color) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._add_memory_link_bloom(parent, pos, color)

func _memory_link_color(relation_type: String) -> Color:
	_ensure_runtime_modules()
	return _memory_scene_controller._memory_link_color(relation_type)

func _memory_link_label(relation_type: String) -> String:
	_ensure_runtime_modules()
	return _memory_scene_controller._memory_link_label(relation_type)

func _open_memory_link_panel(link: Dictionary) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._open_memory_link_panel(link)

func _add_memory_link_summary_card(parent: Control, pos: Vector2, card_size: Vector2, heading: String, card: Dictionary) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._add_memory_link_summary_card(parent, pos, card_size, heading, card)

func _open_memory_from_link(memory_id: String) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._open_memory_from_link(memory_id)

func _find_rendered_memory_by_memory_id(memory_id: String) -> Dictionary:
	_ensure_runtime_modules()
	return _memory_scene_controller._find_rendered_memory_by_memory_id(memory_id)

func _save_memory_link_followup(link_id: String, input: TextEdit, button: Button, status: Label) -> void:
	_ensure_runtime_modules()
	await _memory_scene_controller._save_memory_link_followup(link_id, input, button, status)

func _refresh_memory_link_visuals(scene: String) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._refresh_memory_link_visuals(scene)

func _clear_memory_focus() -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._clear_memory_focus()

func _clear_memory_link_nodes() -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._clear_memory_link_nodes()

func _refresh_current_memory_scene(scene: String) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._refresh_current_memory_scene(scene)

func _render_scene_nodes(scene: String, cache: Array, click_cb: Callable) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._render_scene_nodes(scene, cache, click_cb)

func _render_garden_archives(cache: Array) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._render_garden_archives(cache)

func _garden_archive_position(archive_key: String) -> Vector2:
	_ensure_runtime_modules()
	return _memory_scene_controller._garden_archive_position(archive_key)

func _garden_archive_count() -> int:
	_ensure_runtime_modules()
	return _memory_scene_controller._garden_archive_count()

func _add_garden_archive_caption(node: Node2D, archive_key: String, count: int) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._add_garden_archive_caption(node, archive_key, count)

func _add_memory_cluster_badge(node: Node2D, count: int) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._add_memory_cluster_badge(node, count)

func _open_memory_archive(archive_key: String, items: Array) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._open_memory_archive(archive_key, items)

func _populate_memory_archive_list(list: VBoxContainer, empty_label: Label, items: Array, member_select: OptionButton, state_select: OptionButton, archive_key: String = "flowers") -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._populate_memory_archive_list(list, empty_label, items, member_select, state_select, archive_key)

func _archive_filter_bar_style() -> StyleBoxFlat:
	_ensure_runtime_modules()
	return _memory_scene_controller._archive_filter_bar_style()

func _archive_row_style(active: bool) -> StyleBoxFlat:
	_ensure_runtime_modules()
	return _memory_scene_controller._archive_row_style(active)

func _archive_icon_style(archive_key: String) -> StyleBoxFlat:
	_ensure_runtime_modules()
	return _memory_scene_controller._archive_icon_style(archive_key)

func _archive_status_style(active: bool) -> StyleBoxFlat:
	_ensure_runtime_modules()
	return _memory_scene_controller._archive_status_style(active)

func _archive_row_hover_style() -> StyleBoxFlat:
	_ensure_runtime_modules()
	return _memory_scene_controller._archive_row_hover_style()

func _archive_row_pressed_style() -> StyleBoxFlat:
	_ensure_runtime_modules()
	return _memory_scene_controller._archive_row_pressed_style()

func _open_memory_archive_item(item: Dictionary) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._open_memory_archive_item(item)

func _open_memory_cluster(items: Array) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._open_memory_cluster(items)

func _add_memory_tag(node: Node2D, state: String) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._add_memory_tag(node, state)

func _animate_scene_node_arrival(node: Node2D, target_scale: Vector2) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._animate_scene_node_arrival(node, target_scale)

func _play_memory_archive_arrival(memory_id: String) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._play_memory_archive_arrival(memory_id)

func _pulse_memory_archive(node: Variant) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._pulse_memory_archive(node)

func _find_demo_memory(mem_id: String) -> Dictionary:
	_ensure_runtime_modules()
	return _memory_scene_controller._find_demo_memory(mem_id)

func _on_memory_clicked(mem_id: String) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._on_memory_clicked(mem_id)

func _open_memory_card(mem: Dictionary) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._open_memory_card(mem)

func _submit_memory_answer(mem_id: String, input: TextEdit) -> void:
	_ensure_runtime_modules()
	await _memory_scene_controller._submit_memory_answer(mem_id, input)

func _season_cn(season: String) -> String:
	_ensure_runtime_modules()
	return _memory_scene_controller._season_cn(season)

func _grow_memory_node(node: Variant, target_scale: Vector2 = Vector2.ONE) -> void:
	_ensure_runtime_modules()
	_memory_scene_controller._grow_memory_node(node, target_scale)

func _show_global_map() -> void:
	_ensure_runtime_modules()
	_scene_navigation_controller._show_global_map()

func _add_global_map_decoration(view: Control, decoration: Dictionary) -> bool:
	_ensure_runtime_modules()
	return _scene_navigation_controller._add_global_map_decoration(view, decoration)

func _add_global_map_region(view: Control, region: Dictionary) -> bool:
	_ensure_runtime_modules()
	return _scene_navigation_controller._add_global_map_region(view, region)

func _on_global_map_region_hover(button: TextureButton, shadow: TextureRect, hovering: bool) -> void:
	_ensure_runtime_modules()
	_scene_navigation_controller._on_global_map_region_hover(button, shadow, hovering)

func _on_global_map_region_pressed(target: String, label_text: String) -> void:
	_ensure_runtime_modules()
	_scene_navigation_controller._on_global_map_region_pressed(target, label_text)

func _build_embedded_scene(scene_key: String, scene_path: String, title: String, fallback_color: Color, add_player: bool) -> void:
	_ensure_runtime_modules()
	_scene_navigation_controller._build_embedded_scene(scene_key, scene_path, title, fallback_color, add_player)

func goto_scene(target: String, spawn_key: String = "default") -> void:
	_ensure_runtime_modules()
	_scene_navigation_controller.goto_scene(target, spawn_key)

func _on_portal_travel(target: String, spawn_key: String) -> void:
	_ensure_runtime_modules()
	_scene_navigation_controller._on_portal_travel(target, spawn_key)

func _add_scene_background(scene: String, fallback_color: Color) -> void:
	_ensure_runtime_modules()
	_scene_navigation_controller._add_scene_background(scene, fallback_color)

func _build_fishpond(spawn_key: String = "default") -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._build_fishpond(spawn_key)

func _scale_fishpond_player_visual() -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._scale_fishpond_player_visual()

func _spawn_demo_bottles() -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._spawn_demo_bottles()

func _generate_missing_bottles() -> void:
	_ensure_runtime_modules()
	await _fishpond_scene_controller._generate_missing_bottles()

func _render_bottle_record(bottle: Dictionary) -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._render_bottle_record(bottle)

func _register_scene_message_bottle(pond_area: Node2D) -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._register_scene_message_bottle(pond_area)

func _on_scene_message_bottle_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._on_scene_message_bottle_input(_viewport, event, _shape_idx)

func _register_pond_fishing_spot(pond_area: Node2D) -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._register_pond_fishing_spot(pond_area)

func _on_pond_fishing_spot_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._on_pond_fishing_spot_input(_viewport, event, _shape_idx)

func _on_pond_fishing_spot_body_entered(body: Node) -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._on_pond_fishing_spot_body_entered(body)

func _on_pond_fishing_spot_body_exited(body: Node) -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._on_pond_fishing_spot_body_exited(body)

func _show_pond_fishing_prompt() -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._show_pond_fishing_prompt()

func _hide_pond_fishing_prompt() -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._hide_pond_fishing_prompt()

func _start_fishing_sequence() -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._start_fishing_sequence()

func _pick_fishing_result(score: float) -> Dictionary:
	_ensure_runtime_modules()
	return _fishpond_scene_controller._pick_fishing_result(score)

func _open_fishing_failed_panel() -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._open_fishing_failed_panel()

func _open_fishing_result_panel(result: Dictionary = {}) -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._open_fishing_result_panel(result)

func _award_fishing_result(result: Dictionary) -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._award_fishing_result(result)

func _open_caught_bottle_content() -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._open_caught_bottle_content()

func _find_demo_bottle(bid: String) -> Dictionary:
	_ensure_runtime_modules()
	return _fishpond_scene_controller._find_demo_bottle(bid)

func _on_bottle_clicked(bid: String) -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._on_bottle_clicked(bid)

func _open_bottle_panel(b: Dictionary) -> void:
	_ensure_runtime_modules()
	_fishpond_scene_controller._open_bottle_panel(b)

func _submit_bottle_answer(bid: String, input: TextEdit, button: Button, status: Label) -> void:
	_ensure_runtime_modules()
	await _fishpond_scene_controller._submit_bottle_answer(bid, input, button, status)

func _clear_world() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._clear_world()

func _clear_map_ui() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._clear_map_ui()

func _clear_global_map_ui() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._clear_global_map_ui()

func _add_background() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_background()

func _add_season_overlay() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_season_overlay()

func _update_season_overlay() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._update_season_overlay()

func _season_overlay_color(season: String) -> Color:
	_ensure_runtime_modules()
	return _garden_scene_controller._season_overlay_color(season)

func _add_garden_spawn_markers() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_garden_spawn_markers()

func _add_core_objects() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_core_objects()

func _add_mailbox_hotspot(pos: Vector2, hotspot_size: Vector2) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_mailbox_hotspot(pos, hotspot_size)

func _on_mailbox_alert_changed(_state: String) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._on_mailbox_alert_changed(_state)

func _render_mailbox_badge() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._render_mailbox_badge()

func _on_mailbox_hotspot_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._on_mailbox_hotspot_input(_viewport, event, _shape_idx)

func _add_message_board_hotspot(pos: Vector2, hotspot_size: Vector2) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_message_board_hotspot(pos, hotspot_size)

func _on_message_board_hotspot_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._on_message_board_hotspot_input(_viewport, event, _shape_idx)

func _add_houses() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_houses()

func _add_invisible_hotspot(node_name: String, pos: Vector2, hotspot_size: Vector2, action: String, label_text: String) -> Node2D:
	_ensure_runtime_modules()
	return _garden_scene_controller._add_invisible_hotspot(node_name, pos, hotspot_size, action, label_text)

func _add_animals() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_animals()

func _get_animal_bounds() -> Rect2:
	_ensure_runtime_modules()
	return _garden_scene_controller._get_animal_bounds()

func _get_animal_blocked_rects() -> Array:
	_ensure_runtime_modules()
	return _garden_scene_controller._get_animal_blocked_rects()

func _get_character_blocked_rects() -> Array:
	_ensure_runtime_modules()
	return _garden_scene_controller._get_character_blocked_rects()

func _add_collision_zones() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_collision_zones()

func _setup_garden_builder() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._setup_garden_builder()

func _get_garden_build_blocked_rects() -> Array:
	_ensure_runtime_modules()
	return _garden_scene_controller._get_garden_build_blocked_rects()

func _add_collision_rect(body_name: String, center: Vector2, size: Vector2) -> StaticBody2D:
	_ensure_runtime_modules()
	return _garden_scene_controller._add_collision_rect(body_name, center, size)

func _add_player(pos: Vector2, parent_override: Node = null) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_player(pos, parent_override)

func _create_character(label_text: String, path: String, pos: Vector2, controllable: bool, hframes: int = 3, vframes: int = 4, frame_rects: Array = [], scale_override: float = -1.0) -> CharacterBody2D:
	_ensure_runtime_modules()
	return _garden_scene_controller._create_character(label_text, path, pos, controllable, hframes, vframes, frame_rects, scale_override)

func _add_online_status_badge(parent: Node2D, online: bool) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_online_status_badge(parent, online)

func _add_static_sprite(node_name: String, path: String, pos: Vector2, target_height: float) -> Sprite2D:
	_ensure_runtime_modules()
	return _garden_scene_controller._add_static_sprite(node_name, path, pos, target_height)

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
	_ensure_runtime_modules()
	return _garden_scene_controller._add_interactable_sprite(node_name, path, pos, target_height, action, label_text, click_size, click_offset)

func _add_click_area(parent: Node2D, area_size: Vector2, action: String, label_text: String, offset: Vector2 = Vector2.ZERO) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_click_area(parent, area_size, action, label_text, offset)

func _on_interactable_input(_viewport: Node, event: InputEvent, _shape_idx: int, action: String, label_text: String) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._on_interactable_input(_viewport, event, _shape_idx, action, label_text)

func _handle_action(action: String, label_text: String) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._handle_action(action, label_text)

func _show_house_destination_panel() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._show_house_destination_panel()

func _enter_house(id: String, label_text: String) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._enter_house(id, label_text)

func _get_room_data(house_id: String) -> Dictionary:
	_ensure_runtime_modules()
	return _room_scene_controller._get_room_data(house_id)

func _add_room_background(asset_key: String) -> Rect2:
	_ensure_runtime_modules()
	return _room_scene_controller._add_room_background(asset_key)

func _add_room_foreground_if_exists(foreground_asset_key: String, room_rect: Rect2) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._add_room_foreground_if_exists(foreground_asset_key, room_rect)

func _add_room_hint_panel(room_label: String, house_id: String) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._add_room_hint_panel(room_label, house_id)

func _apply_room_card_style(panel: Panel) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._apply_room_card_style(panel)

func _on_generate_room(house_id: String) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._on_generate_room(house_id)

func _open_first_room_brief_form() -> void:
	_ensure_runtime_modules()
	_room_scene_controller._open_first_room_brief_form()

func _generate_first_room_from_brief(prompt: TextEdit, button: Button, status: Label) -> void:
	_ensure_runtime_modules()
	await _room_scene_controller._generate_first_room_from_brief(prompt, button, status)

func _open_room_management() -> void:
	_ensure_runtime_modules()
	_room_scene_controller._open_room_management()

func _delete_current_ai_room(button: Button, status: Label) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._delete_current_ai_room(button, status)

func _open_room_photo_form() -> void:
	_ensure_runtime_modules()
	_room_scene_controller._open_room_photo_form()

func _analyze_selected_room_photo(button: Button, status: Label) -> void:
	_ensure_runtime_modules()
	await _room_scene_controller._analyze_selected_room_photo(button, status)

func _open_room_draft_preview(draft: Dictionary) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._open_room_draft_preview(draft)

func _room_ai_display_label(meta: Dictionary) -> String:
	_ensure_runtime_modules()
	return _room_scene_controller._room_ai_display_label(meta)

func _add_room_preview_map(parent: Control, pos: Vector2, map_size: Vector2, objects: Array, schema: Dictionary = {}) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._add_room_preview_map(parent, pos, map_size, objects, schema)

func _add_room_schema_preview(map: Control, map_size: Vector2, schema: Dictionary) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._add_room_schema_preview(map, map_size, schema)

func _room_preview_color(object_id: String) -> Color:
	_ensure_runtime_modules()
	return _room_scene_controller._room_preview_color(object_id)

func _room_object_display_label(object_type: String) -> String:
	_ensure_runtime_modules()
	return _room_scene_controller._room_object_display_label(object_type)

func _room_theme_display_label(theme_key: String) -> String:
	_ensure_runtime_modules()
	return _room_scene_controller._room_theme_display_label(theme_key)

func _room_style_display_label(style_key: String) -> String:
	_ensure_runtime_modules()
	return _room_scene_controller._room_style_display_label(style_key)

func _zone_display_label(zone: String) -> String:
	_ensure_runtime_modules()
	return _room_scene_controller._zone_display_label(zone)

func _commit_room_preview(draft: Dictionary, button: Button, status: Label) -> void:
	_ensure_runtime_modules()
	await _room_scene_controller._commit_room_preview(draft, button, status)

func _render_room(house_id: String) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._render_room(house_id)

func _on_room_object_clicked(obj_id: String) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._on_room_object_clicked(obj_id)

func _open_room_object_editor(object: Dictionary) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._open_room_object_editor(object)

func _move_room_object(object_id: String, zone_select: OptionButton, button: Button, status: Label) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._move_room_object(object_id, zone_select, button, status)

func _delete_room_object(object_id: String, button: Button, status: Label) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._delete_room_object(object_id, button, status)

func _add_room_collision_zones(room_id: String, room_rect: Rect2) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._add_room_collision_zones(room_id, room_rect)

func _add_room_outer_boundaries(room_rect: Rect2) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._add_room_outer_boundaries(room_rect)

func _add_room_block(room_rect: Rect2, block_name: String, normalized_rect: Rect2) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._add_room_block(room_rect, block_name, normalized_rect)

func _remove_room_card_and_back(card: Panel) -> void:
	_ensure_runtime_modules()
	_room_scene_controller._remove_room_card_and_back(card)

func _show_travel_map() -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._show_travel_map()

func _add_travel_map_background() -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._add_travel_map_background()

func _build_map_ui() -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._build_map_ui()

func _start_add_place() -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._start_add_place()

func _open_add_place_form(pos: Vector2) -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._open_add_place_form(pos)

func _save_new_place(title_input: LineEdit, note_input: TextEdit) -> void:
	_ensure_runtime_modules()
	await _travel_scene_controller._save_new_place(title_input, note_input)

func _rebuild_travel_pins() -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._rebuild_travel_pins()

func _add_travel_pin(place: Dictionary) -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._add_travel_pin(place)

func _open_postcard_for_place(place_id: String) -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._open_postcard_for_place(place_id)

func _choose_photo_for_place() -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._choose_photo_for_place()

func _selected_gate4_photo() -> Dictionary:
	_ensure_runtime_modules()
	return _travel_scene_controller._selected_gate4_photo()

func _open_memory_creator(preserve_selection: bool = false, initial_text: String = "") -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._open_memory_creator(preserve_selection, initial_text)

func _generate_memory_draft(text_input: TextEdit, button: Button, status: Label) -> void:
	_ensure_runtime_modules()
	await _travel_scene_controller._generate_memory_draft(text_input, button, status)

func _open_memory_draft_preview(draft: Dictionary) -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._open_memory_draft_preview(draft)

func _commit_memory_preview(draft: Dictionary, original_card: Dictionary, title_input: LineEdit, description_input: TextEdit, question_input: TextEdit, scene_select: OptionButton, button: Button, status: Label) -> void:
	_ensure_runtime_modules()
	await _travel_scene_controller._commit_memory_preview(draft, original_card, title_input, description_input, question_input, scene_select, button, status)

func _on_place_photo_selected(path: String) -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._on_place_photo_selected(path)

func _setup_web_photo_bridge() -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._setup_web_photo_bridge()

func _choose_photo_for_place_web() -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._choose_photo_for_place_web()

func _on_web_photo_selected(args: Array) -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._on_web_photo_selected(args)

func _reset_selected_photo_state() -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._reset_selected_photo_state()

func _content_type_for_filename(file_name: String) -> String:
	_ensure_runtime_modules()
	return _travel_scene_controller._content_type_for_filename(file_name)

func _open_postcard_detail_panel(title_text: String, message: String, photo_path: String, place_id: String) -> void:
	_ensure_runtime_modules()
	_travel_scene_controller._open_postcard_detail_panel(title_text, message, photo_path, place_id)

func _load_photo_into_rect(photo_reference: String, photo_rect: TextureRect, photo_status: Label) -> void:
	_ensure_runtime_modules()
	await _travel_scene_controller._load_photo_into_rect(photo_reference, photo_rect, photo_status)

func _resolve_photo_url(photo_reference: String) -> String:
	_ensure_runtime_modules()
	return await _travel_scene_controller._resolve_photo_url(photo_reference)

func _photo_reference(row: Dictionary) -> String:
	_ensure_runtime_modules()
	return _travel_scene_controller._photo_reference(row)

func _download_photo_texture(url: String) -> Texture2D:
	_ensure_runtime_modules()
	return await _travel_scene_controller._download_photo_texture(url)

func _pin_asset_for_place(place: Dictionary) -> String:
	_ensure_runtime_modules()
	return _travel_scene_controller._pin_asset_for_place(place)

func _delete_place(place_id: String) -> void:
	_ensure_runtime_modules()
	await _travel_scene_controller._delete_place(place_id)

func _open_animal_dialog(animal_id: String, display_name: String) -> void:
	_ensure_runtime_modules()
	_family_social_controller._open_animal_dialog(animal_id, display_name)

func _open_message_board_panel() -> void:
	_ensure_runtime_modules()
	_family_social_controller._open_message_board_panel()

func _open_add_message_form() -> void:
	_ensure_runtime_modules()
	_family_social_controller._open_add_message_form()

func _save_new_message(author_input: LineEdit, message_input: TextEdit) -> void:
	_ensure_runtime_modules()
	await _family_social_controller._save_new_message(author_input, message_input)

func _open_postcards_panel() -> void:
	_ensure_runtime_modules()
	_family_social_controller._open_postcards_panel()

func _open_postcard_detail_from_id(postcard_id: String) -> void:
	_ensure_runtime_modules()
	_family_social_controller._open_postcard_detail_from_id(postcard_id)

func _open_family_tree_panel() -> void:
	_ensure_runtime_modules()
	_family_social_controller._open_family_tree_panel()

func _offer_family_tree_welcome_gift() -> void:
	_ensure_runtime_modules()
	_family_social_controller._offer_family_tree_welcome_gift()

func _begin_family_tree_placement() -> void:
	_ensure_runtime_modules()
	_family_social_controller._begin_family_tree_placement()

func begin_family_tree_placement() -> void:
	_ensure_runtime_modules()
	_family_social_controller.begin_family_tree_placement()

func _open_family_members_panel() -> void:
	_ensure_runtime_modules()
	await _family_social_controller._open_family_members_panel()

func _online_family_members() -> Dictionary:
	_ensure_runtime_modules()
	return _family_social_controller._online_family_members()

func _role_display_name(role_key: String) -> String:
	_ensure_runtime_modules()
	return _family_social_controller._role_display_name(role_key)

func _scene_display_name(scene_id: String) -> String:
	_ensure_runtime_modules()
	return _family_social_controller._scene_display_name(scene_id)

func _open_mailbox_panel() -> void:
	_ensure_runtime_modules()
	await _family_social_controller._open_mailbox_panel()

func _open_npc_dialog(npc_id: String, display_name: String) -> void:
	_ensure_runtime_modules()
	_family_social_controller._open_npc_dialog(npc_id, display_name)

func _show_cozy_panel(panel_title: String, body_text: String, buttons: Array) -> void:
	_ensure_runtime_modules()
	_family_social_controller._show_cozy_panel(panel_title, body_text, buttons)

func _add_panel_close_button(panel: Panel) -> void:
	_ensure_runtime_modules()
	_family_social_controller._add_panel_close_button(panel)

func _create_modal_overlay() -> Control:
	_ensure_runtime_modules()
	return _scene_ui_controller._create_modal_overlay()

func _make_status_label(parent: Control, pos: Vector2, label_size: Vector2, text: String = "") -> Label:
	_ensure_runtime_modules()
	return _scene_ui_controller._make_status_label(parent, pos, label_size, text)

func _set_status(label: Label, text: String, is_error: bool = false) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._set_status(label, text, is_error)

func _set_button_busy(button: Button, busy_text: String) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._set_button_busy(button, busy_text)

func _set_button_ready(button: Button, ready_text: String = "") -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._set_button_ready(button, ready_text)

func _result_error_message(result: Dictionary, fallback: String) -> String:
	_ensure_runtime_modules()
	return _scene_ui_controller._result_error_message(result, fallback)

func _watch_ai_workflow(workflow: String, status_label: Label, initial_text: String) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._watch_ai_workflow(workflow, status_label, initial_text)

func _clear_ai_workflow_watch(status_label: Label = null) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._clear_ai_workflow_watch(status_label)

func _on_ai_workflow_state_changed(workflow: String, state: String, detail: Dictionary) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._on_ai_workflow_state_changed(workflow, state, detail)

func _discard_draft_and_close(draft: Dictionary) -> void:
	_ensure_runtime_modules()
	await _scene_ui_controller._discard_draft_and_close(draft)

func _format_file_size(byte_count: int) -> String:
	_ensure_runtime_modules()
	return _scene_ui_controller._format_file_size(byte_count)

func _apply_small_card_style(panel: Panel) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._apply_small_card_style(panel)

func _apply_panel_style(panel: Panel) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._apply_panel_style(panel)

func _add_panel_button(parent: Control, button_text: String, pos: Vector2, button_size: Vector2, action: String, args: Array = []) -> Button:
	_ensure_runtime_modules()
	return _scene_ui_controller._add_panel_button(parent, button_text, pos, button_size, action, args)

func _set_button_icon(button: Button, asset_key: String) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._set_button_icon(button, asset_key)

func _icon_key_for_action(action: String) -> String:
	_ensure_runtime_modules()
	return _scene_ui_controller._icon_key_for_action(action)

func _apply_button_style(button: Button, selected: bool = false) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._apply_button_style(button, selected)

func _play_button_click_sfx() -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._play_button_click_sfx()

func _button_style(asset_key: String, fallback_color: Color, border_color: Color) -> StyleBox:
	_ensure_runtime_modules()
	return _scene_ui_controller._button_style(asset_key, fallback_color, border_color)

func _on_panel_button(action: String) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._on_panel_button(action)

func _close_active_panel() -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._close_active_panel()

func open_global_map() -> void:
	_ensure_runtime_modules()
	_scene_ui_controller.open_global_map()

func open_travel_map() -> void:
	_ensure_runtime_modules()
	_scene_ui_controller.open_travel_map()

func open_memory_creator() -> void:
	_ensure_runtime_modules()
	_scene_ui_controller.open_memory_creator()

func open_world_chat() -> void:
	_ensure_runtime_modules()
	_scene_ui_controller.open_world_chat()

func open_family_tree() -> void:
	_ensure_runtime_modules()
	_scene_ui_controller.open_family_tree()

func open_family_members() -> void:
	_ensure_runtime_modules()
	_scene_ui_controller.open_family_members()

func open_postcards() -> void:
	_ensure_runtime_modules()
	_scene_ui_controller.open_postcards()

func _set_hud_context(scene_id: String) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._set_hud_context(scene_id)

func set_player_input_locked(locked: bool) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller.set_player_input_locked(locked)

func _add_plant(pos: Vector2, plant_type: String, existing_id: String = "") -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._add_plant(pos, plant_type, existing_id)

func _rebuild_plants() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._rebuild_plants()

func _on_plant_deleted(item_id: String) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._on_plant_deleted(item_id)

func _on_plant_moved(item_id: String, new_position: Vector2) -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._on_plant_moved(item_id, new_position)

func _refresh_family_tree_visual() -> void:
	_ensure_runtime_modules()
	_garden_scene_controller._refresh_family_tree_visual()

func _family_tree_display_scale() -> float:
	_ensure_runtime_modules()
	return _garden_scene_controller._family_tree_display_scale()

func _get_house_intro(id: String) -> String:
	_ensure_runtime_modules()
	return _garden_scene_controller._get_house_intro(id)

func _show_toast(toast_text: String) -> void:
	_ensure_runtime_modules()
	_scene_ui_controller._show_toast(toast_text)

func _safe_texture(path: String) -> Texture2D:
	_ensure_runtime_modules()
	return _scene_ui_controller._safe_texture(path)

func _solid_texture(width: int, height: int, color: Color) -> Texture2D:
	_ensure_runtime_modules()
	return _scene_ui_controller._solid_texture(width, height, color)
