extends CanvasLayer
class_name GameHUD

## 常驻游戏 HUD(单实例,由 SceneManager.setup 创建挂到 main 根)。
## 组织:左上角色卡 / 左右侧图标导航 / 右上设置 / 底部背包 / tooltip 层 / 面板层。
## 导航图标直接接回 SceneManager 现有打开逻辑(不另建平行系统);Profile/Settings/Inventory
## 是 HUD 自管的面板(单面板互斥 + 锁玩家移动 + 关旧 cozy 面板 + 图标选中高亮)。
## layer=3:盖在底部导航/聊天条(layer 1)之上,低于将来更高层的临时叠加。

const ICON_ALL_ICONS := "res://assets/ui/icons/All Icons.png"

var profile_card: PlayerProfileCard
var tooltip: HUDTooltip
var panel_root: Control

var _settings_btn: HUDIconButton
var _backpack_btn: HUDIconButton
var _quests_btn: HUDIconButton
var _current_panel: HUDPanel
var _current_kind := ""
var _active_source: HUDIconButton

func _ready() -> void:
	layer = 3
	_build()

func _build() -> void:
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- 左上:玩家卡片 ----
	profile_card = PlayerProfileCard.new()
	profile_card.position = Vector2(16, 16)
	profile_card.pressed.connect(_on_profile_pressed)
	root.add_child(profile_card)

	# ---- 左侧导航(家庭与记忆):家庭树 / 明信片 ----
	var left_nav := VBoxContainer.new()
	left_nav.name = "LeftNavigation"
	left_nav.position = Vector2(18, 300)
	left_nav.add_theme_constant_override("separation", 14)
	root.add_child(left_nav)
	left_nav.add_child(_make_icon(_tex("icon_tree"), "家庭树 / Family Tree", "family_tree",
		HUDIconButton.Side.RIGHT, func() -> void: SceneManager.open_family_tree()))
	left_nav.add_child(_make_icon(_tex("icon_postcard"), "明信片 / Postcards", "postcards",
		HUDIconButton.Side.RIGHT, func() -> void: SceneManager.open_postcards()))
	_quests_btn = _make_icon(_tex("icon_sign"), "任务 / Chapter 1", "quests",
		HUDIconButton.Side.RIGHT, _on_quests_pressed)
	left_nav.add_child(_quests_btn)

	# ---- 右侧导航(世界与行动):世界 / 地图 ----
	var right_nav := VBoxContainer.new()
	right_nav.name = "RightNavigation"
	right_nav.position = Vector2(1210, 300)
	right_nav.add_theme_constant_override("separation", 14)
	root.add_child(right_nav)
	right_nav.add_child(_make_icon(_tex("icon_home"), "世界 / World", "world",
		HUDIconButton.Side.LEFT, func() -> void: SceneManager.open_global_map()))
	right_nav.add_child(_make_icon(_tex("icon_map"), "地图 / Map", "map",
		HUDIconButton.Side.LEFT, func() -> void: SceneManager.open_travel_map()))

	# ---- 右上:设置(时钟左侧,独立于导航组)----
	_settings_btn = _make_icon(_sheet_icon(9, 0), "设置 / Settings", "settings",
		HUDIconButton.Side.BOTTOM, _on_settings_pressed)
	_settings_btn.position = Vector2(1080, 20)
	root.add_child(_settings_btn)

	# ---- 底部:背包(避开右侧世界聊天条)----
	_backpack_btn = _make_icon(_sheet_icon(8, 1), "背包 / Backpack (I)", "backpack",
		HUDIconButton.Side.TOP, _on_backpack_pressed)
	_backpack_btn.button_size = Vector2(56, 56)
	_backpack_btn.position = Vector2(300, 652)
	root.add_child(_backpack_btn)

	# ---- 面板层(HUD 自管面板;无面板时不拦截,面板自身 STOP 做模态)----
	panel_root = Control.new()
	panel_root.name = "PanelLayer"
	panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_root)

	# ---- tooltip 层(最上,不拦截鼠标)----
	tooltip = HUDTooltip.new()
	tooltip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tooltip)

func _make_icon(icon: Texture2D, tip: String, action: String, side: int, on_press: Callable) -> HUDIconButton:
	var b := HUDIconButton.new()
	b.icon_texture = icon
	b.tooltip_label = tip
	b.action_id = action
	b.tooltip_side = side
	b.pressed.connect(on_press)
	b.hover_started.connect(func(t: String, r: Rect2, s: int) -> void:
		if tooltip != null:
			tooltip.show_for(t, r, s))
	b.hover_ended.connect(func() -> void:
		if tooltip != null:
			tooltip.hide_tip())
	return b

# ---------- 输入 ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_I:
		_on_backpack_pressed()   # I 键切换背包(替代原 inventory_ui 的监听)
		get_viewport().set_input_as_handled()

# ---------- 按钮回调 ----------

func _on_profile_pressed() -> void:
	_toggle("profile", func() -> HUDPanel: return ProfilePanel.new(), profile_card_active_proxy())

func _on_settings_pressed() -> void:
	_toggle("settings", func() -> HUDPanel: return SettingsPanel.new(), _settings_btn)

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

# ---------- 面板管理 ----------

## 同类型面板已开则关闭(toggle),否则关掉旧面板并打开新的。
func _toggle(kind: String, factory: Callable, source_btn: HUDIconButton) -> void:
	if _current_kind == kind and has_open_panel():
		close_current()
		return
	var panel: HUDPanel = factory.call()
	open_panel(panel, source_btn)
	_current_kind = kind

func open_panel(panel: HUDPanel, source_btn: HUDIconButton = null) -> void:
	close_current()
	SceneManager._close_active_panel()   # 避免与旧 cozy/地图面板叠在一起
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

## 昵称/头像变更后刷新左上角色卡(角色选择完成时由 SceneManager 调用)。
func refresh_profile() -> void:
	if profile_card != null:
		profile_card.refresh()

# ---------- 图标取图 ----------

func _tex(asset_key: String) -> Texture2D:
	# 复用 SceneManager.ASSETS 里已注册的独立图标(已导入)。
	var path := str(SceneManager.ASSETS.get(asset_key, ""))
	return load(path) if path != "" and ResourceLoader.exists(path) else null

## 从已导入的 "All Icons.png"(16×16 图集)裁一格做图标,免新增资源文件。
func _sheet_icon(col: int, row: int) -> Texture2D:
	if not ResourceLoader.exists(ICON_ALL_ICONS):
		return null
	var at := AtlasTexture.new()
	at.atlas = load(ICON_ALL_ICONS)
	at.region = Rect2(col * 16, row * 16, 16, 16)
	return at
