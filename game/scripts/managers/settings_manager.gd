extends Node

## 全局设置(autoload SettingsManager)。集中管理玩家偏好:音乐/音效音量、全屏。
## 持久化到 user://settings.json(与游戏存档、库存存档分开);启动时 load + apply。
## 设置面板只跟本管理器打交道,音频细节委托给 AudioManager。

const SAVE_PATH := "user://settings.json"

signal settings_changed

var music_volume: float = 0.8   ## 0.0~1.0 线性
var sfx_volume: float = 0.9     ## 0.0~1.0 线性
var fullscreen: bool = false
var day_night_filter: bool = true   ## 昼夜滤镜(整屏染色);关掉不影响时间

func _ready() -> void:
	_load()
	# 延后一帧套用:确保 AudioManager 的音频总线在 apply 前已建好(autoload 顺序里它在前)。
	call_deferred("apply_all")

## 把当前设置一次性套到运行时(启动 / 外部批量应用时用)。
func apply_all() -> void:
	AudioManager.set_music_volume(music_volume)
	AudioManager.set_sfx_volume(sfx_volume)
	_apply_fullscreen()
	GameClock.set_filter_enabled(day_night_filter)
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

func _apply_fullscreen() -> void:
	if OS.has_feature("web"):
		return   # Web 端全屏由浏览器/用户手势控制,跳过以免报错
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

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
	}))
