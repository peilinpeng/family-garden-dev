extends "res://scripts/scene_runtime/scene_runtime_module.gd"

## 房间构建、AI 房间草稿与物件编辑。
## 仅由 SceneManager 创建；外部代码继续调用 SceneManager 兼容门面。

func _get_room_data(house_id: String) -> Dictionary:
	if ROOM_DATA.has(house_id):
		return ROOM_DATA[house_id]

	return {
		"label": "Family Room",
		"asset": "",
		"foreground": "",
		"spawn": Vector2(640, 560),
	}

func _add_room_background(asset_key: String) -> Rect2:
	var backdrop = Sprite2D.new()
	backdrop.name = "RoomBackdrop"
	backdrop.texture = _host._solid_texture(int(GAME_SIZE.x), int(GAME_SIZE.y), Color(0.72, 0.66, 0.54, 1.0))
	backdrop.centered = true
	backdrop.position = GAME_SIZE / 2.0
	backdrop.z_index = -100
	world.add_child(backdrop)

	var texture = _host._safe_texture(str(ASSETS.get(asset_key, "")))
	var room_sprite = Sprite2D.new()
	room_sprite.name = "RoomBackground"
	room_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	room_sprite.centered = true
	room_sprite.position = GAME_SIZE / 2.0
	room_sprite.z_index = -80

	var room_rect = Rect2(Vector2.ZERO, GAME_SIZE)
	if texture:
		room_sprite.texture = texture
		var scale_factor: float = minf(GAME_SIZE.x / float(texture.get_width()), GAME_SIZE.y / float(texture.get_height()))
		room_sprite.scale = Vector2.ONE * scale_factor
		var displayed_size = Vector2(float(texture.get_width()), float(texture.get_height())) * scale_factor
		room_rect = Rect2((GAME_SIZE - displayed_size) * 0.5, displayed_size)
	else:
		room_sprite.texture = _host._solid_texture(1280, 720, Color(0.95, 0.89, 0.78, 1.0))

	world.add_child(room_sprite)
	return room_rect

func _add_room_foreground_if_exists(foreground_asset_key: String, room_rect: Rect2) -> void:
	var foreground_path = str(ASSETS.get(foreground_asset_key, ""))
	if foreground_path == "" or not ResourceLoader.exists(foreground_path):
		return

	var texture = _host._safe_texture(foreground_path)
	if texture == null:
		return

	var sprite = Sprite2D.new()
	sprite.name = "RoomForeground"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = room_rect.position + room_rect.size * 0.5
	sprite.z_index = 3900
	var scale_factor: float = minf(room_rect.size.x / float(texture.get_width()), room_rect.size.y / float(texture.get_height()))
	sprite.scale = Vector2.ONE * scale_factor
	world.add_child(sprite)

func _add_room_hint_panel(room_label: String, house_id: String) -> void:
	var is_player = house_id == "player"
	var panel = Panel.new()
	room_card = panel
	panel.position = Vector2(24, 76)
	panel.size = Vector2(278, 184 if is_player else 146)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_room_card_style(panel)
	ui_layer.add_child(panel)

	var accent = ColorRect.new()
	accent.position = Vector2(0, 14)
	accent.size = Vector2(4, 42)
	accent.color = Color(0.63, 0.43, 0.27, 0.92)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent)

	var title = Label.new()
	title.text = room_label
	title.position = Vector2(18, 11)
	title.size = Vector2(242, 27)
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var body = Label.new()
	if is_player:
		var room = MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
		var object_count = 0 if room.is_empty() else MemoryManager.get_room_objects(String(room.get("id", ""))).size()
		var generated = "AI 布局已生成 · %d 件物件" % object_count if not room.is_empty() and ROOM_SCENE_GENERATOR.has_scene_schema(room) else "%d 件物件已摆放" % object_count
		body.text = "照片生成可确认的布局草稿\n%s" % ("还没有生成 AI 房间" if room.is_empty() else generated)
	else:
		body.text = "在房间里走走看看，返回花园时会保留当前位置。"
	body.position = Vector2(18, 41)
	body.size = Vector2(242, 43 if is_player else 40)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.36, 0.30, 0.23, 0.90))
	panel.add_child(body)

	var btn_y = 144 if is_player else 94
	if is_player:
		var room_action = "管理 AI 房间" if not MemoryManager.get_room_for_user(MemoryManager.selected_role_key).is_empty() else "照片生成房间"
		var primary = _host._add_panel_button(panel, room_action, Vector2(18, 92), Vector2(242, 34), "generate_room:" + house_id)
		_host._apply_button_style(primary, true)
	_host._add_panel_button(panel, "便签", Vector2(18, btn_y), Vector2(72, 30), "house_note:" + house_id)
	_host._add_panel_button(panel, "明信片", Vector2(98, btn_y), Vector2(78, 30), "MemoryManager.postcards")
	_host._add_panel_button(panel, "返回", Vector2(184, btn_y), Vector2(76, 30), "back_garden")

