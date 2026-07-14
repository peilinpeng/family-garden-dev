extends Control
class_name CharacterCreatorPanel

signal confirmed(role_key: String, display_name: String, family_code: String, appearance: Dictionary)
signal canceled

const ROLE_OPTIONS := [
	{"id": "girl", "label": "女儿"},
	{"id": "boy", "label": "儿子"},
	{"id": "papa", "label": "爸爸"},
	{"id": "mama", "label": "妈妈"},
]

var _role_key := "girl"
var _appearance: Dictionary = {}
var _can_cancel := false
var _preview: TextureRect
var _summary: Label
var _name_input: LineEdit
var _family_input: LineEdit
var _hair_choice_root: Control
var _outfit_choice_root: Control
var _body_buttons: Dictionary = {}
var _hair_style_buttons: Dictionary = {}
var _hair_color_buttons: Dictionary = {}
var _outfit_buttons: Dictionary = {}

func setup(initial_role: String, initial_name: String, family_code: String, saved_appearance: Dictionary) -> void:
	_role_key = initial_role if initial_role != "" else "girl"
	_can_cancel = initial_role != ""
	_appearance = AppearanceManager.normalize(saved_appearance, _role_key) if not saved_appearance.is_empty() else AppearanceManager.default_for_role(_role_key)
	_appearance["enabled"] = true
	_build(initial_name, family_code)

func _build(initial_name: String, family_code: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.color = Color(0.10, 0.08, 0.06, 0.26)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := Panel.new()
	panel.position = Vector2(70, 35)
	panel.size = Vector2(1140, 650)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(1.0, 0.96, 0.84, 0.99), Color(0.60, 0.43, 0.25, 0.96), 16, 2))
	add_child(panel)

	var title := Label.new()
	title.text = "角色形象"
	title.position = Vector2(30, 18)
	title.size = Vector2(1080, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 1.0))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "保存后，这套形象会在花园、农场、厨房和房间中保持一致"
	subtitle.position = Vector2(30, 52)
	subtitle.size = Vector2(1080, 22)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.43, 0.34, 0.25, 0.84))
	panel.add_child(subtitle)

	_build_preview(panel)
	_build_editor(panel, initial_name, family_code)
	_build_actions(panel)
	_update_preview()

func _build_preview(panel: Panel) -> void:
	var preview_card := Panel.new()
	preview_card.position = Vector2(24, 86)
	preview_card.size = Vector2(300, 492)
	preview_card.add_theme_stylebox_override("panel", _panel_style(Color(0.94, 0.94, 0.78, 0.62), Color(0.52, 0.61, 0.37, 0.62), 13))
	panel.add_child(preview_card)

	var preview_title := Label.new()
	preview_title.text = "当前形象"
	preview_title.position = Vector2(18, 16)
	preview_title.size = Vector2(264, 24)
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_font_size_override("font_size", 16)
	preview_card.add_child(preview_title)

	var preview_frame := Panel.new()
	preview_frame.position = Vector2(42, 52)
	preview_frame.size = Vector2(216, 320)
	preview_frame.add_theme_stylebox_override("panel", _panel_style(Color(1.0, 0.98, 0.90, 0.94), Color(0.65, 0.49, 0.28, 0.56), 12))
	preview_card.add_child(preview_frame)

	_preview = TextureRect.new()
	_preview.position = Vector2(12, 10)
	_preview.size = Vector2(192, 300)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_frame.add_child(_preview)

	_summary = Label.new()
	_summary.position = Vector2(18, 386)
	_summary.size = Vector2(264, 78)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_theme_font_size_override("font_size", 14)
	_summary.add_theme_color_override("font_color", Color(0.32, 0.27, 0.20, 0.94))
	preview_card.add_child(_summary)

