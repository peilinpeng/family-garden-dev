extends HUDPanel
class_name SettingsPanel

## 设置面板(右上设置图标打开)。音乐/音效音量、全屏、UI 缩放(占位)、退出游戏/返回主菜单(占位)。
## 只跟 SettingsManager 打交道,音频/显示细节由它委托 AudioManager / DisplayServer。

func _init() -> void:
	panel_title = "设置 / Settings"
	card_size = Vector2(480, 420)

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

	# UI 缩放 —— 占位(后续接 content_scale_factor)
	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 12)
	scale_row.add_child(_row_label("🔍 UI 缩放"))
	var scale_hint := Label.new()
	scale_hint.text = "即将开放"
	scale_hint.add_theme_font_size_override("font_size", 13)
	scale_hint.add_theme_color_override("font_color", Color(0.55, 0.45, 0.32, 0.8))
	scale_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scale_row.add_child(scale_hint)
	content_root.add_child(scale_row)

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
