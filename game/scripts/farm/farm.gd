@tool
extends Node2D

## Farm 场景控制器(独立场景,可用 F6 单独运行)。
## 负责:1) 按每个建筑下的 SortAnchor 设置遮挡排序 z_index
##      2) 用 walkable_area.png 当遮罩逐像素限制行走(碰撞)
##      3) 农场玩法:[E] 就近上下文交互(播种/浇水/施肥/收获)+ 畜牧收集(鸡→蛋/牛→奶)
##
## 作物/畜牧的状态与规则都在 FarmManager(家庭共享 + 时间戳生长 + 持久化),这里只做渲染与交互。
## @tool:编辑器里实时同步 SortAnchor 拖动的遮挡关系;运行时才跑玩法逻辑。

## crop_points.png 扫描得到的 36 个种植点中心(屏幕坐标,1280x720 与图层 1:1)。
const PLOTS: Array[Vector2] = [
	Vector2(505, 301), Vector2(548, 301), Vector2(589, 301),
	Vector2(718, 301), Vector2(761, 301), Vector2(802, 301),
	Vector2(929, 301), Vector2(972, 301), Vector2(1013, 301),
	Vector2(505, 333), Vector2(548, 333), Vector2(589, 333),
	Vector2(718, 333), Vector2(761, 333), Vector2(802, 333),
	Vector2(929, 333), Vector2(972, 333), Vector2(1013, 333),
	Vector2(505, 467), Vector2(548, 467), Vector2(589, 467),
	Vector2(718, 467), Vector2(761, 467), Vector2(802, 467),
	Vector2(928, 467), Vector2(971, 467), Vector2(1012, 467),
	Vector2(505, 499), Vector2(548, 499), Vector2(589, 499),
	Vector2(718, 499), Vector2(761, 499), Vector2(802, 499),
	Vector2(928, 499), Vector2(971, 499), Vector2(1012, 499),
]

const PLANT_REACH := 90.0   ## 玩家离种植点多近才能交互
const CLICK_SNAP := 32.0    ## 点击离种植点多近算选中该点
const FEET_OFFSET := Vector2(0, 18)  ## 玩家脚底相对其原点的偏移(同 Player 碰撞体)
const WALKABLE_ALPHA_THRESHOLD := 0.3

const DOOR_PATHS := ["Objects/DoorChickenHouse", "Objects/DoorCowHouse"]
const DOOR_REACH := 110.0   ## 玩家离门多近才能开
const DOOR_CLICK := 44.0    ## 点击离门多近算点到门
const FARM_TABLE := "farm_plots"
const FARM_SYNC_DEBOUNCE := 0.35
const TOOL_WATERING_CAN := "tool_wateringcan"
const FERTILIZER := "fertilizer"
const FARMER_PATH := "Objects/NpcFarmer"
const FARMER_POS := Vector2(1040, 260)
const FARMER_REACH := 115.0
const FARMER_CLICK := 72.0
const SEED_SHOP_PANEL_SCRIPT := preload("res://scripts/ui/seed_shop_panel.gd")
const NOTICE_BOARD_PANEL_SCRIPT := preload("res://scripts/ui/farm_notice_board_panel.gd")
const NOTEBOARD_PATH := "Objects/Noteboard"
const NOTEBOARD_REACH := 125.0
const NOTEBOARD_CLICK := 86.0
const LIVESTOCK_TARGETS := {
	"chicken_coop": {"point": Vector2(274, 300), "reach": 150.0, "click": 150.0},
	"cow_shed": {"point": Vector2(214, 545), "reach": 155.0, "click": 175.0},
}

var walk_img: Image
var player: CharacterBody2D
var last_safe: Vector2
var crops: Dictionary = {}   ## plot_index -> Crop
var crop_rows: Dictionary = {} ## plot_index -> FarmManager farm_plots 行
var selected: int = 0        ## 当前选中的作物种类(按数字键 1-9 切换)
var doors: Array = []        ## [{node, point}] 门节点 + 其参考点(Farm 本地坐标)
var seed_vendor: Node2D
var noteboard: Node2D
var noteboard_point := Vector2.ZERO
var remote_players: Dictionary = {}      ## member_id -> RemotePlayer
var placeholder_players: Dictionary = {} ## role_key -> RemotePlayer
var presence_hud: CanvasLayer
var presence_label: Label
var farm_hud: CanvasLayer
var seed_label: Label
var farm_status_label: Label
var farm_hint_label: Label
var _farm_refresh_pending := false
var _farm_refresh_running := false
var _farm_busy := false
var _crop_stage_tick := 0.0

