extends "res://scripts/scene_runtime/scene_runtime_module.gd"

## 花园引导、场景构建、角色与种植。
## 仅由 SceneManager 创建；外部代码继续调用 SceneManager 兼容门面。

func _clear_gate4_guide() -> void:
	if gate4_guide_card != null and is_instance_valid(gate4_guide_card):
		gate4_guide_card.queue_free()
	gate4_guide_card = null

func _show_gate4_scene_guide(scene_id: String) -> void:
	_clear_gate4_guide()
	var panel = Panel.new()
	panel.name = "Gate4SceneGuide"
	gate4_guide_card = panel
	panel.position = Vector2(1022, 116) if scene_id == "room" else (Vector2(16, 132) if scene_id == "garden" else Vector2(20, 96))
	panel.size = Vector2(226, 76) if scene_id == "room" else (Vector2(244, 184) if scene_id == "garden" and garden_guide_expanded else (Vector2(244, 44) if scene_id == "garden" else Vector2(248, 92)))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_guide_card_style(panel, scene_id)
	if ui_root != null and is_instance_valid(ui_root):
		ui_root.add_child(panel)
	else:
		ui_layer.add_child(panel)

	var accent = ColorRect.new()
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

	var title = Label.new()
	title.text = _gate4_guide_title(scene_id)
	title.position = Vector2(28, 8) if scene_id == "room" else Vector2(28, 10)
	title.size = Vector2(184, 21) if scene_id == "room" else Vector2(202, 22)
	title.add_theme_font_size_override("font_size", 14 if scene_id == "room" else 15)
	title.add_theme_color_override("font_color", Color(0.21, 0.18, 0.13, 0.96))
	panel.add_child(title)

	var body = Label.new()
	body.text = _gate4_guide_body(scene_id)
	body.position = Vector2(28, 31) if scene_id == "room" else Vector2(28, 36)
	body.size = Vector2(184, 36) if scene_id == "room" else Vector2(202, 40)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.33, 0.28, 0.21, 0.90))
	panel.add_child(body)

func _add_garden_guide_title(parent: Control) -> void:
	var title = Label.new()
	title.text = _gate4_guide_title("garden")
	title.position = Vector2(32, 10)
	title.size = Vector2(96, 24)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.21, 0.18, 0.13, 0.96))
	parent.add_child(title)

func _add_garden_guide_compact(parent: Control) -> void:
	var title = Label.new()
	title.text = "新手指引"
	title.position = Vector2(28, 8)
	title.size = Vector2(76, 24)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.21, 0.18, 0.13, 0.96))
	parent.add_child(title)

	var summary = Label.new()
	summary.text = "移动 · 建造 · 撤销"
	summary.position = Vector2(106, 10)
	summary.size = Vector2(92, 21)
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_theme_font_size_override("font_size", 11)
	summary.add_theme_color_override("font_color", Color(0.36, 0.30, 0.20, 0.86))
	parent.add_child(summary)

func _add_garden_beginner_steps(parent: Control) -> void:
	var guide = Label.new()
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
	var family_button = Panel.new()
	family_button.name = "FamilyPortraitMiniature"
	family_button.position = Vector2(252, 8)
	family_button.size = Vector2(32, 28)
	family_button.mouse_filter = Control.MOUSE_FILTER_STOP
	family_button.tooltip_text = "查看家庭成员"
	var family_style = StyleBoxFlat.new()
	family_style.bg_color = Color(0.80, 0.87, 0.63, 0.88)
	family_style.border_color = Color(0.43, 0.31, 0.19, 0.64)
	family_style.set_border_width_all(1)
	family_style.set_corner_radius_all(4)
	family_button.add_theme_stylebox_override("panel", family_style)
	parent.add_child(family_button)

	var count = Label.new()
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
			_host._open_family_members_panel()
	)