func _apply_room_card_style(panel: Panel) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.94, 0.84, 0.94)
	style.border_color = Color(0.48, 0.33, 0.23, 0.72)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.shadow_color = Color(0.16, 0.10, 0.07, 0.18)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)

# 上传房间照片 → 本地压缩 → 受控上传 → AI 草稿 → 用户确认后布局。

func _on_generate_room(house_id: String) -> void:
	if house_id != "player":
		return
	if not MemoryManager.get_room_for_user(MemoryManager.selected_role_key).is_empty():
		_open_room_management()
		return
	if StoryManager != null and StoryManager.current_chapter() == 3:
		_open_first_room_brief_form()
		return
	_open_room_photo_form()

func _open_first_room_brief_form() -> void:
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay
	var panel = Panel.new()
	panel.position = Vector2(330, 125)
	panel.size = Vector2(620, 470)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)
	var title = Label.new()
	title.text = "生成第一间记忆房间"
	title.position = Vector2(34, 28)
	title.size = Vector2(550, 36)
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)
	var sources = Label.new()
	sources.text = "可用记忆：花园照片、第一顿料理、河边木桥、第一张明信片、第一朵记忆花"
	sources.position = Vector2(34, 78)
	sources.size = Vector2(550, 54)
	sources.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sources.add_theme_font_size_override("font_size", 14)
	sources.add_theme_color_override("font_color", Color(0.48, 0.39, 0.27, 1.0))
	panel.add_child(sources)
	var prompt = TextEdit.new()
	prompt.placeholder_text = "例如：一个有河边晚风感觉的小厨房，温暖、安静，窗边放着一朵花。"
	prompt.text = "一个有河边晚风感觉的小厨房，温暖、安静，窗边放着一朵花。"
	prompt.position = Vector2(34, 145)
	prompt.size = Vector2(552, 150)
	panel.add_child(prompt)
	var status = _host._make_status_label(panel, Vector2(34, 310), Vector2(552, 46), "首次生成会使用少量主线记忆，之后仍可继续布置。")
	var generate = Button.new()
	generate.text = "生成房间"
	generate.position = Vector2(215, 382)
	generate.size = Vector2(190, 44)
	_host._apply_button_style(generate, true)
	generate.pressed.connect(_generate_first_room_from_brief.bind(prompt, generate, status))
	panel.add_child(generate)

func _generate_first_room_from_brief(prompt: TextEdit, button: Button, status: Label) -> void:
	var description = prompt.text.strip_edges()
	if description == "":
		_host._set_status(status, "先写一句你想要的房间感觉。", true)
		return
	_host._set_button_busy(button, "正在生成...")
	_host._set_status(status, "正在把第一段花园生活整理成房间...")
	await get_tree().create_timer(0.45).timeout
	var analysis = AIClient.mock_room_analysis()
	analysis["room_type"] = "kitchen_corner"
	analysis["style"] = "warm_cozy"
	analysis["suggested_room_theme"] = "memory_corner"
	analysis["description"] = description.left(240)
	analysis["objects"] = [
		{"object_type": "desk", "zone": "back_left"},
		{"object_type": "lamp", "zone": "back_right"},
		{"object_type": "photo_wall", "zone": "back_wall"},
		{"object_type": "plant", "zone": "right_side"},
		{"object_type": "chair", "zone": "front_left"},
	]
	var room = RoomLayoutManager.generate(analysis, "first_memory_flower", "story:first_room", {
		"source": "mock",
		"provider": "story_memory",
		"model": "first-room-layout",
		"prompt_version": "chapter3-v1",
		"memory_sources": ["garden_photo", "first_dish", "bridge_place", "first_postcard", "first_memory_flower"],
	})
	if room.is_empty():
		_host._set_button_ready(button, "重新生成")
		_host._set_status(status, "房间布局没有生成成功，请再试一次。", true)
		return
	_host._close_active_panel()
	_host._enter_house("player", "我的房间")
	_host._show_toast("第一间记忆房间已经生成，可以继续移动和摆放物件。")

