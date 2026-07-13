extends CanvasLayer
class_name GameHUD

## 统一常驻 HUD：左上家庭状态卡 + 底部行动坞。
## 作为所有可游玩场景共享的一套入口；角色选择等流程页会临时隐藏。

const ICON_ALL_ICONS := "res://assets/ui/icons/All Icons.png"

var profile_card: PlayerProfileCard
var tooltip: HUDTooltip
var panel_root: Control

var _hud_root: Control
var _dock: Panel
var _memory_btn: Button
var _map_btn: HUDIconButton
var _backpack_btn: HUDIconButton
var _quests_btn: HUDIconButton
var _chat_btn: HUDIconButton
var _current_panel: HUDPanel
var _current_kind := ""
var _active_source: HUDIconButton

func _ready() -> void:
	layer = 30
	_build()
	set_context(SceneManager.mode)

func _build() -> void:
	_hud_root = Control.new()
	_hud_root.name = "HUDRoot"
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	profile_card = PlayerProfileCard.new()
	profile_card.position = Vector2(16, 16)
	profile_card.pressed.connect(_on_profile_pressed)
	profile_card.members_pressed.connect(_on_members_pressed)
	_hud_root.add_child(profile_card)

	_build_action_dock()

	panel_root = Control.new()
	panel_root.name = "PanelLayer"
	panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_root)

	tooltip = HUDTooltip.new()
	tooltip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tooltip)

func _build_action_dock() -> void:
	_dock = Panel.new()
	_dock.name = "GardenActionDock"
	_dock.position = Vector2(354, 652)
	_dock.size = Vector2(572, 54)
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	var dock_style := StyleBoxFlat.new()
	dock_style.bg_color = Color(1.0, 0.96, 0.84, 0.88)
	dock_style.border_color = Color(0.54, 0.40, 0.25, 0.68)
	dock_style.set_border_width_all(1)
	dock_style.set_corner_radius_all(12)
	dock_style.shadow_color = Color(0.18, 0.12, 0.07, 0.18)
	dock_style.shadow_size = 4
	dock_style.shadow_offset = Vector2(0, 2)
	_dock.add_theme_stylebox_override("panel", dock_style)
	_hud_root.add_child(_dock)

	_memory_btn = Button.new()
	_memory_btn.text = "＋ 记录记忆"
	_memory_btn.position = Vector2(7, 7)
	_memory_btn.size = Vector2(168, 40)
	_memory_btn.focus_mode = Control.FOCUS_ALL
	_memory_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_memory_btn.tooltip_text = "把文字或照片变成一段家庭记忆"
	_memory_btn.add_theme_font_size_override("font_size", 14)
	_memory_btn.add_theme_color_override("font_color", Color(0.22, 0.25, 0.14, 1.0))
	_memory_btn.add_theme_stylebox_override("normal", _action_box(Color(0.78, 0.86, 0.60, 0.96), Color(0.43, 0.54, 0.28, 0.86)))
	_memory_btn.add_theme_stylebox_override("hover", _action_box(Color(0.86, 0.91, 0.68, 1.0), Color(0.48, 0.60, 0.30, 1.0)))
	_memory_btn.add_theme_stylebox_override("pressed", _action_box(Color(0.70, 0.81, 0.52, 1.0), Color(0.39, 0.50, 0.24, 1.0)))
	_memory_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("按钮")
		SceneManager.open_memory_creator())
	_dock.add_child(_memory_btn)

	_map_btn = _make_icon(_tex("icon_map"), "地图 / Maps", "maps", HUDIconButton.Side.TOP, _on_map_pressed)
	_map_btn.position = Vector2(188, 7)
	_map_btn.button_size = Vector2(40, 40)
	_dock.add_child(_map_btn)

	_backpack_btn = _make_icon(_sheet_icon(8, 1), "背包 / Backpack (I)", "backpack", HUDIconButton.Side.TOP, _on_backpack_pressed)
	_backpack_btn.position = Vector2(244, 7)
	_backpack_btn.button_size = Vector2(40, 40)
	_dock.add_child(_backpack_btn)

	_chat_btn = _make_icon(_tex("icon_letter"), "家人聊天 / Family Chat", "chat", HUDIconButton.Side.TOP, _on_chat_pressed)
	_chat_btn.position = Vector2(300, 7)
	_chat_btn.button_size = Vector2(40, 40)
	_dock.add_child(_chat_btn)

	_quests_btn = _make_icon(_tex("icon_sign"), "任务 / Chapter 1", "quests", HUDIconButton.Side.TOP, _on_quests_pressed)
	_quests_btn.position = Vector2(356, 7)
	_quests_btn.button_size = Vector2(40, 40)
	_dock.add_child(_quests_btn)

	var labels := Label.new()
	labels.name = "ActionLabels"
	labels.text = "地图       背包       聊天       任务"
	labels.position = Vector2(178, 36)
	labels.size = Vector2(236, 14)
	labels.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_theme_font_size_override("font_size", 9)
	labels.add_theme_color_override("font_color", Color(0.39, 0.31, 0.22, 0.72))
	_dock.add_child(labels)

	var shortcut := Label.new()
	shortcut.name = "GardenMoodLabel"
	shortcut.text = "宁静花园 · 与家人共享"
	shortcut.position = Vector2(418, 17)
	shortcut.size = Vector2(144, 20)
	shortcut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shortcut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shortcut.add_theme_font_size_override("font_size", 10)
	shortcut.add_theme_color_override("font_color", Color(0.43, 0.35, 0.24, 0.66))
	_dock.add_child(shortcut)

