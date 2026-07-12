extends Control
class_name PlayerProfileCard

## 左上角常驻玩家卡片:头像 + 昵称 + 极小家园标识。整卡可点,打开个人资料面板。
## 数据来自 CharacterDB.avatar_texture / MemoryManager.player_display_name;refresh() 可在昵称变更后刷新。

signal pressed

const CARD_SIZE := Vector2(224, 64)

var _avatar: TextureRect
var _name_label: Label
var _hit: Button
var _scale_tween: Tween

func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = CARD_SIZE * 0.5

	var board := Panel.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1.0, 0.96, 0.86, 0.90)
	box.border_color = Color(0.62, 0.46, 0.28, 0.75)
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	box.shadow_color = Color(0.20, 0.14, 0.08, 0.18)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 2)
	board.add_theme_stylebox_override("panel", box)
	add_child(board)

	var avatar_frame := Panel.new()
	avatar_frame.position = Vector2(8, 8)
	avatar_frame.size = Vector2(48, 48)
	avatar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fb := StyleBoxFlat.new()
	fb.bg_color = Color(1.0, 0.98, 0.92, 1.0)
	fb.border_color = Color(0.62, 0.46, 0.28, 0.9)
	fb.set_border_width_all(1)
	fb.set_corner_radius_all(12)
	avatar_frame.add_theme_stylebox_override("panel", fb)
	add_child(avatar_frame)

	_avatar = TextureRect.new()
	_avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_avatar.offset_left = 3
	_avatar.offset_top = 3
	_avatar.offset_right = -3
	_avatar.offset_bottom = -3
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_frame.add_child(_avatar)

	_name_label = Label.new()
	_name_label.position = Vector2(66, 12)
	_name_label.size = Vector2(CARD_SIZE.x - 74, 22)
	_name_label.add_theme_font_size_override("font_size", 17)
	_name_label.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 1.0))
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	var home := Label.new()
	home.text = "🏡 温馨小家"
	home.position = Vector2(66, 36)
	home.size = Vector2(CARD_SIZE.x - 74, 18)
	home.add_theme_font_size_override("font_size", 12)
	home.add_theme_color_override("font_color", Color(0.48, 0.38, 0.27, 0.85))
	home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(home)

	# 透明命中层:整卡可点 + 键盘可聚焦。
	_hit = Button.new()
	_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hit.flat = true
	_hit.focus_mode = Control.FOCUS_ALL
	_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		_hit.add_theme_stylebox_override(s, empty)
	_hit.mouse_entered.connect(func() -> void: _tween_scale(1.03))
	_hit.mouse_exited.connect(func() -> void: _tween_scale(1.0))
	_hit.focus_entered.connect(func() -> void: _tween_scale(1.03))
	_hit.focus_exited.connect(func() -> void: _tween_scale(1.0))
	_hit.pressed.connect(_on_pressed)
	add_child(_hit)

	refresh()

## 昵称/头像变更后调用(如角色选择完成)。
func refresh() -> void:
	if _avatar != null:
		_avatar.texture = CharacterDB.avatar_texture(MemoryManager.selected_role_key)
	if _name_label != null:
		var n: String = MemoryManager.player_display_name.strip_edges()
		if n == "":
			n = CharacterDB.display_name(MemoryManager.selected_role_key)
		_name_label.text = n

func _on_pressed() -> void:
	AudioManager.play_sfx("按钮")
	pressed.emit()

func _tween_scale(target: float) -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE * target, 0.10)
