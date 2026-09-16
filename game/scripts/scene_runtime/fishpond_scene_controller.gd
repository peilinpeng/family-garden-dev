extends "res://scripts/scene_runtime/scene_runtime_module.gd"

## 鱼塘、钓鱼与漂流瓶。
## 仅由 SceneManager 创建；外部代码继续调用 SceneManager 兼容门面。

func _build_fishpond(spawn_key: String = "default") -> void:
	_host.save_current_progress()
	_host._close_active_panel()
	_host._clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	_host._clear_gate4_guide()
	mode = "fishpond"
	_current_spawn_key = spawn_key
	_current_room_id = ""
	_host._set_hud_context(mode)
	adding_place = false
	plant_mode = false
	_host._update_plant_button()
	AudioManager.play_music("fishpond")
	_host._clear_world()
	info_label.text = "爸爸鱼塘"
	var pond_area: Node2D = null
	if ResourceLoader.exists(POND_AREA_SCENE):
		pond_area = (load(POND_AREA_SCENE) as PackedScene).instantiate() as Node2D
		if pond_area != null:
			pond_area.position = GAME_SIZE / 2.0
			world.add_child(pond_area)
	else:
		_host._add_scene_background("fishpond", Color(0.42, 0.62, 0.70, 1.0))  # 占位水色，等 A 出背景
	var spawn: Vector2 = ScenePortal.get_spawn("fishpond", spawn_key)
	var player_parent: Node = world
	var player_spawn = spawn
	if pond_area != null:
		var ysort_objects = pond_area.get_node_or_null("YSortObjects") as Node2D
		if ysort_objects != null:
			player_parent = ysort_objects
			player_spawn = ysort_objects.to_local(spawn)
	_host._add_player(player_spawn, player_parent)
	_scale_fishpond_player_visual()
	_spawn_demo_bottles()
	_register_scene_message_bottle(pond_area)
	_register_pond_fishing_spot(pond_area)
	# 旧版鱼塘记忆花迁移到主花园；鱼塘只保留漂流瓶与钓鱼交互。
	var migrated_memories = MemoryManager.migrate_fishpond_memories_to_garden()
	_fishpond_memories.clear()
	ScenePortal.build_portals("fishpond", world, _host._on_portal_travel)
	_host._show_gate4_scene_guide("fishpond")
	print("[SceneManager] fishpond bottles=", _demo_bottles.size(), " 已迁移主花园记忆=", migrated_memories)

func _scale_fishpond_player_visual() -> void:
	if player == null or not is_instance_valid(player):
		return
	var sprite = player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.scale *= FISHPOND_PLAYER_VISUAL_SCALE
	var shadow = player.get_node_or_null("Shadow") as Sprite2D
	if shadow != null:
		shadow.scale *= 1.15
	var name_label = player.get_node_or_null("NameLabel") as Label
	if name_label != null:
		name_label.position.y = -84.0

func _spawn_demo_bottles() -> void:
	_demo_bottles.clear()
	SlotManager.reset("fishpond")
	SlotManager.load_scene("fishpond")
	for bottle in MemoryManager.get_bottles():
		var slot_id = String(bottle.get("slot_id", ""))
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
		var bid = String(bottle.get("id", ""))
		if not _demo_bottles.any(func(item): return String(item.get("id", "")) == bid):
			_render_bottle_record(bottle)
	_host._show_gate4_scene_guide("fishpond")

func _render_bottle_record(bottle: Dictionary) -> void:
	var slot = SlotManager.get_slot("fishpond", String(bottle.get("slot_id", "")))
	if slot.is_empty():
		return
	var bid = String(bottle.get("id", ""))
	var card = {"node_type": "bottle", "suggested_scene": "fishpond"}
	var node = NodeFactory.make_memory_node(card, slot, _on_bottle_clicked.bind(bid))
	world.add_child(node)
	var view_model = bottle.duplicate(true)
	view_model["node"] = node
	_demo_bottles.append(view_model)