func _add_garden_guide_toggle(parent: Control, pos: Vector2, expanded: bool) -> void:
	var toggle = Button.new()
	toggle.text = "-" if expanded else "+"
	toggle.position = pos
	toggle.size = Vector2(26, 28)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.tooltip_text = "收起新手指引" if expanded else "展开新手指引"
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.add_theme_color_override("font_color", Color(0.35, 0.29, 0.19, 0.90))
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.91, 0.87, 0.69, 0.52)
	normal_style.border_color = Color(0.48, 0.37, 0.23, 0.24)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(4)
	var hover_style = normal_style.duplicate()
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
	var inset = Panel.new()
	inset.position = Vector2(5, 5)
	inset.size = parent.size - Vector2(10, 10)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset_style = StyleBoxFlat.new()
	inset_style.bg_color = Color(0, 0, 0, 0)
	inset_style.border_color = Color(1.0, 0.98, 0.88, 0.54)
	inset_style.set_border_width_all(1)
	inset_style.set_corner_radius_all(6)
	inset.add_theme_stylebox_override("panel", inset_style)
	parent.add_child(inset)

	var title_rule = ColorRect.new()
	title_rule.position = Vector2(32, 36)
	title_rule.size = Vector2(190, 1)
	title_rule.color = Color(0.45, 0.58, 0.32, 0.42)
	title_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(title_rule)

func _add_garden_guide_stats(parent: Control) -> void:
	var stats = [
		{"value": _demo_memories.size(), "label": "段记忆"},
		{"value": MemoryManager.get_memory_links("garden").size(), "label": "条藤蔓"},
	]
	for index in range(stats.size()):
		var stat: Dictionary = stats[index]
		var card = Panel.new()
		card.position = Vector2(28 + index * 66, 46)
		card.size = Vector2(60, 46)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.94, 0.90, 0.73, 0.58)
		card_style.border_color = Color(0.53, 0.43, 0.27, 0.18)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(4)
		card.add_theme_stylebox_override("panel", card_style)
		parent.add_child(card)

		var value = Label.new()
		value.text = str(stat.get("value", 0))
		value.position = Vector2(4, 2)
		value.size = Vector2(52, 24)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value.add_theme_font_size_override("font_size", 17)
		value.add_theme_color_override("font_color", Color(0.25, 0.22, 0.15, 0.98))
		card.add_child(value)

		var caption = Label.new()
		caption.text = String(stat.get("label", ""))
		caption.position = Vector2(4, 25)
		caption.size = Vector2(52, 16)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_font_size_override("font_size", 10)
		caption.add_theme_color_override("font_color", Color(0.38, 0.32, 0.21, 0.82))
		card.add_child(caption)