func _open_room_management() -> void:
	_host._close_active_panel()
	var room = MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
	var overlay = _host._create_modal_overlay()
	active_modal = overlay
	var panel = Panel.new()
	panel.position = Vector2(370, 190)
	panel.size = Vector2(540, 330)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)
	var title = Label.new()
	title.text = "管理我的 AI 房间"
	title.position = Vector2(34, 26)
	title.size = Vector2(460, 34)
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)
	var summary = Label.new()
	var scene_badge = " · 语义室内" if ROOM_SCENE_GENERATOR.has_scene_schema(room) else ""
	summary.text = "%s · %s · %d 件家具%s" % [_room_theme_display_label(String(room.get("room_name", "我的房间"))), _room_style_display_label(String(room.get("style", ""))), MemoryManager.get_room_objects(String(room.get("id", ""))).size(), scene_badge]
	summary.position = Vector2(34, 82)
	summary.size = Vector2(470, 50)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(summary)
	var status = _host._make_status_label(panel, Vector2(34, 142), Vector2(470, 32), "换照片会先生成新预览，确认后才替换当前房间。")
	var reanalyze = Button.new()
	reanalyze.text = "换照片重新分析"
	reanalyze.position = Vector2(70, 188)
	reanalyze.size = Vector2(180, 42)
	_host._apply_button_style(reanalyze, false)
	reanalyze.pressed.connect(_open_room_photo_form)
	panel.add_child(reanalyze)
	var remove = Button.new()
	remove.text = "删除房间"
	remove.position = Vector2(290, 188)
	remove.size = Vector2(180, 42)
	_host._apply_button_style(remove, false)
	remove.pressed.connect(_delete_current_ai_room.bind(remove, status))
	panel.add_child(remove)

func _delete_current_ai_room(button: Button, status: Label) -> void:
	var room = MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
	if room.is_empty():
		return
	if not bool(button.get_meta("confirm_delete_room", false)):
		button.set_meta("confirm_delete_room", true)
		button.text = "再次点击删除"
		_host._set_status(status, "会删除 AI 房间、家具和关联照片；这个操作不能撤销。", true)
		return
	_host._set_button_busy(button, "正在删除...")
	_host._set_status(status, "正在删除房间和临时照片...")
	var source_id = String(room.get("source_memory_id", ""))
	MemoryManager.delete_room(String(room.get("id", "")))
	if source_id != "":
		MemoryManager.delete_memory(source_id)
	_host._close_active_panel()
	_host._enter_house("player", "我的房间")
	_host._show_toast("AI 房间及照片已删除。")

func _open_room_photo_form() -> void:
	_host._reset_selected_photo_state()
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay
	var panel = Panel.new()
	panel.position = Vector2(330, 135)
	panel.size = Vector2(620, 450)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)
	var title = Label.new()
	title.text = "用照片生成我的房间"
	title.position = Vector2(34, 26)
	title.size = Vector2(550, 34)
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)
	var info = Label.new()
	info.text = "支持 JPEG、PNG、WebP，原图不超过 12 MB。确认布局前不会创建房间。"
	info.position = Vector2(34, 78)
	info.size = Vector2(550, 54)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(info)
	var choose = Button.new()
	choose.text = "选择房间照片"
	choose.position = Vector2(34, 160)
	choose.size = Vector2(180, 42)
	_host._apply_button_style(choose, false)
	choose.pressed.connect(_host._choose_photo_for_place)
	panel.add_child(choose)
	selected_photo_label = Label.new()
	selected_photo_label.text = "未选择照片"
	selected_photo_label.position = Vector2(230, 168)
	selected_photo_label.size = Vector2(350, 28)
	panel.add_child(selected_photo_label)
	var status = _host._make_status_label(panel, Vector2(34, 226), Vector2(550, 52), "选择照片后会先在本机压缩，再安全上传给 AI 分析。")
	var analyze = Button.new()
	analyze.text = "上传并分析"
	analyze.position = Vector2(210, 310)
	analyze.size = Vector2(200, 44)
	_host._apply_button_style(analyze, false)
	analyze.pressed.connect(_analyze_selected_room_photo.bind(analyze, status))
	panel.add_child(analyze)

func _analyze_selected_room_photo(button: Button, status: Label) -> void:
	var photo = _host._selected_gate4_photo()
	if (photo.get("bytes", PackedByteArray()) as PackedByteArray).is_empty():
		_host._set_status(status, "请先选择一张房间照片。", true)
		_host._show_toast("请先选择一张房间照片。")
		return
	_host._set_button_busy(button, "分析中...")
	_host._watch_ai_workflow("room", status, "正在准备房间照片...")
	var draft: Dictionary = await AIWorkflowManager.prepare_room_draft(photo.get("bytes", PackedByteArray()), String(photo.get("content_type", "")))
	if not bool(draft.get("ok", false)):
		_host._set_button_ready(button, "重试分析")
		var message = _host._result_error_message(draft, "房间分析失败。")
		_host._set_status(status, message, true)
		_host._show_toast(message)
		_host._clear_ai_workflow_watch(status)
		return
	_host._clear_ai_workflow_watch(status)
	_open_room_draft_preview(draft)

