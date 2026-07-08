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
const FEET_OFFSET := Vector2(0, 18)  ## 玩家脚底相对其原点的偏移(同 Player 碰撞体)

const DOOR_PATHS := ["Objects/DoorChickenHouse", "Objects/DoorCowHouse"]
const DOOR_REACH := 110.0
const DOOR_CLICK := 44.0

# 畜牧交互点:source_id -> 场景里对应建筑节点(取其 SortAnchor 作为交互坐标)
const LIVESTOCK_NODES := {
	"chicken_coop": "Objects/ChickenHouse/Coop",
	"cow_shed": "Objects/CowHouse/Shed",
}
const LIVESTOCK_REACH := 120.0

var walk_img: Image
var player: CharacterBody2D
var last_safe: Vector2
var crops: Dictionary = {}          ## plot_index -> Crop(视觉)
var doors: Array = []               ## [{node, point}]
var _livestock_points: Dictionary = {}   ## source_id -> Vector2(交互坐标)
var _livestock_ready_icons: Dictionary = {}  ## source_id -> Sprite2D(就绪时冒出的产物图标)
var _prompt_label: Label = null
var _focus: Dictionary = {}         ## 当前就近可交互目标 {kind, ref, action, text}
var _refresh_accum := 0.0

func _ready() -> void:
	_sync_object_z()
	if Engine.is_editor_hint():
		return
	walk_img = load("res://assets/farm/walkable_area.png").get_image()
	_spawn_player()
	_setup_doors()
	_setup_farm_systems()

func _setup_doors() -> void:
	doors.clear()
	for path in DOOR_PATHS:
		var n := get_node_or_null(path) as Sprite2D
		if n == null:
			continue
		n.visible = true
		var anchor := n.get_node_or_null("SortAnchor") as Node2D
		var pt: Vector2 = anchor.global_position if anchor != null else n.global_position
		doors.append({"node": n, "point": pt})

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_sync_object_z()
		return
	_process_game(delta)

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
	# 农场自 spawn 玩家:指向 SceneManager.player,让 GameHUD 开面板时锁移动生效(同 Kitchen)。
	SceneManager.player = player
	var mem := get_node_or_null("/root/MemoryManager")
	var local_fallback := str(mem.selected_role_key) if mem != null and mem.selected_role_key != "" else "father"
	var identity := get_node_or_null("/root/GameIdentity")
	var role: String = identity.local_role(local_fallback) if identity != null else local_fallback
	if player.has_method("apply_character"):
		player.apply_character(role)
	_spawn_family(role)

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
		rp.global_position = spots[cid][0]

func _find_walkable_start() -> Vector2:
	# 出生点必须在"回花园"传送门(trigger_rect y585-615)的内侧(上方),
	# 否则玩家出生在门外、一往上走就踩进触发区被立刻送回花园。
	var spawn_center := Vector2(640, 540)
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
	var feet := player.global_position + FEET_OFFSET
	if _walkable(feet):
		last_safe = player.global_position
	else:
		player.global_position = last_safe
		player.velocity = Vector2.ZERO

# ── 农场玩法:渲染 + 就近交互 ─────────────────────────────

func _setup_farm_systems() -> void:
	# 畜牧交互点坐标(取建筑 SortAnchor 全局位置)+ 就绪图标
	for sid in LIVESTOCK_NODES:
		var node := get_node_or_null(str(LIVESTOCK_NODES[sid])) as Node2D
		if node == null:
			continue
		var anchor := node.get_node_or_null("SortAnchor") as Node2D
		var pt: Vector2 = anchor.global_position if anchor != null else node.global_position
		_livestock_points[sid] = pt
		var def: Dictionary = FarmManager.livestock_def(sid)
		var icon := Sprite2D.new()
		icon.texture = ItemDB.icon_texture(str(def.get("output_item_id", "")))
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = pt + Vector2(0, -70)
		icon.z_index = 4000
		icon.visible = false
		add_child(icon)
		_livestock_ready_icons[sid] = icon

	# 交互提示 UI
	var ui := CanvasLayer.new()
	ui.name = "FarmUI"
	ui.layer = 4
	add_child(ui)
	var panel := Panel.new()
	panel.name = "InteractionPrompt"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(440, 596)
	panel.size = Vector2(400, 40)
	var pbox := StyleBoxFlat.new()
	pbox.bg_color = Color(0.20, 0.15, 0.11, 0.92)
	pbox.border_color = Color(0.95, 0.82, 0.55, 0.8)
	pbox.set_border_width_all(1)
	pbox.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", pbox)
	ui.add_child(panel)
	_prompt_label = Label.new()
	_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 15)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90, 1.0))
	panel.add_child(_prompt_label)
	panel.visible = false

	FarmManager.changed.connect(_render_crops)
	_render_crops()

## 按 FarmManager.plots() 重建所有作物精灵。
func _render_crops() -> void:
	for c in crops.values():
		if is_instance_valid(c):
			c.queue_free()
	crops.clear()
	for p in FarmManager.plots():
		if not (p is Dictionary):
			continue
		var plot: int = int(p.get("plot", -1))
		if plot < 0 or plot >= PLOTS.size():
			continue
		var cd: Dictionary = CropDB.find(str(p.get("crop_id", "")))
		if cd.is_empty():
			continue
		var crop := Crop.new()
		add_child(crop)
		crop.setup(int(cd.panel), int(cd.row), PLOTS[plot])
		crops[plot] = crop
	_refresh_crop_visuals()

