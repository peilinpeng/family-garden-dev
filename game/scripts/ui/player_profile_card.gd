extends Control
class_name PlayerProfileCard

## 左上角统一家庭状态卡：身份、家园与花园核心数据只占一个视觉层级。
## 头像/昵称区域打开个人资料，“家人”数据可直接打开家庭成员。

signal pressed
signal members_pressed

const CARD_SIZE := Vector2(304, 68)

var _avatar: TextureRect
var _name_label: Label
var _stats_label: Label
var _profile_hit: Button
var _members_hit: Button
var _scale_tween: Tween

func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = Vector2(24, 24)

	var board := Panel.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1.0, 0.96, 0.86, 0.88)
	box.border_color = Color(0.54, 0.40, 0.25, 0.68)
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.shadow_color = Color(0.20, 0.14, 0.08, 0.16)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 2)
	board.add_theme_stylebox_override("panel", box)
	add_child(board)

	var accent := ColorRect.new()
	accent.position = Vector2(7, 10)
	accent.size = Vector2(3, 48)
	accent.color = Color(0.48, 0.67, 0.38, 0.90)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent)

	var avatar_frame := Panel.new()
	avatar_frame.position = Vector2(16, 10)
	avatar_frame.size = Vector2(48, 48)
	avatar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fb := StyleBoxFlat.new()
	fb.bg_color = Color(1.0, 0.98, 0.92, 0.96)
	fb.border_color = Color(0.58, 0.43, 0.27, 0.76)
	fb.set_border_width_all(1)
	fb.set_corner_radius_all(10)
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
	_name_label.position = Vector2(74, 8)
	# 右侧 250px 起是成员按钮；限制文字绘制范围，关怀模式放大字号后也不能越界叠字。
	_name_label.size = Vector2(168, 24)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.add_theme_font_size_override("font_size", 17)
	_name_label.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 1.0))
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	_stats_label = Label.new()
	_stats_label.position = Vector2(74, 35)
	_stats_label.size = Vector2(168, 20)
	_stats_label.clip_text = true
	_stats_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_stats_label.add_theme_font_size_override("font_size", 11)
	_stats_label.add_theme_color_override("font_color", Color(0.43, 0.35, 0.24, 0.88))
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stats_label)

	_profile_hit = _transparent_hit_button()
	_profile_hit.position = Vector2.ZERO
	_profile_hit.size = Vector2(246, CARD_SIZE.y)
	_profile_hit.tooltip_text = "打开我的家庭资料"
	_profile_hit.mouse_entered.connect(func() -> void: _tween_scale(1.018))
	_profile_hit.mouse_exited.connect(func() -> void: _tween_scale(1.0))
	_profile_hit.pressed.connect(func() -> void:
		AudioManager.play_sfx("按钮")
		pressed.emit())
	add_child(_profile_hit)

	_members_hit = Button.new()
	_members_hit.text = "家人"
	_members_hit.position = Vector2(250, 20)
	_members_hit.size = Vector2(44, 28)
	_members_hit.focus_mode = Control.FOCUS_ALL
	_members_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_members_hit.tooltip_text = "查看家庭成员"
	_members_hit.add_theme_font_size_override("font_size", 11)
	_members_hit.add_theme_color_override("font_color", Color(0.30, 0.27, 0.17, 0.92))
	_members_hit.add_theme_stylebox_override("normal", _member_box(Color(0.80, 0.87, 0.63, 0.72)))
	_members_hit.add_theme_stylebox_override("hover", _member_box(Color(0.86, 0.91, 0.69, 0.96)))
	_members_hit.add_theme_stylebox_override("pressed", _member_box(Color(0.72, 0.82, 0.56, 0.96)))
	_members_hit.pressed.connect(func() -> void:
		AudioManager.play_sfx("按钮")
		members_pressed.emit())
	add_child(_members_hit)

	refresh()

func _transparent_hit_button() -> Button:
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_ALL
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		hit.add_theme_stylebox_override(state_name, empty)
	return hit

func _member_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color(0.43, 0.31, 0.19, 0.48)
	box.set_border_width_all(1)
	box.set_corner_radius_all(7)
	return box

func refresh() -> void:
	if _avatar != null:
		var appearance: Dictionary = AppearanceManager.current(MemoryManager.selected_role_key)
		_avatar.texture = AppearanceManager.avatar_texture(appearance, MemoryManager.selected_role_key) \
			if bool(appearance.get("enabled", false)) else CharacterDB.avatar_texture(MemoryManager.selected_role_key)
	if _name_label != null:
		var display_name: String = MemoryManager.player_display_name.strip_edges()
		if display_name == "":
			display_name = CharacterDB.display_name(MemoryManager.selected_role_key)
		_name_label.text = display_name + "  ·  温馨小家"
	if _stats_label != null:
		var member_count := 1
		var members: Array = MemoryManager.family_portrait.get("members", [])
		if not members.is_empty():
			member_count = members.size()
		_stats_label.text = "%d 记忆  ·  %d 藤蔓" % [
			MemoryManager.memories.size(),
			MemoryManager.get_memory_links("garden").size(),
		]
		if _members_hit != null:
			_members_hit.text = "%d人" % member_count

func _tween_scale(target: float) -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE * target, 0.10)
