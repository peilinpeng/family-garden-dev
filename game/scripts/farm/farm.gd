@tool
extends Node2D

## Farm 场景控制器(独立场景,可用 F6 单独运行)。
## 负责:1) 按每个建筑下的 SortAnchor(可在编辑器拖动)设置遮挡排序 z_index
##      2) 用 walkable_area.png 当遮罩,逐像素限制玩家行走范围(碰撞)
##      3) 用 crop_points 烘焙出的 36 个种植点,走近+点击种作物,按 10 分钟一阶段生长
##
## @tool:拖动 Objects 下任意建筑的 SortAnchor 时,编辑器里实时更新遮挡关系。
## 数据层(crop_points / walkable_area)在画面上不显示:walkable 只当 Image 读,
## 种植点坐标已烘焙进下面的 PLOTS,不需要把图加进场景。

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

const PLANT_REACH := 90.0   ## 玩家离种植点多近才能种
const CLICK_SNAP := 32.0    ## 点击离种植点多近算选中该点
const FEET_OFFSET := Vector2(0, 18)  ## 玩家脚底相对其原点的偏移(同 Player 碰撞体)

const DOOR_PATHS := ["Objects/DoorChickenHouse", "Objects/DoorCowHouse"]
const DOOR_REACH := 110.0   ## 玩家离门多近才能开
const DOOR_CLICK := 44.0    ## 点击离门多近算点到门
const FARM_TABLE := "farm_plots"
const FARM_SYNC_DEBOUNCE := 0.35

var walk_img: Image
var player: CharacterBody2D
var last_safe: Vector2
var crops: Dictionary = {}   ## plot_index -> Crop
var crop_rows: Dictionary = {} ## plot_index -> 云端 farm_plots 行
var selected: int = 0        ## 当前选中的作物种类(按数字键 1-9 切换)
var doors: Array = []        ## [{node, point}] 门节点 + 其参考点(SortAnchor 全局位置)
var remote_players: Dictionary = {}      ## member_id -> RemotePlayer
var placeholder_players: Dictionary = {} ## role_key -> RemotePlayer
var presence_hud: CanvasLayer
var presence_label: Label
var farm_hud: CanvasLayer
var seed_label: Label
var farm_status_label: Label
var _farm_refresh_pending := false
var _farm_refresh_running := false
var _farm_busy := false

func _ready() -> void:
	_sync_object_z()
	if Engine.is_editor_hint():
		return  # 编辑器里只同步遮挡排序,不跑游戏逻辑
	# 行走遮罩只当数据读,不显示:
	walk_img = load("res://assets/farm/walkable_area.png").get_image()
	_build_presence_hud()
	_build_farm_hud()
	_spawn_player()
	_setup_doors()
	_setup_shared_farm()
	_update_seed_label()

func _exit_tree() -> void:
	if not Engine.is_editor_hint() and PresenceChannel != null:
		PresenceChannel.leave_scene("farm")

## 收集两扇门,记录各自参考点(用它们的 SortAnchor 全局位置)。
func _setup_doors() -> void:
	doors.clear()
	for path in DOOR_PATHS:
		var n := get_node_or_null(path) as Sprite2D
		if n == null:
			continue
		n.visible = true  # 门初始为关(可见),点击后开(消失)
		var anchor := n.get_node_or_null("SortAnchor") as Node2D
		var pt: Vector2 = anchor.global_position if anchor != null else n.global_position
		doors.append({"node": n, "point": pt})

func _process(_delta: float) -> void:
	# 编辑器中实时跟随 SortAnchor 拖动;运行时只需 _ready 同步一次,这里跳过省开销
	if Engine.is_editor_hint():
		_sync_object_z()