func _register_scene_message_bottle(pond_area: Node2D) -> void:
	if pond_area == null:
		return
	var bottle = pond_area.get_node_or_null("MessageBottle") as Area2D
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
	var fishing_spot = pond_area.get_node_or_null("FishingSpot") as Area2D
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
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay

	var panel = Panel.new()
	panel.position = Vector2(382, 136)
	panel.size = Vector2(516, 392)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)

	var title = Label.new()
	title.text = "正在钓鱼"
	title.position = Vector2(42, 28)
	title.size = Vector2(432, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.20, 0.24, 0.20, 1.0))
	panel.add_child(title)

	var water = ColorRect.new()
	water.position = Vector2(78, 168)
	water.size = Vector2(360, 34)
	water.color = Color(0.34, 0.64, 0.72, 0.42)
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(water)

	var line = Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.45, 0.36, 0.24, 0.78)
	line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = 1
	panel.add_child(line)

	var rod = TextureRect.new()
	rod.position = Vector2(118, 58)
	rod.size = Vector2(88, 172)
	rod.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rod.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rod.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rod.texture = _host._safe_texture(str(ASSETS.get("fishing_rod", "")))
	rod.pivot_offset = Vector2(rod.size.x * 0.46, rod.size.y * 0.86)
	rod.rotation = -0.08
	rod.z_index = 2
	rod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(rod)

	var bobber = TextureRect.new()
	bobber.position = Vector2(292, 139)
	bobber.size = Vector2(28, 54)
	bobber.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bobber.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bobber.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bobber.texture = _host._safe_texture(str(ASSETS.get("fishing_bobber", "")))
	bobber.z_index = 3
	bobber.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bobber)

	var hook_item = TextureRect.new()
	hook_item.position = bobber.position + Vector2(-12, 38)
	hook_item.size = Vector2(52, 52)
	hook_item.visible = false
	hook_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hook_item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hook_item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hook_item.z_index = 4
	hook_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hook_item)

	var update_fishing_line = func() -> void:
		if not is_instance_valid(line) or not is_instance_valid(rod) or not is_instance_valid(bobber):
			return
		var rod_tip_local = Vector2(rod.size.x * 0.76, rod.size.y * 0.05)
		var rod_tip = rod.position + rod.pivot_offset + (rod_tip_local - rod.pivot_offset).rotated(rod.rotation)
		var bobber_top = bobber.position + Vector2(bobber.size.x * 0.5, bobber.size.y * 0.12)
		line.points = PackedVector2Array([rod_tip, bobber_top])
		if is_instance_valid(hook_item):
			hook_item.position = bobber.position + Vector2(-12, 38)
	update_fishing_line.call()

	var ripple = ColorRect.new()
	ripple.position = Vector2(222, 166)
	ripple.size = Vector2(42, 8)
	ripple.color = Color(0.90, 1.0, 0.95, 0.38)
	ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(ripple)

	var status = Label.new()
	status.text = "等浮漂下沉，在绿色区域拉竿，越靠中间越容易钓到鱼"
	status.position = Vector2(58, 216)
	status.size = Vector2(400, 28)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 17)
	status.add_theme_color_override("font_color", Color(0.34, 0.29, 0.22, 1.0))
	panel.add_child(status)

	var track_back = Panel.new()
	track_back.position = Vector2(76, 258)
	track_back.size = Vector2(364, 26)
	track_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track_style = StyleBoxFlat.new()
	track_style.bg_color = Color(0.50, 0.36, 0.24, 0.22)
	track_style.border_color = Color(0.42, 0.30, 0.18, 0.55)
	track_style.set_border_width_all(1)
	track_style.set_corner_radius_all(6)
	track_back.add_theme_stylebox_override("panel", track_style)
	panel.add_child(track_back)

	var sweet_zone = ColorRect.new()
	sweet_zone.position = Vector2(202, 258)
	sweet_zone.size = Vector2(108, 26)
	sweet_zone.color = Color(0.54, 0.76, 0.44, 0.78)
	sweet_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sweet_zone)

	var marker = ColorRect.new()
	marker.position = Vector2(78, 252)
	marker.size = Vector2(8, 38)
	marker.color = Color(0.90, 0.28, 0.18, 1.0)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(marker)

	var pull_btn = Button.new()
	pull_btn.text = "拉竿"
	pull_btn.position = Vector2(198, 318)
	pull_btn.size = Vector2(120, 42)
	pull_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_button_style(pull_btn, false)
	panel.add_child(pull_btn)

	var tween = create_tween()
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

	var marker_tween = create_tween()
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
		var marker_center = marker.position.x + marker.size.x * 0.5
		var target_center = sweet_zone.position.x + sweet_zone.size.x * 0.5
		var distance = absf(marker_center - target_center)
		var hit_zone = marker_center >= sweet_zone.position.x and marker_center <= sweet_zone.position.x + sweet_zone.size.x
		var score = clampf(1.0 - distance / 72.0, 0.0, 1.0) if hit_zone else 0.0
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
				hook_item.texture = _host._safe_texture(str(ASSETS.get(asset_key, "")))
				hook_item.size = Vector2(62, 42) if String(caught_result.get("id", "")) == "branch" else Vector2(52, 52)
				update_fishing_line.call()
		var finish_tween = create_tween()
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
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay

	var panel = Panel.new()
	panel.position = Vector2(402, 184)
	panel.size = Vector2(476, 274)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)

	var title = Label.new()
	title.text = "鱼脱钩了"
	title.position = Vector2(44, 48)
	title.size = Vector2(388, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.20, 0.24, 0.22, 1.0))
	panel.add_child(title)

	var body = Label.new()
	body.text = "拉竿时机偏了，鱼线松了一下，水面只剩一圈涟漪。"
	body.position = Vector2(62, 112)
	body.size = Vector2(352, 64)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.32, 0.27, 0.20, 1.0))
	panel.add_child(body)

	_host._add_panel_button(panel, "再试一次", Vector2(104, 204), Vector2(130, 40), "fish_again")
	_host._add_panel_button(panel, "收起鱼竿", Vector2(258, 204), Vector2(132, 40), "close")