func _ready() -> void:
	_sync_object_z()
	if Engine.is_editor_hint():
		return
	process_physics_priority = 100
	walk_img = load("res://assets/farm/walkable_area.png").get_image()
	_build_presence_hud()
	_build_farm_hud()
	_spawn_player()
	_setup_doors()
	_setup_noteboard()
	_setup_seed_vendor()
	_setup_shared_farm()
	_update_seed_label()

func _exit_tree() -> void:
	if not Engine.is_editor_hint() and PresenceChannel != null:
		PresenceChannel.leave_scene("farm")

func _setup_doors() -> void:
	doors.clear()
	for path in DOOR_PATHS:
		var n := get_node_or_null(path) as Sprite2D
		if n == null:
			continue
		n.visible = true
		var anchor := n.get_node_or_null("SortAnchor") as Node2D
		var pt: Vector2 = to_local(anchor.global_position if anchor != null else n.global_position)
		doors.append({"node": n, "point": pt})

func _setup_seed_vendor() -> void:
	seed_vendor = get_node_or_null(FARMER_PATH) as Node2D
	if seed_vendor == null:
		return
	seed_vendor.position = FARMER_POS
	if seed_vendor.has_method("set_hint_visible"):
		seed_vendor.call("set_hint_visible", false)

func _setup_noteboard() -> void:
	noteboard = get_node_or_null(NOTEBOARD_PATH) as Node2D
	if noteboard == null:
		return
	var anchor := noteboard.get_node_or_null("SortAnchor") as Node2D
	noteboard_point = to_local(anchor.global_position if anchor != null else noteboard.global_position)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_sync_object_z()
	else:
		_update_seed_vendor_hint()
		_update_interaction_hint()
		_crop_stage_tick += delta
		if _crop_stage_tick >= 1.0:
			_crop_stage_tick = 0.0
			_refresh_crop_stages()

func _sync_object_z() -> void:
	var objs := get_node_or_null("Objects")
	if objs != null:
		_apply_anchor_z(objs)

func _apply_anchor_z(n: Node) -> void:
	for child in n.get_children():
		if child is Node2D:
			var anchor := child.get_node_or_null("SortAnchor") as Node2D
			if anchor != null:
				(child as CanvasItem).z_index = int(anchor.global_position.y)
			_apply_anchor_z(child)

func _spawn_player() -> void:
	player = preload("res://scenes/Player.tscn").instantiate()
	player.position = _find_walkable_start()
	player.add_to_group("player")
	last_safe = player.position
	add_child(player)
	# 农场自 spawn 玩家:指向 SceneManager.player,让 GameHUD 开面板时锁移动生效(同 Kitchen)。
	SceneManager.player = player
	var mem := get_node_or_null("/root/MemoryManager")
	var local_fallback := str(mem.selected_role_key) if mem != null and mem.selected_role_key != "" else "father"
	var identity := get_node_or_null("/root/GameIdentity")
	var role: String = identity.local_role(local_fallback) if identity != null else local_fallback
	if player.has_method("apply_character"):
		player.apply_character(role)
	_spawn_family(role)
	_setup_presence()

func _spawn_family(local_role: String) -> void:
	var db := get_node_or_null("/root/CharacterDB")
	if db == null:
		return
	var local_id: String = db.resolve(local_role)
	var spots := {
		"mother":  [Vector2(705, 235), Rect2(660, 222, 95, 36)],
		"partner": [Vector2(1120, 600), Rect2(1075, 582, 95, 44)],
		"player":  [Vector2(470, 640), Rect2(430, 622, 95, 44)],
		"father":  [Vector2(640, 250), Rect2(600, 236, 95, 36)],
	}
	for cid in db.all_ids():
		if cid == local_id or not spots.has(cid):
			continue
		var rp: Node2D = preload("res://scenes/RemotePlayer.tscn").instantiate()
		rp.role_key = cid
		rp.placeholder_wander = true
		rp.wander_area = spots[cid][1]
		add_child(rp)
		rp.position = spots[cid][0]
		placeholder_players[cid] = rp

