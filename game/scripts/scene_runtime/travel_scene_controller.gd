extends "res://scripts/scene_runtime/scene_runtime_module.gd"

## 旅行地图、照片、记忆草稿与明信片详情。
## 仅由 SceneManager 创建；外部代码继续调用 SceneManager 兼容门面。

func _show_travel_map() -> void:
	_host.save_current_progress()
	_host._close_active_panel()
	_host._clear_map_ui()
	if room_card != null and is_instance_valid(room_card):
		room_card.queue_free()
		room_card = null
	mode = "map"
	_current_spawn_key = "default"
	_current_room_id = ""
	_host._set_hud_context(mode)
	plant_mode = false
	_host._update_plant_button()
	_host._clear_world()
	info_label.text = "旅行地图"
	_add_travel_map_background()
	_rebuild_travel_pins()
	_build_map_ui()

func _add_travel_map_background() -> void:
	var texture = _host._safe_texture(ASSETS["travel_map"])
	var sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.name = "TravelMapBackground"
	sprite.position = GAME_SIZE / 2.0
	if texture:
		sprite.texture = texture
		var scale_factor = max(GAME_SIZE.x / float(texture.get_width()), GAME_SIZE.y / float(texture.get_height()))
		sprite.scale = Vector2.ONE * scale_factor
	else:
		sprite.texture = _host._solid_texture(1280, 720, Color(0.80, 0.92, 0.92, 1.0))
	world.add_child(sprite)

func _build_map_ui() -> void:
	map_ui = Control.new()
	map_ui.name = "TravelMapUI"
	map_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(map_ui)

	var back_btn = Button.new()
	back_btn.text = "返回花园"
	back_btn.position = Vector2(24, 24)
	back_btn.size = Vector2(126, 38)
	back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_button_style(back_btn, false)
	_host._set_button_icon(back_btn, "icon_back")
	back_btn.pressed.connect(func() -> void: _host._show_garden())
	map_ui.add_child(back_btn)

	var add_btn = Button.new()
	add_btn.text = "Add Place"
	add_btn.position = Vector2(1086, 24)
	add_btn.size = Vector2(130, 38)
	add_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_button_style(add_btn, false)
	_host._set_button_icon(add_btn, "icon_add")
	add_btn.pressed.connect(_start_add_place)
	map_ui.add_child(add_btn)

	var hint = Label.new()
	hint.text = "Add memories by placing a pin on the map."
	hint.position = Vector2(850, 68)
	hint.size = Vector2(390, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.25, 0.22, 0.18, 0.85))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_ui.add_child(hint)

func _start_add_place() -> void:
	_host._close_active_panel()
	adding_place = true
	_host._show_toast("Click a location on the travel map.")

func _open_add_place_form(pos: Vector2) -> void:
	adding_place = false
	pending_place_position = pos
	_reset_selected_photo_state()
	_host._close_active_panel()

	var overlay = _host._create_modal_overlay()
	active_modal = overlay
	var panel = Panel.new()
	panel.position = Vector2(360, 125)
	panel.size = Vector2(560, 470)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)

	var title = Label.new()
	title.text = "添加旅行地点"
	title.position = Vector2(34, 24)
	title.size = Vector2(492, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var name_label = Label.new()
	name_label.text = "城市 / 地点名"
	name_label.position = Vector2(34, 76)
	name_label.size = Vector2(492, 22)
	name_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(name_label)

	var title_input = LineEdit.new()
	title_input.placeholder_text = "Zurich, Paris, Shanghai..."
	title_input.position = Vector2(34, 102)
	title_input.size = Vector2(492, 36)
	panel.add_child(title_input)

	var note_label = Label.new()
	note_label.text = "记忆留言"
	note_label.position = Vector2(34, 150)
	note_label.size = Vector2(492, 22)
	note_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(note_label)

	var note_input = TextEdit.new()
	note_input.placeholder_text = "写下这个地方带回来的小记忆..."
	note_input.position = Vector2(34, 176)
	note_input.size = Vector2(492, 92)
	panel.add_child(note_input)

	var photo_label_title = Label.new()
	photo_label_title.text = "照片"
	photo_label_title.position = Vector2(34, 286)
	photo_label_title.size = Vector2(492, 22)
	photo_label_title.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(photo_label_title)

	var choose_photo_button = Button.new()
	choose_photo_button.text = "选择照片"
	choose_photo_button.position = Vector2(34, 314)
	choose_photo_button.size = Vector2(150, 38)
	choose_photo_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_button_style(choose_photo_button, false)
	_host._set_button_icon(choose_photo_button, "icon_camera")
	choose_photo_button.pressed.connect(_choose_photo_for_place)
	panel.add_child(choose_photo_button)

	selected_photo_label = Label.new()
	selected_photo_label.text = "未选择照片"
	selected_photo_label.position = Vector2(198, 320)
	selected_photo_label.size = Vector2(328, 28)
	selected_photo_label.add_theme_font_size_override("font_size", 13)
	selected_photo_label.add_theme_color_override("font_color", Color(0.43, 0.35, 0.27, 0.95))
	panel.add_child(selected_photo_label)

	var hint = Label.new()
	hint.text = "桌面端会打开文件选择器，Web 端会打开浏览器照片选择器。"
	hint.position = Vector2(34, 360)
	hint.size = Vector2(492, 24)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.45, 0.38, 0.30, 0.75))
	panel.add_child(hint)

	_host._add_panel_button(panel, "保存地点", Vector2(126, 404), Vector2(140, 40), "save_new_place", [title_input, note_input])
	_host._add_panel_button(panel, "取消", Vector2(300, 404), Vector2(120, 40), "close")

