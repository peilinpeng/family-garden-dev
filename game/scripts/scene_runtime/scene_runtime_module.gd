extends Node

## SceneManager 内部模块基类。只代理共享状态；公开兼容面仍由 SceneManager 持有。
var _host

func _init(host) -> void:
	_host = host

var GAME_SIZE:
	get:
		return _host.GAME_SIZE

var ANNA_ROOM_SCENE:
	get:
		return _host.ANNA_ROOM_SCENE

var POND_AREA_SCENE:
	get:
		return _host.POND_AREA_SCENE

var FARM_SCENE:
	get:
		return _host.FARM_SCENE

var KITCHEN_SCENE:
	get:
		return _host.KITCHEN_SCENE

var GARDEN_TILED_SCENE:
	get:
		return _host.GARDEN_TILED_SCENE

var USE_GARDEN_TILED_AS_MAIN:
	get:
		return _host.USE_GARDEN_TILED_AS_MAIN

var CHARACTER_CREATOR_PANEL_SCRIPT:
	get:
		return _host.CHARACTER_CREATOR_PANEL_SCRIPT

var LOOP_TWEEN_GUARD_INTERVAL:
	get:
		return _host.LOOP_TWEEN_GUARD_INTERVAL

var FISHPOND_PLAYER_VISUAL_SCALE:
	get:
		return _host.FISHPOND_PLAYER_VISUAL_SCALE

var DAY_NIGHT_CLOCK_UI_SCRIPT:
	get:
		return _host.DAY_NIGHT_CLOCK_UI_SCRIPT

var ROOM_SCENE_GENERATOR:
	get:
		return _host.ROOM_SCENE_GENERATOR

var ASSETS:
	get:
		return _host.ASSETS

var FAMILY_TREE_TEXTURE_PATTERN:
	get:
		return _host.FAMILY_TREE_TEXTURE_PATTERN

var FAMILY_TREE_DISPLAY_SCALES:
	get:
		return _host.FAMILY_TREE_DISPLAY_SCALES

var HOUSE_DATA:
	get:
		return _host.HOUSE_DATA

var ROOM_DATA:
	get:
		return _host.ROOM_DATA

var CHARACTER_DATA:
	get:
		return _host.CHARACTER_DATA

var GARDEN_ARCHIVES:
	get:
		return _host.GARDEN_ARCHIVES

var GARDEN_ARCHIVE_ORDER:
	get:
		return _host.GARDEN_ARCHIVE_ORDER

var ANIMAL_DATA:
	get:
		return _host.ANIMAL_DATA

var world:
	get:
		return _host.world
	set(value):
		_host.world = value

var ui_layer:
	get:
		return _host.ui_layer
	set(value):
		_host.ui_layer = value

var ui_root:
	get:
		return _host.ui_root
	set(value):
		_host.ui_root = value

var orientation_layer:
	get:
		return _host.orientation_layer
	set(value):
		_host.orientation_layer = value

var info_label:
	get:
		return _host.info_label
	set(value):
		_host.info_label = value

var plant_button:
	get:
		return _host.plant_button
	set(value):
		_host.plant_button = value

var world_chat_input:
	get:
		return _host.world_chat_input
	set(value):
		_host.world_chat_input = value

var world_chat_feed_panel:
	get:
		return _host.world_chat_feed_panel
	set(value):
		_host.world_chat_feed_panel = value

var world_chat_feed:
	get:
		return _host.world_chat_feed
	set(value):
		_host.world_chat_feed = value

var day_night_clock_ui:
	get:
		return _host.day_night_clock_ui
	set(value):
		_host.day_night_clock_ui = value

var world_chat_fade_tween:
	get:
		return _host.world_chat_fade_tween
	set(value):
		_host.world_chat_fade_tween = value

var _chat_panel_list:
	get:
		return _host._chat_panel_list
	set(value):
		_host._chat_panel_list = value

var _chat_panel_scroll:
	get:
		return _host._chat_panel_scroll
	set(value):
		_host._chat_panel_scroll = value

var plant_mode:
	get:
		return _host.plant_mode
	set(value):
		_host.plant_mode = value

var selected_plant_type:
	get:
		return _host.selected_plant_type
	set(value):
		_host.selected_plant_type = value

var mode:
	get:
		return _host.mode
	set(value):
		_host.mode = value

var player:
	get:
		return _host.player
	set(value):
		_host.player = value

var plant_nodes:
	get:
		return _host.plant_nodes
	set(value):
		_host.plant_nodes = value

var room_card:
	get:
		return _host.room_card
	set(value):
		_host.room_card = value

var gate4_guide_card:
	get:
		return _host.gate4_guide_card
	set(value):
		_host.gate4_guide_card = value

var garden_guide_expanded:
	get:
		return _host.garden_guide_expanded
	set(value):
		_host.garden_guide_expanded = value

var mailbox_badge:
	get:
		return _host.mailbox_badge
	set(value):
		_host.mailbox_badge = value

