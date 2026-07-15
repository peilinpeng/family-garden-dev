extends Node

## 全局设置(autoload SettingsManager)。集中管理玩家偏好:音量、显示与关怀模式。
## 持久化到 user://settings.json(与游戏存档、库存存档分开);启动时 load + apply。
## 设置面板只跟本管理器打交道,音频细节委托给 AudioManager。

const SAVE_PATH := "user://settings.json"
const CARE_UI_SCALE := 1.25
const CARE_FONT_STATE_META := &"_family_garden_care_font_state"
const CARE_MINIMUM_SIZE_META := &"_family_garden_care_minimum_size"
const RICH_TEXT_FONT_SIZES: Array[StringName] = [
	&"normal_font_size",
	&"bold_font_size",
	&"italics_font_size",
	&"bold_italics_font_size",
	&"mono_font_size",
]

signal settings_changed

var music_volume: float = 0.8   ## 0.0~1.0 线性
var sfx_volume: float = 0.9     ## 0.0~1.0 线性
var fullscreen: bool = false
var day_night_filter: bool = true   ## 昼夜滤镜(整屏染色);关掉不影响时间
var care_mode: bool = false   ## 关怀模式:全局放大界面与文字,方便年长玩家阅读

func _ready() -> void:
	_load()
	get_tree().node_added.connect(_on_tree_node_added)
	# 延后一帧套用:确保 AudioManager 的音频总线在 apply 前已建好(autoload 顺序里它在前)。
	call_deferred("apply_all")

## 把当前设置一次性套到运行时(启动 / 外部批量应用时用)。
func apply_all() -> void:
	AudioManager.set_music_volume(music_volume)
	AudioManager.set_sfx_volume(sfx_volume)
	_apply_fullscreen()
	GameClock.set_filter_enabled(day_night_filter)
	_apply_care_mode()
	settings_changed.emit()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	AudioManager.set_music_volume(music_volume)
	_save()
	settings_changed.emit()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	AudioManager.set_sfx_volume(sfx_volume)
	_save()
	settings_changed.emit()

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_fullscreen()
	_save()
	settings_changed.emit()

func set_day_night_filter(on: bool) -> void:
	day_night_filter = on
	GameClock.set_filter_enabled(on)
	_save()
	settings_changed.emit()

func set_care_mode(on: bool) -> void:
	care_mode = on
	_apply_care_mode()
	_save()
	settings_changed.emit()

func _apply_fullscreen() -> void:
	if OS.has_feature("web"):
		return   # Web 端全屏由浏览器/用户手势控制,跳过以免报错
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _apply_care_mode() -> void:
	# 只改 Control 节点的字体与交互最小尺寸；不改 Window / Viewport，游戏画面与可视范围保持不变。
	_apply_care_mode_recursive(get_tree().root)

func _apply_care_mode_recursive(node: Node) -> void:
	if node is Control:
		_apply_care_to_control(node as Control)
	for child in node.get_children():
		_apply_care_mode_recursive(child)

func _on_tree_node_added(node: Node) -> void:
	if care_mode and node is Control:
		# 新节点刚入树时主题继承可能尚未完成，延后一拍读取最终字号。
		call_deferred("_apply_care_to_control", node as Control)

func _apply_care_to_control(control: Control) -> void:
	if not is_instance_valid(control):
		return
	if care_mode:
		_enlarge_control_fonts(control)
		_enlarge_interactive_control(control)
	else:
		_restore_control_fonts(control)
		_restore_interactive_control(control)

func _enlarge_control_fonts(control: Control) -> void:
	if control.has_meta(CARE_FONT_STATE_META):
		return
	var font_size_names: Array[StringName] = []
	if control.has_theme_font_size(&"font_size"):
		font_size_names.append(&"font_size")
	if control is RichTextLabel:
		for font_size_name in RICH_TEXT_FONT_SIZES:
			if control.has_theme_font_size(font_size_name):
				font_size_names.append(font_size_name)
	if font_size_names.is_empty():
		return
	var state := {}
	for font_size_name in font_size_names:
		var had_override := control.has_theme_font_size_override(font_size_name)
		state[font_size_name] = {
			"had_override": had_override,
			"value": control.get_theme_font_size(font_size_name) if had_override else 0,
		}
		var enlarged_size := maxi(1, roundi(float(control.get_theme_font_size(font_size_name)) * CARE_UI_SCALE))
		control.add_theme_font_size_override(font_size_name, enlarged_size)
	control.set_meta(CARE_FONT_STATE_META, state)

func _restore_control_fonts(control: Control) -> void:
	if not control.has_meta(CARE_FONT_STATE_META):
		return
	var state: Dictionary = control.get_meta(CARE_FONT_STATE_META)
	for font_size_name: StringName in state:
		var item: Dictionary = state[font_size_name]
		if bool(item.get("had_override", false)):
			control.add_theme_font_size_override(font_size_name, int(item.get("value", 14)))
		else:
			control.remove_theme_font_size_override(font_size_name)
	control.remove_meta(CARE_FONT_STATE_META)

func _enlarge_interactive_control(control: Control) -> void:
	if not _is_interactive_control(control) or control.has_meta(CARE_MINIMUM_SIZE_META):
		return
	var original_size := control.custom_minimum_size
	control.set_meta(CARE_MINIMUM_SIZE_META, original_size)
	var content_size := control.get_combined_minimum_size()
	control.custom_minimum_size = Vector2(
		maxf(original_size.x * CARE_UI_SCALE, content_size.x),
		maxf(original_size.y * CARE_UI_SCALE, content_size.y)
	)

func _restore_interactive_control(control: Control) -> void:
	if not control.has_meta(CARE_MINIMUM_SIZE_META):
		return
	control.custom_minimum_size = control.get_meta(CARE_MINIMUM_SIZE_META) as Vector2
	control.remove_meta(CARE_MINIMUM_SIZE_META)

func _is_interactive_control(control: Control) -> bool:
	return control is BaseButton or control is LineEdit or control is TextEdit or control is SpinBox

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return
	music_volume = clampf(float(parsed.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(parsed.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(parsed.get("fullscreen", fullscreen))
	day_night_filter = bool(parsed.get("day_night_filter", day_night_filter))
	care_mode = bool(parsed.get("care_mode", care_mode))

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[SettingsManager] 无法写入设置: " + SAVE_PATH)
		return
	f.store_string(JSON.stringify({
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"fullscreen": fullscreen,
		"day_night_filter": day_night_filter,
		"care_mode": care_mode,
	}))