func _save_new_place(title_input: LineEdit, note_input: TextEdit) -> void:
	var place_title: String = title_input.text.strip_edges()
	if place_title == "":
		place_title = "未命名地点"
	var place_note: String = note_input.text.strip_edges()
	if place_note == "":
		place_note = "这个地方带回来一段小小的记忆。"

	var place_id: String = "place_" + str(Time.get_ticks_msec())
	var postcard_id: String = "postcard_" + str(Time.get_ticks_msec())
	var photo_upload_id: String = ""
	print("[FamilyGarden] Save place photo state: from_web=", selected_photo_from_web, " bytes=", selected_photo_bytes.size(), " path=", selected_photo_path, " name=", selected_photo_filename, " type=", selected_photo_content_type)

	var source_photo_bytes: PackedByteArray = selected_photo_bytes
	if source_photo_bytes.is_empty() and selected_photo_path != "":
		source_photo_bytes = FileAccess.get_file_as_bytes(selected_photo_path)
	if not source_photo_bytes.is_empty():
		if CloudManager != null:
			_host._show_toast("正在压缩照片并安全上传...")
			var upload_result: Dictionary = await CloudManager.upload_private_photo(
				source_photo_bytes,
				selected_photo_content_type
			)
			if not bool(upload_result.get("ok", false)):
				_host._show_toast(_host._result_error_message(upload_result, "照片上传失败，将不带照片保存。"))
			else:
				photo_upload_id = String(upload_result.get("upload_id", ""))
				_host._show_toast("照片已安全上传。")
		else:
			_host._show_toast("云端尚未就绪，将不带照片保存。")

	if CloudManager != null:
		_host._show_toast("正在保存到家庭云端...")
		var created: Dictionary = await CloudManager.create_place_with_postcard(
			place_title,
			place_note,
			pending_place_position.x,
			pending_place_position.y,
			"",
			photo_upload_id
		)
		if created.has("place") and created["place"] is Dictionary:
			var cloud_place: Dictionary = created["place"]
			if str(cloud_place.get("id", "")) != "":
				place_id = str(cloud_place.get("id", ""))
			if str(cloud_place.get("photo_upload_id", "")) != "":
				photo_upload_id = str(cloud_place.get("photo_upload_id", ""))
		if created.has("postcard") and created["postcard"] is Dictionary:
			var cloud_postcard: Dictionary = created["postcard"]
			if str(cloud_postcard.get("id", "")) != "":
				postcard_id = str(cloud_postcard.get("id", ""))

	var place = {
		"id": place_id,
		"title": place_title,
		"note": place_note,
		"x": pending_place_position.x,
		"y": pending_place_position.y,
		"postcard_id": postcard_id,
		"created_by": MemoryManager.player_display_name,
		"role": MemoryManager.selected_role_key,
		"photo_upload_id": photo_upload_id,
		"photo_path": ""
	}
	MemoryManager.travel_places.append(place)

	var postcard = {
		"id": postcard_id,
		"place_id": place_id,
		"title": "来自%s的明信片" % place_title,
		"message": place_note,
		"is_new": true,
		"created_by": MemoryManager.player_display_name,
		"role": MemoryManager.selected_role_key,
		"photo_upload_id": photo_upload_id,
		"photo_path": ""
	}
	MemoryManager.postcards.append(postcard)
	if StoryManager != null and StoryManager.has_method("record_place_and_postcard"):
		StoryManager.record_place_and_postcard(place, postcard)
	MemoryManager.notify_new_postcard()
	MemoryManager.save_game()
	_reset_selected_photo_state()
	_host._close_active_panel()
	_show_travel_map()
	_host._show_toast("来自%s的新明信片已寄回花园。" % place_title)

