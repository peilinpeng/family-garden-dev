extends Node

var failures: Array[String] = []
var _settings_existed := false
var _settings_backup := ""
var _original_care_mode := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	_backup_settings()
	_original_care_mode = SettingsManager.care_mode
	SettingsManager.set_care_mode(false)
	var original_viewport_size := get_viewport().get_visible_rect().size
	var original_window_scale := get_window().content_scale_factor

	var test_ui := VBoxContainer.new()
	add_child(test_ui)
	var test_label := Label.new()
	test_label.text = "关怀模式字号测试"
	test_label.add_theme_font_size_override("font_size", 16)
	test_ui.add_child(test_label)
	var inherited_label := Label.new()
	inherited_label.text = "继承全局字号测试"
	test_ui.add_child(inherited_label)
	var test_button := Button.new()
	test_button.text = "操作按钮"
	test_button.custom_minimum_size = Vector2(120, 32)
	test_button.add_theme_font_size_override("font_size", 14)
	test_ui.add_child(test_button)
	await get_tree().process_frame
	var inherited_font_size := inherited_label.get_theme_font_size("font_size")

	SettingsManager.set_care_mode(true)
	await get_tree().process_frame
	_assert(SettingsManager.care_mode, "开启后应记录关怀模式状态")
	_assert(is_equal_approx(get_window().content_scale_factor, original_window_scale),
		"开启关怀模式后不得缩放 Window 内容")
	_assert(get_viewport().get_visible_rect().size.is_equal_approx(original_viewport_size),
		"开启关怀模式后游戏可视范围必须保持不变")
	_assert(test_label.get_theme_font_size("font_size") == 20,
		"开启关怀模式后应将显式文字字号放大 25%")
	_assert(inherited_label.get_theme_font_size("font_size") == roundi(float(inherited_font_size) * SettingsManager.CARE_UI_SCALE),
		"开启关怀模式后应放大继承全局主题字号的文字")
	_assert(test_button.custom_minimum_size.is_equal_approx(Vector2(150, 40)),
		"开启关怀模式后应将操作控件最小尺寸放大 25%")
	SettingsManager.set_care_mode(true)
	_assert(test_label.get_theme_font_size("font_size") == 20,
		"重复应用关怀模式时字号不得累积放大")
	_assert(_saved_care_mode() == true, "开启关怀模式后应写入 settings.json")

	var dynamic_label := Label.new()
	dynamic_label.text = "动态界面"
	dynamic_label.add_theme_font_size_override("font_size", 12)
	test_ui.add_child(dynamic_label)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(dynamic_label.get_theme_font_size("font_size") == 15,
		"关怀模式开启期间新增的 UI 也应自动放大")

	var panel := SettingsPanel.new()
	add_child(panel)
	await get_tree().process_frame
	var care_toggle := panel.find_child("CareModeToggle", true, false) as CheckButton
	_assert(care_toggle != null, "设置面板应提供关怀模式开关")
	_assert(care_toggle != null and care_toggle.button_pressed, "关怀模式开关应反映已保存状态")
	panel.queue_free()

	SettingsManager.set_care_mode(false)
	_assert(not SettingsManager.care_mode, "关闭后应清除关怀模式状态")
	_assert(is_equal_approx(get_window().content_scale_factor, original_window_scale),
		"关闭关怀模式后 Window 内容缩放仍应保持不变")
	_assert(test_label.get_theme_font_size("font_size") == 16,
		"关闭关怀模式后应恢复原始显式字号")
	_assert(inherited_label.get_theme_font_size("font_size") == inherited_font_size,
		"关闭关怀模式后应恢复继承的全局主题字号")
	_assert(test_button.custom_minimum_size.is_equal_approx(Vector2(120, 32)),
		"关闭关怀模式后应恢复操作控件原始最小尺寸")
	_assert(dynamic_label.get_theme_font_size("font_size") == 12,
		"关闭关怀模式后应恢复动态 UI 的原始字号")
	test_ui.queue_free()

	_restore_settings()
	if failures.is_empty():
		print("Settings care mode tests passed: unchanged viewport, enlarged UI, restore and persistence")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _backup_settings() -> void:
	_settings_existed = FileAccess.file_exists(SettingsManager.SAVE_PATH)
	if not _settings_existed:
		return
	var file := FileAccess.open(SettingsManager.SAVE_PATH, FileAccess.READ)
	if file != null:
		_settings_backup = file.get_as_text()

func _restore_settings() -> void:
	if _settings_existed:
		var file := FileAccess.open(SettingsManager.SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(_settings_backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SettingsManager.SAVE_PATH))
	SettingsManager.care_mode = _original_care_mode
	SettingsManager._apply_care_mode()

func _saved_care_mode() -> Variant:
	var file := FileAccess.open(SettingsManager.SAVE_PATH, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return null
	return parsed.get("care_mode", null)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
