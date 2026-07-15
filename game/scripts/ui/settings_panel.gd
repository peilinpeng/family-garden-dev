extends HUDPanel
class_name SettingsPanel

## 设置面板(右上设置图标打开)。音量、全屏、昼夜滤镜、关怀模式与存档操作。
## 只跟 SettingsManager 打交道,音频/显示细节由它委托 AudioManager / DisplayServer。

var _delete_save_dialog: ConfirmationDialog = null

func _init() -> void:
	panel_title = "设置 / Settings"
	card_size = Vector2(480, 470)

func _build_content() -> void:
	content_root.add_child(_slider_row("🎵 音乐音量", SettingsManager.music_volume,
		func(v: float) -> void: SettingsManager.set_music_volume(v)))
	content_root.add_child(_slider_row("🔊 音效音量", SettingsManager.sfx_volume,
		func(v: float) -> void: SettingsManager.set_sfx_volume(v)))

	# 全屏(Web 端由浏览器控制,隐藏)
	if not OS.has_feature("web"):
		var fs_row := HBoxContainer.new()
		fs_row.add_theme_constant_override("separation", 12)
		var fs_label := _row_label("🖥️ 全屏模式")
		fs_row.add_child(fs_label)
		var fs_toggle := CheckButton.new()
		fs_toggle.button_pressed = SettingsManager.fullscreen
		fs_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
		fs_toggle.toggled.connect(func(on: bool) -> void: SettingsManager.set_fullscreen(on))
		fs_row.add_child(fs_toggle)
		content_root.add_child(fs_row)

	# 昼夜滤镜开关(关掉只取消整屏染色,不影响时间/时钟)
	var dn_row := HBoxContainer.new()
	dn_row.add_theme_constant_override("separation", 12)
	dn_row.add_child(_row_label("🌗 昼夜滤镜"))
	var dn_toggle := CheckButton.new()
	dn_toggle.button_pressed = SettingsManager.day_night_filter
	dn_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	dn_toggle.toggled.connect(func(on: bool) -> void: SettingsManager.set_day_night_filter(on))
	dn_row.add_child(dn_toggle)
	content_root.add_child(dn_row)

	# 关怀模式:只放大 Control UI 的文字与交互尺寸，不改变游戏画面与可视范围。
	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 12)
	scale_row.add_child(_row_label("👓 关怀模式"))
	var care_toggle := CheckButton.new()
	care_toggle.name = "CareModeToggle"
	care_toggle.text = ""
	care_toggle.button_pressed = SettingsManager.care_mode
	care_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	care_toggle.tooltip_text = "开启后只放大文字、按钮和输入控件，不改变游戏画面与可视范围。"
	care_toggle.toggled.connect(func(on: bool) -> void: SettingsManager.set_care_mode(on))
	scale_row.add_child(care_toggle)
	content_root.add_child(scale_row)

	# 重播开场 —— 仅开发/debug 构建可见(编辑器运行与 debug 导出;正式 release 导出自动隐藏)。
	# 只重置 opening_seen 并重播,不清任务/库存/记忆卡/存档。
	if OS.is_debug_build():
		var replay_row := HBoxContainer.new()
		replay_row.add_theme_constant_override("separation", 12)
		replay_row.add_child(_row_label("🎬 开场剧情"))
		var replay_btn := Button.new()
		replay_btn.text = "重播开场(开发)"
		replay_btn.custom_minimum_size = Vector2(150, 34)
		HUDPanel._style_soft_button(replay_btn)
		replay_btn.pressed.connect(func() -> void:
			close_requested.emit()
			StoryManager.debug_replay_opening(SceneManager.ui_layer.get_parent()))
		replay_row.add_child(replay_btn)
		content_root.add_child(replay_row)

	var reset_row := HBoxContainer.new()
	reset_row.add_theme_constant_override("separation", 12)
	reset_row.add_child(_row_label("🧹 存档管理"))
	var reset_btn := Button.new()
	reset_btn.text = "删档 / 恢复初始状态"
	reset_btn.custom_minimum_size = Vector2(190, 34)
	reset_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	HUDPanel._style_soft_button(reset_btn)
	reset_btn.pressed.connect(_show_delete_save_confirm)
	reset_row.add_child(reset_btn)
	content_root.add_child(reset_row)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_root.add_child(spacer)

	# 底部操作按钮
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	content_root.add_child(actions)

	# 返回主菜单 —— 占位(当前无主菜单场景),禁用
	var menu_btn := Button.new()
	menu_btn.text = "返回主菜单(即将开放)"
	menu_btn.custom_minimum_size = Vector2(0, 40)
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_btn.disabled = true
	HUDPanel._style_soft_button(menu_btn)
	actions.add_child(menu_btn)

	# 退出游戏(Web 端无效,隐藏)
	if not OS.has_feature("web"):
		var quit_btn := Button.new()
		quit_btn.text = "退出游戏"
		quit_btn.custom_minimum_size = Vector2(140, 40)
		HUDPanel._style_soft_button(quit_btn)
		quit_btn.pressed.connect(func() -> void: get_tree().quit())
		actions.add_child(quit_btn)

func _show_delete_save_confirm() -> void:
	if _delete_save_dialog == null or not is_instance_valid(_delete_save_dialog):
		_delete_save_dialog = ConfirmationDialog.new()
		_delete_save_dialog.title = "确认删档"
		_delete_save_dialog.dialog_text = "这会清除当前本机存档、角色进度和上次位置，并回到初始状态。确定继续吗？"
		_delete_save_dialog.confirmed.connect(func() -> void:
			SceneManager.call_deferred("reset_to_new_game"))
		add_child(_delete_save_dialog)
	_delete_save_dialog.popup_centered(Vector2(420, 170))

func _slider_row(text: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_row_label(text))

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(200, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.mouse_filter = Control.MOUSE_FILTER_STOP

	var pct := Label.new()
	pct.custom_minimum_size = Vector2(44, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pct.add_theme_font_size_override("font_size", 13)
	pct.add_theme_color_override("font_color", Color(0.42, 0.34, 0.24, 0.9))
	pct.text = "%d%%" % int(round(value * 100.0))

	slider.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % int(round(v * 100.0))
		on_change.call(v))
	row.add_child(slider)
	row.add_child(pct)
	return row

func _row_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(150, 32)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16, 1.0))
	return l