func _rebuild_travel_pins() -> void:
	for place in MemoryManager.travel_places:
		_add_travel_pin(place)

func _add_travel_pin(place: Dictionary) -> void:
	var marker = Node2D.new()
	marker.name = "Pin_" + str(place.get("id", ""))
	marker.position = Vector2(float(place.get("x", 640)), float(place.get("y", 360)))
	marker.z_index = 50
	world.add_child(marker)

	var pin_texture = _host._safe_texture(_pin_asset_for_place(place))
	if pin_texture:
		var pin_sprite = Sprite2D.new()
		pin_sprite.texture = pin_texture
		pin_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pin_sprite.centered = true
		pin_sprite.position = Vector2(0, -16)
		var pin_scale = 44.0 / float(pin_texture.get_height())
		pin_sprite.scale = Vector2.ONE * pin_scale
		marker.add_child(pin_sprite)
	else:
		var pin = Label.new()
		pin.text = "●"
		pin.position = Vector2(-10, -22)
		pin.size = Vector2(28, 28)
		pin.add_theme_font_size_override("font_size", 26)
		pin.add_theme_color_override("font_color", Color(0.88, 0.22, 0.18, 1.0))
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.add_child(pin)

	var name_label = Label.new()
	name_label.text = str(place.get("title", "Place"))
	name_label.position = Vector2(-50, 6)
	name_label.size = Vector2(100, 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.16, 0.25, 0.22, 1.0))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(name_label)

	_host._add_click_area(marker, Vector2(44, 54), "place:" + str(place.get("id", "")), str(place.get("title", "Place")), Vector2(0, 0))

func _open_postcard_for_place(place_id: String) -> void:
	var place = MemoryManager.find_place(place_id)
	if place.is_empty():
		return
	var postcard = MemoryManager.find_postcard_by_place(place_id)
	var title_text = str(postcard.get("title", "来自%s的明信片" % str(place.get("title", "地点"))))
	var message = str(postcard.get("message", place.get("note", "A small memory.")))
	var photo_reference = _photo_reference(postcard)
	if photo_reference == "":
		photo_reference = _photo_reference(place)
	_open_postcard_detail_panel(title_text, message, photo_reference, place_id)

func _choose_photo_for_place() -> void:
	if OS.has_feature("web"):
		_choose_photo_for_place_web()
		return

	if photo_file_dialog != null and is_instance_valid(photo_file_dialog):
		photo_file_dialog.queue_free()

	photo_file_dialog = FileDialog.new()
	photo_file_dialog.title = "选择照片"
	photo_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	photo_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	photo_file_dialog.filters = PackedStringArray([
		"*.png, *.jpg, *.jpeg, *.webp ; 图片文件"
	])
	photo_file_dialog.file_selected.connect(_on_place_photo_selected)
	ui_layer.add_child(photo_file_dialog)
	photo_file_dialog.popup_centered(Vector2i(900, 620))

func _selected_gate4_photo() -> Dictionary:
	var bytes = selected_photo_bytes
	if bytes.is_empty() and selected_photo_path != "":
		bytes = FileAccess.get_file_as_bytes(selected_photo_path)
	return {
		"bytes": bytes,
		"content_type": selected_photo_content_type if selected_photo_content_type != "" else _content_type_for_filename(selected_photo_filename),
		"filename": selected_photo_filename,
	}