var active_modal:
	get:
		return _host.active_modal
	set(value):
		_host.active_modal = value

var game_hud:
	get:
		return _host.game_hud
	set(value):
		_host.game_hud = value

var map_ui:
	get:
		return _host.map_ui
	set(value):
		_host.map_ui = value

var global_map_ui:
	get:
		return _host.global_map_ui
	set(value):
		_host.global_map_ui = value

var pond_fishing_available:
	get:
		return _host.pond_fishing_available
	set(value):
		_host.pond_fishing_available = value

var pond_fishing_prompt:
	get:
		return _host.pond_fishing_prompt
	set(value):
		_host.pond_fishing_prompt = value

var adding_place:
	get:
		return _host.adding_place
	set(value):
		_host.adding_place = value

var _garden_controls_hint_shown:
	get:
		return _host._garden_controls_hint_shown
	set(value):
		_host._garden_controls_hint_shown = value

var pending_place_position:
	get:
		return _host.pending_place_position
	set(value):
		_host.pending_place_position = value

var animal_nodes:
	get:
		return _host.animal_nodes
	set(value):
		_host.animal_nodes = value

var cloud_load_finished:
	get:
		return _host.cloud_load_finished
	set(value):
		_host.cloud_load_finished = value

var selected_photo_path:
	get:
		return _host.selected_photo_path
	set(value):
		_host.selected_photo_path = value

var selected_photo_label:
	get:
		return _host.selected_photo_label
	set(value):
		_host.selected_photo_label = value

var photo_file_dialog:
	get:
		return _host.photo_file_dialog
	set(value):
		_host.photo_file_dialog = value

var selected_photo_bytes:
	get:
		return _host.selected_photo_bytes
	set(value):
		_host.selected_photo_bytes = value

var selected_photo_filename:
	get:
		return _host.selected_photo_filename
	set(value):
		_host.selected_photo_filename = value

var selected_photo_content_type:
	get:
		return _host.selected_photo_content_type
	set(value):
		_host.selected_photo_content_type = value

var selected_photo_from_web:
	get:
		return _host.selected_photo_from_web
	set(value):
		_host.selected_photo_from_web = value

var web_photo_callback:
	get:
		return _host.web_photo_callback
	set(value):
		_host.web_photo_callback = value

var photo_texture_cache:
	get:
		return _host.photo_texture_cache
	set(value):
		_host.photo_texture_cache = value

var active_ai_workflow:
	get:
		return _host.active_ai_workflow
	set(value):
		_host.active_ai_workflow = value

var active_ai_status_label:
	get:
		return _host.active_ai_status_label
	set(value):
		_host.active_ai_status_label = value

var _last_world_sync_toast_msec:
	get:
		return _host._last_world_sync_toast_msec
	set(value):
		_host._last_world_sync_toast_msec = value

var orientation_overlay:
	get:
		return _host.orientation_overlay
	set(value):
		_host.orientation_overlay = value

var orientation_content:
	get:
		return _host.orientation_content
	set(value):
		_host.orientation_content = value

var _autosave_timer:
	get:
		return _host._autosave_timer
	set(value):
		_host._autosave_timer = value

var _current_spawn_key:
	get:
		return _host._current_spawn_key
	set(value):
		_host._current_spawn_key = value

var _current_room_id:
	get:
		return _host._current_room_id
	set(value):
		_host._current_room_id = value

var _pending_resume_position:
	get:
		return _host._pending_resume_position
	set(value):
		_host._pending_resume_position = value

var _has_pending_resume_position:
	get:
		return _host._has_pending_resume_position
	set(value):
		_host._has_pending_resume_position = value

var _demo_memories:
	get:
		return _host._demo_memories
	set(value):
		_host._demo_memories = value

var _focused_memory_id:
	get:
		return _host._focused_memory_id
	set(value):
		_host._focused_memory_id = value

var _pending_memory_arrival_id:
	get:
		return _host._pending_memory_arrival_id
	set(value):
		_host._pending_memory_arrival_id = value

var _demo_bottles:
	get:
		return _host._demo_bottles
	set(value):
		_host._demo_bottles = value

var _fishpond_memories:
	get:
		return _host._fishpond_memories
	set(value):
		_host._fishpond_memories = value

var _room_objects:
	get:
		return _host._room_objects
	set(value):
		_host._room_objects = value

var _travel_lock:
	get:
		return _host._travel_lock
	set(value):
		_host._travel_lock = value

var GLOBAL_MAP_REGIONS:
	get:
		return _host.GLOBAL_MAP_REGIONS

var GLOBAL_MAP_DECORATIONS:
	get:
		return _host.GLOBAL_MAP_DECORATIONS

var SCENE_BOTTLE_QUESTION:
	get:
		return _host.SCENE_BOTTLE_QUESTION

var FISHING_RESULTS:
	get:
		return _host.FISHING_RESULTS