func _open_room_draft_preview(draft: Dictionary) -> void:
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay
	var panel = Panel.new()
	panel.position = Vector2(250, 64)
	panel.size = Vector2(780, 592)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)
	var analysis: Dictionary = draft.get("analysis", {})

	var title = Label.new()
	title.name = "RoomDraftTitle"
	title.text = "语义房间预览" + (" · 示例回退布局" if bool(draft.get("used_fallback", false)) else "")
	title.position = Vector2(34, 24)
	title.size = Vector2(666, 34)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.25, 0.20, 0.14, 1.0))
	panel.add_child(title)

	var description_card = Panel.new()
	description_card.name = "RoomDraftDescriptionCard"
	description_card.position = Vector2(34, 72)
	description_card.size = Vector2(712, 84)
	description_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var description_style = StyleBoxFlat.new()
	description_style.bg_color = Color(1.0, 0.92, 0.72, 0.42)
	description_style.border_color = Color(0.72, 0.52, 0.30, 0.42)
	description_style.set_border_width_all(1)
	description_style.set_corner_radius_all(9)
	description_card.add_theme_stylebox_override("panel", description_style)
	panel.add_child(description_card)

	var description = Label.new()
	description.name = "RoomDraftDescription"
	description.text = String(analysis.get("description", ""))
	if description.text.strip_edges() == "":
		description.text = "AI 已完成房间结构识别，请检查下方的家具与摆放区域。"
	description.position = Vector2(16, 12)
	description.size = Vector2(680, 60)
	description.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	description.max_lines_visible = 3
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", Color(0.33, 0.27, 0.20, 0.94))
	description_card.add_child(description)

	var layout: Dictionary = draft.get("layout", {})
	var layout_objects: Array = layout.get("objects", [])
	var object_lines: Array[String] = []
	for object in layout_objects:
		object_lines.append("• %s → %s" % [_room_object_display_label(String(object.get("object_type", ""))), _zone_display_label(String(object.get("zone", "")))])
	if object_lines.is_empty():
		object_lines.append("没有可安全摆放的家具。")

	_add_room_preview_map(panel, Vector2(34, 176), Vector2(414, 246), layout_objects, layout.get("scene_schema", {}))

	var objects_card = Panel.new()
	objects_card.name = "RoomDraftObjectCard"
	objects_card.position = Vector2(466, 176)
	objects_card.size = Vector2(280, 246)
	objects_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var objects_style = StyleBoxFlat.new()
	objects_style.bg_color = Color(1.0, 0.96, 0.84, 0.76)
	objects_style.border_color = Color(0.61, 0.45, 0.28, 0.48)
	objects_style.set_border_width_all(1)
	objects_style.set_corner_radius_all(9)
	objects_card.add_theme_stylebox_override("panel", objects_style)
	panel.add_child(objects_card)

	var objects_title = Label.new()
	objects_title.text = "家具清单 · %d 件" % layout_objects.size()
	objects_title.position = Vector2(16, 13)
	objects_title.size = Vector2(248, 26)
	objects_title.add_theme_font_size_override("font_size", 15)
	objects_title.add_theme_color_override("font_color", Color(0.31, 0.24, 0.17, 1.0))
	objects_card.add_child(objects_title)

	var objects_scroll = ScrollContainer.new()
	objects_scroll.name = "RoomDraftObjectScroll"
	objects_scroll.position = Vector2(12, 48)
	objects_scroll.size = Vector2(256, 184)
	objects_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	objects_card.add_child(objects_scroll)

	var objects_list = VBoxContainer.new()
	objects_list.name = "RoomDraftObjectList"
	objects_list.custom_minimum_size = Vector2(236, 0)
	objects_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objects_list.add_theme_constant_override("separation", 8)
	objects_scroll.add_child(objects_list)
	for line in object_lines:
		var object_label = Label.new()
		object_label.text = line
		object_label.custom_minimum_size = Vector2(232, 26)
		object_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		object_label.add_theme_font_size_override("font_size", 14)
		object_label.add_theme_color_override("font_color", Color(0.32, 0.26, 0.19, 0.94))
		objects_list.add_child(object_label)

	var meta: Dictionary = draft.get("generation_meta", {})
	var ai_badge = Panel.new()
	ai_badge.name = "RoomDraftAIBadge"
	ai_badge.position = Vector2(34, 440)
	ai_badge.size = Vector2(712, 38)
	ai_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.82, 0.90, 0.68, 0.36)
	badge_style.border_color = Color(0.45, 0.58, 0.34, 0.48)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(8)
	ai_badge.add_theme_stylebox_override("panel", badge_style)
	panel.add_child(ai_badge)

	var attribution = Label.new()
	attribution.name = "RoomDraftAIAttribution"
	attribution.text = "由 %s 生成" % _room_ai_display_label(meta)
	attribution.position = Vector2(14, 8)
	attribution.size = Vector2(330, 22)
	attribution.add_theme_font_size_override("font_size", 12)
	attribution.add_theme_color_override("font_color", Color(0.27, 0.40, 0.23, 0.96))
	ai_badge.add_child(attribution)

	var safety_hint = Label.new()
	safety_hint.text = "家具坐标由游戏安全布局生成"
	safety_hint.position = Vector2(356, 8)
	safety_hint.size = Vector2(340, 22)
	safety_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	safety_hint.add_theme_font_size_override("font_size", 12)
	safety_hint.add_theme_color_override("font_color", Color(0.38, 0.34, 0.27, 0.80))
	ai_badge.add_child(safety_hint)

	var status = _host._make_status_label(panel, Vector2(34, 492), Vector2(712, 28), "这是预览草稿；确认后才会创建或替换可探索的语义房间。")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cancel = Button.new()
	cancel.text = "放弃草稿"
	cancel.position = Vector2(166, 532)
	cancel.size = Vector2(190, 42)
	_host._apply_button_style(cancel, false)
	cancel.pressed.connect(_host._discard_draft_and_close.bind(draft))
	panel.add_child(cancel)
	var confirm = Button.new()
	confirm.text = "确认布局"
	confirm.position = Vector2(424, 532)
	confirm.size = Vector2(190, 42)
	_host._apply_button_style(confirm, true)
	confirm.pressed.connect(_commit_room_preview.bind(draft, confirm, status))
	panel.add_child(confirm)