func _open_memory_creator(preserve_selection: bool = false, initial_text: String = "") -> void:
	if not preserve_selection:
		_reset_selected_photo_state()
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay
	var panel = Panel.new()
	panel.position = Vector2(290, 70)
	panel.size = Vector2(700, 590)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)

	var title = Label.new()
	title.text = "创建一段家庭记忆"
	title.position = Vector2(34, 24)
	title.size = Vector2(620, 36)
	title.add_theme_font_size_override("font_size", 26)
	panel.add_child(title)

	var hint = Label.new()
	hint.text = "可以只写文字、只选照片，或图文一起提交。生成草稿前不会保存记忆。"
	hint.position = Vector2(34, 66)
	hint.size = Vector2(620, 40)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(hint)

	var text_input = TextEdit.new()
	text_input.name = "MemoryTextInput"
	text_input.placeholder_text = "例如：今天和家人一起种了一棵树……"
	text_input.text = initial_text
	text_input.position = Vector2(34, 118)
	text_input.size = Vector2(632, 190)
	panel.add_child(text_input)

	var choose = Button.new()
	choose.text = "选择照片（可选）"
	choose.position = Vector2(34, 330)
	choose.size = Vector2(180, 40)
	_host._apply_button_style(choose, false)
	choose.pressed.connect(_choose_photo_for_place)
	panel.add_child(choose)
	selected_photo_label = Label.new()
	selected_photo_label.text = "未选择照片" if selected_photo_filename == "" else "已选择：" + selected_photo_filename
	selected_photo_label.position = Vector2(230, 338)
	selected_photo_label.size = Vector2(420, 28)
	panel.add_child(selected_photo_label)

	var privacy = Label.new()
	privacy.text = "照片会先在本机压缩并去除元数据，再上传到家庭隔离的 CloudBase 路径。"
	privacy.position = Vector2(34, 390)
	privacy.size = Vector2(632, 44)
	privacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	privacy.add_theme_font_size_override("font_size", 13)
	panel.add_child(privacy)

	var status = _host._make_status_label(panel, Vector2(34, 438), Vector2(632, 30), "确认草稿前不会创建记忆。")

	var generate = Button.new()
	generate.text = "生成可编辑草稿"
	generate.position = Vector2(250, 476)
	generate.size = Vector2(200, 44)
	_host._apply_button_style(generate, false)
	generate.pressed.connect(_generate_memory_draft.bind(text_input, generate, status))
	panel.add_child(generate)

func _generate_memory_draft(text_input: TextEdit, button: Button, status: Label) -> void:
	var photo = _selected_gate4_photo()
	if text_input.text.strip_edges() == "" and (photo.get("bytes", PackedByteArray()) as PackedByteArray).is_empty():
		_host._set_status(status, "先写一段文字，或选择一张照片。", true)
		_host._show_toast("请先写文字或选择照片。")
		return
	_host._set_button_busy(button, "正在生成...")
	_host._watch_ai_workflow("memory", status, "正在准备输入...")
	var draft: Dictionary = await AIWorkflowManager.prepare_memory_draft(text_input.text, photo.get("bytes", PackedByteArray()), String(photo.get("content_type", "")))
	if not bool(draft.get("ok", false)):
		_host._set_button_ready(button, "重试生成")
		var message = _host._result_error_message(draft, "生成失败，请重试。")
		_host._set_status(status, message, true)
		_host._show_toast(message)
		_host._clear_ai_workflow_watch(status)
		return
	_host._clear_ai_workflow_watch(status)
	_open_memory_draft_preview(draft)

