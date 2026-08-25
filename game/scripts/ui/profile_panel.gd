extends HUDPanel
class_name ProfilePanel

signal settings_requested
signal appearance_requested
signal family_tree_requested

## 玩家个人资料面板(点左上角色卡打开)。头像 / 昵称 / 家庭名称 / 家庭成员入口 / 收集成就(占位)。
## 复用 CharacterDB.avatar_texture 取头像、MemoryManager.player_display_name 取昵称;
## 成员入口直接接回 SceneManager 现有的家庭树面板,不另建一套。

# TODO: 项目暂无"用户可见的家庭名称"字段(FAMILY_ID 是云端行 id,非展示名),先用友好默认名占位,
#       待数据模型补上家庭 profile 后接真实值。
const FAMILY_NAME_PLACEHOLDER := "温馨小家"

func _init() -> void:
	panel_title = "我的资料"
	card_size = Vector2(500, 520)

func _build_content() -> void:
	# ---- 头像 + 昵称 + 家庭名 ----
	var head := Panel.new()
	head.custom_minimum_size = Vector2(0, 106)
	var head_box := StyleBoxFlat.new()
	head_box.bg_color = Color(1.0, 0.97, 0.87, 0.72)
	head_box.border_color = Color(0.66, 0.52, 0.34, 0.45)
	head_box.set_border_width_all(1)
	head_box.set_corner_radius_all(12)
	head.add_theme_stylebox_override("panel", head_box)
	content_root.add_child(head)

	var avatar_frame := Panel.new()
	avatar_frame.position = Vector2(14, 11)
	avatar_frame.size = Vector2(84, 84)
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
	var appearance: Dictionary = AppearanceManager.current(MemoryManager.selected_role_key)
	avatar.texture = AppearanceManager.avatar_texture(appearance, MemoryManager.selected_role_key) \
		if bool(appearance.get("enabled", false)) else CharacterDB.avatar_texture(MemoryManager.selected_role_key)
	avatar_frame.add_child(avatar)

	var nickname := Label.new()
	var display_name: String = MemoryManager.player_display_name.strip_edges()
	if display_name == "":
		display_name = CharacterDB.display_name(MemoryManager.selected_role_key)
	nickname.text = display_name
	nickname.position = Vector2(116, 25)
	nickname.size = Vector2(300, 30)
	nickname.add_theme_font_size_override("font_size", 22)
	nickname.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 1.0))
	head.add_child(nickname)

	var family := Label.new()
	family.text = "家庭：" + FAMILY_NAME_PLACEHOLDER
	family.position = Vector2(116, 60)
	family.size = Vector2(300, 24)
	family.add_theme_font_size_override("font_size", 14)
	family.add_theme_color_override("font_color", Color(0.45, 0.36, 0.26, 0.9))
	head.add_child(family)

	# ---- 家庭与设置入口（低频设置从主界面下沉到这里）----
	var members_btn := Button.new()
	members_btn.text = "家庭成员"
	members_btn.custom_minimum_size = Vector2(0, 42)
	members_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	HUDPanel._style_soft_button(members_btn)
	members_btn.pressed.connect(_on_members)
	content_root.add_child(members_btn)

	var family_tree_btn := Button.new()
	family_tree_btn.name = "ProfileFamilyTreeButton"
	family_tree_btn.text = "家庭树"
	family_tree_btn.custom_minimum_size = Vector2(0, 42)
	family_tree_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	HUDPanel._style_soft_button(family_tree_btn)
	family_tree_btn.pressed.connect(func() -> void:
		close_requested.emit()
		family_tree_requested.emit())
	content_root.add_child(family_tree_btn)

	var appearance_btn := Button.new()
	appearance_btn.text = "修改角色形象"
	appearance_btn.custom_minimum_size = Vector2(0, 42)
	appearance_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	HUDPanel._style_soft_button(appearance_btn)
	appearance_btn.pressed.connect(func() -> void:
		close_requested.emit()
		appearance_requested.emit())
	content_root.add_child(appearance_btn)

	var settings_btn := Button.new()
	settings_btn.text = "设置"
	settings_btn.custom_minimum_size = Vector2(0, 42)
	settings_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	HUDPanel._style_soft_button(settings_btn)
	settings_btn.pressed.connect(func() -> void:
		close_requested.emit()
		settings_requested.emit())
	content_root.add_child(settings_btn)

	# ---- 我的收集 / 成就(占位) ----
	var collection := Panel.new()
	collection.custom_minimum_size = Vector2(0, 58)
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
	col_label.text = "收集与成就（暂未开放）"
	col_label.add_theme_font_size_override("font_size", 14)
	col_label.add_theme_color_override("font_color", Color(0.50, 0.40, 0.28, 0.85))
	collection.add_child(col_label)

func _on_members() -> void:
	# 关闭本面板，复用现有云端家庭成员面板。
	close_requested.emit()
	SceneManager.open_family_members()