func _open_fishing_result_panel(result: Dictionary = {}) -> void:
	_host._close_active_panel()
	if result.is_empty():
		_open_fishing_failed_panel()
		return
	_award_fishing_result(result)
	var result_color: Color = result.get("color", Color(0.5, 0.5, 0.5, 1.0))
	var overlay = _host._create_modal_overlay()
	active_modal = overlay

	var panel = Panel.new()
	panel.position = Vector2(292, 150)
	panel.size = Vector2(696, 420)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)

	var icon_back = Panel.new()
	icon_back.position = Vector2(42, 82)
	icon_back.size = Vector2(150, 150)
	icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = result_color.lightened(0.35)
	icon_style.border_color = Color(0.52, 0.42, 0.28, 0.72)
	icon_style.set_border_width_all(2)
	icon_style.corner_radius_top_left = 8
	icon_style.corner_radius_top_right = 8
	icon_style.corner_radius_bottom_left = 8
	icon_style.corner_radius_bottom_right = 8
	icon_back.add_theme_stylebox_override("panel", icon_style)
	panel.add_child(icon_back)

	var result_icon = TextureRect.new()
	result_icon.position = Vector2(58, 98)
	result_icon.size = Vector2(118, 118)
	result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_icon.texture = _host._safe_texture(str(ASSETS.get(String(result.get("asset", "")), "")))
	panel.add_child(result_icon)

	var title = Label.new()
	title.text = "钓到了：" + String(result.get("title", "什么东西"))
	title.position = Vector2(228, 78)
	title.size = Vector2(382, 44)
	title.clip_text = true
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.18, 0.24, 0.22, 1.0))
	panel.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "池塘收获"
	subtitle.position = Vector2(230, 126)
	subtitle.size = Vector2(280, 24)
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.48, 0.42, 0.32, 0.92))
	panel.add_child(subtitle)

	var body = Label.new()
	body.text = String(result.get("body", "鱼线从池塘里收了回来。"))
	body.position = Vector2(230, 166)
	body.size = Vector2(398, 118)
	body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	body.clip_text = true
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.25, 0.24, 0.20, 1.0))
	panel.add_child(body)

	if String(result.get("id", "")) == "bottle":
		_host._add_panel_button(panel, "打开", Vector2(282, 334), Vector2(132, 42), "open_caught_bottle")
	else:
		_host._add_panel_button(panel, "再钓一次", Vector2(190, 334), Vector2(150, 42), "fish_again")
		_host._add_panel_button(panel, "收下", Vector2(372, 334), Vector2(126, 42), "close")

func _award_fishing_result(result: Dictionary) -> void:
	var result_id = String(result.get("id", ""))
	if StoryManager != null and StoryManager.has_method("record_fishing_result"):
		StoryManager.record_fishing_result(result_id)
	if result_id != "goldfish":
		return
	var item_id = String(result.get("item_id", "fish_goldfish"))
	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null or not inv.has_method("give"):
		return
	var leftover: int = inv.give(item_id, 1)
	if leftover > 0:
		_host._show_toast("背包已满，金鱼没有放进去。")
	else:
		_host._show_toast("金鱼已放入背包。")

func _open_caught_bottle_content() -> void:
	var bid = "caught_bottle_" + str(Time.get_ticks_msec())
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
	var b = _find_demo_bottle(bid)
	if not b.is_empty():
		_open_bottle_panel(b)

# 漂流瓶问题面板（复用记忆卡片样式）：未答=问题+回答框；已答=显示回答。