func _open_memory_draft_preview(draft: Dictionary) -> void:
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay
	var panel = Panel.new()
	panel.position = Vector2(260, 46)
	panel.size = Vector2(760, 628)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)

	var heading = Label.new()
	heading.text = "记忆卡草稿" + (" · 已使用安全回退" if bool(draft.get("used_fallback", false)) else " · AI 已生成")
	heading.position = Vector2(34, 20)
	heading.size = Vector2(690, 34)
	heading.add_theme_font_size_override("font_size", 24)
	panel.add_child(heading)
	var card: Dictionary = draft.get("card", {})

	var title_label = Label.new()
	title_label.text = "标题"
	title_label.position = Vector2(34, 58)
	title_label.size = Vector2(692, 20)
	title_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(title_label)
	var title_input = LineEdit.new()
	title_input.text = String(card.get("title", ""))
	title_input.position = Vector2(34, 82)
	title_input.size = Vector2(692, 38)
	panel.add_child(title_input)

	var description_label = Label.new()
	description_label.text = "描述"
	description_label.position = Vector2(34, 126)
	description_label.size = Vector2(692, 20)
	description_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(description_label)
	var description_input = TextEdit.new()
	description_input.text = String(card.get("description", ""))
	description_input.position = Vector2(34, 150)
	description_input.size = Vector2(692, 112)
	panel.add_child(description_input)

	var question_label = Label.new()
	question_label.text = "想追问家人的问题"
	question_label.position = Vector2(34, 278)
	question_label.size = Vector2(692, 20)
	question_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(question_label)
	var question_input = TextEdit.new()
	question_input.text = String(card.get("question", ""))
	question_input.position = Vector2(34, 302)
	question_input.size = Vector2(692, 86)
	panel.add_child(question_input)
	var scene_label = Label.new()
	scene_label.text = "放到哪里"
	scene_label.position = Vector2(34, 410)
	scene_label.size = Vector2(100, 28)
	panel.add_child(scene_label)
	var scene_select = OptionButton.new()
	scene_select.position = Vector2(140, 404)
	scene_select.size = Vector2(220, 38)
	scene_select.add_item("家庭花园", 0)
	scene_select.set_item_metadata(0, "garden")
	scene_select.select(0)
	scene_select.disabled = true
	scene_select.tooltip_text = "记忆花统一陈列在主花园"
	panel.add_child(scene_select)
	var source = Label.new()
	var meta: Dictionary = draft.get("generation_meta", {})
	source.text = "来源：%s · 模型：%s · Prompt：%s" % [String(meta.get("source", "unknown")), String(meta.get("model", "unknown")), String(meta.get("prompt_version", "unknown"))]
	source.position = Vector2(34, 462)
	source.size = Vector2(692, 48)
	source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source.add_theme_font_size_override("font_size", 12)
	panel.add_child(source)
	var status = _host._make_status_label(panel, Vector2(34, 514), Vector2(692, 22), "可以先修改草稿；只有点击确认才会写入花园。")
	var cancel = Button.new()
	cancel.text = "取消并清理照片"
	cancel.position = Vector2(116, 542)
	cancel.size = Vector2(170, 42)
	_host._apply_button_style(cancel, false)
	cancel.pressed.connect(_host._discard_draft_and_close.bind(draft))
	panel.add_child(cancel)
	var confirm = Button.new()
	confirm.text = "确认创建"
	confirm.position = Vector2(474, 542)
	confirm.size = Vector2(170, 42)
	_host._apply_button_style(confirm, false)
	confirm.pressed.connect(_commit_memory_preview.bind(draft, card, title_input, description_input, question_input, scene_select, confirm, status))
	panel.add_child(confirm)

func _commit_memory_preview(draft: Dictionary, original_card: Dictionary, title_input: LineEdit, description_input: TextEdit, question_input: TextEdit, scene_select: OptionButton, button: Button, status: Label) -> void:
	var card = original_card.duplicate(true)
	card["title"] = title_input.text.strip_edges()
	card["description"] = description_input.text.strip_edges()
	card["question"] = question_input.text.strip_edges()
	card["suggested_scene"] = String(scene_select.get_selected_metadata())
	if String(card.get("title", "")).strip_edges() == "":
		_host._set_status(status, "标题不能为空。", true)
		return
	if String(card.get("description", "")).strip_edges() == "":
		_host._set_status(status, "描述不能为空。", true)
		return
	if String(card.get("question", "")).strip_edges() == "":
		_host._set_status(status, "请保留一个想追问家人的问题。", true)
		return
	_host._set_button_busy(button, "正在保存...")
	_host._set_status(status, "正在写入记忆，并计算可能的关联...")
	var result: Dictionary = await AIWorkflowManager.commit_memory_draft(draft, card)
	if not bool(result.get("ok", false)):
		_host._set_button_ready(button, "确认创建")
		var message = _host._result_error_message(result, "保存失败。")
		_host._set_status(status, message, true)
		_host._show_toast(message)
		return
	_host._close_active_panel()
	var scene = String(card.get("suggested_scene", "garden"))
	var saved_memory: Dictionary = result.get("memory", {})
	var link_count = MemoryManager.count_memory_links_for_memory(String(saved_memory.get("id", "")), scene)
	var link_text = "，发现 %d 条记忆关联" % link_count if link_count > 0 else ""
	var saved_message = "记忆已保存到%s%s。" % [("爸爸鱼塘" if scene == "fishpond" else "家庭花园"), link_text]
	if bool(result.get("sync_pending", false)):
		saved_message += " 已保存在本机，联网后会自动同步。"
	_host._show_toast(saved_message)
	if scene == "garden":
		_pending_memory_arrival_id = String(saved_memory.get("id", ""))
		_host._show_garden()