func _build_editor(panel: Panel, initial_name: String, family_code: String) -> void:
	var edit_card := Panel.new()
	edit_card.position = Vector2(340, 86)
	edit_card.size = Vector2(776, 492)
	edit_card.add_theme_stylebox_override("panel", _panel_style(Color(1.0, 0.97, 0.87, 0.76), Color(0.68, 0.50, 0.30, 0.46), 13))
	panel.add_child(edit_card)

	_add_field_label(edit_card, "名字", Vector2(20, 14), Vector2(224, 20))
	_name_input = LineEdit.new()
	_name_input.position = Vector2(20, 36)
	_name_input.size = Vector2(224, 38)
	_name_input.placeholder_text = "输入名字"
	_name_input.text = initial_name if initial_name != "" else "佩林"
	_style_input(_name_input)
	edit_card.add_child(_name_input)

	_add_field_label(edit_card, "家庭邀请码", Vector2(264, 14), Vector2(224, 20))
	_family_input = LineEdit.new()
	_family_input.position = Vector2(264, 36)
	_family_input.size = Vector2(224, 38)
	_family_input.placeholder_text = "没有可以留空"
	_family_input.text = family_code
	_style_input(_family_input)
	edit_card.add_child(_family_input)

	_add_field_label(edit_card, "家庭身份", Vector2(508, 14), Vector2(244, 20))
	var role_select := OptionButton.new()
	role_select.position = Vector2(508, 36)
	role_select.size = Vector2(244, 38)
	var role_index := 0
	for index in ROLE_OPTIONS.size():
		var option: Dictionary = ROLE_OPTIONS[index]
		role_select.add_item(String(option.label))
		role_select.set_item_metadata(index, String(option.id))
		if String(option.id) == _role_key:
			role_index = index
	role_select.select(role_index)
	_style_input(role_select)
	role_select.item_selected.connect(func(index: int) -> void:
		_role_key = String(role_select.get_item_metadata(index))
		_update_preview())
	edit_card.add_child(role_select)

	_add_section_title(edit_card, "角色类型", Vector2(20, 92))
	var body_index := 0
	for body_id_value in AppearanceManager.body_types().keys():
		var body_id := String(body_id_value)
		var body_definition: Dictionary = AppearanceManager.body_definition(body_id)
		var sample := _appearance.duplicate(true)
		sample["body_type"] = body_id
		sample["hair_style"] = String(body_definition.get("default_hair_style", ""))
		var button := _make_avatar_choice(
			edit_card,
			String(body_definition.get("label", body_id)),
			AppearanceManager.avatar_texture(sample, _role_key),
			Vector2(20 + body_index * 178, 116),
			Vector2(166, 58)
		)
		button.pressed.connect(_select_body.bind(body_id))
		_body_buttons[body_id] = button
		body_index += 1

	_add_section_title(edit_card, "发型", Vector2(20, 188))
	_hair_choice_root = Control.new()
	_hair_choice_root.position = Vector2(20, 212)
	_hair_choice_root.size = Vector2(732, 72)
	edit_card.add_child(_hair_choice_root)
	_rebuild_hair_choices()

	# 发色功能暂时隐藏，但 _appearance.hair_color 仍按原值保存，便于以后恢复。
	_add_section_title(edit_card, "服装", Vector2(20, 296))
	_outfit_choice_root = Control.new()
	_outfit_choice_root.position = Vector2(20, 320)
	_outfit_choice_root.size = Vector2(732, 70)
	edit_card.add_child(_outfit_choice_root)
	_rebuild_outfit_choices()

func _build_actions(panel: Panel) -> void:
	var confirm := Button.new()
	confirm.text = "保存形象" if _can_cancel else "创建角色并进入花园"
	confirm.position = Vector2(596, 594)
	confirm.size = Vector2(220, 40)
	_style_button(confirm, true)
	confirm.pressed.connect(_confirm)
	panel.add_child(confirm)

	if _can_cancel:
		var cancel := Button.new()
		cancel.text = "取消修改"
		cancel.position = Vector2(356, 594)
		cancel.size = Vector2(200, 40)
		_style_button(cancel, false)
		cancel.pressed.connect(func() -> void: canceled.emit())
		panel.add_child(cancel)

func _select_body(body_id: String) -> void:
	_appearance["body_type"] = body_id
	_appearance["hair_style"] = String(AppearanceManager.body_definition(body_id).get("default_hair_style", ""))
	_rebuild_hair_choices()
	_rebuild_outfit_choices()
	_update_preview()

func _rebuild_hair_choices() -> void:
	if _hair_choice_root == null:
		return
	for child in _hair_choice_root.get_children():
		child.queue_free()
	_hair_style_buttons.clear()
	var styles: Dictionary = AppearanceManager.hair_styles(String(_appearance.body_type))
	var index := 0
	for style_id_value in styles.keys():
		var style_id := String(style_id_value)
		var data: Dictionary = styles[style_id]
		var sample := _appearance.duplicate(true)
		sample["hair_style"] = style_id
		var button := _make_avatar_choice(
			_hair_choice_root,
			String(data.get("label", style_id)),
			AppearanceManager.avatar_texture(sample, _role_key),
			Vector2(index * 190, 0),
			Vector2(178, 70)
		)
		button.pressed.connect(_select_hair_style.bind(style_id))
		_hair_style_buttons[style_id] = button
		index += 1

func _select_hair_style(style_id: String) -> void:
	_appearance["hair_style"] = style_id
	_rebuild_outfit_choices()
	_update_preview()

func _select_hair_color(hair_id: String) -> void:
	_appearance["hair_color"] = hair_id
	_rebuild_outfit_choices()
	_update_preview()

func _select_outfit(outfit_id: String) -> void:
	_appearance["outfit"] = outfit_id
	_update_preview()

func _rebuild_outfit_choices() -> void:
	if _outfit_choice_root == null:
		return
	for child in _outfit_choice_root.get_children():
		child.queue_free()
	_outfit_buttons.clear()
	var index := 0
	for outfit_id_value in AppearanceManager.outfits().keys():
		var outfit_id := String(outfit_id_value)
		var data: Dictionary = AppearanceManager.outfits()[outfit_id]
		var sample := _appearance.duplicate(true)
		sample["outfit"] = outfit_id
		var button := _make_avatar_choice(
			_outfit_choice_root,
			String(data.get("label", outfit_id)),
			AppearanceManager.avatar_texture(sample, _role_key),
			Vector2(index * 146, 0),
			Vector2(136, 64)
		)
		button.pressed.connect(_select_outfit.bind(outfit_id))
		_outfit_buttons[outfit_id] = button
		index += 1