func _setup_presence() -> void:
	if PresenceChannel == null:
		_update_presence_hud("离线")
		return
	if not PresenceChannel.peer_snapshot.is_connected(_on_presence_snapshot):
		PresenceChannel.peer_snapshot.connect(_on_presence_snapshot)
	if not PresenceChannel.peer_joined.is_connected(_on_presence_peer_joined):
		PresenceChannel.peer_joined.connect(_on_presence_peer_joined)
	if not PresenceChannel.peer_moved.is_connected(_on_presence_peer_moved):
		PresenceChannel.peer_moved.connect(_on_presence_peer_moved)
	if not PresenceChannel.peer_left.is_connected(_on_presence_peer_left):
		PresenceChannel.peer_left.connect(_on_presence_peer_left)
	if not PresenceChannel.status_changed.is_connected(_on_presence_status_changed):
		PresenceChannel.status_changed.connect(_on_presence_status_changed)
	PresenceChannel.enter_scene("farm", player)
	_on_presence_status_changed(PresenceChannel.status())

func _build_presence_hud() -> void:
	presence_hud = CanvasLayer.new()
	presence_hud.name = "PresenceHUD"
	presence_hud.layer = 20
	add_child(presence_hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(1064, 18)
	panel.custom_minimum_size = Vector2(176, 34)
	presence_hud.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.98, 0.93, 0.9)
	style.border_color = Color(0.34, 0.44, 0.28, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	presence_label = Label.new()
	presence_label.text = "离线"
	presence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	presence_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	presence_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(presence_label)

func _build_farm_hud() -> void:
	farm_hud = CanvasLayer.new()
	farm_hud.name = "FarmHUD"
	farm_hud.layer = 19
	add_child(farm_hud)

	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(360, 96)
	farm_hud.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.95, 0.84, 0.92)
	style.border_color = Color(0.43, 0.34, 0.20, 0.86)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(336, 82)
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)

	seed_label = Label.new()
	seed_label.text = "种子"
	seed_label.add_theme_font_size_override("font_size", 15)
	seed_label.add_theme_color_override("font_color", Color(0.20, 0.16, 0.10, 1.0))
	box.add_child(seed_label)

	farm_status_label = Label.new()
	farm_status_label.text = "家庭农场同步中..."
	farm_status_label.add_theme_font_size_override("font_size", 13)
	farm_status_label.add_theme_color_override("font_color", Color(0.36, 0.29, 0.18, 0.92))
	box.add_child(farm_status_label)

	farm_hint_label = Label.new()
	farm_hint_label.text = "靠近田地、告示牌或老爷爷，会出现操作提示。"
	farm_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	farm_hint_label.add_theme_font_size_override("font_size", 13)
	farm_hint_label.add_theme_color_override("font_color", Color(0.22, 0.42, 0.20, 0.95))
	box.add_child(farm_hint_label)

func _setup_shared_farm() -> void:
	if FarmManager != null and not FarmManager.changed.is_connected(_on_farm_manager_changed):
		FarmManager.changed.connect(_on_farm_manager_changed)
	if CloudManager != null and CloudManager.has_signal("cloud_world_changed") \
		and not CloudManager.cloud_world_changed.is_connected(_on_cloud_world_changed):
		CloudManager.cloud_world_changed.connect(_on_cloud_world_changed)
	_load_shared_farm_plots()

func _on_farm_manager_changed() -> void:
	_load_shared_farm_plots()

func _on_cloud_world_changed(event: Dictionary) -> void:
	if str(event.get("table", "")) != FARM_TABLE:
		return
	_schedule_farm_refresh("家人的农场更新已同步。")

func _schedule_farm_refresh(message: String = "") -> void:
	if message != "":
		_set_farm_status(message)
	_farm_refresh_pending = true
	if _farm_refresh_running:
		return
	_farm_refresh_running = true
	call_deferred("_run_farm_refresh")

