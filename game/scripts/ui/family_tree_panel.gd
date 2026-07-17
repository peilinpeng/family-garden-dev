extends HUDPanel
class_name FamilyTreePanel

signal plant_requested

const TEXTURE_PATTERN := "res://assets/garden/family_tree/stage_%d.png"
const STAGE_NAMES := ["幼苗", "新芽", "初长", "繁茂", "家树"]

func _init() -> void:
	panel_title = "家庭树"
	card_size = Vector2(780, 520)

func _build_content() -> void:
	var stage := MemoryManager.family_tree_stage()
	var interactions := MemoryManager.cross_member_interaction_count
	var next_threshold := MemoryManager.family_tree_next_threshold()

	var main := HBoxContainer.new()
	main.custom_minimum_size = Vector2(0, 320)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 20)
	content_root.add_child(main)

	main.add_child(_build_tree_preview(stage))
	main.add_child(_build_progress_card(stage, interactions, next_threshold))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	content_root.add_child(footer)

	var hint := Label.new()
	hint.text = "树根会固定在你选择的位置，成长不会改变花园的可见范围。"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.43, 0.35, 0.25, 0.9))
	footer.add_child(hint)

	var action := Button.new()
	action.name = "FamilyTreePlantButton"
	action.custom_minimum_size = Vector2(150, 42)
	action.focus_mode = Control.FOCUS_NONE
	HUDPanel._style_soft_button(action)
	if MemoryManager.has_planted_family_tree():
		action.text = "已种在花园"
		action.disabled = true
		action.tooltip_text = "可以在花园中直接拖动家庭树调整位置。"
	else:
		action.text = "种下幼苗"
		action.pressed.connect(func() -> void:
			close_requested.emit()
			plant_requested.emit())
	footer.add_child(action)

func _build_tree_preview(stage: int) -> Panel:
	var preview := Panel.new()
	preview.custom_minimum_size = Vector2(360, 320)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.86, 0.91, 0.72, 0.55)
	box.border_color = Color(0.52, 0.58, 0.34, 0.5)
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	preview.add_theme_stylebox_override("panel", box)

	var texture_rect := TextureRect.new()
	texture_rect.name = "FamilyTreeStagePreview"
	texture_rect.position = Vector2(22, 18)
	texture_rect.size = Vector2(316, 260)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := TEXTURE_PATTERN % stage
	if ResourceLoader.exists(path):
		texture_rect.texture = load(path)
	preview.add_child(texture_rect)

	var caption := Label.new()
	caption.text = "第 %d 阶段 · %s" % [stage, STAGE_NAMES[stage - 1]]
	caption.position = Vector2(20, 280)
	caption.size = Vector2(320, 28)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 17)
	caption.add_theme_color_override("font_color", Color(0.30, 0.28, 0.16, 1.0))
	preview.add_child(caption)
	return preview

func _build_progress_card(stage: int, interactions: int, next_threshold: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(320, 320)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)

	var status := Label.new()
	status.text = "已种植" if MemoryManager.has_planted_family_tree() else "幼苗等待种植"
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override(
		"font_color",
		Color(0.31, 0.52, 0.24, 1.0) if MemoryManager.has_planted_family_tree() else Color(0.78, 0.48, 0.18, 1.0)
	)
	column.add_child(status)

	var description := Label.new()
	description.text = "家人回答彼此留下的记忆时，家庭树会积累真实互动并逐渐成长。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(0, 64)
	description.add_theme_font_size_override("font_size", 15)
	description.add_theme_color_override("font_color", Color(0.31, 0.26, 0.20, 0.95))
	column.add_child(description)

	var count := Label.new()
	count.text = "家庭互动量  %d" % interactions
	count.add_theme_font_size_override("font_size", 16)
	count.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16, 1.0))
	column.add_child(count)

	var progress := ProgressBar.new()
	progress.name = "FamilyTreeProgress"
	progress.custom_minimum_size = Vector2(0, 24)
	progress.show_percentage = false
	progress.min_value = 0
	progress.max_value = float(next_threshold if next_threshold > 0 else 10)
	progress.value = float(interactions if next_threshold > 0 else 10)
	progress.add_theme_stylebox_override("background", HUDPanel._soft_box(Color(0.91, 0.85, 0.69, 0.7), Color(0.63, 0.51, 0.34, 0.55), 1))
	progress.add_theme_stylebox_override("fill", HUDPanel._soft_box(Color(0.66, 0.78, 0.42, 0.95), Color(0.45, 0.58, 0.25, 0.9), 1))
	column.add_child(progress)

	var progress_text := Label.new()
	if next_threshold < 0:
		progress_text.text = "家庭树已经长成最终形态。"
	else:
		progress_text.text = "再完成 %d 次跨成员互动，即可成长到第 %d 阶段。" % [max(0, next_threshold - interactions), stage + 1]
	progress_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_text.custom_minimum_size = Vector2(0, 48)
	progress_text.add_theme_font_size_override("font_size", 14)
	progress_text.add_theme_color_override("font_color", Color(0.46, 0.38, 0.26, 0.92))
	column.add_child(progress_text)

	var rule := Label.new()
	rule.text = "有效互动：回答者与记忆上传者不同；同一位成员对同一段记忆只计算一次。"
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rule.add_theme_font_size_override("font_size", 12)
	rule.add_theme_color_override("font_color", Color(0.49, 0.42, 0.33, 0.75))
	column.add_child(rule)
	return column
