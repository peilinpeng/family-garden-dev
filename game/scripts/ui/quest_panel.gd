extends HUDPanel
class_name QuestPanel

## 三章主线与主线结束后的开放成长目标面板。

func _init() -> void:
	var chapter := StoryManager.current_chapter()
	panel_title = "主线完成 · 开放成长" if chapter == 0 else "第 %d 章 · %s" % [chapter, StoryManager.chapter_title(chapter)]
	card_size = Vector2(520, 480)

func _build_content() -> void:
	var banner := Label.new()
	banner.text = StoryManager.chapter_subtitle()
	banner.add_theme_font_size_override("font_size", 14)
	banner.add_theme_color_override("font_color", Color(0.45, 0.36, 0.26, 0.95))
	content_root.add_child(banner)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_root.add_child(list)

	var chapter := StoryManager.current_chapter()
	var current: String = StoryManager.current_task()
	if chapter == 0:
		for milestone in StoryManager.milestone_status():
			list.add_child(_milestone_row(milestone))
	else:
		for t in StoryManager.tasks(chapter):
			var tid: String = str(t.id)
			list.add_child(_task_row(tid, str(t.label), StoryManager.is_task_done(tid), tid == current))

	# 全部完成的小结语
	if chapter == 0:
		var done := Label.new()
		done.text = "主线已经完成。花园会随着你的生活继续成长。"
		done.add_theme_font_size_override("font_size", 14)
		done.add_theme_color_override("font_color", Color(0.35, 0.50, 0.28, 1.0))
		content_root.add_child(done)

func _task_row(tid: String, label: String, done: bool, is_current: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var mark := Label.new()
	mark.custom_minimum_size = Vector2(26, 0)
	mark.add_theme_font_size_override("font_size", 16)
	if done:
		mark.text = "完成"
	elif is_current:
		mark.text = "当前"
		mark.add_theme_color_override("font_color", Color(0.85, 0.55, 0.20, 1.0))
	else:
		mark.text = "稍后"
		mark.add_theme_color_override("font_color", Color(0.55, 0.46, 0.35, 0.6))
	row.add_child(mark)

	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	if done:
		lbl.add_theme_color_override("font_color", Color(0.45, 0.40, 0.32, 0.75))
	elif is_current:
		lbl.add_theme_color_override("font_color", Color(0.22, 0.17, 0.12, 1.0))
	else:
		lbl.add_theme_color_override("font_color", Color(0.42, 0.35, 0.27, 0.85))
	row.add_child(lbl)

	# 旧木盒照片沿用现有开场素材；这里完成“收好照片”的确认。
	if tid == "first_photo" and not done and is_current:
		var btn := Button.new()
		btn.name = "QuestAction_first_photo"
		btn.text = "收好照片"
		btn.custom_minimum_size = Vector2(140, 34)
		HUDPanel._style_soft_button(btn)
		btn.pressed.connect(func() -> void:
			if StoryManager.complete_task("first_photo"):
				StoryManager.unlock_card("first_photo")
			close_requested.emit())
		row.add_child(btn)
	elif tid == "collect_memory_flower" and not done and is_current:
		var collect := Button.new()
		collect.text = "收录记忆花"
		collect.custom_minimum_size = Vector2(130, 34)
		HUDPanel._style_soft_button(collect)
		collect.pressed.connect(func() -> void:
			StoryManager.collect_first_memory_flower()
			close_requested.emit())
		row.add_child(collect)
	elif tid == "garden_edit" and is_current:
		row.add_child(_where_hint("在花园打开编辑"))
	elif tid in ["first_seed", "harvest_tomato"] and is_current:
		row.add_child(_travel_button("去农场", "farm"))
	elif tid in ["first_dish", "dish_on_table"] and is_current:
		row.add_child(_where_hint("去厨房"))
	elif tid in ["first_fishing", "first_bottle"] and is_current:
		row.add_child(_where_hint("去河边"))
	elif tid in ["first_place", "first_postcard"] and is_current:
		row.add_child(_where_hint("打开地图"))
	elif tid == "first_ai_room" and is_current:
		row.add_child(_where_hint("进入我的房间"))
	return row

func _milestone_row(data: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var title := Label.new()
	title.text = ("已达成 · " if bool(data.get("done", false)) else "成长目标 · ") + str(data.get("title", ""))
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	var progress := Label.new()
	progress.text = str(data.get("progress", "")) + "\n奖励：" + str(data.get("reward", ""))
	progress.add_theme_font_size_override("font_size", 13)
	progress.add_theme_color_override("font_color", Color(0.48, 0.40, 0.29, 0.95))
	box.add_child(progress)
	return box

func _where_hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.60, 0.48, 0.30, 0.85))
	return l

func _travel_button(text: String, target: String) -> Button:
	var button := Button.new()
	button.name = "QuestTravel_" + target
	button.text = text
	button.custom_minimum_size = Vector2(86, 30)
	button.focus_mode = Control.FOCUS_NONE
	HUDPanel._style_soft_button(button)
	button.pressed.connect(func() -> void:
		close_requested.emit()
		SceneManager.goto_scene(target))
	return button