func _run_farm_refresh() -> void:
	while _farm_refresh_pending:
		_farm_refresh_pending = false
		await get_tree().create_timer(FARM_SYNC_DEBOUNCE).timeout
		_load_shared_farm_plots()
	_farm_refresh_running = false

func _load_shared_farm_plots() -> void:
	var rows: Array = FarmManager.plots() if FarmManager != null else []
	_render_farm_rows(rows)
	_set_farm_status("农场已加载。")

func _render_farm_rows(rows: Array) -> void:
	for plot_index in crops.keys():
		var crop: Node = crops[plot_index]
		if crop != null and is_instance_valid(crop):
			crop.queue_free()
	crops.clear()
	crop_rows.clear()
	for raw in rows:
		if raw is Dictionary:
			_render_farm_row(raw)

func _render_farm_row(row: Dictionary) -> void:
	var plot_index := int(row.get("plot", row.get("plot_index", -1)))
	if plot_index < 0 or plot_index >= PLOTS.size():
		return
	var crop_id := str(row.get("crop_id", ""))
	var data := CropDB.get_crop_by_id(crop_id)
	if data.is_empty():
		return
	if crops.has(plot_index):
		var old_crop: Node = crops[plot_index]
		if old_crop != null and is_instance_valid(old_crop):
			old_crop.queue_free()
	var crop := Crop.new()
	add_child(crop)
	crop.setup(
		int(data.get("panel", 0)),
		int(data.get("row", 0)),
		PLOTS[plot_index],
		crop_id,
		int(row.get("planted_at_unix", int(row.get("planted_at", 0)))))
	crop.set_process(false)
	crop.set_stage(FarmManager.stage_of(plot_index) if FarmManager != null else 0)
	crop.set_watered(bool(row.get("watered", false)))
	crop.set_fertilized(bool(row.get("fertilized", false)))
	crops[plot_index] = crop
	crop_rows[plot_index] = row.duplicate(true)

func _refresh_crop_stages() -> void:
	if FarmManager == null:
		return
	for raw_index in crops.keys():
		var plot_index := int(raw_index)
		var crop: Crop = crops.get(plot_index, null)
		if crop == null or not is_instance_valid(crop):
			continue
		var row: Dictionary = FarmManager.get_plot(plot_index)
		if row.is_empty():
			continue
		crop.set_stage(FarmManager.stage_of(plot_index))
		crop.set_watered(bool(row.get("watered", false)))
		crop.set_fertilized(bool(row.get("fertilized", false)))
		crop_rows[plot_index] = row.duplicate(true)

func _on_presence_snapshot(peers: Array) -> void:
	for member_id in remote_players.keys():
		_remove_remote_player(str(member_id))
	for peer in peers:
		if peer is Dictionary:
			_upsert_remote_player(peer)
	_refresh_presence_count()

func _on_presence_peer_joined(peer: Dictionary) -> void:
	_upsert_remote_player(peer)
	_refresh_presence_count()

func _on_presence_peer_moved(peer: Dictionary) -> void:
	_upsert_remote_player(peer)

func _on_presence_peer_left(member_id: String) -> void:
	_remove_remote_player(member_id)
	_refresh_presence_count()

func _on_presence_status_changed(status: String) -> void:
	match status:
		"online":
			_refresh_presence_count()
		"connecting", "reconnecting":
			_update_presence_hud("连接中")
		"waiting_identity":
			_update_presence_hud("等待身份")
		"disabled":
			_update_presence_hud("离线演示")
		_:
			_update_presence_hud("离线")

func _upsert_remote_player(peer: Dictionary) -> void:
	var member_id := str(peer.get("member_id", ""))
	if member_id == "":
		return
	if str(peer.get("scene_id", "")) != "farm":
		_remove_remote_player(member_id)
		return
	var role := CharacterDB.resolve(str(peer.get("role", "father")))
	if placeholder_players.has(role):
		var placeholder := placeholder_players[role] as Node
		placeholder_players.erase(role)
		if placeholder != null:
			placeholder.queue_free()
	var rp: Node2D = remote_players.get(member_id, null)
	if rp == null:
		rp = preload("res://scenes/RemotePlayer.tscn").instantiate()
		add_child(rp)
		remote_players[member_id] = rp
	var display_name := str(peer.get("display_name", CharacterDB.display_name(role)))
	if rp.has_method("configure_presence"):
		rp.configure_presence(member_id, role, display_name)
	var pos := _peer_position(peer)
	if rp.global_position == Vector2.ZERO:
		rp.global_position = pos
	if rp.has_method("set_presence_target"):
		rp.set_presence_target(
			pos,
			str(peer.get("direction", "down")),
			str(peer.get("animation_state", "idle")),
			int(peer.get("sequence", 0)))
	else:
		rp.set_target(pos)

