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
		p.volume_db = MUSIC_VOLUME_DB
		add_child(p)
		_music_players.append(p)

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

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
	if scene_key == _current_music_key:
		return
	_current_music_key = scene_key

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
	var stream := _load_first(SFX_DIR, name)
	if stream == null:
		push_warning("[AudioManager] 找不到音效: " + name)
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.play()

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
