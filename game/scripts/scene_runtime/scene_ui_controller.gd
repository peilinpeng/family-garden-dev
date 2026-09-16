extends "res://scripts/scene_runtime/scene_runtime_module.gd"

## 基础 UI、角色创建与通用面板。
## 仅由 SceneManager 创建；外部代码继续调用 SceneManager 兼容门面。

func _setup_custom_cursor() -> void:
	var arrow = _safe_texture(str(ASSETS.get("cursor_arrow", "")))
	if arrow:
		Input.set_custom_mouse_cursor(arrow, Input.CURSOR_ARROW, Vector2(6, 4))
	var pointer = _safe_texture(str(ASSETS.get("cursor_pointer", "")))
	if pointer:
		Input.set_custom_mouse_cursor(pointer, Input.CURSOR_POINTING_HAND, Vector2(6, 4))

func _build_ui() -> void:
	var root = Control.new()
	ui_root = root
	root.name = "UIRoot"
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = GAME_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	var day_night_clock = TextureRect.new()
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
	_host._add_world_chat_feed(root, Vector2(826, 580), Vector2(382, 60))
	world_chat_input = null
	_host._refresh_world_chat_feed()
	_build_orientation_overlay(root)

func _navigation_dock_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
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

	var background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.10, 0.17, 0.14, 0.98)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orientation_overlay.add_child(background)

	var content = VBoxContainer.new()
	orientation_content = content
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.position = Vector2(-260, -155)
	content.size = Vector2(520, 310)
	content.pivot_offset = content.size * 0.5
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	orientation_overlay.add_child(content)

	var brand = Label.new()
	brand.text = "FAMILY GARDEN · 家庭花园"
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_font_size_override("font_size", 22)
	brand.add_theme_color_override("font_color", Color(0.78, 0.88, 0.72, 0.92))
	content.add_child(brand)

	var rotate_icon = Label.new()
	rotate_icon.text = "↻"
	rotate_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_icon.add_theme_font_size_override("font_size", 72)
	rotate_icon.add_theme_color_override("font_color", Color(0.96, 0.87, 0.62, 1.0))
	content.add_child(rotate_icon)

	var title = Label.new()
	title.text = "请旋转手机"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88, 1.0))
	content.add_child(title)

	var hint = Label.new()
	hint.text = "横屏进入 Family Garden"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.78, 0.84, 0.78, 0.90))
	content.add_child(hint)

func _update_orientation_overlay() -> void:
	if orientation_overlay == null or not is_instance_valid(orientation_overlay):
		return
	var portrait = _is_portrait_size(get_viewport().get_visible_rect().size)
	orientation_overlay.visible = portrait
	if portrait and orientation_content != null and is_instance_valid(orientation_content):
		orientation_content.scale = Vector2(2.0, 2.0)

func _update_viewport_layout() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var frame_margin = Vector2(
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
	var button = Button.new()
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
	var chat = LineEdit.new()
	chat.name = "WorldChatInput"
	chat.placeholder_text = "给家人留一句话..."
	chat.position = pos
	chat.size = box_size
	chat.mouse_filter = Control.MOUSE_FILTER_STOP
	chat.clear_button_enabled = true
	chat.add_theme_font_size_override("font_size", 13)
	chat.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16, 1.0))
	chat.add_theme_color_override("font_placeholder_color", Color(0.38, 0.31, 0.24, 0.68))
	var normal_style = _host._world_chat_input_style(false)
	var focus_style = _host._world_chat_input_style(true)
	chat.add_theme_stylebox_override("normal", normal_style)
	chat.add_theme_stylebox_override("focus", focus_style)
	chat.add_theme_stylebox_override("read_only", normal_style)
	chat.text_submitted.connect(_host._on_world_chat_submitted)
	root.add_child(chat)
	return chat