func _action_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(9)
	return box

func _make_icon(icon: Texture2D, tip: String, action: String, side: int, on_press: Callable) -> HUDIconButton:
	var button := HUDIconButton.new()
	button.icon_texture = icon
	button.tooltip_label = tip
	button.action_id = action
	button.tooltip_side = side
	button.pressed.connect(on_press)
	button.hover_started.connect(func(t: String, rect: Rect2, tooltip_side: int) -> void:
		if tooltip != null:
			tooltip.show_for(t, rect, tooltip_side))
	button.hover_ended.connect(func() -> void:
		if tooltip != null:
			tooltip.hide_tip())
	return button

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_I:
		_on_backpack_pressed()
		get_viewport().set_input_as_handled()

func _on_profile_pressed() -> void:
	_toggle("profile", _create_profile_panel, null)

func _create_profile_panel() -> HUDPanel:
	var panel := ProfilePanel.new()
	panel.settings_requested.connect(_open_settings_from_profile)
	return panel

func _open_settings_from_profile() -> void:
	_toggle("settings", func() -> HUDPanel: return SettingsPanel.new(), null)

func _on_members_pressed() -> void:
	close_current()
	SceneManager.open_family_members()

func _on_map_pressed() -> void:
	_toggle("maps", _create_map_panel, _map_btn)

func _create_map_panel() -> HUDPanel:
	var panel := MapHubPanel.new()
	panel.world_map_requested.connect(func() -> void:
		close_current()
		SceneManager.open_global_map())
	panel.travel_map_requested.connect(func() -> void:
		close_current()
		SceneManager.open_travel_map())
	return panel

func _on_backpack_pressed() -> void:
	_toggle("inventory", func() -> HUDPanel: return InventoryPanel.new(), _backpack_btn)

func _on_quests_pressed() -> void:
	_toggle("quests", func() -> HUDPanel: return QuestPanel.new(), _quests_btn)

## 开场结束后自动弹一次任务面板(StoryManager 经 SceneManager 调)。
func show_quests() -> void:
	if _current_kind != "quests" or not has_open_panel():
		_toggle("quests", func() -> HUDPanel: return QuestPanel.new(), _quests_btn)

## 角色卡不是 HUDIconButton,不参与 set_active 高亮,这里返回 null 让面板管理跳过高亮。
func profile_card_active_proxy() -> HUDIconButton:
	return null

func _on_chat_pressed() -> void:
	close_current()
	SceneManager.open_world_chat()

func _toggle(kind: String, factory: Callable, source_btn: HUDIconButton) -> void:
	if _current_kind == kind and has_open_panel():
		close_current()
		return
	var panel: HUDPanel = factory.call()
	open_panel(panel, source_btn)
	_current_kind = kind

func open_panel(panel: HUDPanel, source_btn: HUDIconButton = null) -> void:
	close_current()
	SceneManager._close_active_panel()
	if tooltip != null:
		tooltip.hide_tip()
	_current_panel = panel
	panel.close_requested.connect(close_current)
	panel_root.add_child(panel)
	_active_source = source_btn
	if source_btn != null:
		source_btn.set_active(true)
	SceneManager.set_player_input_locked(true)

func close_current() -> void:
	if _current_panel != null and is_instance_valid(_current_panel):
		_current_panel.queue_free()
	_current_panel = null
	_current_kind = ""
	if _active_source != null and is_instance_valid(_active_source):
		_active_source.set_active(false)
	_active_source = null
	SceneManager.set_player_input_locked(false)

func has_open_panel() -> bool:
	return _current_panel != null and is_instance_valid(_current_panel)

func refresh_profile() -> void:
	if profile_card != null:
		profile_card.refresh()

## 所有可游玩场景共用同一套 HUD；只在角色选择/启动前隐藏。
func set_context(scene_id: String) -> void:
	var show_global_hud := scene_id != "" and scene_id != "role_select"
	if _hud_root != null:
		_hud_root.visible = show_global_hud
	if panel_root != null:
		panel_root.visible = show_global_hud
	if tooltip != null:
		tooltip.visible = show_global_hud
	if _memory_btn != null:
		_memory_btn.visible = show_global_hud
	if _dock != null:
		_dock.position.x = 354.0
		_dock.size.x = 572.0
		_map_btn.position.x = 188.0
		_backpack_btn.position.x = 244.0
		_chat_btn.position.x = 300.0
		_quests_btn.position.x = 356.0
		var action_labels := _dock.get_node_or_null("ActionLabels") as Label
		if action_labels != null:
			action_labels.visible = show_global_hud
		var mood_label := _dock.get_node_or_null("GardenMoodLabel") as Label
		if mood_label != null:
			mood_label.visible = show_global_hud
	if profile_card != null and show_global_hud:
		profile_card.refresh()
	if not show_global_hud:
		close_current()

func _tex(asset_key: String) -> Texture2D:
	var path := str(SceneManager.ASSETS.get(asset_key, ""))
	return load(path) if path != "" and ResourceLoader.exists(path) else null

func _sheet_icon(col: int, row: int) -> Texture2D:
	if not ResourceLoader.exists(ICON_ALL_ICONS):
		return null
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = load(ICON_ALL_ICONS)
	atlas_texture.region = Rect2(col * 16, row * 16, 16, 16)
	return atlas_texture
