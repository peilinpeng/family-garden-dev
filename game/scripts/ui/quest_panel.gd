extends HUDPanel
class_name QuestPanel

## Chapter 1 任务面板。checklist:✓已完成 / ▶当前(高亮) / ·未开始。
## 任务定义与进度都在 StoryManager;task2(放入第一张照片)由本面板的占位照片按钮完成
## (spec 允许占位照片;未来接真实相册/上传)。农场/厨房任务由信号自动打勾。

func _init() -> void:
	panel_title = "Chapter 1 · 重新打开花园"
	card_size = Vector2(520, 480)

func _build_content() -> void:
	# 章节横幅(缺美术,文字条占位)
	var banner := Label.new()
	banner.text = "🌿 把这里一点点变回家的样子"
	banner.add_theme_font_size_override("font_size", 14)
	banner.add_theme_color_override("font_color", Color(0.45, 0.36, 0.26, 0.95))
	content_root.add_child(banner)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_root.add_child(list)

	var current: String = StoryManager.current_task()
	for t in StoryManager.tasks():
		var tid: String = str(t.id)
		list.add_child(_task_row(tid, str(t.label), StoryManager.is_task_done(tid), tid == current))

	# 全部完成的小结语
	if current == "":
		var done := Label.new()
		done.text = "🎉 第一章完成!花园重新有了生活的气息。"
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
		mark.text = "✅"
	elif is_current:
		mark.text = "▶"
		mark.add_theme_color_override("font_color", Color(0.85, 0.55, 0.20, 1.0))
	else:
		mark.text = "·"
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

	# task2 的完成入口:当前任务是放照片时给一个占位照片按钮
	if tid == "first_photo" and not done and is_current:
		var btn := Button.new()
		btn.name = "QuestAction_first_photo"
		btn.text = "🖼️ 放入一张照片"
		btn.custom_minimum_size = Vector2(140, 34)
		HUDPanel._style_soft_button(btn)
		btn.pressed.connect(func() -> void:
			if StoryManager.complete_task("first_photo"):
				StoryManager.unlock_card("first_photo")
			close_requested.emit())
		row.add_child(btn)
	# 依赖农场/厨房的任务,给一句去哪儿做的提示(不阻塞、不报错)
	elif tid in ["first_seed", "harvest_tomato"] and is_current:
		row.add_child(_where_hint("去农场"))
	elif tid in ["first_dish", "dish_on_table"] and is_current:
		row.add_child(_where_hint("去厨房"))
	return row

func _where_hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.60, 0.48, 0.30, 0.85))
	return l