func _apply_guide_card_style(panel: Panel, scene_id: String = "") -> void:
	var style = StyleBoxFlat.new()
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
			var room = MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
			var object_count = 0 if room.is_empty() else MemoryManager.get_room_objects(String(room.get("id", ""))).size()
			return "%s · %d 件物件\n点击家具可调整位置" % [
				_host._room_theme_display_label(String(room.get("room_name", "还没有生成房间"))) if not room.is_empty() else "等待一张房间照片",
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

func _update_plant_button() -> void:
	if plant_button:
		plant_button.text = "种植：开启" if plant_mode else "种植：关闭"
		_host._apply_button_style(plant_button, plant_mode)

func _show_garden(spawn_key: String = "default") -> void:
	_host.save_current_progress()
	_host._close_active_panel()
	_clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	_clear_gate4_guide()
	mode = "garden"
	_current_spawn_key = spawn_key
	_current_room_id = ""
	_host._set_hud_context(mode)
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
	_add_animals()
	var spawn: Vector2 = ScenePortal.get_spawn("garden", spawn_key)
	_add_player(spawn)
	_rebuild_plants()
	_host._spawn_demo_memory_nodes()
	MemoryManager.maybe_recompute_family_portrait()  # 进花园按当前成员/记忆数更新左上迷你合影
	_host._render_family_portrait()
	ScenePortal.build_portals("garden", world, _host._on_portal_travel)
	_setup_garden_builder()
	_host.call_deferred("_offer_family_tree_welcome_gift")
	# 花园统计已合并到左上家庭状态卡，不再叠加第二张“花园今日”。
	if game_hud != null:
		game_hud.refresh_profile()
	if not _garden_controls_hint_shown:
		_garden_controls_hint_shown = true
		_host._show_toast("方向键 / WASD 移动 · 点击花园物件互动")

# 场景层只负责渲染和交互；AI 生成、草稿确认和持久化由 AIClient / AIWorkflowManager / MemoryManager 处理。
# 这里缓存当前场景已渲染的节点 view model，离场后可由数据层重建。

func _clear_world() -> void:
	pond_fishing_available = false
	_host._hide_pond_fishing_prompt()
	var garden_builder = get_node_or_null("/root/GardenBuildManager")
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
		var tiled = (load(GARDEN_TILED_SCENE) as PackedScene).instantiate()
		tiled.name = "GardenTiled"
		world.add_child(tiled)
		_add_season_overlay()
		return

	var texture = _host._safe_texture(ASSETS["background"])
	var sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.name = "SharedGardenBackground"
	sprite.centered = true
	sprite.position = GAME_SIZE / 2.0
	if texture:
		sprite.texture = texture
		var scale_factor = max(GAME_SIZE.x / float(texture.get_width()), GAME_SIZE.y / float(texture.get_height()))
		sprite.scale = Vector2.ONE * scale_factor
	else:
		sprite.texture = _host._solid_texture(1280, 720, Color(0.72, 0.86, 0.62, 1.0))
	world.add_child(sprite)
	_add_season_overlay()

# 分季氛围叠加层（家庭关系温度计）：按跨成员互动数着色，0→春稀疏 / 3-9→夏 / 10+→秋繁茂。
# 半透明叠在背景之上、记忆花之下；无需新美术，A 的分季层定稿后可替换为真层。

func _add_season_overlay() -> void:
	var overlay = ColorRect.new()
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
	var ov = world.get_node_or_null("SeasonOverlay")
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
	var marker = Marker2D.new()
	marker.name = "GardenFromPondSpawnPoint"
	marker.position = ScenePortal.get_spawn("garden", "GardenFromPondSpawnPoint")
	world.add_child(marker)

func _add_core_objects() -> void:
	# 新主花园背景已经包含建筑与邮箱，场景层只补交互热点，避免重复叠图。
	_add_invisible_hotspot("family_tree", Vector2(520, 320), Vector2(180, 130), "tree", "家庭树")
	_add_mailbox_hotspot(Vector2(232, 172), Vector2(80, 80))
	_add_message_board_hotspot(Vector2(1196, 456), Vector2(110, 120))

func _add_mailbox_hotspot(pos: Vector2, hotspot_size: Vector2) -> void:
	var area = Area2D.new()
	area.name = "MailboxHotspot"
	area.position = pos
	area.z_index = 120
	area.input_pickable = true
	area.monitoring = true
	area.monitorable = true

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
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
	var badge_texture: Texture2D = _host._safe_texture(badge_path)
	if badge_texture:
		mailbox_badge.texture = badge_texture
		var target_height: float = 42.0 if MemoryManager.mailbox_alert_state == MemoryManager.MAILBOX_ALERT_LETTER else 28.0
		mailbox_badge.scale = Vector2.ONE * (target_height / float(badge_texture.get_height()))
	else:
		mailbox_badge.texture = _host._solid_texture(28, 28, Color(0.95, 0.10, 0.08, 1.0))
		mailbox_badge.scale = Vector2.ONE

func _on_mailbox_hotspot_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_host._open_mailbox_panel()

func _add_message_board_hotspot(pos: Vector2, hotspot_size: Vector2) -> void:
	var area = Area2D.new()
	area.name = "MessageBoardHotspot"
	area.position = pos
	area.z_index = 120
	area.input_pickable = true
	area.monitoring = true
	area.monitorable = true

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = hotspot_size
	shape.shape = rect
	area.add_child(shape)
	area.input_event.connect(_on_message_board_hotspot_input)
	world.add_child(area)

func _on_message_board_hotspot_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_host._open_message_board_panel()

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
	var root = Node2D.new()
	root.name = node_name
	root.position = pos
	root.z_index = int(pos.y)
	world.add_child(root)
	_add_click_area(root, hotspot_size, action, label_text)
	return root

func _add_animals() -> void:
	animal_nodes.clear()
	for animal_data in ANIMAL_DATA:
		var animal = preload("res://scripts/animal.gd").new()
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
	var builder = get_node_or_null("/root/GardenBuildManager")
	if builder == null or not builder.has_method("setup"):
		return
	# 向栅栏方向开放额外两行 32px 网格；首个完整可画格由 y=320 提前到 y=256。
	var build_area = Rect2(Vector2(80, 236), Vector2(1120, 400))
	builder.call("setup", world, ui_layer, player, build_area, _get_garden_build_blocked_rects())

func _get_garden_build_blocked_rects() -> Array:
	return [
		Rect2(Vector2(0, 0), Vector2(1280, 250)),
		Rect2(Vector2(0, 652), Vector2(1280, 68)),
		Rect2(Vector2(0, 250), Vector2(86, 430)),
		Rect2(Vector2(1194, 250), Vector2(86, 430)),
		# 记忆花圃是默认固定区域，禁止铺地和 DIY 物件覆盖。
		Rect2(Vector2(840, 414), Vector2(180, 142)),
	]

func _add_collision_rect(body_name: String, center: Vector2, size: Vector2) -> StaticBody2D:
	var body = StaticBody2D.new()
	body.name = body_name
	body.position = center
	body.z_index = -20

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	world.add_child(body)
	return body

func _add_player(pos: Vector2, parent_override: Node = null) -> void:
	var asset_key = _host._current_player_asset_key()
	var display_name = MemoryManager.player_display_name if MemoryManager.player_display_name != "" else _host._default_name_for_role(MemoryManager.selected_role_key)
	# 角色贴图网格(hframes/vframes)以 CharacterDB/characters.json 为准,
	# 不同角色的行数可能不一样(如 girl 现在是 3x5,多一行待机眨眼帧)。
	var char_def: Dictionary = CharacterDB.get_def(asset_key)
	var char_hframes: int = int(char_def.get("hframes", 3))
	var char_vframes: int = int(char_def.get("vframes", 4))
	var player_texture_path = _host._character_texture_path(asset_key, str(ASSETS.get(asset_key, "")))
	player = _create_character(display_name, player_texture_path, pos, true, char_hframes, char_vframes)
	player.name = "Player_" + MemoryManager.selected_role_key
	player.add_to_group("player")  # ScenePortal body_entered 仅认 player 组
	var parent = world if parent_override == null else parent_override
	parent.add_child(player)
	# player.gd 的 apply_character() 是唯一处理 frame_rects(非等分网格精确裁切)的地方。
	# 节点入树后再调用，避免从树外访问 /root/CharacterDB。
	if player.has_method("apply_character"):
		player.apply_character(asset_key)
	var parent_canvas = parent as CanvasItem
	if parent_canvas != null and parent_canvas.y_sort_enabled:
		var sort_origin_offset = 18.0
		player.position.y += sort_origin_offset
		for child in player.get_children():
			if child is Node2D:
				(child as Node2D).position.y -= sort_origin_offset
		player.z_index = 0

func _create_character(label_text: String, path: String, pos: Vector2, controllable: bool, hframes: int = 3, vframes: int = 4, frame_rects: Array = [], scale_override: float = -1.0) -> CharacterBody2D:
	var body = CharacterBody2D.new()
	body.position = pos
	body.z_index = int(pos.y)
	body.collision_layer = 1
	body.collision_mask = 1

	var shadow = Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.texture = _host._safe_texture("res://assets/characters/shadow.png")
	shadow.position = Vector2(0, 30)
	shadow.scale = Vector2(0.28, 0.16)
	shadow.modulate = Color(1, 1, 1, 0.8)
	body.add_child(shadow)

	var sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.name = "Sprite2D"
	var texture = _host._safe_texture(path)
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
			var frame_height = float(texture.get_height()) / float(vframes)
			if frame_height > 0.0:
				sprite.scale = Vector2.ONE * (scale_override if scale_override > 0.0 else (82.0 / frame_height))
	else:
		sprite.texture = _host._solid_texture(32, 48, Color(0.92, 0.80, 0.62, 1.0))
		sprite.scale = Vector2(1.6, 1.6)
	body.add_child(sprite)

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(28, 22)
	shape.shape = rect
	shape.position = Vector2(0, 18)
	body.add_child(shape)

	if controllable:
		body.set_script(preload("res://scripts/player.gd"))

	var name_label = Label.new()
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
	var dot = Label.new()
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
	var texture = _host._safe_texture(path)
	var sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.name = node_name
	sprite.centered = true
	sprite.position = pos
	sprite.z_index = int(pos.y + target_height * 0.35)
	if texture:
		sprite.texture = texture
		var scale_factor = target_height / float(texture.get_height())
		sprite.scale = Vector2.ONE * scale_factor
	else:
		sprite.texture = _host._solid_texture(96, 64, Color(0.95, 0.83, 0.58, 1.0))
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
	var root = Node2D.new()
	root.name = node_name
	root.position = pos
	# Draw order is based on the object base: lower objects appear in front.
	root.z_index = int(pos.y + target_height * 0.35)
	world.add_child(root)

	var texture = _host._safe_texture(path)
	var sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	var sprite_size = Vector2(80, 80)
	if texture:
		sprite.texture = texture
		var scale_factor = target_height / float(texture.get_height())
		sprite.scale = Vector2.ONE * scale_factor
		sprite_size = Vector2(texture.get_width() * scale_factor, texture.get_height() * scale_factor)
	else:
		sprite.texture = _host._solid_texture(120, 90, Color(0.94, 0.84, 0.64, 1.0))
		sprite_size = Vector2(120, 90)
	root.add_child(sprite)

	var final_click_size = click_size
	if final_click_size == Vector2.ZERO:
		final_click_size = sprite_size
	_add_click_area(root, final_click_size, action, label_text, click_offset)
	return root

func _add_click_area(parent: Node2D, area_size: Vector2, action: String, label_text: String, offset: Vector2 = Vector2.ZERO) -> void:
	var area = Area2D.new()
	area.name = "ClickArea"
	area.position = offset
	area.input_pickable = true
	area.monitoring = true
	area.monitorable = true
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
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
		_host._open_family_tree_panel()
	elif action.begins_with("house:"):
		var house_id = action.split(":")[1]
		_enter_house(house_id, label_text)
	elif action.begins_with("npc:"):
		var npc_id = action.split(":")[1]
		_host._open_npc_dialog(npc_id, label_text)
	elif action.begins_with("place:"):
		var place_id = action.split(":")[1]
		_host._open_postcard_for_place(place_id)
	elif action.begins_with("animal:"):
		var animal_id = action.split(":")[1]
		_host._open_animal_dialog(animal_id, label_text)

func _show_house_destination_panel() -> void:
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay

	var panel = Panel.new()
	panel.position = Vector2(360, 132)
	panel.size = Vector2(560, 456)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)

	var title = Label.new()
	title.text = "进入小屋"
	title.position = Vector2(34, 28)
	title.size = Vector2(470, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var body = Label.new()
	body.text = "选择要去的室内区域。"
	body.position = Vector2(36, 72)
	body.size = Vector2(480, 26)
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.38, 0.31, 0.24, 0.9))
	panel.add_child(body)

	var kitchen = _host._add_panel_button(panel, "厨房", Vector2(40, 118), Vector2(480, 48), "enter_kitchen")
	_host._apply_button_style(kitchen, true)

	var room_buttons = [
		{"text": "我的房间", "action": "enter_room:player"},
		{"text": "爸爸的房间", "action": "enter_room:father"},
		{"text": "妈妈的房间", "action": "enter_room:mother"},
		{"text": "路易的房间", "action": "enter_room:partner"},
	]
	for i in range(room_buttons.size()):
		var item: Dictionary = room_buttons[i]
		var col = i % 2
		var row = int(i / 2)
		_host._add_panel_button(
			panel,
			str(item.get("text", "")),
			Vector2(40 + col * 250, 188 + row * 66),
			Vector2(230, 46),
			str(item.get("action", "close"))
		)

	_host._add_panel_button(panel, "关闭", Vector2(214, 350), Vector2(132, 40), "close")

