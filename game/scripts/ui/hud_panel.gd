extends Control
class_name HUDPanel

## HUD 主面板基类:统一的半透明遮罩 + 居中圆角卡片 + 标题 + 右上关闭按钮。
## 子类(ProfilePanel / SettingsPanel / InventoryPanel)只需在 content_root 里填内容。
## 由 GameHUD 统一开关(单面板互斥 + 锁玩家移动);点击遮罩空白处或关闭按钮都触发 close_requested。

signal close_requested

@export var panel_title: String = ""
@export var card_size: Vector2 = Vector2(520, 380)

var card: Panel
var content_root: VBoxContainer
var _title_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 吃掉面板范围内的点击,不漏到游戏世界

	var shade := ColorRect.new()
	shade.color = Color(0.10, 0.08, 0.06, 0.24)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_shade_input)   # 点空白处关闭
	add_child(shade)

	# 用 CenterContainer 居中,自动跟随实际可视区(工程是 expand 拉伸,窗口尺寸≠1280×720,不能硬算)。
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 空白处点击穿到下面的 shade 触发关闭
	add_child(center)

	card = Panel.new()
	card.custom_minimum_size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_card_style(card)
	center.add_child(card)

	_title_label = Label.new()
	_title_label.text = panel_title
	_title_label.position = Vector2(28, 22)
	_title_label.size = Vector2(card_size.x - 90, 34)
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	card.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.size = Vector2(34, 30)
	close_btn.position = Vector2(card_size.x - 46, 12)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_soft_button(close_btn)
	close_btn.pressed.connect(func() -> void: close_requested.emit())
	card.add_child(close_btn)

	content_root = VBoxContainer.new()
	content_root.position = Vector2(28, 70)
	content_root.size = Vector2(card_size.x - 56, card_size.y - 98)
	content_root.add_theme_constant_override("separation", 12)
	card.add_child(content_root)

	_build_content()

## 子类重写:往 content_root 填内容。
func _build_content() -> void:
	pass

func set_title(t: String) -> void:
	panel_title = t
	if _title_label != null:
		_title_label.text = t

func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()

func _apply_card_style(p: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.95, 0.82, 0.97)
	style.border_color = Color(0.60, 0.43, 0.25, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.20, 0.12, 0.06, 0.24)
	style.shadow_size = 12
	p.add_theme_stylebox_override("panel", style)

## 供子类复用的柔和小按钮样式(暖色、圆角、hover/press 反馈)。
static func _style_soft_button(b: Button) -> void:
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16, 1.0))
	b.add_theme_color_override("font_hover_color", Color(0.20, 0.15, 0.10, 1.0))
	b.add_theme_stylebox_override("normal", _soft_box(Color(1.0, 0.93, 0.76, 0.95), Color(0.60, 0.46, 0.30, 0.8), 1))
	b.add_theme_stylebox_override("hover", _soft_box(Color(1.0, 0.97, 0.84, 0.98), Color(0.90, 0.62, 0.32, 0.95), 2))
	b.add_theme_stylebox_override("pressed", _soft_box(Color(0.94, 0.88, 0.66, 0.98), Color(0.72, 0.52, 0.28, 1.0), 2))
	b.add_theme_stylebox_override("focus", _soft_box(Color(1.0, 0.97, 0.84, 0.98), Color(0.90, 0.62, 0.32, 0.95), 2))

static func _soft_box(bg: Color, border: Color, w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(w)
	box.set_corner_radius_all(10)
	return box