func _on_ui_button(action: String) -> void:
	match action:
		"family_tree":
			_host._open_family_tree_panel()
		"family_members":
			_host._open_family_members_panel()
		"message_board":
			_host._open_message_board_panel()
		"role_select":
			_show_role_select()
		"toggle_plant":
			plant_mode = not plant_mode
			_host._update_plant_button()
		"plant_family_tree":
			_host._begin_family_tree_placement()
		"global_map":
			_host._show_global_map()
		"travel_map":
			_host._show_travel_map()
		"MemoryManager.postcards":
			_host._open_postcards_panel()
		"world_chat_send":
			if world_chat_input != null and is_instance_valid(world_chat_input):
				_host._send_world_chat_message(world_chat_input.text, world_chat_input)
		"world_chat_history":
			_host._open_world_chat_history_panel()
		"create_memory":
			_host._open_memory_creator()
		"save":
			MemoryManager.save_game()
			_show_toast("已保存。")
		"back_garden":
			_host._show_garden()
		"reset":
			_show_toast("线上版本已关闭重置。")

func _show_role_select() -> void:
	_close_active_panel()
	_host._clear_map_ui()
	_host._clear_world()
	mode = "role_select"
	_current_spawn_key = "default"
	_current_room_id = ""
	_set_hud_context(mode)
	info_label.text = "创建角色"
	_host._add_background()
	var overlay = _create_modal_overlay()
	active_modal = overlay
	var creator: Control = CHARACTER_CREATOR_PANEL_SCRIPT.new()
	overlay.add_child(creator)
	var family_code = CloudManager.family_code() if CloudManager != null and CloudManager.has_method("family_code") else ""
	creator.call("setup", MemoryManager.selected_role_key, MemoryManager.player_display_name, family_code, MemoryManager.character_appearance)
	creator.connect("confirmed", _confirm_character_creation)
	creator.connect("canceled", func() -> void:
		_close_active_panel()
		if MemoryManager.selected_role_key != "":
			_host._show_garden())

func _confirm_character_creation(role_key: String, display_name: String, family_code: String, appearance: Dictionary) -> void:
	MemoryManager.selected_role_key = role_key
	MemoryManager.player_display_name = display_name.strip_edges()
	AppearanceManager.set_current(appearance, role_key)
	_close_active_panel()
	if game_hud != null:
		game_hud.refresh_profile()
	_host._show_garden()
	if StoryManager.consume_quest_intro() and game_hud != null:
		game_hud.start_onboarding_guide()
	var canonical_role: String = CharacterDB.resolve(role_key)
	CloudManager.ensure_cloud_identity(canonical_role, MemoryManager.player_display_name, family_code)

## 旧四卡片选择器保留为兼容参考；新游戏入口使用上面的捏脸面板。