## 把每个建筑的 z_index 设为它 SortAnchor 的全局 Y。
## 玩家 z = 脚底 Y,二者一比即得正确遮挡:玩家在锚点线之上被挡,之下则挡住建筑。
## 递归遍历 Objects:任何带 SortAnchor 子节点的精灵,z_index = 锚点全局 Y。
## 这样既支持整块建筑(一个锚点),也支持拆成多件的建筑(每件各自一个锚点,
## 如 CowHouse/Shed 与 CowHouse/SouthFence 各管一段深度)。
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
	player.global_position = _find_walkable_start()
	player.add_to_group("player")
	last_safe = player.global_position
	add_child(player)
	# 本地玩家角色:云身份(每用户登录,不可伪造)优先,否则回退本地存档角色
	var mem := get_node_or_null("/root/MemoryManager")
	var local_fallback := str(mem.selected_role_key) if mem != null and mem.selected_role_key != "" else "father"
	var identity := get_node_or_null("/root/GameIdentity")
	var role: String = identity.local_role(local_fallback) if identity != null else local_fallback
	if player.has_method("apply_character"):
		player.apply_character(role)
	_spawn_family(role)
	_setup_presence()

## 其他家庭成员(占位:轻度溜达;联机后由 presence 驱动,见 docs/43)。
func _spawn_family(local_role: String) -> void:
	var db := get_node_or_null("/root/CharacterDB")
	if db == null:
		return
	var local_id: String = db.resolve(local_role)
	# 几个开阔草地落点 + 各自小范围漫步框
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
		rp.global_position = spots[cid][0]
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
	panel.custom_minimum_size = Vector2(330, 70)
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
	box.custom_minimum_size = Vector2(306, 56)
	box.add_theme_constant_override("separation", 2)
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

func _setup_shared_farm() -> void:
	if CloudManager != null and CloudManager.has_signal("cloud_world_changed") \
		and not CloudManager.cloud_world_changed.is_connected(_on_cloud_world_changed):
		CloudManager.cloud_world_changed.connect(_on_cloud_world_changed)
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
	if CloudManager == null or not CloudManager.has_method("load_farm_plots"):
		_set_farm_status("离线农场")
		return
	var rows: Array = CloudManager.load_farm_plots()
	_render_farm_rows(rows)
	_set_farm_status("家庭农场已同步" if _farm_cloud_ready() else "离线农场")

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
	var plot_index := int(row.get("plot_index", -1))
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
		int(row.get("planted_at_unix", 0)))
	crops[plot_index] = crop
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

## 在画面底部中心附近螺旋找一个可走点作为出生位置。
func _find_walkable_start() -> Vector2:
	var spawn_center := Vector2(640, 650)
	for r in range(0, 420, 8):
		for a in range(0, 360, 15):
			var p: Vector2 = spawn_center + Vector2(r, 0).rotated(deg_to_rad(a))
			if _walkable(p):
				return p
	return spawn_center

func _walkable(feet: Vector2) -> bool:
	var x := int(feet.x)
	var y := int(feet.y)
	if x < 0 or y < 0 or x >= walk_img.get_width() or y >= walk_img.get_height():
		return false
	return walk_img.get_pixelv(Vector2i(x, y)).a > 0.3

func _physics_process(_delta: float) -> void:
	if player == null:
		return
	# 玩家移动后做一次脚底采样:不可走则退回上一安全点(用手绘遮罩实现碰撞)
	var feet := player.global_position + FEET_OFFSET
	if _walkable(feet):
		last_safe = player.global_position
	else:
		player.global_position = last_safe
		player.velocity = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k: int = event.keycode
		if k >= KEY_1 and k <= KEY_9:
			selected = (k - KEY_1) % CropDB.CROPS.size()
			_update_seed_label()
			_set_farm_status("已选择 " + _selected_seed_name())
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var click := get_global_mouse_position()
		if _try_doors(click):
			return
		_try_plant(click)

## 点击靠近某扇门、且玩家也走近时,切换门的显隐(开/关门)。返回是否处理了点击。
func _try_doors(click: Vector2) -> bool:
	for d in doors:
		if click.distance_to(d.point) > DOOR_CLICK:
			continue
		if player.global_position.distance_to(d.point) <= DOOR_REACH:
			d.node.visible = not d.node.visible
			AudioManager.play_sfx("开门" if not d.node.visible else "门")
			print("开门" if not d.node.visible else "关门", " ", d.node.name)
		else:
			print("离门太远,走近点再开")
		return true  # 点到门附近就算处理了(不再去种植)
	return false

