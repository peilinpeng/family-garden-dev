@tool
extends Node2D

## KitchenNew 场景控制器(独立场景,可用 F6 单独运行)。
## 负责:1) 按 Objects 下每个装饰物的 SortAnchor(可在编辑器拖动)设置遮挡排序 z_index
##      2) 用 walkable_area.png 当遮罩,逐像素限制玩家行走范围(碰撞),做法与 farm.gd 一致
##
## @tool:拖动 Objects 下任意装饰物的 SortAnchor 时,编辑器里实时更新遮挡关系。
## walkable_area 在画面上不显示:只当 Image 读,不需要把图加进场景树。

const FEET_OFFSET := Vector2(0, 18)  ## 玩家脚底相对其原点的偏移(同 Player 碰撞体)

## 厨房交互站点:走进 trigger_rect 显示 [E] 提示,按 E 开对应面板(经 GameHUD.open_panel)。
## 坐标是贴着可行走地板放的近似值,后续可在这里微调(单位=1280×720 逻辑像素,rect=[x,y,w,h])。
## GardenEntry(回花园)已由 portals_kitchen.json 的传送门负责,这里不重复。
const STATIONS := [
	{ "id": "stove", "rect": [250, 360, 110, 80], "prompt": "[E] 做饭", "panel": "recipe_stove" },
	{ "id": "prep_table", "rect": [330, 470, 130, 80], "prompt": "[E] 备餐 / 看食谱", "panel": "recipe_prep" },
	{ "id": "fridge", "rect": [390, 360, 110, 80], "prompt": "[E] 查看冰箱", "panel": "board" },
	{ "id": "dining", "rect": [700, 445, 130, 85], "prompt": "[E] 使用餐桌", "panel": "meal" },
	{ "id": "pantry", "rect": [100, 455, 120, 80], "prompt": "[E] 查看储藏", "panel": "pantry" },
]

var walk_img: Image
var player: CharacterBody2D
var last_safe: Vector2
var _stations_inside: Array = []      ## 玩家当前所在的站点 id(可重叠,取最后进入的)
var _prompt_label: Label = null

func _ready() -> void:
	_sync_object_z()
	if Engine.is_editor_hint():
		return  # 编辑器里只同步遮挡排序,不跑游戏逻辑
	AudioManager.play_music("kitchen")  # res://music/kitchen.mp3;同一首曲子重复调用不会重播(AudioManager 内部去重)
	walk_img = load("res://assets/kitchen_new/walkable_area.png").get_image()
	_spawn_player()
	_setup_kitchen_interactions()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_sync_object_z()

## 把每个装饰物的 z_index 设为它 SortAnchor 的全局 Y,与玩家脚底 Y 一比即得正确遮挡。
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
	# 厨房自己 spawn 玩家,把 SceneManager.player 指向它,让 GameHUD 打开面板时的锁移动生效
	# (否则 SceneManager.player 还是上一个场景那个已释放的引用,锁不住厨房玩家)。
	SceneManager.player = player
	# 套用玩家所选角色贴图(同 farm.gd):否则一直是 Player.tscn 里默认的 papa 贴图。
	var mem := get_node_or_null("/root/MemoryManager")
	var local_fallback := str(mem.selected_role_key) if mem != null and mem.selected_role_key != "" else "father"
	var identity := get_node_or_null("/root/GameIdentity")
	var role: String = identity.local_role(local_fallback) if identity != null else local_fallback
	if player.has_method("apply_character"):
		player.apply_character(role)

## 在画面中心附近螺旋找一个可走点作为出生位置。
func _find_walkable_start() -> Vector2:
	for r in range(0, 420, 8):
		for a in range(0, 360, 15):
			var p: Vector2 = Vector2(640, 500) + Vector2(r, 0).rotated(deg_to_rad(a))
			if _walkable(p):
				return p
	return Vector2(640, 500)

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
	_update_prompt()

# ── 厨房交互:站点热点 + [E] 提示 + 开面板 ─────────────────────────────

func _setup_kitchen_interactions() -> void:
	# 站点热点(Area2D):走进显示提示,按 E 开面板。GardenEntry 由现有传送门负责。
	var group := Node2D.new()
	group.name = "Interactables"
	add_child(group)
	for st in STATIONS:
		var r: Array = st["rect"]
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var area := Area2D.new()
		area.name = str(st["id"]).capitalize() + "Area"
		area.monitoring = true
		area.collision_mask = 1   # 主控角色在 layer 1
		area.position = rect.position + rect.size * 0.5
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		area.add_child(shape)
		var sid: String = str(st["id"])
		var ptext: String = str(st["prompt"])
		area.body_entered.connect(func(body: Node) -> void:
			if body.is_in_group("player"):
				_stations_inside.append({ "id": sid, "prompt": ptext, "panel": str(st["panel"]) }))
		area.body_exited.connect(func(body: Node) -> void:
			if body.is_in_group("player"):
				_stations_inside = _stations_inside.filter(func(e): return e.id != sid))
		group.add_child(area)

	# 交互提示 UI(独立 CanvasLayer,不随镜头/染色变化)
	var ui := CanvasLayer.new()
	ui.name = "KitchenUI"
	ui.layer = 4
	add_child(ui)
	var panel := Panel.new()
	panel.name = "InteractionPrompt"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(520, 596)
	panel.size = Vector2(240, 40)
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
	_prompt_label.add_theme_font_size_override("font_size", 16)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90, 1.0))
	panel.add_child(_prompt_label)
	panel.visible = false

func _update_prompt() -> void:
	if _prompt_label == null:
		return
	var host := _prompt_label.get_parent() as Control
	var st := _active_station()
	# 有站点在身边 且 当前没有打开面板时才显示提示
	var show_prompt: bool = not st.is_empty() and not _hud_panel_open()
	host.visible = show_prompt
	if show_prompt:
		_prompt_label.text = str(st.get("prompt", ""))

func _active_station() -> Dictionary:
	if _stations_inside.is_empty():
		return {}
	return _stations_inside[_stations_inside.size() - 1]   # 取最后进入的

func _hud_panel_open() -> bool:
	var hud := SceneManager.game_hud
	return hud != null and hud.has_open_panel()

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_E):
		return
	if _hud_panel_open():
		return
	var st := _active_station()
	if st.is_empty():
		return
	get_viewport().set_input_as_handled()
	_open_station_panel(str(st.get("panel", "")))

func _open_station_panel(panel_key: String) -> void:
	var hud := SceneManager.game_hud
	if hud == null:
		return
	var panel: HUDPanel = null
	match panel_key:
		"recipe_stove":
			var rp := RecipePanel.new()
			rp.station = "stove"
			rp.panel_title = "灶台 · 做饭"
			panel = rp
		"recipe_prep":
			var rp := RecipePanel.new()
			rp.station = "prep_table"
			rp.panel_title = "备餐台 · 备餐"
			panel = rp
		"board":
			panel = KitchenBoardPanel.new()
		"meal":
			panel = MealTablePanel.new()
		"pantry":
			panel = PantryPanel.new()
	if panel != null:
		if _prompt_label != null and _prompt_label.get_parent() is Control:
			(_prompt_label.get_parent() as Control).visible = false
		hud.open_panel(panel)