func _show_legacy_role_select() -> void:
	_close_active_panel()
	_host._clear_map_ui()
	_host._clear_world()
	mode = "role_select"
	_current_spawn_key = "default"
	_current_room_id = ""
	_set_hud_context(mode)
	info_label.text = "选择角色"
	_host._add_background()

	var overlay = _create_modal_overlay()
	active_modal = overlay

	var panel = Panel.new()
	panel.position = Vector2(150, 82)
	panel.size = Vector2(980, 550)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)

	var title = Label.new()
	title.text = "Family Garden · 家庭花园"
	title.position = Vector2(40, 28)
	title.size = Vector2(900, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "选择你的身份，和家人一起进入同一座花园。"
	subtitle.position = Vector2(70, 72)
	subtitle.size = Vector2(840, 28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.35, 0.29, 0.22, 0.88))
	panel.add_child(subtitle)

	var name_label = Label.new()
	name_label.text = "显示名字"
	name_label.position = Vector2(360, 112)
	name_label.size = Vector2(260, 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(name_label)

	var name_input = LineEdit.new()
	name_input.placeholder_text = "输入你的名字"
	name_input.text = MemoryManager.player_display_name if MemoryManager.player_display_name != "" else "佩林"
	name_input.position = Vector2(350, 140)
	name_input.size = Vector2(280, 38)
	panel.add_child(name_input)

	var family_label = Label.new()
	family_label.text = "家庭邀请码"
	family_label.position = Vector2(650, 112)
	family_label.size = Vector2(230, 22)
	family_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	family_label.add_theme_font_size_override("font_size", 15)
	family_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(family_label)

	var family_input = LineEdit.new()
	family_input.placeholder_text = "输入家庭邀请码"
	family_input.text = CloudManager.family_code() if CloudManager != null and CloudManager.has_method("family_code") else ""
	family_input.position = Vector2(630, 140)
	family_input.size = Vector2(270, 38)
	panel.add_child(family_input)

	var grid = GridContainer.new()
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
	var card = PanelContainer.new()
	card.custom_minimum_size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# If parent is an absolute-positioned panel, keep compatibility with the old pos argument.
	# If parent is a GridContainer, the container will ignore position and lay the card out cleanly.
	if parent is GridContainer:
		pass
	else:
		card.position = pos
		card.size = card_size

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(1.0, 0.94, 0.80, 0.96)
	card_style.border_color = Color(0.62, 0.44, 0.25, 1.0)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(14)
	card_style.shadow_color = Color(0.20, 0.12, 0.06, 0.20)
	card_style.shadow_size = 7
	card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(card)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 7)
	margin.add_child(vbox)

	var preview = TextureRect.new()
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

	var label = Label.new()
	label.text = str(role_data.get("label", "家人"))
	label.custom_minimum_size = Vector2(card_size.x - 34, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.25, 0.20, 0.15, 1.0))
	vbox.add_child(label)

	var default_name = Label.new()
	default_name.text = str(role_data.get("default_name", "家人"))
	default_name.custom_minimum_size = Vector2(card_size.x - 34, 20)
	default_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	default_name.add_theme_font_size_override("font_size", 13)
	default_name.add_theme_color_override("font_color", Color(0.42, 0.34, 0.25, 0.86))
	vbox.add_child(default_name)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(1, 4)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var choose_btn = Button.new()
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
	_host._show_garden()
	# 首次流程(开场→选角色→进花园)刚走完开场时,自动弹一次 Chapter 1 任务面板
	if StoryManager.consume_quest_intro() and game_hud != null:
		game_hud.start_onboarding_guide()
	# 首次选角色时,若配置了 CloudBase 且本设备还没自助加入过,后台自动注册云身份
	# (不阻塞进花园;角色别名如 girl/papa 转成 CharacterDB 的规范值 player/father 再传)。
	var canonical_role: String = CharacterDB.resolve(role_key)
	var family_code = family_input.text.strip_edges() if family_input != null else ""
	CloudManager.ensure_cloud_identity(canonical_role, MemoryManager.player_display_name, family_code)

func _default_name_for_role(role_key: String) -> String:
	var role_data = _get_role_data(role_key)
	if role_data.is_empty():
		return "家人"
	return str(role_data.get("default_name", "家人"))

func _get_role_data(role_key: String) -> Dictionary:
	for role_data in CHARACTER_DATA:
		if str(role_data.get("role", "")) == role_key:
			return role_data
	return {}

func _current_player_asset_key() -> String:
	var selected_id = CharacterDB.resolve(MemoryManager.selected_role_key) if CharacterDB != null else MemoryManager.selected_role_key
	var role_data = _get_role_data(MemoryManager.selected_role_key)
	if role_data.is_empty():
		for candidate in CHARACTER_DATA:
			var candidate_role = str(candidate.get("role", ""))
			var candidate_id = CharacterDB.resolve(candidate_role) if CharacterDB != null else candidate_role
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
	var sheet = str(character_def.get("sheet", "")).strip_edges()
	if sheet == "":
		return fallback_path
	var configured_path = "res://assets/characters/%s.png" % sheet
	return configured_path if ResourceLoader.exists(configured_path) else fallback_path

func _create_modal_overlay() -> Control:
	var overlay = Control.new()
	overlay.name = "CozyModalOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(overlay)

	var shade = ColorRect.new()
	shade.color = Color(0.10, 0.08, 0.06, 0.20)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	return overlay

func _make_status_label(parent: Control, pos: Vector2, label_size: Vector2, text: String = "") -> Label:
	var label = Label.new()
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
		var message = String((error as Dictionary).get("message", "")).strip_edges()
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
		var created = int(detail.get("created", 0))
		if created > 0 and mode == "garden":
			_host._refresh_current_memory_scene("garden")
			_show_toast("%d 条记忆藤蔓已长出。" % created)
		return
	if workflow != active_ai_workflow:
		return
	if active_ai_status_label == null or not is_instance_valid(active_ai_status_label):
		return
	var message = ""
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
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.96, 0.86, 0.92)
	style.border_color = Color(0.64, 0.48, 0.30, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.20, 0.14, 0.08, 0.16)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)