func _remove_remote_player(member_id: String) -> void:
	var rp: Node = remote_players.get(member_id, null)
	remote_players.erase(member_id)
	if rp != null:
		rp.queue_free()

func _peer_position(peer: Dictionary) -> Vector2:
	var raw: Variant = peer.get("position", {})
	if raw is Dictionary:
		return Vector2(float(raw.get("x", 640.0)), float(raw.get("y", 650.0)))
	return Vector2(640, 650)

func _refresh_presence_count() -> void:
	var count := 1 + remote_players.size()
	_update_presence_hud("在线 " + str(count))

func _update_presence_hud(text: String) -> void:
	if presence_label != null:
		presence_label.text = text

func _update_interaction_hint() -> void:
	if farm_hint_label == null:
		return
	farm_hint_label.text = _interaction_hint_text()

func _interaction_hint_text() -> String:
	if player == null:
		return "靠近田地、告示牌或老爷爷，会出现操作提示。"
	if _can_reach_seed_vendor():
		return "按 E 打开农场小铺。"
	if _can_reach_noteboard():
		return "按 E 查看农场告示牌。"
	var livestock_id := _nearest_livestock(player.position, false)
	if livestock_id != "" and _can_reach_livestock(livestock_id):
		return _livestock_hint(livestock_id)
	var plot_index := _nearest_reachable_plot(player.position)
	if plot_index >= 0:
		return _plot_hint(plot_index)
	return "靠近田地、告示牌或老爷爷，会出现操作提示。"

func _livestock_hint(id: String) -> String:
	if FarmManager == null:
		return "按 E 查看畜棚。"
	var def: Dictionary = FarmManager.livestock_def(id)
	var label := str(def.get("interaction_label", "收集"))
	if FarmManager.livestock_ready(id):
		return "按 E " + label + "。"
	var left := int(ceil(FarmManager.cooldown_left(id)))
	return "按 E 查看%s还要多久。" % label

func _plot_hint(plot_index: int) -> String:
	if FarmManager == null:
		return "按 E 查看这块田。"
	if not crops.has(plot_index):
		return "按 E 种下：" + _selected_seed_name() + "。"
	var row: Dictionary = crop_rows.get(plot_index, {})
	var crop_id := str(row.get("crop_id", ""))
	var crop_name := _item_name("produce_" + crop_id)
	if not bool(row.get("watered", false)):
		if _has_item_anywhere(TOOL_WATERING_CAN):
			return "按 E 给%s浇水。" % crop_name
		return "需要浇水壶才能给%s浇水。" % crop_name
	if FarmManager.is_mature(plot_index):
		return "按 E 收获%s。" % crop_name
	if not bool(row.get("fertilized", false)) and _has_item_anywhere(FERTILIZER):
		return "按 E 给%s施肥。" % crop_name
	var left := int(ceil(FarmManager.seconds_to_next_stage(plot_index)))
	return "%s正在生长，还要%s。" % [crop_name, _format_wait(left)]

func _find_walkable_start() -> Vector2:
	# 出生点必须在"回花园"传送门(trigger_rect y585-615)的内侧(上方),
	# 否则玩家出生在门外、一往上走就踩进触发区被立刻送回花园。
	var spawn_center := Vector2(640, 540)
	for r in range(0, 420, 8):
		for a in range(0, 360, 15):
			var p: Vector2 = spawn_center + Vector2(r, 0).rotated(deg_to_rad(a))
			if _position_walkable(p):
				return p
	return spawn_center