func _update_preview() -> void:
	_appearance = AppearanceManager.normalize(_appearance, _role_key)
	_appearance["enabled"] = true
	if _preview != null:
		_preview.texture = AppearanceManager.avatar_texture(_appearance, _role_key)
	var body_label := String(AppearanceManager.body_definition(String(_appearance.body_type)).get("label", ""))
	var hair_label := String(AppearanceManager.hair_styles(String(_appearance.body_type)).get(String(_appearance.hair_style), {}).get("label", ""))
	var outfit_label := String(AppearanceManager.outfits().get(String(_appearance.outfit), {}).get("label", ""))
	if _summary != null:
		_summary.text = "%s　%s\n%s" % [body_label, hair_label, outfit_label]
	_refresh_choice_styles()

func _refresh_choice_styles() -> void:
	for body_id in _body_buttons:
		_style_button(_body_buttons[body_id], String(body_id) == String(_appearance.body_type))
	for style_id in _hair_style_buttons:
		_style_button(_hair_style_buttons[style_id], String(style_id) == String(_appearance.hair_style))
	for hair_id in _hair_color_buttons:
		_style_button(_hair_color_buttons[hair_id], String(hair_id) == String(_appearance.hair_color))
	for outfit_id in _outfit_buttons:
		_style_button(_outfit_buttons[outfit_id], String(outfit_id) == String(_appearance.outfit))

func _confirm() -> void:
	var clean_name := _name_input.text.strip_edges()
	if clean_name == "":
		_name_input.placeholder_text = "请先输入名字"
		_name_input.grab_focus()
		return
	confirmed.emit(_role_key, clean_name, _family_input.text.strip_edges(), _appearance.duplicate(true))

func _make_avatar_choice(parent: Control, label_text: String, avatar_texture: Texture2D, pos: Vector2, choice_size: Vector2) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = choice_size
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)

	var avatar := TextureRect.new()
	avatar.position = Vector2(8, 5)
	avatar.size = Vector2(50, choice_size.y - 10)
	avatar.texture = avatar_texture
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(avatar)

	var label := Label.new()
	label.text = label_text
	label.position = Vector2(64, 0)
	label.size = Vector2(choice_size.x - 72, choice_size.y)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.27, 0.22, 0.17, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button

func _make_color_choice(parent: Control, label_text: String, color: Color, pos: Vector2) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = Vector2(136, 46)
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)

	var swatch := Panel.new()
	swatch.position = Vector2(9, 10)
	swatch.size = Vector2(24, 24)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swatch_style := StyleBoxFlat.new()
	swatch_style.bg_color = color
	swatch_style.border_color = Color(0.35, 0.27, 0.19, 0.72)
	swatch_style.set_border_width_all(1)
	swatch_style.set_corner_radius_all(6)
	swatch.add_theme_stylebox_override("panel", swatch_style)
	button.add_child(swatch)

	var label := Label.new()
	label.text = label_text
	label.position = Vector2(40, 0)
	label.size = Vector2(88, 46)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.27, 0.22, 0.17, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button

func _add_field_label(parent: Control, text_value: String, pos: Vector2, label_size: Vector2) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.39, 0.31, 0.23, 0.92))
	parent.add_child(label)

func _add_section_title(parent: Control, text_value: String, pos: Vector2) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = Vector2(732, 22)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.30, 0.24, 0.18, 1.0))
	parent.add_child(label)

func _panel_style(bg: Color, border: Color, radius: int, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.18, 0.11, 0.05, 0.12)
	style.shadow_size = 4
	return style

func _style_button(button: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.82, 0.90, 0.66, 0.96) if selected else Color(1.0, 0.94, 0.80, 0.96)
	normal.border_color = Color(0.38, 0.55, 0.26, 0.96) if selected else Color(0.65, 0.47, 0.28, 0.74)
	normal.set_border_width_all(2 if selected else 1)
	normal.set_corner_radius_all(9)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.06)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", normal)
	var text_color := Color(0.25, 0.21, 0.16, 1.0)
	for state_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state_name, text_color)

func _style_input(control: Control) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 0.96, 0.84, 0.96)
	normal.border_color = Color(0.65, 0.47, 0.28, 0.68)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	var focus := normal.duplicate()
	focus.border_color = Color(0.39, 0.58, 0.27, 0.92)
	focus.set_border_width_all(2)
	if control is LineEdit:
		control.add_theme_stylebox_override("normal", normal)
		control.add_theme_stylebox_override("focus", focus)
		control.add_theme_color_override("font_color", Color(0.25, 0.21, 0.16, 1.0))
		control.add_theme_color_override("font_placeholder_color", Color(0.45, 0.38, 0.29, 0.58))
	elif control is OptionButton:
		for state_name in ["normal", "hover", "pressed", "focus"]:
			control.add_theme_stylebox_override(state_name, focus if state_name == "focus" else normal)
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			control.add_theme_color_override(color_name, Color(0.25, 0.21, 0.16, 1.0))