func _apply_panel_style(panel: Panel) -> void:
	var style = StyleBoxFlat.new()
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
	var button = Button.new()
	button.text = button_text
	button.position = pos
	button.size = button_size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_style(button, false)
	_set_button_icon(button, _icon_key_for_action(action))
	if action == "save_new_place" and args.size() >= 2:
		button.pressed.connect(_host._save_new_place.bind(args[0], args[1]))
	elif action == "save_new_message" and args.size() >= 2:
		button.pressed.connect(_host._save_new_message.bind(args[0], args[1]))
	else:
		button.pressed.connect(_on_panel_button.bind(action))
	parent.add_child(button)
	return button

func _set_button_icon(button: Button, asset_key: String) -> void:
	if asset_key == "":
		return
	var path = str(ASSETS.get(asset_key, ""))
	var texture = _safe_texture(path)
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
		"family_tree", "plant_tree", "plant_family_tree":
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
	var normal_style = _button_style("button_selected" if selected else "button_normal", Color(1.0, 0.92, 0.74, 0.92), Color(0.58, 0.45, 0.30, 1.0))
	var hover_style = _button_style("button_hover", Color(1.0, 0.96, 0.82, 0.96), Color(0.60, 0.48, 0.32, 1.0))
	var pressed_style = _button_style("button_selected", Color(0.86, 0.92, 0.72, 0.98), Color(0.45, 0.58, 0.40, 1.0))
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
	var texture = _safe_texture(str(ASSETS.get(asset_key, "")))
	if texture:
		var tex_style = StyleBoxTexture.new()
		tex_style.texture = texture
		return tex_style
	var style = StyleBoxFlat.new()
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
		_host._show_travel_map()
	elif action == "MemoryManager.postcards":
		_host._open_postcards_panel()
	elif action == "message_board":
		_host._open_message_board_panel()
	elif action == "family_tree":
		_host._open_family_tree_panel()
	elif action == "plant_family_tree":
		_host._begin_family_tree_placement()
	elif action == "add_message":
		_host._open_add_message_form()
	elif action == "fish_again":
		_host._start_fishing_sequence()
	elif action == "open_caught_bottle":
		_host._open_caught_bottle_content()
	elif action == "back_garden":
		_host._show_garden()
	elif action == "enter_kitchen":
		_close_active_panel()
		_show_toast("进入厨房…")
		_host.goto_scene("kitchen")
	elif action.begins_with("enter_room:"):
		var house_id = action.split(":")[1]
		var room_info: Dictionary = _host._get_room_data(house_id)
		_host._enter_house(house_id, str(room_info.get("label", "房间")))
	elif action.begins_with("open_postcard:"):
		_host._open_postcard_detail_from_id(action.split(":")[1])
	elif action.begins_with("delete_place:"):
		_host._delete_place(action.split(":")[1])
	elif action.begins_with("house_note:"):
		_host._open_add_message_form()
	elif action.begins_with("house_photos:"):
		_host._open_postcards_panel()
	elif action.begins_with("generate_room:"):
		_host._on_generate_room(action.split(":")[1])

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
	_host._show_global_map()

func open_travel_map() -> void:
	_host._show_travel_map()

func open_memory_creator() -> void:
	_host._open_memory_creator()

func open_world_chat() -> void:
	_host._open_world_chat_history_panel()

func open_family_tree() -> void:
	_host._open_family_tree_panel()

func open_family_members() -> void:
	_host._open_family_members_panel()

func open_postcards() -> void:
	_host._open_postcards_panel()

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

func _show_toast(toast_text: String) -> void:
	if info_label == null or not is_instance_valid(info_label):
		return   # UI 尚未构建(如启动早期的任务信号),静默跳过
	info_label.text = "家庭花园   —   " + toast_text

func _safe_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _solid_texture(width: int, height: int, color: Color) -> Texture2D:
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