func _on_place_photo_selected(path: String) -> void:
	selected_photo_path = path
	selected_photo_bytes = PackedByteArray()
	selected_photo_filename = path.get_file()
	selected_photo_content_type = _content_type_for_filename(selected_photo_filename)
	selected_photo_from_web = false

	if selected_photo_label != null and is_instance_valid(selected_photo_label):
		var bytes = FileAccess.get_file_as_bytes(selected_photo_path)
		selected_photo_label.text = "已选择：" + selected_photo_filename + "（" + _host._format_file_size(bytes.size()) + "）"

	_host._show_toast("已选择照片：" + selected_photo_filename)

func _setup_web_photo_bridge() -> void:
	if not OS.has_feature("web"):
		return

	var photo_picker_js = """
(function () {
	if (window.__familyGardenPhotoBridgeReady) {
		return;
	}

	window.__familyGardenPhotoBridgeReady = true;
	window.__familyGardenPhotoOverlayInput = null;

	window.__familyGardenRemovePhotoInput = function () {
		var oldInput = window.__familyGardenPhotoOverlayInput || document.getElementById("family-garden-photo-input");
		if (oldInput && oldInput.parentNode) {
			oldInput.parentNode.removeChild(oldInput);
		}
		window.__familyGardenPhotoOverlayInput = null;
	};

	window.__familyGardenCreatePhotoInput = function () {
		window.__familyGardenRemovePhotoInput();

		var input = document.createElement("input");
		input.id = "family-garden-photo-input";
		input.type = "file";
		input.accept = "image/png,image/jpeg,image/webp";

		/*
			The full-window invisible input is a fallback for browsers that block
			programmatic input.click() from a WebAssembly/Godot event. If click() works,
			the picker opens immediately. If it is blocked, the next user tap/click will
			hit this native input.
		*/
		input.style.position = "fixed";
		input.style.left = "0";
		input.style.top = "0";
		input.style.width = "100vw";
		input.style.height = "100vh";
		input.style.opacity = "0.001";
		input.style.zIndex = "2147483647";
		input.style.cursor = "pointer";
		input.style.pointerEvents = "auto";

			input.addEventListener("change", function () {
				var file = input.files && input.files.length > 0 ? input.files[0] : null;
				if (!file) {
					window.__familyGardenRemovePhotoInput();
					return;
			}

			console.log("[FamilyGarden] Photo chosen:", file.name, file.type, file.size);

			var reader = new FileReader();

			reader.onload = function () {
				var bytes = new Uint8Array(reader.result);
				var chunkSize = 0x8000;
				var binary = "";

				for (var i = 0; i < bytes.length; i += chunkSize) {
					var chunk = bytes.subarray(i, i + chunkSize);
					binary += String.fromCharCode.apply(null, chunk);
				}

				var base64 = btoa(binary);

				if (window.__familyGardenPhotoPicked) {
					console.log("[FamilyGarden] Sending photo to Godot callback");
					window.__familyGardenPhotoPicked(
						base64,
						file.name || "photo.jpg",
						file.type || "image/jpeg"
					);
				} else {
					console.error("[FamilyGarden] Godot photo callback is missing");
				}

				window.__familyGardenRemovePhotoInput();
			};

			reader.onerror = function () {
				console.error("[FamilyGarden] Photo read failed", reader.error);
				window.__familyGardenRemovePhotoInput();
			};

				reader.readAsArrayBuffer(file);
			});

			input.addEventListener("cancel", function () {
				window.__familyGardenRemovePhotoInput();
			});

			document.body.appendChild(input);
			window.__familyGardenPhotoOverlayInput = input;
		return input;
	};

	window.familyGardenChoosePhoto = function () {
		if (!window.__familyGardenPhotoPicked) {
			console.error("[FamilyGarden] Photo callback is not ready");
			return false;
		}

		var input = window.__familyGardenCreatePhotoInput();
		try {
			input.click();
		} catch (e) {
			console.warn("[FamilyGarden] input.click() was blocked; click once more to open picker", e);
		}
		return true;
	};
})();
"""
	JavaScriptBridge.eval(photo_picker_js, true)

	if web_photo_callback == null:
		web_photo_callback = JavaScriptBridge.create_callback(_on_web_photo_selected)

	var js_window = JavaScriptBridge.get_interface("window")
	if js_window != null:
		js_window["__familyGardenPhotoPicked"] = web_photo_callback

func _choose_photo_for_place_web() -> void:
	if web_photo_callback == null:
		_setup_web_photo_bridge()

	_host._show_toast("请选择设备中的照片...")

	if selected_photo_label != null and is_instance_valid(selected_photo_label):
		selected_photo_label.text = "请选择设备中的照片..."

	var js_result = JavaScriptBridge.eval("""
		window.familyGardenChoosePhoto ? window.familyGardenChoosePhoto() : false;
	""", true)
	if not bool(js_result):
		_host._show_toast("照片选择器还没准备好，请重试。")

