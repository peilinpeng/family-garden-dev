extends Node

## 全局音频管理器(autoload)。统一入口播放场景 BGM 和一次性音效,别处不要再散建 AudioStreamPlayer。
## BGM: res://music/{scene_key}.{mp3,m4a,ogg,wav},按场景名切歌,自动循环 + 交叉淡入淡出。
## SFX: res://soundeffect/{name}.{mp3,wav,ogg},按文件名(不含扩展名)一次性播放,可多个叠放。

const MUSIC_DIR := "res://music/"
const SFX_DIR := "res://soundeffect/"
const AUDIO_EXTS := ["mp3", "ogg", "wav", "m4a"]
const MUSIC_FADE_SECONDS := 0.8
const MUSIC_VOLUME_DB := -6.0
const SFX_VOLUME_DB := 0.0
const SFX_SILENT_DB := -80.0
const SFX_POOL_SIZE := 8

var _music_players: Array[AudioStreamPlayer] = []
var _active_music_index := 0
var _current_music_key := ""
var _pending_web_music_key := ""
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _stream_cache: Dictionary = {}   ## "dir/name" -> AudioStream(或 null,记过的"找不到"也缓存,省重复扫盘)

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")

	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "Music%d" % i
		p.bus = "Music"
		# Godot Web 默认把播放器视为 Sample；动态加载的长音乐、总线与淡入淡出
		# 统一强制走 Stream，避免浏览器端播放器显示 playing 却没有实际输出。
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		p.volume_db = MUSIC_VOLUME_DB
		add_child(p)
		_music_players.append(p)

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		p.bus = "SFX"
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(p)
		_sfx_pool.append(p)

	# 浏览器会在首次真实点击/按键前暂停 Web Audio。保留输入监听，在用户手势内重试启动 BGM。
	set_process_input(OS.has_feature("web"))

func _exit_tree() -> void:
	for p in _music_players:
		p.stop()
		p.stream = null
	for p in _sfx_pool:
		p.stop()
		p.stream = null
	_stream_cache.clear()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

## 切场景时调用一次:scene_key 对应 res://music/{scene_key}.*,找不到就把当前 BGM 淡出静音。
## 同一个 scene_key 连续调用(比如同场景内小范围切换)不会重复重播。
func play_music(scene_key: String) -> void:
	if _audio_disabled_for_headless():
		return
	if scene_key == _current_music_key and _active_music_is_playing():
		return
	_start_music(scene_key)

func _start_music(scene_key: String) -> void:
	_current_music_key = scene_key
	if OS.has_feature("web") and scene_key != "":
		_pending_web_music_key = scene_key

	var outgoing: AudioStreamPlayer = _music_players[_active_music_index]
	var stream := _load_first(MUSIC_DIR, scene_key)

	if stream == null:
		if scene_key != "":
			push_warning("[AudioManager] 没找到场景 BGM: " + scene_key)
		_fade_out_and_stop(outgoing)
		return

	_active_music_index = 1 - _active_music_index
	var incoming: AudioStreamPlayer = _music_players[_active_music_index]

	_enable_loop(stream)

	incoming.stream = stream
	incoming.volume_db = SFX_SILENT_DB
	incoming.play()
	create_tween().tween_property(incoming, "volume_db", MUSIC_VOLUME_DB, MUSIC_FADE_SECONDS)

	if outgoing != incoming:
		_fade_out_and_stop(outgoing)

func _input(event: InputEvent) -> void:
	if _pending_web_music_key == "" or not _is_audio_unlock_event(event):
		return
	# 必须在浏览器用户手势的同步输入回调中重播；call_deferred 会错过自动播放授权窗口。
	var scene_key := _pending_web_music_key
	_pending_web_music_key = ""
	_start_music(scene_key)
	set_process_input(false)

func _active_music_is_playing() -> bool:
	return not _music_players.is_empty() \
		and _active_music_index >= 0 \
		and _active_music_index < _music_players.size() \
		and _music_players[_active_music_index].playing

func _is_audio_unlock_event(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventScreenTouch and event.pressed)

## 不同音频格式的循环开关字段不一样(MP3/OGG 是 loop 布尔,WAV 是 loop_mode 枚举),分别设。
func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

func _fade_out_and_stop(player: AudioStreamPlayer) -> void:
	if not player.playing:
		return
	var t := create_tween()
	t.tween_property(player, "volume_db", SFX_SILENT_DB, MUSIC_FADE_SECONDS)
	t.tween_callback(player.stop)

## 一次性音效,name 是 res://soundeffect/ 下的文件名(不含扩展名,支持中文文件名)。
func play_sfx(name: String, volume_db: float = SFX_VOLUME_DB) -> void:
	if _audio_disabled_for_headless():
		return
	var stream := _load_first(SFX_DIR, name)
	if stream == null:
		push_warning("[AudioManager] 找不到音效: " + name)
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.play()

## 音量总线控制(0.0~1.0 线性),供 SettingsManager / 设置面板调用。0 视为静音。
## 音乐/音效各走独立 bus(_ready 里已建),这里只改 bus 音量,不动各 player 的基础音量。
func set_music_volume(linear: float) -> void:
	_set_bus_volume("Music", linear)

func set_sfx_volume(linear: float) -> void:
	_set_bus_volume("SFX", linear)

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))

func _load_first(dir: String, base_name: String) -> AudioStream:
	var cache_key := dir + base_name
	if _stream_cache.has(cache_key):
		return _stream_cache[cache_key]
	var found: AudioStream = null
	for ext in AUDIO_EXTS:
		var path := "%s%s.%s" % [dir, base_name, ext]
		if ResourceLoader.exists(path):
			found = load(path)
			break
	_stream_cache[cache_key] = found
	return found

func _audio_disabled_for_headless() -> bool:
	return DisplayServer.get_name() == "headless"
