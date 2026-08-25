extends Control
class_name TutorialHighlightOverlay

## 新手流程的非阻塞聚光灯。四块半透明遮罩围出目标区域，底层目标仍可直接点击。

signal skipped

const HOLE_PADDING := 10.0
const CARD_SIZE := Vector2(336, 102)

var _target: Control
var _message_label: Label
var _card: Panel
var _pulse := 0.0
var _last_hole := Rect2()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_card()
	set_process(true)

func _build_card() -> void:
	_card = Panel.new()
	_card.name = "GuideCard"
	_card.size = CARD_SIZE
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(1.0, 0.96, 0.83, 0.98)
	card_style.border_color = Color(0.88, 0.60, 0.25, 1.0)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(13)
	card_style.shadow_color = Color(0.12, 0.08, 0.04, 0.28)
	card_style.shadow_size = 10
	card_style.shadow_offset = Vector2(0, 3)
	_card.add_theme_stylebox_override("panel", card_style)
	add_child(_card)

	var title := Label.new()
	title.text = "新手指引"
	title.position = Vector2(16, 10)
	title.size = Vector2(120, 22)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.49, 0.31, 0.14, 1.0))
	_card.add_child(title)

	_message_label = Label.new()
	_message_label.position = Vector2(16, 34)
	_message_label.size = Vector2(304, 40)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label.add_theme_font_size_override("font_size", 15)
	_message_label.add_theme_color_override("font_color", Color(0.23, 0.18, 0.13, 1.0))
	_card.add_child(_message_label)

	var skip := Button.new()
	skip.name = "SkipGuideButton"
	skip.text = "跳过引导"
	skip.position = Vector2(238, 72)
	skip.size = Vector2(82, 24)
	skip.focus_mode = Control.FOCUS_NONE
	skip.mouse_filter = Control.MOUSE_FILTER_STOP
	skip.flat = true
	skip.add_theme_font_size_override("font_size", 12)
	skip.add_theme_color_override("font_color", Color(0.45, 0.36, 0.26, 0.82))
	skip.pressed.connect(func() -> void: skipped.emit())
	_card.add_child(skip)

func highlight(target: Control, message: String) -> void:
	_target = target
	_message_label.text = message
	visible = target != null and is_instance_valid(target)
	_update_layout()
	queue_redraw()

func clear_highlight() -> void:
	_target = null
	visible = false
	_last_hole = Rect2()
	queue_redraw()

func is_highlighting() -> bool:
	return visible and _target != null and is_instance_valid(_target)

func target() -> Control:
	return _target if is_highlighting() else null

func _process(delta: float) -> void:
	if not visible:
		return
	_pulse = fmod(_pulse + delta * 2.4, TAU)
	if _target == null or not is_instance_valid(_target) or not _target.is_visible_in_tree():
		clear_highlight()
		return
	_update_layout()
	queue_redraw()

func _target_hole() -> Rect2:
	if _target == null or not is_instance_valid(_target):
		return Rect2()
	var global_rect := _target.get_global_rect().grow(HOLE_PADDING)
	return Rect2(global_rect.position - global_position, global_rect.size)

func _update_layout() -> void:
	if not is_highlighting() or _card == null:
		return
	_last_hole = _target_hole()
	var card_x := clampf(_last_hole.get_center().x - CARD_SIZE.x * 0.5, 18.0, maxf(18.0, size.x - CARD_SIZE.x - 18.0))
	var card_y := _last_hole.position.y - CARD_SIZE.y - 22.0
	if card_y < 18.0:
		card_y = _last_hole.end.y + 22.0
	card_y = clampf(card_y, 18.0, maxf(18.0, size.y - CARD_SIZE.y - 18.0))
	_card.position = Vector2(card_x, card_y)

func _draw() -> void:
	if not is_highlighting():
		return
	var hole := _target_hole()
	if hole.size == Vector2.ZERO:
		return
	var shade := Color(0.08, 0.06, 0.04, 0.58)
	# 四块遮罩围出真正透明的目标区域，避免整屏蒙版再假画高亮造成目标仍发暗。
	draw_rect(Rect2(0, 0, size.x, maxf(0.0, hole.position.y)), shade)
	draw_rect(Rect2(0, hole.end.y, size.x, maxf(0.0, size.y - hole.end.y)), shade)
	draw_rect(Rect2(0, hole.position.y, maxf(0.0, hole.position.x), hole.size.y), shade)
	draw_rect(Rect2(hole.end.x, hole.position.y, maxf(0.0, size.x - hole.end.x), hole.size.y), shade)
	var pulse_alpha := 0.72 + (sin(_pulse) + 1.0) * 0.14
	draw_rect(hole.grow(3.0), Color(1.0, 0.72, 0.26, pulse_alpha * 0.34), false, 7.0)
	draw_rect(hole, Color(1.0, 0.78, 0.34, pulse_alpha), false, 3.0)