func _on_web_photo_selected(args: Array) -> void:
	if args.size() < 3:
		_host._show_toast("照片选择失败。")
		return

	var base64_text: String = str(args[0])
	var file_name: String = str(args[1])
	var content_type: String = str(args[2])

	var bytes: PackedByteArray = Marshalls.base64_to_raw(base64_text)
	if bytes.is_empty():
		_host._show_toast("无法读取所选照片。")
		return

	selected_photo_bytes = bytes
	selected_photo_filename = file_name
	selected_photo_content_type = content_type
	selected_photo_path = ""
	selected_photo_from_web = true
	print("[FamilyGarden] Web photo received by Godot: ", selected_photo_filename, " bytes=", selected_photo_bytes.size(), " type=", selected_photo_content_type)

	if selected_photo_label != null and is_instance_valid(selected_photo_label):
		selected_photo_label.text = "已选择：" + selected_photo_filename + "（" + _host._format_file_size(selected_photo_bytes.size()) + "）"

	_host._show_toast("已选择照片：" + selected_photo_filename)

func _reset_selected_photo_state() -> void:
	selected_photo_path = ""
	selected_photo_bytes = PackedByteArray()
	selected_photo_filename = ""
	selected_photo_content_type = ""
	selected_photo_from_web = false
	selected_photo_label = null

func _content_type_for_filename(file_name: String) -> String:
	var ext: String = file_name.get_extension().to_lower()
	match ext:
		"png":
			return "image/png"
		"webp":
			return "image/webp"
		"jpg", "jpeg":
			return "image/jpeg"
		_:
			return "application/octet-stream"