func _walkable_point(feet: Vector2) -> bool:
	var x := int(feet.x)
	var y := int(feet.y)
	if x < 0 or y < 0 or x >= walk_img.get_width() or y >= walk_img.get_height():
		return false
	return walk_img.get_pixelv(Vector2i(x, y)).a > WALKABLE_ALPHA_THRESHOLD

func _position_walkable(origin: Vector2) -> bool:
	return _walkable_point(origin + FEET_OFFSET)

func _physics_process(_delta: float) -> void:
	if player == null:
		return
	if _position_walkable(player.position):
		last_safe = player.position
	else:
		player.position = last_safe
		player.velocity = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k: int = event.keycode
		if k == KEY_E and not event.echo:
			if _try_context_interact():
				get_viewport().set_input_as_handled()
				return
		if k >= KEY_1 and k <= KEY_9:
			selected = (k - KEY_1) % CropDB.CROPS.size()
			_update_seed_label()
			_set_farm_status("已选择 " + _selected_seed_name())
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var click := to_local(get_global_mouse_position())
		if _try_seed_vendor_click(click):
			return
		if _try_noteboard_click(click):
			return
		if _try_livestock_click(click):
			return
		if _try_doors(click):
			return
		_try_plant(click)

func _try_seed_vendor_interact() -> bool:
	if not _can_reach_seed_vendor():
		return false
	_open_seed_shop()
	return true

func _try_context_interact() -> bool:
	if _try_seed_vendor_interact():
		return true
	if _try_noteboard_interact():
		return true
	if player == null:
		return false
	var livestock_id := _nearest_livestock(player.position, false)
	if livestock_id != "" and _can_reach_livestock(livestock_id):
		_collect_livestock(livestock_id)
		return true
	var plot_index := _nearest_reachable_plot(player.position)
	if plot_index >= 0:
		_try_plot_index(plot_index)
		return true
	return false

func _try_seed_vendor_click(click: Vector2) -> bool:
	if seed_vendor == null:
		return false
	if click.distance_to(seed_vendor.position) > FARMER_CLICK:
		return false
	if not _can_reach_seed_vendor():
		_set_farm_status("再走近一点，老爷爷的农场小铺就在这里。")
		return true
	_open_seed_shop()
	return true

func _can_reach_seed_vendor() -> bool:
	return player != null and seed_vendor != null and player.position.distance_to(seed_vendor.position) <= FARMER_REACH

func _update_seed_vendor_hint() -> void:
	if seed_vendor == null or not seed_vendor.has_method("set_hint_visible"):
		return
	seed_vendor.call("set_hint_visible", _can_reach_seed_vendor())

func _open_seed_shop() -> void:
	var panel: HUDPanel = SEED_SHOP_PANEL_SCRIPT.new()
	if SceneManager.game_hud != null and is_instance_valid(SceneManager.game_hud):
		SceneManager.game_hud.open_panel(panel)
	else:
		var layer := CanvasLayer.new()
		layer.layer = 40
		add_child(layer)
		panel.close_requested.connect(func() -> void: layer.queue_free())
		layer.add_child(panel)
	_set_farm_status("老爷爷的农场小铺开张了。")

func _try_noteboard_interact() -> bool:
	if not _can_reach_noteboard():
		return false
	_open_noteboard()
	return true

func _try_noteboard_click(click: Vector2) -> bool:
	if noteboard == null:
		return false
	if click.distance_to(noteboard_point) > NOTEBOARD_CLICK:
		return false
	if not _can_reach_noteboard():
		_set_farm_status("再走近一点，告示牌在这里。")
		return true
	_open_noteboard()
	return true

func _can_reach_noteboard() -> bool:
	return player != null and noteboard != null and player.position.distance_to(noteboard_point) <= NOTEBOARD_REACH

func _open_noteboard() -> void:
	var panel: HUDPanel = NOTICE_BOARD_PANEL_SCRIPT.new()
	if SceneManager.game_hud != null and is_instance_valid(SceneManager.game_hud):
		SceneManager.game_hud.open_panel(panel)
	else:
		var layer := CanvasLayer.new()
		layer.layer = 40
		add_child(layer)
		panel.close_requested.connect(func() -> void: layer.queue_free())
		layer.add_child(panel)
	_set_farm_status("打开了农场告示牌。")

