extends Control
class_name HUDIconButton

## 常驻 HUD 的统一图标按钮。纯图标、无文字标签,悬停出 tooltip,五态视觉封装在一处,
## 避免每个按钮各写一套样式。GameHUD 用它拼左右导航 / 设置 / 背包等入口。
##
## 用法(代码构建):
##   var b := HUDIconButton.new()
##   b.icon_texture = tex; b.tooltip_label = "地图 / Map"; b.action_id = "map"
##   b.tooltip_side = HUDIconButton.Side.LEFT
##   add_child(b); b.pressed.connect(...)
##
## 五态:default / hover(含键盘 focus)/ pressed / active(外部 set_active 驱动,表示对应面板开着)
##      / disabled(灰化不可点)。

enum Side { LEFT, RIGHT, TOP, BOTTOM }

signal pressed
signal hover_started(text: String, anchor_rect: Rect2, side: int)
signal hover_ended

@export var icon_texture: Texture2D
@export var tooltip_label: String = ""
@export var action_id: String = ""
@export var tooltip_side: int = Side.RIGHT   ## 取 Side 枚举值;用 int 以便跨脚本赋值时类型可解析
@export var start_disabled: bool = false
@export var button_size: Vector2 = Vector2(52, 52)

var _visual: Control
var _board: Panel
var _icon: TextureRect
var _hit: Button
var _active := false
var _hovering := false
var _scale_tween: Tween

const _INSET := 9.0

func _ready() -> void:
	custom_minimum_size = button_size
	size = button_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 交互交给内部的 _hit Button

	# 缩放容器:hover/press 时整体放大/缩小,绕中心枢轴。
	_visual = Control.new()
	_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visual)

	_board = Panel.new()
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(_board)

	_icon = TextureRect.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = _INSET
	_icon.offset_top = _INSET
	_icon.offset_right = -_INSET
	_icon.offset_bottom = -_INSET
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 缩放不糊
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_texture != null:
		_icon.texture = icon_texture
	_visual.add_child(_icon)

	# 命中层:透明 flat Button,负责鼠标 hover/press + 键盘 focus/Enter,盖在最上。
	_hit = Button.new()
	_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hit.flat = true
	_hit.focus_mode = Control.FOCUS_ALL
	_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		_hit.add_theme_stylebox_override(s, empty)
	_hit.mouse_entered.connect(_on_hover_enter)
	_hit.mouse_exited.connect(_on_hover_exit)
	_hit.focus_entered.connect(_on_hover_enter)
	_hit.focus_exited.connect(_on_hover_exit)
	_hit.button_down.connect(_on_down)
	_hit.button_up.connect(_on_up)
	_hit.pressed.connect(_on_pressed)
	_visual.add_child(_hit)

	resized.connect(_recenter_pivot)
	_recenter_pivot()
	_refresh_board()
	if start_disabled:
		set_disabled(true)

func _recenter_pivot() -> void:
	if _visual != null:
		_visual.pivot_offset = size * 0.5

# ---------- 外部 API ----------

func set_icon(tex: Texture2D) -> void:
	icon_texture = tex
	if _icon != null:
		_icon.texture = tex

## 选中态:对应面板正在打开时为 true(底板更深/描边更明显)。
func set_active(on: bool) -> void:
	_active = on
	_refresh_board()

func is_active() -> bool:
	return _active

func set_disabled(on: bool) -> void:
	if _hit != null:
		_hit.disabled = on
	modulate = Color(1, 1, 1, 0.45) if on else Color(1, 1, 1, 1)
	if on:
		_hovering = false
		_tween_scale(1.0)
	_refresh_board()

func is_disabled() -> bool:
	return _hit != null and _hit.disabled

func grab_button_focus() -> void:
	if _hit != null:
		_hit.grab_focus()

# ---------- 交互回调 ----------

func _on_hover_enter() -> void:
	if is_disabled():
		return
	_hovering = true
	_tween_scale(1.05)
	_refresh_board()
	hover_started.emit(tooltip_label, get_global_rect(), int(tooltip_side))

func _on_hover_exit() -> void:
	_hovering = false
	_tween_scale(1.0)
	_refresh_board()
	hover_ended.emit()

func _on_down() -> void:
	if not is_disabled():
		_tween_scale(0.96)

func _on_up() -> void:
	if not is_disabled():
		_tween_scale(1.05 if _hovering else 1.0)

func _on_pressed() -> void:
	if is_disabled():
		return
	AudioManager.play_sfx("按钮")   # 复用现有点击音效接口,不新增音频资源
	pressed.emit()

func _tween_scale(target: float) -> void:
	if _visual == null:
		return
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(_visual, "scale", Vector2.ONE * target, 0.10)

func _refresh_board() -> void:
	if _board == null:
		return
	var box: StyleBoxFlat
	if _active:
		box = _make_box(Color(0.98, 0.90, 0.66, 0.98), Color(0.80, 0.55, 0.25, 1.0), 2, 6, Color(0.30, 0.20, 0.10, 0.22))
	elif _hovering:
		box = _make_box(Color(1.0, 0.98, 0.90, 0.96), Color(0.92, 0.62, 0.32, 0.95), 2, 8, Color(0.30, 0.20, 0.10, 0.24))
	else:
		box = _make_box(Color(1.0, 0.96, 0.86, 0.82), Color(0.64, 0.48, 0.30, 0.55), 1, 4, Color(0.20, 0.14, 0.08, 0.14))
	_board.add_theme_stylebox_override("panel", box)

func _make_box(bg: Color, border: Color, border_w: int, shadow: int, shadow_col: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(12)
	b.shadow_color = shadow_col
	b.shadow_size = shadow
	b.shadow_offset = Vector2(0, 2)
	return b