func _room_ai_display_label(meta: Dictionary) -> String:
	var model = String(meta.get("model", "")).strip_edges()
	var source = String(meta.get("source", "")).strip_edges().to_lower()
	if source == "mock" or model.to_lower().contains("mock"):
		return "本地模拟 AI"
	match model.to_lower():
		"hy-vision-2.0-instruct":
			return "腾讯混元 HY Vision 2.0"
		"hunyuan-vision":
			return "腾讯混元视觉模型"
		"":
			return "AI"
		_:
			return model

func _add_room_preview_map(parent: Control, pos: Vector2, map_size: Vector2, objects: Array, schema: Dictionary = {}) -> void:
	var map = Panel.new()
	map.name = "RoomPreviewMap"
	map.position = pos
	map.size = map_size
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.94, 0.88, 0.76, 0.78)
	style.border_color = Color(0.55, 0.40, 0.26, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	map.add_theme_stylebox_override("panel", style)
	parent.add_child(map)
	if not schema.is_empty():
		_add_room_schema_preview(map, map_size, schema)
		return

	var zones = {
		"back_wall": Rect2(18, 14, 298, 28),
		"back_left": Rect2(28, 58, 82, 34),
		"back_center": Rect2(126, 58, 82, 34),
		"back_right": Rect2(224, 58, 82, 34),
		"left_side": Rect2(28, 110, 72, 44),
		"right_side": Rect2(234, 110, 72, 44),
		"front_left": Rect2(46, 168, 74, 28),
		"front_center": Rect2(130, 168, 74, 28),
		"front_right": Rect2(214, 168, 74, 28),
		"floor_center": Rect2(122, 112, 90, 40),
	}
	var zone_counts: Dictionary = {}
	for object in objects:
		var zone = String((object as Dictionary).get("zone", "")) if object is Dictionary else ""
		zone_counts[zone] = int(zone_counts.get(zone, 0)) + 1

	for zone_key in zones.keys():
		var rect: Rect2 = zones[zone_key]
		var tile = ColorRect.new()
		tile.position = rect.position
		tile.size = rect.size
		tile.color = Color(0.72, 0.60, 0.44, 0.22 + minf(0.28, float(zone_counts.get(zone_key, 0)) * 0.12))
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map.add_child(tile)
		if zone_counts.has(zone_key):
			var mark = Label.new()
			mark.text = str(zone_counts[zone_key])
			mark.position = rect.position + rect.size * 0.5 - Vector2(8, 10)
			mark.size = Vector2(16, 20)
			mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mark.add_theme_font_size_override("font_size", 13)
			mark.add_theme_color_override("font_color", Color(0.24, 0.18, 0.12, 0.95))
			map.add_child(mark)

	var title = Label.new()
	title.text = "布局小地图"
	title.position = Vector2(16, 184)
	title.size = Vector2(140, 18)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.42, 0.32, 0.22, 0.78))
	map.add_child(title)