func _try_livestock_click(click: Vector2) -> bool:
	var target_id := _nearest_livestock(click, true)
	if target_id == "":
		return false
	if not _can_reach_livestock(target_id):
		_set_farm_status("再走近一点。")
		return true
	_collect_livestock(target_id)
	return true

func _nearest_livestock(point: Vector2, use_click_radius: bool) -> String:
	var best_id := ""
	var best_d := INF
	for raw_id in LIVESTOCK_TARGETS.keys():
		var id := String(raw_id)
		var target: Dictionary = LIVESTOCK_TARGETS[id]
		var d: float = point.distance_to(target.get("point", Vector2.ZERO))
		var limit: float = float(target.get("click" if use_click_radius else "reach", 120.0))
		if d <= limit and d < best_d:
			best_d = d
			best_id = id
	return best_id

func _can_reach_livestock(id: String) -> bool:
	if player == null or not LIVESTOCK_TARGETS.has(id):
		return false
	var target: Dictionary = LIVESTOCK_TARGETS[id]
	return player.position.distance_to(target.get("point", Vector2.ZERO)) <= float(target.get("reach", 120.0))

func _collect_livestock(id: String) -> void:
	if FarmManager == null:
		return
	var def: Dictionary = FarmManager.livestock_def(id)
	var qty: int = FarmManager.collect(id)
	if qty > 0:
		var item_id := str(def.get("output_item_id", ""))
		_set_farm_status("收集到 " + _item_name(item_id) + " ×" + str(qty) + "。")
		_record_farm_activity("collect_livestock", "收集", "收集了%s ×%d" % [_item_name(item_id), qty], item_id, qty)
		return
	var left := int(ceil(FarmManager.cooldown_left(id)))
	_set_farm_status(str(def.get("interaction_label", "收集")) + "还要 " + _format_wait(left) + "。")

func _try_doors(click: Vector2) -> bool:
	for d in doors:
		if click.distance_to(d.point) > DOOR_CLICK:
			continue
		if player.position.distance_to(d.point) <= DOOR_REACH:
			d.node.visible = not d.node.visible
			AudioManager.play_sfx("开门" if not d.node.visible else "门")
		return true
	return false

func _try_plant(click: Vector2) -> void:
	if _farm_busy:
		return
	var best := _nearest_plot(click, CLICK_SNAP)
	if best == -1:
		return  # 没点在任何种植点附近

	if not _can_reach_plot(best):
		_set_farm_status("再走近一点。")
		return
	_try_plot_index(best)

func _try_plot_index(plot_index: int) -> void:
	# 已有作物:未浇水先浇水,成熟则收获,否则可施肥或提示剩余时间。
	if crops.has(plot_index):
		_try_existing_crop(plot_index)
		return

	var data := CropDB.get_crop(selected)
	_plant_plot(plot_index, data)

func _nearest_plot(point: Vector2, max_distance: float) -> int:
	var best := -1
	var best_d := INF
	for i in PLOTS.size():
		var d: float = PLOTS[i].distance_to(point)
		if d < best_d:
			best_d = d
			best = i
	return best if best_d <= max_distance else -1

func _nearest_reachable_plot(point: Vector2) -> int:
	var best := _nearest_plot(point, PLANT_REACH)
	return best if best >= 0 and _can_reach_plot(best) else -1

func _try_existing_crop(plot_index: int) -> void:
	if FarmManager == null:
		return
	var row: Dictionary = crop_rows.get(plot_index, {})
	var crop_id := str(row.get("crop_id", ""))
	if not bool(row.get("watered", false)):
		if not _has_item_anywhere(TOOL_WATERING_CAN):
			_set_farm_status("需要浇水壶。")
			return
		if FarmManager.water(plot_index):
			_set_farm_status("浇水了，" + _item_name("produce_" + crop_id) + "开始生长。")
			_record_farm_activity("water", "浇水", "给%s浇水了" % _item_name("produce_" + crop_id), "produce_" + crop_id)
		return
	if FarmManager.is_mature(plot_index):
		_harvest_plot(plot_index)
		return
	if not bool(row.get("fertilized", false)) and _has_item_anywhere(FERTILIZER):
		if _take_item_anywhere(FERTILIZER, 1) and FarmManager.fertilize(plot_index):
			_set_farm_status("施肥了，成熟后会多收一点。")
			_record_farm_activity("fertilize", "施肥", "给%s施肥了" % _item_name("produce_" + crop_id), FERTILIZER, 1)
		return
	var left := int(ceil(FarmManager.seconds_to_next_stage(plot_index)))
	_set_farm_status("还要 " + _format_wait(left) + " 进入下一阶段。")