func _open_postcard_detail_panel(title_text: String, message: String, photo_path: String, place_id: String) -> void:
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay

	var panel = Panel.new()
	panel.position = Vector2(320, 80)
	panel.size = Vector2(640, 560)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)

	var title = Label.new()
	title.text = title_text
	title.position = Vector2(36, 26)
	title.size = Vector2(520, 34)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var photo_frame = Panel.new()
	photo_frame.position = Vector2(36, 78)
	photo_frame.size = Vector2(568, 250)
	photo_frame.clip_contents = true
	_host._apply_small_card_style(photo_frame)
	panel.add_child(photo_frame)

	var photo_rect = TextureRect.new()
	photo_rect.position = Vector2(12, 12)
	photo_rect.size = Vector2(544, 226)
	photo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	photo_frame.add_child(photo_rect)

	var photo_status = Label.new()
	photo_status.text = "未附加照片。"
	photo_status.position = Vector2(20, 108)
	photo_status.size = Vector2(528, 28)
	photo_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	photo_status.add_theme_color_override("font_color", Color(0.45, 0.37, 0.28, 0.78))
	photo_frame.add_child(photo_status)

	var body = RichTextLabel.new()
	body.text = message
	body.position = Vector2(36, 350)
	body.size = Vector2(568, 110)
	body.fit_content = false
	body.scroll_active = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.fit_content = false
	body.scroll_active = true
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("default_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(body)

	# Add all controls before loading the photo, so the user can close the panel while the image is loading.
	_host._add_panel_button(panel, "删除", Vector2(96, 490), Vector2(120, 40), "delete_place:" + place_id)
	_host._add_panel_button(panel, "返回地图", Vector2(246, 490), Vector2(150, 40), "close")
	_host._add_panel_button(panel, "明信片", Vector2(426, 490), Vector2(130, 40), "MemoryManager.postcards")

	var clean_photo_path: String = photo_path.strip_edges()
	if clean_photo_path == "" or clean_photo_path.to_lower() in ["null", "<null>", "nil", "none"]:
		photo_status.text = "未附加照片。"
	else:
		photo_status.text = "正在加载照片..."
		_load_photo_into_rect(clean_photo_path, photo_rect, photo_status)

func _load_photo_into_rect(photo_reference: String, photo_rect: TextureRect, photo_status: Label) -> void:
	var clean_reference: String = photo_reference.strip_edges()
	if clean_reference == "" or clean_reference.to_lower() in ["null", "<null>", "nil", "none"]:
		if is_instance_valid(photo_status):
			photo_status.text = "未附加照片。"
		return

	if is_instance_valid(photo_rect):
		photo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if photo_texture_cache.has(clean_reference):
		var cached_texture: Texture2D = photo_texture_cache[clean_reference]
		if is_instance_valid(photo_rect):
			photo_rect.texture = cached_texture
		if is_instance_valid(photo_status):
			photo_status.visible = false
		return

	if is_instance_valid(photo_status):
		photo_status.text = "正在加载照片..."

	var photo_url: String = await _resolve_photo_url(clean_reference)
	if photo_url == "":
		if is_instance_valid(photo_status):
			photo_status.text = "照片不可访问或已被删除。"
		return
	var texture: Texture2D = await _download_photo_texture(photo_url)
	if texture != null:
		photo_texture_cache[clean_reference] = texture
		if is_instance_valid(photo_rect):
			photo_rect.texture = texture
		if is_instance_valid(photo_status):
			photo_status.visible = false
	else:
		if is_instance_valid(photo_status):
			photo_status.text = "照片加载失败。"

func _resolve_photo_url(photo_reference: String) -> String:
	if photo_reference.begins_with("upload_"):
		if CloudManager == null:
			return ""
		var resolved: Dictionary = await CloudManager.resolve_private_photo(photo_reference)
		var temporary_url = String(resolved.get("image_url", ""))
		return temporary_url if bool(resolved.get("ok", false)) and temporary_url.begins_with("https://") else ""

	# 历史存档只读兼容：M1 后的新数据不会再写入永久 URL 或 Supabase 路径。
	if photo_reference.begins_with("http://") or photo_reference.begins_with("https://"):
		return photo_reference

	if CloudManager != null:
		return CloudManager.public_url_from_photo_path(photo_reference)

	return photo_reference

func _photo_reference(row: Dictionary) -> String:
	var upload_id = String(row.get("photo_upload_id", "")).strip_edges()
	if upload_id != "":
		return upload_id
	return String(row.get("photo_path", "")).strip_edges()

func _download_photo_texture(url: String) -> Texture2D:
	if url == "":
		return null

	if photo_texture_cache.has(url):
		return photo_texture_cache[url]

	var request = HTTPRequest.new()
	add_child(request)

	var err = request.request(url)
	if err != OK:
		request.queue_free()
		return null

	var response: Array = await request.request_completed
	request.queue_free()

	var result_code: int = int(response[0])
	var status_code: int = int(response[1])
	if result_code != HTTPRequest.RESULT_SUCCESS or status_code < 200 or status_code >= 300:
		return null

	var bytes: PackedByteArray = response[3]
	var image = Image.new()
	var load_err: int = image.load_png_from_buffer(bytes)

	if load_err != OK:
		load_err = image.load_jpg_from_buffer(bytes)

	if load_err != OK:
		load_err = image.load_webp_from_buffer(bytes)

	if load_err != OK:
		return null

	var texture = ImageTexture.create_from_image(image)
	photo_texture_cache[url] = texture
	return texture

func _pin_asset_for_place(place: Dictionary) -> String:
	var postcard = MemoryManager.find_postcard_by_place(str(place.get("id", "")))
	if not postcard.is_empty() and bool(postcard.get("is_new", false)):
		return ASSETS["pin_postcard"]
	return ASSETS["pin_saved"] if ResourceLoader.exists(ASSETS["pin_saved"]) else ASSETS["pin_default"]

func _delete_place(place_id: String) -> void:
	if CloudManager != null:
		var delete_result: Dictionary = await CloudManager.delete_place_and_postcards(place_id)
		if CloudManager.has_cloud_records() and not bool(delete_result.get("ok", false)):
			_host._show_toast(_host._result_error_message(delete_result, "云端删除失败，请稍后重试。"))
			return

	MemoryManager.travel_places = MemoryManager.travel_places.filter(func(place): return str(place.get("id", "")) != place_id)
	MemoryManager.postcards = MemoryManager.postcards.filter(func(postcard): return str(postcard.get("place_id", "")) != place_id)
	if MemoryManager.count_unread_postcards() > 0:
		MemoryManager.set_mailbox_alert(MemoryManager.MAILBOX_ALERT_LETTER)
	elif MemoryManager.mailbox_alert_state == MemoryManager.MAILBOX_ALERT_LETTER:
		MemoryManager.clear_mailbox_alert()
	MemoryManager.save_game()
	_host._close_active_panel()
	if mode == "map":
		_show_travel_map()
	else:
		_host._show_toast("地点已删除。")
