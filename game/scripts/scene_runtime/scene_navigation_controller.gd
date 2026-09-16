extends "res://scripts/scene_runtime/scene_runtime_module.gd"

## 全局地图、场景路由与传送。
## 仅由 SceneManager 创建；外部代码继续调用 SceneManager 兼容门面。

func _show_global_map() -> void:
	_host.save_current_progress()
	_host._close_active_panel()
	_host._clear_map_ui()
	_host._clear_gate4_guide()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	mode = "global_map"
	_current_spawn_key = "default"
	_current_room_id = ""
	_host._set_hud_context(mode)
	adding_place = false
	plant_mode = false
	_host._update_plant_button()
	_host._clear_world()
	info_label.text = "世界地图"
	AudioManager.play_music("globalmap")
	AudioManager.play_sfx("打开地图")

	# 整张导航页放在固定设计尺寸的 ui_root（在 world 之上），底部导航栏仍由更高层 GameHUD 保持可点。
	var view = Control.new()
	view.name = "GlobalMapView"
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.position = Vector2.ZERO
	view.size = GAME_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 地图严格使用 1280×720 设计画布，并复用 ui_root 的居中定位；不能直接铺满可变宽高的 Viewport。
	ui_root.add_child(view)
	ui_root.move_child(view, 0)
	global_map_ui = view

	# 美术没导入时的柔色兜底。
	var fallback = ColorRect.new()
	fallback.name = "GlobalMapFallback"
	fallback.color = Color(0.80, 0.88, 0.70, 1.0)
	fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(fallback)

	# 拍平底图。
	var bg_tex = _host._safe_texture(ASSETS["globalmap_background"])
	if bg_tex:
		var bg = TextureRect.new()
		bg.name = "GlobalMapBackground"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.texture = bg_tex
		view.add_child(bg)

	var loaded = 0
	for region in GLOBAL_MAP_REGIONS:
		if _add_global_map_region(view, region):
			loaded += 1
	for decoration in GLOBAL_MAP_DECORATIONS:
		_add_global_map_decoration(view, decoration)

	if loaded == 0:
		_host._show_toast("世界地图美术还没导入 — 用 Godot 打开一次项目即可。")
	else:
		_host._show_toast("把鼠标移到某个地点，点击即可进入。")

func _add_global_map_decoration(view: Control, decoration: Dictionary) -> bool:
	var tex = _host._safe_texture(ASSETS[str(decoration["asset"])])
	if tex == null:
		return false
	var layer = TextureRect.new()
	layer.name = "Decoration_" + str(decoration["id"])
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.texture = tex
	view.add_child(layer)
	return true

