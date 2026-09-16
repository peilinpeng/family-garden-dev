extends "res://scripts/scene_runtime/scene_runtime_module.gd"

## 世界聊天预览、发送与历史面板。
## 仅由 SceneManager 创建；外部代码继续调用 SceneManager 兼容门面。

func _world_chat_input_style(focused: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.96, 0.86, 0.94) if focused else Color(1.0, 0.94, 0.82, 0.90)
	style.border_color = Color(0.56, 0.42, 0.27, 0.95) if focused else Color(0.60, 0.48, 0.33, 0.86)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _add_world_chat_feed(root: Control, pos: Vector2, feed_size: Vector2) -> Label:
	var panel = Panel.new()
	panel.name = "WorldChatPreview"
	panel.position = pos
	panel.size = feed_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0
	panel.visible = false
	panel.gui_input.connect(_on_world_chat_preview_input)
	panel.add_theme_stylebox_override("panel", _world_chat_preview_style())
	root.add_child(panel)
	world_chat_feed_panel = panel

	var feed = Label.new()
	feed.name = "WorldChatFeed"
	feed.position = Vector2(12, 8)
	feed.size = feed_size - Vector2(24, 14)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feed.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	feed.add_theme_font_size_override("font_size", 12)
	feed.add_theme_color_override("font_color", Color(0.24, 0.20, 0.15, 0.90))
	panel.add_child(feed)
	world_chat_feed = feed
	return feed

func _world_chat_preview_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.94, 0.78, 0.78)
	style.border_color = Color(0.52, 0.36, 0.20, 0.72)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _on_world_chat_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_open_world_chat_history_panel()

func _on_world_chat_submitted(submitted_text: String) -> void:
	_send_world_chat_message(submitted_text, world_chat_input)

## 发送世界聊天消息。source_input:发起发送的输入框(底部栏或聊天面板内嵌),发送期间禁用、
## 完成后清空并重新聚焦。回车键与 Send 按钮、聊天面板发送都走这里。

func _send_world_chat_message(raw_text: String, source_input: LineEdit = null) -> void:
	var text = raw_text.strip_edges()
	if text == "":
		return
	if source_input != null and is_instance_valid(source_input):
		source_input.editable = false
		source_input.text = ""
		source_input.placeholder_text = "正在发送..."

	var author = _get_world_chat_author()
	var message_id = "message_" + str(Time.get_ticks_msec())
	if CloudManager != null:
		var cloud_message: Dictionary = await CloudManager.create_message(author, text, "")
		if not cloud_message.is_empty() and str(cloud_message.get("id", "")) != "":
			message_id = str(cloud_message.get("id", ""))

	var message = {
		"id": message_id,
		"author": author,
		"text": text,
		"created_at": Time.get_datetime_string_from_system(),
		"role": MemoryManager.selected_role_key
	}
	MemoryManager.garden_messages.append(message)
	MemoryManager.notify_family_activity()
	MemoryManager.save_game()
	_refresh_world_chat_feed(true)
	_refresh_chat_panel_messages()
	if source_input != null and is_instance_valid(source_input):
		source_input.editable = true
		source_input.placeholder_text = "给家人留一句话..."
		source_input.grab_focus()
	_host._show_toast("留言已发送。")

func _get_world_chat_author() -> String:
	if GameIdentity != null and GameIdentity.is_ready() and str(GameIdentity.display_name).strip_edges() != "":
		return str(GameIdentity.display_name).strip_edges()
	if str(MemoryManager.player_display_name).strip_edges() != "":
		return str(MemoryManager.player_display_name).strip_edges()
	var role = str(MemoryManager.selected_role_key).strip_edges()
	if role != "":
		for character in CHARACTER_DATA:
			if str(character.get("role", "")) == role:
				return str(character.get("default_name", "家人"))
	return "家人"

func _refresh_world_chat_feed(show_preview: bool = false) -> void:
	if world_chat_feed == null or not is_instance_valid(world_chat_feed):
		return
	var recent: Array[String] = []
	var start_index = MemoryManager.garden_messages.size() - 3
	if start_index < 0:
		start_index = 0
	for i in range(start_index, MemoryManager.garden_messages.size()):
		var raw_message: Variant = MemoryManager.garden_messages[i]
		if not (raw_message is Dictionary):
			continue
		var message: Dictionary = raw_message
		var author = str(message.get("author", "家人"))
		var text = str(message.get("text", "")).strip_edges()
		if text == "":
			continue
		recent.append(author + ": " + text)
	world_chat_feed.text = "\n".join(recent)
	if show_preview and not recent.is_empty():
		_show_world_chat_preview()

