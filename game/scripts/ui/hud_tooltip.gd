extends Control
class_name HUDTooltip

## HUD 图标的自定义 tooltip 小气泡(像素风,暖色圆角)。
## GameHUD 把它挂在最上层的 TooltipLayer,图标 hover 时调 show_for(),移出调 hide_tip()。
## 全程 mouse_filter = IGNORE,绝不遮挡/拦截按钮本身;按 side 相对图标定位并夹在屏幕内。

const GAP := 10.0
const PAD_X := 12.0
const PAD_Y := 7.0
const GAME_SIZE := Vector2(1280, 720)

var _panel: Panel
var _label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.20, 0.15, 0.11, 0.94)
	box.border_color = Color(0.95, 0.82, 0.55, 0.85)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 2)
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2(PAD_X, PAD_Y)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90, 1.0))
	_panel.add_child(_label)

## side: HUDIconButton.Side 的整数值(0 LEFT / 1 RIGHT / 2 TOP / 3 BOTTOM),表示气泡出现在图标的哪一侧。
func show_for(text: String, anchor_rect: Rect2, side: int) -> void:
	if text.strip_edges() == "":
		hide_tip()
		return
	_label.text = text
	var content: Vector2 = _label.get_minimum_size()
	var box_size := Vector2(content.x + PAD_X * 2.0, content.y + PAD_Y * 2.0)
	_panel.size = box_size
	_panel.position = _place(anchor_rect, side, box_size)
	visible = true

func hide_tip() -> void:
	visible = false

func _place(anchor: Rect2, side: int, box_size: Vector2) -> Vector2:
	var center := anchor.get_center()
	var pos := Vector2.ZERO
	match side:
		0:   # LEFT:气泡在图标左侧
			pos = Vector2(anchor.position.x - GAP - box_size.x, center.y - box_size.y * 0.5)
		2:   # TOP
			pos = Vector2(center.x - box_size.x * 0.5, anchor.position.y - GAP - box_size.y)
		3:   # BOTTOM
			pos = Vector2(center.x - box_size.x * 0.5, anchor.position.y + anchor.size.y + GAP)
		_:   # RIGHT(默认):气泡在图标右侧
			pos = Vector2(anchor.position.x + anchor.size.x + GAP, center.y - box_size.y * 0.5)
	# 夹在屏幕内,避免溢出被裁。
	pos.x = clampf(pos.x, 4.0, GAME_SIZE.x - box_size.x - 4.0)
	pos.y = clampf(pos.y, 4.0, GAME_SIZE.y - box_size.y - 4.0)
	return pos
