extends Node

## 昼夜时钟(autoload 单例)。游戏点钟≈现实点钟(动森式)。
## 联机一致:锚到服务器时间(set_server_time);全家用同一"花园时区"。
## 季节不在这里——季节是"家庭关系温度计",见 MemoryManager.garden_season()。
##
## 调试看夜晚:把 debug_start_hour 设成 22(从晚上起),或把 time_scale 调大(如 600,一天≈2.4分钟)。

signal hour_changed(hour: int)
signal phase_changed(phase: String)

@export var time_scale: float = 1.0          ## 1=实时;调大用于调试(600=一天约2.4分钟)
@export var debug_start_hour: float = -1.0   ## >=0 时从该时刻起(忽略真实时钟),便于看夜晚
@export var garden_tz_offset_hours: float = 8.0  ## 花园时区(默认 +8 北京);全家一致

var server_offset: float = 0.0   ## 服务器now - 设备now(秒),联机对齐
var filter_enabled: bool = true  ## 昼夜滤镜开关:关掉只取消整屏染色(置纯白),时间/时钟照常走
var _seconds: float = 0.0        ## 当天累计秒 [0,86400)
var _last_hour: int = -1
var _last_phase: String = ""
var _modulate: CanvasModulate    ## 全局昼夜染色(默认画布,覆盖所有场景;UI 在 CanvasLayer 不受影响)

## 一天内的染色乘子关键帧 (小时, 颜色)。白=正午无染色,蓝暗=夜,暖=晨/暮。
const COLOR_KEYS := [
	[0.0,  Color(0.20, 0.24, 0.45)],
	[5.0,  Color(0.26, 0.29, 0.47)],
	[7.0,  Color(0.85, 0.70, 0.62)],
	[9.0,  Color(1.0, 1.0, 1.0)],
	[17.0, Color(1.0, 1.0, 1.0)],
	[19.0, Color(0.92, 0.62, 0.50)],
	[21.0, Color(0.33, 0.32, 0.50)],
	[24.0, Color(0.20, 0.24, 0.45)],
]

func _ready() -> void:
	_seconds = _now_seconds()
	# 全局染色:挂在 autoload 下、不在任何 CanvasLayer 内 → 染默认画布的所有场景
	_modulate = CanvasModulate.new()
	_modulate.name = "DayNightModulate"
	add_child(_modulate)
	_modulate.color = overlay_color()

func _process(delta: float) -> void:
	if debug_start_hour >= 0.0 or time_scale != 1.0:
		_seconds = fposmod(_seconds + delta * time_scale, 86400.0)
	else:
		_seconds = _now_seconds()
	if _modulate != null:
		_modulate.color = overlay_color() if filter_enabled else Color.WHITE
	var h := int(hours())
	if h != _last_hour:
		_last_hour = h
		hour_changed.emit(h)
	var p := phase()
	if p != _last_phase:
		_last_phase = p
		phase_changed.emit(p)

func _now_seconds() -> float:
	if debug_start_hour >= 0.0:
		return fposmod(debug_start_hour * 3600.0, 86400.0)
	var t := Time.get_unix_time_from_system() + server_offset + garden_tz_offset_hours * 3600.0
	return fposmod(t, 86400.0)

func hours() -> float:
	return _seconds / 3600.0

func phase() -> String:
	var h := hours()
	if h >= 21.0 or h < 5.0:
		return "night"
	if h < 8.0:
		return "dawn"
	if h < 18.0:
		return "day"
	return "dusk"

func is_night() -> bool:
	return phase() == "night"

## 当前时段对应的整屏染色乘子(给 CanvasModulate)。
func overlay_color() -> Color:
	var h := hours()
	for i in range(COLOR_KEYS.size() - 1):
		var a: Array = COLOR_KEYS[i]
		var b: Array = COLOR_KEYS[i + 1]
		if h >= a[0] and h <= b[0]:
			var span: float = b[0] - a[0]
			var t: float = (h - a[0]) / span if span > 0.0 else 0.0
			return (a[1] as Color).lerp(b[1] as Color, t)
	return Color.WHITE

## 联机:用服务器时间戳对齐本地时钟。
func set_server_time(server_unix: float) -> void:
	server_offset = server_unix - Time.get_unix_time_from_system()

## 昼夜滤镜开关(设置面板/SettingsManager 调)。关掉立即取消染色,不影响时间与时钟显示。
func set_filter_enabled(on: bool) -> void:
	filter_enabled = on
	if _modulate != null:
		_modulate.color = overlay_color() if filter_enabled else Color.WHITE