func _plant_plot(plot_index: int, data: Dictionary) -> void:
	var crop_id := str(data.get("id", ""))
	_farm_busy = true
	_set_farm_status("正在种下 " + _item_name("seed_" + crop_id) + "...")
	var planted := FarmManager != null and FarmManager.plant(plot_index, crop_id)
	_farm_busy = false
	if planted:
		_set_farm_status("种下了 " + _item_name("seed_" + crop_id) + "。")
		_record_farm_activity("plant", "播种", "种下了%s" % _item_name("seed_" + crop_id), "seed_" + crop_id, 1)
	else:
		_set_farm_status("没有 " + _item_name("seed_" + crop_id) + "，可以去老爷爷那里买。")

func _harvest_plot(plot_index: int) -> void:
	var row: Dictionary = crop_rows.get(plot_index, {})
	var crop_id := str(row.get("crop_id", ""))
	var amount := FarmManager.harvest(plot_index) if FarmManager != null else 0
	if amount > 0:
		_set_farm_status("收获 " + _item_name("produce_" + crop_id) + " ×" + str(amount) + "。")
		_record_farm_activity("harvest", "收获", "收获了%s ×%d" % [_item_name("produce_" + crop_id), amount], "produce_" + crop_id, amount)
	else:
		_set_farm_status("还不能收获。")

func _can_reach_plot(plot_index: int) -> bool:
	return player != null and player.position.distance_to(PLOTS[plot_index]) <= PLANT_REACH

func _farm_cloud_ready() -> bool:
	return CloudManager != null \
		and CloudManager.has_method("has_cloud_records") \
		and CloudManager.has_cloud_records()

func _farm_plot_id(plot_index: int) -> String:
	var family_id := ""
	if GameIdentity != null and GameIdentity.is_ready():
		family_id = str(GameIdentity.family_id)
	if family_id == "":
		family_id = str(CloudBaseBackend.load_config().get("family_id", "local"))
	return "farm_plot:%s:%d" % [family_id, plot_index]

func _update_seed_label() -> void:
	if seed_label == null:
		return
	seed_label.text = "种子 " + str(selected + 1) + ": " + _selected_seed_name()

func _selected_seed_name() -> String:
	var data := CropDB.get_crop(selected)
	return _item_name("seed_" + str(data.get("id", "")))

func _item_name(item_id: String) -> String:
	if ItemDB != null and ItemDB.has_method("display_name"):
		return ItemDB.display_name(item_id)
	return item_id

func _set_farm_status(text: String) -> void:
	if farm_status_label != null:
		farm_status_label.text = text

func _record_farm_activity(action: String, label: String, detail: String, item_id: String = "", qty: int = 0) -> void:
	if MemoryManager != null and MemoryManager.has_method("record_farm_activity"):
		MemoryManager.record_farm_activity(action, label, detail, item_id, qty)

func _format_wait(seconds: int) -> String:
	if seconds <= 0:
		return "很快"
	var minutes := int(ceil(float(seconds) / 60.0))
	if minutes <= 1:
		return "1 分钟"
	return str(minutes) + " 分钟"

func _has_item_anywhere(item_id: String, amount: int = 1) -> bool:
	return InventoryManager != null \
		and (InventoryManager.has(item_id, amount, true) or InventoryManager.has(item_id, amount))

func _take_item_anywhere(item_id: String, amount: int = 1) -> bool:
	if InventoryManager == null:
		return false
	if InventoryManager.has(item_id, amount, true):
		return InventoryManager.take(item_id, amount, true) == amount
	if InventoryManager.has(item_id, amount):
		return InventoryManager.take(item_id, amount) == amount
	return false