func _add_global_map_region(view: Control, region: Dictionary) -> bool:
	var tex = _host._safe_texture(ASSETS[str(region["asset"])])
	if tex == null:
		return false

	# 把缩放轴心放在抠图的视觉中心，悬浮“弹起”才是原地放大。
	var img = tex.get_image()
	var pivot: Vector2 = tex.get_size() / 2.0
	if img != null:
		var used = img.get_used_rect()
		pivot = Vector2(used.position) + Vector2(used.size) / 2.0

	# 柔和阴影：同一剪影模糊染黑，平时隐藏，悬浮时出现在图层正下方，模拟被"抬起"投下的影子。
	var shadow = TextureRect.new()
	shadow.name = "Shadow_" + str(region["id"])
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.texture = tex
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.0)
	shadow.pivot_offset = pivot
	var shadow_mat = ShaderMaterial.new()
	shadow_mat.shader = load("res://assets/shaders/soft_shadow_blur.gdshader")
	shadow.material = shadow_mat
	view.add_child(shadow)

	# 可交互抠图本体。click_mask 让只有画上像素的地方响应，透明处穿透到下面的图层。
	var button = TextureButton.new()
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

	var hotspot = Button.new()
	hotspot.name = "Hotspot_" + str(region["id"])
	hotspot.flat = true
	hotspot.text = ""
	hotspot.mouse_filter = Control.MOUSE_FILTER_STOP
	hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rect = Rect2(Vector2.ZERO, GAME_SIZE)
	if img != null:
		var used_rect = img.get_used_rect()
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
		var lift = Vector2(0, -8)
		var t = create_tween().set_parallel(true)
		t.tween_property(button, "position", lift, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(button, "scale", Vector2(1.06, 1.06), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.chain().tween_property(button, "scale", Vector2(1.045, 1.045), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var tint = create_tween()
		tint.tween_property(button, "modulate", Color(1.18, 1.16, 1.1, 1.0), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tint.tween_property(button, "modulate", Color(1.10, 1.09, 1.05, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if is_instance_valid(shadow):
			var st = create_tween().set_parallel(true)
			st.tween_property(shadow, "scale", Vector2(1.10, 1.10), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			st.tween_property(shadow, "modulate", Color(0.0, 0.0, 0.0, 0.38), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			st.tween_property(shadow, "position", Vector2(12, 20), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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
		_host._show_house_destination_panel()
		return
	_host._show_toast("进入%s…" % label_text)
	goto_scene(target)

# 把一个自包含的编辑器场景（Farm.tscn / AnnaRoom.tscn）嵌进持久化的 world。
# 这些场景按 1280×720 屏幕坐标、左上角为原点制作，所以实例放在 (0,0)。

func _build_embedded_scene(scene_key: String, scene_path: String, title: String, fallback_color: Color, add_player: bool) -> void:
	_host._close_active_panel()
	_host._clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	mode = scene_key
	_current_spawn_key = "default"
	_current_room_id = ""
	_host._set_hud_context(mode)
	adding_place = false
	plant_mode = false
	_host._update_plant_button()
	_host._clear_world()
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
		_host._add_player(ScenePortal.get_spawn(scene_key, "default"))

# ── 通用场景切换（ScenePortal 框架）────────────────────────────────
# 所有场景切换的唯一入口。target = garden/fishpond/...；spawn_key = 目标场景出生点。

func goto_scene(target: String, spawn_key: String = "default") -> void:
	_host.save_current_progress()
	AIClient.cancel_all()
	if target == POND_AREA_SCENE:
		_host._build_fishpond(spawn_key)
		return
	if target == "res://scenes/Main.tscn":
		_host._show_garden(spawn_key)
		return

	match target:
		"garden":
			_host._show_garden(spawn_key)
		"fishpond", "pond":
			_host._build_fishpond(spawn_key)
		"farm":
			# Farm.tscn 自带玩家（farm.gd 的 _spawn_player），不要再补一个。
			AudioManager.play_music("farm")
			_build_embedded_scene("farm", FARM_SCENE, "农场", Color(0.74, 0.62, 0.44, 1.0), false)
			ScenePortal.build_portals("farm", world, _on_portal_travel)
		"house":
			_host._show_house_destination_panel()
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
	var timer = get_tree().create_timer(0.4)
	timer.timeout.connect(func() -> void: _travel_lock = false)

# 通用场景背景：优先读 manifest bg 真实美术，缺图回退纯色（fallback_color）。

func _add_scene_background(scene: String, fallback_color: Color) -> void:
	var backdrop = Sprite2D.new()
	backdrop.name = "SceneBackdrop"
	backdrop.centered = true
	backdrop.position = GAME_SIZE / 2.0
	backdrop.z_index = -100
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg_path = "res://assets/%s/scene_%s_bg_01.png" % [scene, scene]
	if ResourceLoader.exists(bg_path):
		var tex: Texture2D = load(bg_path)
		backdrop.texture = tex
		var sx = GAME_SIZE.x / float(tex.get_width())
		var sy = GAME_SIZE.y / float(tex.get_height())
		backdrop.scale = Vector2(sx, sy)
	else:
		backdrop.texture = _host._solid_texture(int(GAME_SIZE.x), int(GAME_SIZE.y), fallback_color)
	world.add_child(backdrop)

# ── 爸爸鱼塘 fishpond ──────────────────────────────────────────────