func _show_world_chat_preview() -> void:
	if world_chat_feed_panel == null or not is_instance_valid(world_chat_feed_panel):
		return
	if world_chat_fade_tween != null and world_chat_fade_tween.is_valid():
		world_chat_fade_tween.kill()
	world_chat_feed_panel.visible = true
	world_chat_feed_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	world_chat_feed_panel.modulate.a = 1.0
	world_chat_fade_tween = create_tween()
	world_chat_fade_tween.tween_interval(5.0)
	world_chat_fade_tween.tween_property(world_chat_feed_panel, "modulate:a", 0.0, 1.2)
	world_chat_fade_tween.tween_callback(func() -> void:
		if world_chat_feed_panel != null and is_instance_valid(world_chat_feed_panel):
			world_chat_feed_panel.visible = false
			world_chat_feed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)

## 完整家庭聊天面板:滚动消息流(旧→新,气泡按自己/家人左右对齐)+ 内嵌输入框/发送。
## 底部栏"Chat"按钮或点消息预览都打开这里。发送后实时刷新并自动滚到底。

func _open_world_chat_history_panel() -> void:
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay

	var panel = Panel.new()
	panel.position = Vector2(340, 70)
	panel.size = Vector2(600, 580)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)

	var title = Label.new()
	title.text = "家庭聊天"
	title.position = Vector2(34, 22)
	title.size = Vector2(500, 32)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	# 消息流
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(28, 66)
	scroll.size = Vector2(544, 436)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)
	_chat_panel_scroll = scroll

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(544, 0)
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	_chat_panel_list = list

	# 内嵌输入 + 发送
	var input = LineEdit.new()
	input.name = "ChatPanelInput"
	input.placeholder_text = "给家人留一句话..."
	input.position = Vector2(28, 514)
	input.size = Vector2(456, 40)
	input.mouse_filter = Control.MOUSE_FILTER_STOP
	input.add_theme_font_size_override("font_size", 14)
	input.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16, 1.0))
	panel.add_child(input)

	var send_btn = Button.new()
	send_btn.text = "发送"
	send_btn.position = Vector2(492, 514)
	send_btn.size = Vector2(80, 40)
	send_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_button_style(send_btn, false)
	send_btn.pressed.connect(func() -> void: _send_world_chat_message(input.text, input))
	panel.add_child(send_btn)
	input.text_submitted.connect(func(t: String) -> void: _send_world_chat_message(t, input))

	_refresh_chat_panel_messages()
	input.grab_focus()

## 重建聊天面板的消息气泡(打开时 + 每次发送后)。面板已关则安全跳过。

func _refresh_chat_panel_messages() -> void:
	if _chat_panel_list == null or not is_instance_valid(_chat_panel_list):
		return
	for c in _chat_panel_list.get_children():
		c.queue_free()
	if MemoryManager.garden_messages.is_empty():
		var empty = Label.new()
		empty.text = "还没有消息，发一条和家人打个招呼吧～"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.40, 0.33, 0.25, 0.85))
		_chat_panel_list.add_child(empty)
	else:
		for raw in MemoryManager.garden_messages:
			if raw is Dictionary:
				_chat_panel_list.add_child(_make_chat_bubble(raw))
	# 布局完成后滚到底(超大值自动夹到 max)
	if _chat_panel_scroll != null and is_instance_valid(_chat_panel_scroll):
		_chat_panel_scroll.set_deferred("scroll_vertical", 1000000)
## 单条聊天气泡:自己发的靠右(暖绿),家人的靠左(米色);含作者 + 时间。

func _make_chat_bubble(message: Dictionary) -> Control:
	var is_self = str(message.get("role", "")) == str(MemoryManager.selected_role_key)
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bubble = PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if is_self else Control.SIZE_SHRINK_BEGIN
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.86, 0.93, 0.72, 0.96) if is_self else Color(1.0, 0.95, 0.82, 0.94)
	style.border_color = Color(0.58, 0.62, 0.36, 0.7) if is_self else Color(0.62, 0.48, 0.32, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	bubble.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	bubble.add_child(margin)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	margin.add_child(vb)

	var meta = Label.new()
	meta.text = str(message.get("author", "家人")) + "  ·  " + _format_world_chat_time(str(message.get("created_at", "")))
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", Color(0.40, 0.33, 0.25, 0.85))
	vb.add_child(meta)

	var body = Label.new()
	body.text = str(message.get("text", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(320, 0)
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.20, 0.16, 0.12, 1.0))
	vb.add_child(body)

	if is_self:
		var sp = Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		var sp = Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
	return row

func _format_world_chat_time(raw_time: String) -> String:
	if raw_time == "":
		return "未记录时间"
	return raw_time.replace("T", " ").replace("Z", "")