## 刷新每株作物的阶段帧 + 浇水/施肥指示(阶段随时间变,低频调用)。
func _refresh_crop_visuals() -> void:
	for plot in crops:
		var crop: Crop = crops[plot]
		if not is_instance_valid(crop):
			continue
		crop.set_stage(FarmManager.stage_of(plot))
		crop.set_watered(FarmManager.is_watered(plot))
		crop.set_fertilized(FarmManager.is_fertilized(plot))
	for sid in _livestock_ready_icons:
		var icon: Sprite2D = _livestock_ready_icons[sid]
		if is_instance_valid(icon):
			icon.visible = FarmManager.livestock_ready(sid)

func _process_game(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= 2.0:
		_refresh_accum = 0.0
		_refresh_crop_visuals()
	_update_focus()

func _update_focus() -> void:
	_focus = {}
	if player == null:
		return
	var pos := player.global_position
	var best_d := INF

	# 畜牧点
	for sid in _livestock_points:
		var d: float = pos.distance_to(_livestock_points[sid])
		if d <= LIVESTOCK_REACH and d < best_d:
			best_d = d
			var def: Dictionary = FarmManager.livestock_def(sid)
			if FarmManager.livestock_ready(sid):
				_focus = {"kind": "livestock", "ref": sid, "action": "collect", "text": "[E] " + str(def.get("interaction_label", "收集"))}
			else:
				var mins: int = int(ceil(FarmManager.cooldown_left(sid) / 60.0))
				_focus = {"kind": "livestock", "ref": sid, "action": "none", "text": "还没有新的产出(约 %d 分钟)" % mins}

	# 种植点(更近则覆盖)
	for i in PLOTS.size():
		var d: float = pos.distance_to(PLOTS[i])
		if d <= PLANT_REACH and d < best_d:
			best_d = d
			_focus = _plot_focus(i)

	# 更新提示
	if _prompt_label != null and _prompt_label.get_parent() is Control:
		var host := _prompt_label.get_parent() as Control
		var visible_now: bool = not _focus.is_empty() and not _hud_panel_open()
		host.visible = visible_now
		if visible_now:
			_prompt_label.text = str(_focus.get("text", ""))

func _plot_focus(plot: int) -> Dictionary:
	if not FarmManager.is_planted(plot):
		return {"kind": "plot", "ref": plot, "action": "plant", "text": "[E] 播种"}
	var crop_name := CropDB.display_name(str(FarmManager.get_plot(plot).get("crop_id", "")))
	if FarmManager.is_mature(plot):
		return {"kind": "plot", "ref": plot, "action": "harvest", "text": "[E] 收获 " + crop_name}
	if not FarmManager.is_watered(plot):
		return {"kind": "plot", "ref": plot, "action": "water", "text": "[E] 浇水（%s·幼苗）" % crop_name}
	if not FarmManager.is_fertilized(plot):
		return {"kind": "plot", "ref": plot, "action": "fertilize", "text": "[E] 施肥（%s·生长中·已浇水）" % crop_name}
	return {"kind": "plot", "ref": plot, "action": "none", "text": "%s · 生长中 · 已浇水 · 已施肥" % crop_name}

func _do_focus_action() -> void:
	if _focus.is_empty() or _hud_panel_open():
		return
	var action := str(_focus.get("action", ""))
	match action:
		"plant":
			_open_seed_panel(int(_focus.get("ref", -1)))
		"water":
			if FarmManager.water(int(_focus.get("ref", -1))):
				AudioManager.play_sfx("按钮")
		"fertilize":
			if FarmManager.fertilize(int(_focus.get("ref", -1))):
				SceneManager._show_toast("施肥完成，收获时 +1 🌿")
		"harvest":
			var plot := int(_focus.get("ref", -1))
			var crop_name := CropDB.display_name(str(FarmManager.get_plot(plot).get("crop_id", "")))
			var n := FarmManager.harvest(plot)
			if n > 0:
				SceneManager._show_toast("收获 %s ×%d 🧺（已入家庭共享仓）" % [crop_name, n])
		"collect":
			var sid := str(_focus.get("ref", ""))
			var def: Dictionary = FarmManager.livestock_def(sid)
			var n := FarmManager.collect(sid)
			if n > 0:
				SceneManager._show_toast("收集到 %s ×%d 🧺" % [ItemDB.display_name(str(def.get("output_item_id", ""))), n])

func _open_seed_panel(plot: int) -> void:
	var hud := SceneManager.game_hud
	if hud == null or plot < 0:
		return
	var panel := SeedSelectionPanel.new()
	panel.target_plot = plot
	hud.open_panel(panel)

func _hud_panel_open() -> bool:
	var hud := SceneManager.game_hud
	return hud != null and hud.has_open_panel()

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# 每帧驱动一次就近焦点(放在输入里省一个 _process 分支;实际焦点在 _process_game 里持续更新)
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).keycode
		if k == KEY_E:
			if not _hud_panel_open():
				get_viewport().set_input_as_handled()
				_do_focus_action()
			return
		if k == KEY_F9:
			if not _hud_panel_open() and SceneManager.game_hud != null:
				SceneManager.game_hud.open_panel(FarmDebugPanel.new())
			return
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_doors(get_global_mouse_position())

func _try_doors(click: Vector2) -> bool:
	for d in doors:
		if click.distance_to(d.point) > DOOR_CLICK:
			continue
		if player.global_position.distance_to(d.point) <= DOOR_REACH:
			d.node.visible = not d.node.visible
			AudioManager.play_sfx("开门" if not d.node.visible else "门")
		return true
	return false