func _enter_house(id: String, label_text: String) -> void:
	_host.save_current_progress()
	_host._close_active_panel()
	_clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	_clear_gate4_guide()

	mode = "room"
	_current_spawn_key = "default"
	_current_room_id = id
	_host._set_hud_context(mode)
	adding_place = false
	_clear_world()
	plant_mode = false
	_update_plant_button()

	var room_info: Dictionary = _host._get_room_data(id)
	var room_label: String = str(room_info.get("label", label_text))
	info_label.text = room_label

	var saved_room = MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
	if id == "player" and not saved_room.is_empty() and ROOM_SCENE_GENERATOR.has_scene_schema(saved_room):
		var rendered: Dictionary = ROOM_SCENE_GENERATOR.render_scene(saved_room, world)
		if bool(rendered.get("ok", false)):
			_add_player(ROOM_SCENE_GENERATOR.spawn_position(saved_room, room_info.get("spawn", Vector2(640, 560))))
			_host._render_room("player")
			_host._add_room_hint_panel(room_label, id)
			_show_gate4_scene_guide("room")
			return
		else:
			push_warning("[SceneManager] 语义房间渲染失败: " + str(rendered.get("errors", [])))

	# 样板（增量迁移 §7）：玩家房间用编辑器场景 AnnaRoom.tscn（静态背景+碰撞），
	# 玩家/提示面板/返回流程仍复用代码。其他 3 间保持原过程化构建。
	if id == "player" and ResourceLoader.exists(ANNA_ROOM_SCENE):
		world.add_child((load(ANNA_ROOM_SCENE) as PackedScene).instantiate())
		_add_player(room_info.get("spawn", Vector2(640, 560)))
		_host._render_room("player")  # 渲染已落库的房间家具（关游戏重开仍在）
		_host._add_room_hint_panel(room_label, id)
		_show_gate4_scene_guide("room")
		return

	var room_rect: Rect2 = _host._add_room_background(str(room_info.get("asset", "")))
	_host._add_room_collision_zones(id, room_rect)

	var spawn: Vector2 = room_info.get("spawn", Vector2(640, 560))
	_add_player(spawn)

	# Optional true occlusion layer:
	# If you later add assets/rooms/papa_room_fg.png etc., it will be drawn above the player.
	_host._add_room_foreground_if_exists(str(room_info.get("foreground", "")), room_rect)
	_host._add_room_hint_panel(room_label, id)
	if id == "player":
		_show_gate4_scene_guide("room")