func _try_plant(click: Vector2) -> void:
	if _farm_busy:
		return
	# 找离点击最近的种植点
	var best := -1
	var best_d := INF
	for i in PLOTS.size():
		var d: float = PLOTS[i].distance_to(click)
		if d < best_d:
			best_d = d
			best = i
	if best == -1 or best_d > CLICK_SNAP:
		return  # 没点在任何种植点附近

	if not _can_reach_plot(best):
		_set_farm_status("再走近一点。")
		return

	# 已有作物:成熟则收获,未熟则提示剩余时间
	if crops.has(best):
		var c: Crop = crops[best]
		if c.is_mature():
			await _harvest_plot(best, c)
		else:
			_set_farm_status("还要 " + _format_wait(c.seconds_until_mature()) + " 才能收获。")
		return

	var data := CropDB.get_crop(selected)
	var crop_id := str(data.get("id", ""))
	# 种植消耗一颗对应种子
	var inv := get_node_or_null("/root/InventoryManager")
	if inv != null:
		if not inv.has("seed_" + crop_id):
			_set_farm_status("没有 " + _item_name("seed_" + crop_id) + "。")
			return
	await _plant_plot(best, data)

func _plant_plot(plot_index: int, data: Dictionary) -> void:
	var crop_id := str(data.get("id", ""))
	var planted_unix := int(Time.get_unix_time_from_system())
	var row := {
		"id": _farm_plot_id(plot_index),
		"plot_index": plot_index,
		"crop_id": crop_id,
		"planted_at": Time.get_datetime_string_from_system(),
		"planted_at_unix": planted_unix,
	}
	_farm_busy = true
	_set_farm_status("正在种下 " + _item_name("seed_" + crop_id) + "...")
	if _farm_cloud_ready() and CloudManager.has_method("save_farm_plot_confirmed"):
		var result: Dictionary = await CloudManager.save_farm_plot_confirmed(row)
		if not bool(result.get("ok", false)):
			_farm_busy = false
			_schedule_farm_refresh("这块地刚被家人使用了。")
			return
	var inv := get_node_or_null("/root/InventoryManager")
	if inv != null:
		inv.take("seed_" + crop_id, 1)
	row["id"] = str(row.get("id", _farm_plot_id(plot_index)))
	_render_farm_row(row)
	_farm_busy = false
	_set_farm_status("种下了 " + _item_name("seed_" + crop_id) + "。")

func _harvest_plot(plot_index: int, c: Crop) -> void:
	var crop_id := _crop_id_of(c)
	var row: Dictionary = crop_rows.get(plot_index, {})
	var row_id := str(row.get("id", _farm_plot_id(plot_index)))
	_farm_busy = true
	_set_farm_status("正在收获 " + _item_name("produce_" + crop_id) + "...")
	if _farm_cloud_ready() and CloudManager.has_method("delete_farm_plot_confirmed"):
		var result: Dictionary = await CloudManager.delete_farm_plot_confirmed(row_id)
		if not bool(result.get("ok", false)):
			_farm_busy = false
			_schedule_farm_refresh("这株作物已经被家人收走了。")
			return
	_harvest(c)
	if c != null and is_instance_valid(c):
		c.queue_free()
	crops.erase(plot_index)
	crop_rows.erase(plot_index)
	_farm_busy = false

func _can_reach_plot(plot_index: int) -> bool:
	return player != null and player.global_position.distance_to(PLOTS[plot_index]) <= PLANT_REACH

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

func _format_wait(seconds: int) -> String:
	if seconds <= 0:
		return "很快"
	var minutes := int(ceil(float(seconds) / 60.0))
	if minutes <= 1:
		return "1 分钟"
	return str(minutes) + " 分钟"

## 收获:产出 1-3 个对应作物进背包,有概率返还一颗种子。
func _harvest(c: Crop) -> void:
	var crop_id := _crop_id_of(c)
	var inv := get_node_or_null("/root/InventoryManager")
	if inv == null or crop_id == "":
		return
	var yield_n := randi_range(1, 3)
	inv.give("produce_" + crop_id, yield_n)
	if randf() < 0.5:
		inv.give("seed_" + crop_id, 1)
	_set_farm_status("收获 " + _item_name("produce_" + crop_id) + " ×" + str(yield_n) + "。")

func _crop_id_of(c: Crop) -> String:
	for d in CropDB.CROPS:
		if int(d.panel) == c.panel and int(d.row) == c.row:
			return str(d.id)
	return ""