func _add_room_schema_preview(map: Control, map_size: Vector2, schema: Dictionary) -> void:
	var grid: Array = schema.get("grid_size", [34, 22])
	var grid_size = Vector2(maxf(1.0, float(grid[0])), maxf(1.0, float(grid[1]))) if grid.size() >= 2 else Vector2(34, 22)
	var scale = minf((map_size.x - 28.0) / grid_size.x, (map_size.y - 34.0) / grid_size.y)
	var origin = Vector2(14, 12)
	var floor = ColorRect.new()
	floor.position = origin
	floor.size = grid_size * scale
	floor.color = Color(0.86, 0.72, 0.52, 0.42)
	floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(floor)
	var wall = ColorRect.new()
	wall.position = origin
	wall.size = Vector2(grid_size.x * scale, 2.0 * scale)
	wall.color = Color(0.56, 0.44, 0.34, 0.40)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(wall)
	for raw in schema.get("objects", []):
		if not (raw is Dictionary):
			continue
		var obj: Dictionary = raw
		var cell: Array = obj.get("cell", [0, 0])
		var size: Array = obj.get("size", [1, 1])
		if cell.size() < 2 or size.size() < 2:
			continue
		var marker = ColorRect.new()
		marker.position = origin + Vector2(float(cell[0]), float(cell[1])) * scale
		marker.size = Vector2(maxf(1.0, float(size[0]) * scale), maxf(1.0, float(size[1]) * scale))
		marker.color = _room_preview_color(String(obj.get("id", "")))
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map.add_child(marker)
	var title = Label.new()
	title.text = "语义网格"
	title.position = Vector2(16, 184)
	title.size = Vector2(140, 18)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.42, 0.32, 0.22, 0.78))
	map.add_child(title)

func _room_preview_color(object_id: String) -> Color:
	match object_id:
		"bed":
			return Color(0.58, 0.72, 0.86, 0.72)
		"desk":
			return Color(0.64, 0.46, 0.30, 0.72)
		"lamp":
			return Color(0.98, 0.78, 0.34, 0.76)
		"plant":
			return Color(0.42, 0.68, 0.40, 0.74)
		"photo_wall":
			return Color(0.74, 0.54, 0.86, 0.68)
		"chair":
			return Color(0.50, 0.60, 0.74, 0.72)
		_:
			return Color(0.74, 0.60, 0.42, 0.68)

func _room_object_display_label(object_type: String) -> String:
	match object_type:
		"desk":
			return "书桌"
		"bed":
			return "床"
		"bookshelf":
			return "书架"
		"lamp":
			return "灯"
		"plant":
			return "绿植"
		"photo_wall":
			return "照片墙"
		"chair":
			return "椅子"
		"sofa":
			return "沙发"
		"rug":
			return "地毯"
		"table":
			return "小桌"
		_:
			return object_type

func _room_theme_display_label(theme_key: String) -> String:
	match theme_key:
		"study_corner":
			return "温暖学习角"
		"memory_corner":
			return "记忆角落"
		"cozy_bedroom":
			return "温暖卧室"
		_:
			return theme_key.replace("_", " ")

func _room_style_display_label(style_key: String) -> String:
	match style_key:
		"warm_cozy":
			return "温暖舒适"
		"minimal":
			return "简洁"
		"vintage":
			return "怀旧"
		_:
			return style_key.replace("_", " ")

func _zone_display_label(zone: String) -> String:
	match zone:
		"back_wall":
			return "后墙"
		"back_left":
			return "后左"
		"back_center":
			return "后中"
		"back_right":
			return "后右"
		"left_side":
			return "左侧"
		"right_side":
			return "右侧"
		"front_left":
			return "前左"
		"front_center":
			return "前中"
		"front_right":
			return "前右"
		"floor_center":
			return "地面中心"
		_:
			return zone

func _commit_room_preview(draft: Dictionary, button: Button, status: Label) -> void:
	_host._set_button_busy(button, "正在保存...")
	_host._set_status(status, "正在写入房间和家具位置...")
	var result: Dictionary = await AIWorkflowManager.commit_room_draft(draft)
	if not bool(result.get("ok", false)):
		_host._set_button_ready(button, "确认布局")
		var message = _host._result_error_message(result, "房间保存失败。")
		_host._set_status(status, message, true)
		_host._show_toast(message)
		return
	_host._close_active_panel()
	_host._enter_house("player", "我的房间")
	_host._show_toast("房间生成好了，联网后会自动同步。" if bool(result.get("sync_pending", false)) else "房间生成好了。")