func _add_plant(pos: Vector2, plant_type: String, existing_id: String = "") -> void:
	var is_family_tree = plant_type == "family_tree"
	var family_tree_scale = _family_tree_display_scale()
	if is_family_tree and existing_id == "" and MemoryManager.has_planted_family_tree():
		plant_mode = false
		_update_plant_button()
		_host._show_toast("家庭树已经种在花园里了。")
		return
	var item_id = existing_id if existing_id != "" else (MemoryManager.FAMILY_TREE_ID if is_family_tree else "plant_" + str(Time.get_ticks_msec()))
	var item_data = {
		"id": item_id,
		"type": plant_type,
		"position": pos,
		"display_scale": family_tree_scale if is_family_tree else 0.0,
		"bottom_anchored": is_family_tree,
	}
	var texture_path = "res://assets/garden/" + plant_type + ".png"
	if is_family_tree:
		texture_path = FAMILY_TREE_TEXTURE_PATTERN % MemoryManager.family_tree_stage()
	elif not ResourceLoader.exists(texture_path):
		match plant_type:
			"flower":
				texture_path = "res://assets/pond/decorations/flower_bed.png"
			"tree":
				texture_path = "res://assets/garden/family_tree.png"
			_:
				texture_path = "res://assets/pond/decorations/flower_bed.png"
	var texture = _host._safe_texture(texture_path)
	var item = preload("res://scripts/placeable_item.gd").new()
	item.setup(item_data, texture)
	item.z_index = int(pos.y)
	item.item_deleted.connect(_on_plant_deleted)
	item.item_moved.connect(_on_plant_moved)
	world.add_child(item)
	plant_nodes[item_id] = item

	if existing_id == "":
		MemoryManager.plants.append({"id": item_id, "type": plant_type, "x": pos.x, "y": pos.y})
		if is_family_tree:
			plant_mode = false
			selected_plant_type = "tree"
			_update_plant_button()
			_host._show_toast("家庭树幼苗已经种下。家人互动会陪它一起成长。")

