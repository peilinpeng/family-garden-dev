extends HUDPanel
class_name FarmNoticeBoardPanel

const MAX_ROWS := 40
const ROW_HEIGHT := 58
const PANEL_BG := Color(1.0, 0.96, 0.84, 0.96)
const INK := Color(0.24, 0.18, 0.12, 0.96)
const SOFT_INK := Color(0.46, 0.34, 0.22, 0.78)
const LINE := Color(0.62, 0.44, 0.26, 0.35)

var _list: VBoxContainer

func _init() -> void:
	panel_title = "农场告示牌"
	card_size = Vector2(620, 520)

func _build_content() -> void:
	var intro := Label.new()
	intro.text = "家人在农场做过的事会贴在这里。"
	intro.add_theme_font_size_override("font_size", 15)
	intro.add_theme_color_override("font_color", SOFT_INK)
	content_root.add_child(intro)

	var line := ColorRect.new()
	line.color = LINE
	line.custom_minimum_size = Vector2(0, 2)
	content_root.add_child(line)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	if MemoryManager != null and not MemoryManager.farm_activity_changed.is_connected(_rebuild):
		MemoryManager.farm_activity_changed.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	var rows: Array = MemoryManager.recent_farm_activities(MAX_ROWS) if MemoryManager != null else []
	if rows.is_empty():
		_list.add_child(_empty_state())
		return
	for raw in rows:
		if raw is Dictionary:
			_list.add_child(_activity_row(raw))

func _empty_state() -> Control:
	var label := Label.new()
	label.text = "还没有农场记录，先种点什么吧。"
	label.custom_minimum_size = Vector2(0, 180)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", SOFT_INK)
	return label

func _activity_row(row: Dictionary) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	panel.add_theme_stylebox_override("panel", _row_box())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)

	var title := Label.new()
	title.text = "%s %s" % [_actor_name(row), str(row.get("detail", ""))]
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", INK)
	box.add_child(title)

	var meta := Label.new()
	meta.text = "%s · %s" % [_relative_time(int(row.get("created_at_unix", 0))), _label_text(row)]
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", SOFT_INK)
	box.add_child(meta)
	return panel

func _actor_name(row: Dictionary) -> String:
	var name := str(row.get("actor_name", "")).strip_edges()
	if name != "":
		return name
	var role := str(row.get("actor_role", ""))
	if CharacterDB != null:
		return CharacterDB.display_name(role)
	return "家人"

func _label_text(row: Dictionary) -> String:
	var label := str(row.get("label", "")).strip_edges()
	return label if label != "" else "农场动态"

func _relative_time(unix_time: int) -> String:
	if unix_time <= 0:
		return "刚刚"
	var delta := int(Time.get_unix_time_from_system()) - unix_time
	if delta < 60:
		return "刚刚"
	if delta < 3600:
		return "%d分钟前" % int(delta / 60)
	if delta < 86400:
		return "%d小时前" % int(delta / 3600)
	return "%d天前" % int(delta / 86400)

func _row_box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