# 渲染玩家房间已落库的家具（重入/重启后重建）。

func _render_room(house_id: String) -> void:
	_room_objects.clear()
	if house_id != "player":
		return
	var room = MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
	if room.is_empty():
		return
	var n = RoomLayoutManager.render(String(room.get("id", "")), world, _on_room_object_clicked)
	print("[SceneManager] room 家具 rendered=", n, " zone 用量=", ZoneManager.usage("room"))

func _on_room_object_clicked(obj_id: String) -> void:
	for o in MemoryManager.room_objects:
		if o is Dictionary and String(o.get("id", "")) == obj_id:
			_open_room_object_editor(o)
			return
	_host._show_toast("房间里的物件")

func _open_room_object_editor(object: Dictionary) -> void:
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay
	var panel = Panel.new()
	panel.position = Vector2(400, 190)
	panel.size = Vector2(480, 350)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)
	var title = Label.new()
	title.text = "调整家具：" + String(object.get("object_type", "物件"))
	title.position = Vector2(30, 26)
	title.size = Vector2(400, 34)
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)
	var zone_select = OptionButton.new()
	zone_select.position = Vector2(30, 100)
	zone_select.size = Vector2(420, 40)
	var zones: Array = ["back_wall"] if String(object.get("object_type", "")) == "photo_wall" else AIContractValidator.ROOM_ZONES.filter(func(zone): return zone != "back_wall")
	for zone in zones:
		zone_select.add_item(String(zone))
		zone_select.set_item_metadata(zone_select.item_count - 1, String(zone))
		if String(zone) == String(object.get("zone", "")):
			zone_select.select(zone_select.item_count - 1)
	panel.add_child(zone_select)
	var status = _host._make_status_label(panel, Vector2(30, 154), Vector2(420, 34), "选择一个区域后保存；如果没有空位，可以换一个区域。")
	var move = Button.new()
	move.text = "移动到所选区域"
	move.position = Vector2(40, 210)
	move.size = Vector2(180, 42)
	_host._apply_button_style(move, false)
	move.pressed.connect(_move_room_object.bind(String(object.get("id", "")), zone_select, move, status))
	panel.add_child(move)
	var remove = Button.new()
	remove.text = "删除这件家具"
	remove.position = Vector2(260, 210)
	remove.size = Vector2(180, 42)
	_host._apply_button_style(remove, false)
	remove.pressed.connect(_delete_room_object.bind(String(object.get("id", "")), remove, status))
	panel.add_child(remove)

func _move_room_object(object_id: String, zone_select: OptionButton, button: Button, status: Label) -> void:
	_host._set_button_busy(button, "正在移动...")
	if not RoomLayoutManager.move_object(object_id, String(zone_select.get_selected_metadata())):
		_host._set_button_ready(button, "移动到所选区域")
		var message = "这个区域没有合适的空位，请换一个区域。"
		_host._set_status(status, message, true)
		_host._show_toast(message)
		return
	_host._close_active_panel()
	_host._enter_house("player", "我的房间")
	_host._show_toast("家具位置已更新。")

func _delete_room_object(object_id: String, button: Button, status: Label) -> void:
	if not bool(button.get_meta("confirm_delete_object", false)):
		button.set_meta("confirm_delete_object", true)
		button.text = "再次点击删除"
		_host._set_status(status, "会删除这件家具，房间里的其他家具不受影响。", true)
		return
	if MemoryManager.delete_room_object(object_id):
		_host._close_active_panel()
		_host._enter_house("player", "我的房间")
		_host._show_toast("家具已删除。")

