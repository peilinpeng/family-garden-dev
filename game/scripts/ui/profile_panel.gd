extends HUDPanel
class_name ProfilePanel

signal settings_requested

## 玩家个人资料面板(点左上角色卡打开)。头像 / 昵称 / 家庭名称 / 家庭成员入口 / 收集成就(占位)。
## 复用 CharacterDB.avatar_texture 取头像、MemoryManager.player_display_name 取昵称;
## 成员入口直接接回 SceneManager 现有的家庭树面板,不另建一套。

# TODO: 项目暂无"用户可见的家庭名称"字段(FAMILY_ID 是云端行 id,非展示名),先用友好默认名占位,
#       待数据模型补上家庭 profile 后接真实值。
const FAMILY_NAME_PLACEHOLDER := "温馨小家"

func _init() -> void:
	panel_title = "我的家庭 / My Family"
	card_size = Vector2(520, 380)

func _build_content() -> void:
	# ---- 头像 + 昵称 + 家庭名 ----
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	content_root.add_child(head)

	var avatar_frame := Panel.new()
	avatar_frame.custom_minimum_size = Vector2(96, 96)
	var frame_box := StyleBoxFlat.new()
	frame_box.bg_color = Color(1.0, 0.98, 0.90, 1.0)
	frame_box.border_color = Color(0.62, 0.46, 0.28, 1.0)
	frame_box.set_border_width_all(2)
	frame_box.set_corner_radius_all(14)
	avatar_frame.add_theme_stylebox_override("panel", frame_box)
	head.add_child(avatar_frame)

	var avatar := TextureRect.new()
	avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	avatar.offset_left = 6
	avatar.offset_top = 6
	avatar.offset_right = -6
	avatar.offset_bottom = -6
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar.texture = CharacterDB.avatar_texture(MemoryManager.selected_role_key)
	avatar_frame.add_child(avatar)

	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 6)
	head.add_child(names)

	var nickname := Label.new()
	var display_name: String = MemoryManager.player_display_name.strip_edges()
	if display_name == "":
		display_name = CharacterDB.display_name(MemoryManager.selected_role_key)
	nickname.text = display_name
	nickname.add_theme_font_size_override("font_size", 22)
	nickname.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 1.0))
	names.add_child(nickname)

	var family := Label.new()
	family.text = "🏡 " + FAMILY_NAME_PLACEHOLDER
	family.add_theme_font_size_override("font_size", 14)
	family.add_theme_color_override("font_color", Color(0.45, 0.36, 0.26, 0.9))
	names.add_child(family)

	# ---- 家庭与设置入口（低频设置从主界面下沉到这里）----
	var members_btn := Button.new()
	members_btn.text = "👪  家庭成员 / Family Members"
	members_btn.custom_minimum_size = Vector2(0, 40)
	members_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	HUDPanel._style_soft_button(members_btn)
	members_btn.pressed.connect(_on_members)
	content_root.add_child(members_btn)

	var settings_btn := Button.new()
	settings_btn.text = "⚙  设置 / Settings"
	settings_btn.custom_minimum_size = Vector2(0, 40)
	settings_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	HUDPanel._style_soft_button(settings_btn)
	settings_btn.pressed.connect(func() -> void:
		close_requested.emit()
		settings_requested.emit())
	content_root.add_child(settings_btn)

	# ---- 我的收集 / 成就(占位) ----
	var collection := Panel.new()
	collection.custom_minimum_size = Vector2(0, 96)
	collection.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col_box := StyleBoxFlat.new()
	col_box.bg_color = Color(1.0, 0.97, 0.88, 0.65)
	col_box.border_color = Color(0.66, 0.52, 0.34, 0.5)
	col_box.set_border_width_all(1)
	col_box.set_corner_radius_all(12)
	collection.add_theme_stylebox_override("panel", col_box)
	content_root.add_child(collection)

	var col_label := Label.new()
	col_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	col_label.text = "🏆 我的收集 · 成就\n(即将开放)"
	col_label.add_theme_font_size_override("font_size", 14)
	col_label.add_theme_color_override("font_color", Color(0.50, 0.40, 0.28, 0.85))
	collection.add_child(col_label)

func _on_members() -> void:
	# 关闭本面板，复用现有云端家庭成员面板。
	close_requested.emit()
	SceneManager.open_family_members()