func _rebuild_plants() -> void:
	for plant in MemoryManager.plants:
		_add_plant(Vector2(float(plant.get("x", 640)), float(plant.get("y", 360))), str(plant.get("type", "flower")), str(plant.get("id", "")))

func _on_plant_deleted(item_id: String) -> void:
	if plant_nodes.has(item_id):
		plant_nodes[item_id].queue_free()
		plant_nodes.erase(item_id)
	MemoryManager.plants = MemoryManager.plants.filter(func(p): return str(p.get("id", "")) != item_id)
	MemoryManager.save_game()
	if item_id == MemoryManager.FAMILY_TREE_ID:
		_host._show_toast("家庭树已收回，可以从家庭树面板重新种植。")
	else:
		_host._show_toast("已移除。")

func _on_plant_moved(item_id: String, new_position: Vector2) -> void:
	for p in MemoryManager.plants:
		if str(p.get("id", "")) == item_id:
			p["x"] = new_position.x
			p["y"] = new_position.y
			break
	MemoryManager.save_game()

func _refresh_family_tree_visual() -> void:
	if not plant_nodes.has(MemoryManager.FAMILY_TREE_ID):
		return
	var item: Node = plant_nodes[MemoryManager.FAMILY_TREE_ID]
	if item == null or not is_instance_valid(item) or not item.has_method("set_texture"):
		return
	var texture = _host._safe_texture(FAMILY_TREE_TEXTURE_PATTERN % MemoryManager.family_tree_stage())
	if texture:
		item.set_texture(texture, _family_tree_display_scale(), true)

func _family_tree_display_scale() -> float:
	var index = clampi(MemoryManager.family_tree_stage() - 1, 0, FAMILY_TREE_DISPLAY_SCALES.size() - 1)
	return float(FAMILY_TREE_DISPLAY_SCALES[index])

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