func _add_room_collision_zones(room_id: String, room_rect: Rect2) -> void:
	# Block the empty area outside the visible room image.
	_add_room_outer_boundaries(room_rect)

	# Common wall strips inside the room.
	_add_room_block(room_rect, "room_top_wall", Rect2(Vector2(0.00, 0.00), Vector2(1.00, 0.08)))
	_add_room_block(room_rect, "room_bottom_wall", Rect2(Vector2(0.00, 0.965), Vector2(1.00, 0.04)))
	_add_room_block(room_rect, "room_left_wall", Rect2(Vector2(0.00, 0.00), Vector2(0.025, 1.00)))
	_add_room_block(room_rect, "room_right_wall", Rect2(Vector2(0.975, 0.00), Vector2(0.025, 1.00)))

	match room_id:
		"father":
			_add_room_block(room_rect, "papa_bed", Rect2(Vector2(0.05, 0.06), Vector2(0.35, 0.24)))
			_add_room_block(room_rect, "papa_shelf", Rect2(Vector2(0.45, 0.07), Vector2(0.38, 0.13)))
			_add_room_block(room_rect, "papa_bath", Rect2(Vector2(0.05, 0.70), Vector2(0.32, 0.22)))
			_add_room_block(room_rect, "papa_lower_furniture", Rect2(Vector2(0.55, 0.70), Vector2(0.35, 0.22)))
			_add_room_block(room_rect, "papa_side_stairs", Rect2(Vector2(0.44, 0.38), Vector2(0.12, 0.24)))
		"mother":
			_add_room_block(room_rect, "mama_bed", Rect2(Vector2(0.05, 0.05), Vector2(0.28, 0.25)))
			_add_room_block(room_rect, "mama_greenhouse", Rect2(Vector2(0.58, 0.04), Vector2(0.34, 0.28)))
			_add_room_block(room_rect, "mama_lower_bath", Rect2(Vector2(0.05, 0.70), Vector2(0.28, 0.22)))
			_add_room_block(room_rect, "mama_wardrobe", Rect2(Vector2(0.65, 0.45), Vector2(0.28, 0.22)))
		"partner":
			_add_room_block(room_rect, "louis_camera_wall", Rect2(Vector2(0.04, 0.06), Vector2(0.44, 0.22)))
			_add_room_block(room_rect, "louis_greenhouse", Rect2(Vector2(0.56, 0.05), Vector2(0.38, 0.24)))
			_add_room_block(room_rect, "louis_bed", Rect2(Vector2(0.04, 0.62), Vector2(0.30, 0.23)))
			_add_room_block(room_rect, "louis_bath", Rect2(Vector2(0.76, 0.62), Vector2(0.20, 0.25)))
		"player":
			_add_room_block(room_rect, "anna_study", Rect2(Vector2(0.04, 0.05), Vector2(0.38, 0.25)))
			_add_room_block(room_rect, "anna_bed", Rect2(Vector2(0.72, 0.06), Vector2(0.24, 0.25)))
			_add_room_block(room_rect, "anna_kitchen", Rect2(Vector2(0.04, 0.62), Vector2(0.32, 0.26)))
			_add_room_block(room_rect, "anna_sofa", Rect2(Vector2(0.68, 0.54), Vector2(0.27, 0.25)))
			_add_room_block(room_rect, "anna_stairs", Rect2(Vector2(0.42, 0.34), Vector2(0.17, 0.24)))
		_:
			pass

func _add_room_outer_boundaries(room_rect: Rect2) -> void:
	var margin: float = 80.0

	if room_rect.position.y > 0.0:
		_host._add_collision_rect("room_outside_top", Vector2(GAME_SIZE.x * 0.5, room_rect.position.y * 0.5), Vector2(GAME_SIZE.x + margin, room_rect.position.y + margin))

	var bottom_h: float = GAME_SIZE.y - room_rect.end.y
	if bottom_h > 0.0:
		_host._add_collision_rect("room_outside_bottom", Vector2(GAME_SIZE.x * 0.5, room_rect.end.y + bottom_h * 0.5), Vector2(GAME_SIZE.x + margin, bottom_h + margin))

	if room_rect.position.x > 0.0:
		_host._add_collision_rect("room_outside_left", Vector2(room_rect.position.x * 0.5, GAME_SIZE.y * 0.5), Vector2(room_rect.position.x + margin, GAME_SIZE.y + margin))

	var right_w: float = GAME_SIZE.x - room_rect.end.x
	if right_w > 0.0:
		_host._add_collision_rect("room_outside_right", Vector2(room_rect.end.x + right_w * 0.5, GAME_SIZE.y * 0.5), Vector2(right_w + margin, GAME_SIZE.y + margin))

func _add_room_block(room_rect: Rect2, block_name: String, normalized_rect: Rect2) -> void:
	var center = room_rect.position + Vector2(
		(normalized_rect.position.x + normalized_rect.size.x * 0.5) * room_rect.size.x,
		(normalized_rect.position.y + normalized_rect.size.y * 0.5) * room_rect.size.y
	)
	var size = Vector2(
		normalized_rect.size.x * room_rect.size.x,
		normalized_rect.size.y * room_rect.size.y
	)
	_host._add_collision_rect(block_name, center, size)

func _remove_room_card_and_back(card: Panel) -> void:
	if card != null and is_instance_valid(card):
		card.queue_free()
	room_card = null
	_host._show_garden()