func _open_bottle_panel(b: Dictionary) -> void:
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay

	var panel = Panel.new()
	panel.position = Vector2(360, 150)
	panel.size = Vector2(560, 420)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)

	var water_band = ColorRect.new()
	water_band.position = Vector2(0, 0)
	water_band.size = Vector2(560, 64)
	water_band.color = Color(0.72, 0.88, 0.88, 0.28)
	water_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(water_band)

	var title = Label.new()
	title.text = "漂来一个问题"
	title.position = Vector2(34, 24)
	title.size = Vector2(490, 34)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color(0.18, 0.30, 0.38, 1.0))
	panel.add_child(title)

	var q = Label.new()
	q.text = String(b.get("question", ""))
	q.position = Vector2(34, 76)
	q.size = Vector2(492, 70)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.add_theme_font_size_override("font_size", 17)
	q.add_theme_color_override("font_color", Color(0.20, 0.28, 0.26, 1.0))
	panel.add_child(q)

	if String(b.get("state", "floating")) == "floating":
		var input = TextEdit.new()
		input.placeholder_text = "写下这只漂流瓶带来的回忆..."
		input.position = Vector2(34, 160)
		input.size = Vector2(492, 130)
		panel.add_child(input)
		var status = _host._make_status_label(panel, Vector2(34, 294), Vector2(492, 22), "保存后，主花园会收下一朵新的记忆花。")
		_host._add_panel_button(panel, "取消", Vector2(150, 312), Vector2(120, 40), "close")
		var submit = Button.new()
		submit.text = "回答"
		submit.position = Vector2(290, 312)
		submit.size = Vector2(120, 40)
		submit.mouse_filter = Control.MOUSE_FILTER_STOP
		_host._apply_button_style(submit, false)
		submit.pressed.connect(_submit_bottle_answer.bind(String(b.get("id", "")), input, submit, status))
		panel.add_child(submit)
	else:
		var ans_title = Label.new()
		ans_title.text = "你的回答已经收进主花园"
		ans_title.position = Vector2(34, 160)
		ans_title.size = Vector2(492, 22)
		ans_title.add_theme_font_size_override("font_size", 13)
		ans_title.add_theme_color_override("font_color", Color(0.30, 0.45, 0.42, 1.0))
		panel.add_child(ans_title)
		var ans = Label.new()
		ans.text = String(b.get("answer", ""))
		ans.position = Vector2(34, 186)
		ans.size = Vector2(492, 104)
		ans.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ans.add_theme_font_size_override("font_size", 16)
		ans.add_theme_color_override("font_color", Color(0.18, 0.22, 0.20, 1.0))
		panel.add_child(ans)
		_host._add_panel_button(panel, "关闭", Vector2(220, 312), Vector2(120, 40), "close")

func _submit_bottle_answer(bid: String, input: TextEdit, button: Button, status: Label) -> void:
	var b = _find_demo_bottle(bid)
	if b.is_empty():
		return
	var text: String = input.text.strip_edges()
	if text == "":
		_host._set_status(status, "写点什么再回答吧。", true)
		_host._show_toast("写点什么再回答吧～")
		return
	if text.length() > 2000:
		_host._set_status(status, "回答不能超过 2000 个字符。", true)
		return
	_host._set_button_busy(button, "正在保存...")
	_host._set_status(status, "正在把回答保存到主花园...")
	if bid != "scene_bottle":
		var result: Dictionary = await AIWorkflowManager.answer_bottle(bid, text)
		if not bool(result.get("ok", false)):
			_host._set_button_ready(button, "重试回答")
			var message = _host._result_error_message(result, "回答保存失败。")
			_host._set_status(status, message, true)
			_host._show_toast(message)
			return
		_host._close_active_panel()
		_build_fishpond()
		var bottle_message = "这只漂流瓶已经保存过回答。" if bool(result.get("duplicate", false)) else "漂流瓶回答已保存。"
		if bool(result.get("sync_pending", false)):
			bottle_message += " 已保存在本机，联网后会自动同步。"
		_host._show_toast(bottle_message)
		return
	var moderation = await AIClient.moderate_user_content([text], "bottle_answer")
	if String(moderation.get("state", "")) != AIClient.STATE_SUCCESS:
		_host._set_button_ready(button, "重试回答")
		var moderation_message = String(moderation.get("error", {}).get("message", "内容暂时无法通过安全检查。"))
		_host._set_status(status, moderation_message, true)
		_host._show_toast(moderation_message)
		return
	b["answer"] = text
	b["state"] = "opened"
	_host._close_active_panel()
	# 漂流瓶只产生主花园记忆；池塘场景不再实例化记忆花。
	var card = {"title": "鱼塘的回忆", "description": text, "memory_type": "father",
		"suggested_scene": "garden", "question": String(b.get("question", "")),
		"node_type": "memory_flower", "confidence": 1.0, "guess": "与爸爸有关的记忆"}
	var mem = MemoryManager.create_memory(card, "bottle")
	MemoryManager.create_node(String(mem.get("id", "")), "garden", "memory_flower", "garden_archive_flowers")
	MemoryManager.answer_memory(String(mem.get("id", "")), text)
	_host._show_toast("漂流瓶回答已收进主花园的记忆花园。")
