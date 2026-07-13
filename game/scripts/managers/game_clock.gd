extends Node

signal hour_changed(hour: int)
signal phase_changed(phase: String)

@export var time_scale: float = 1.0
@export var debug_start_hour: float = -1.0
@export var garden_tz_offset_hours: float = 8.0

var server_offset: float = 0.0
var day_night_enabled := true
var brightness := 1.0

var _seconds: float = 0.0
var _last_hour: int = -1
var _last_phase: String = ""
var _modulate: CanvasModulate

const COLOR_KEYS := [
	[0.0, Color(0.20, 0.24, 0.45)],
	[5.0, Color(0.26, 0.29, 0.47)],
	[7.0, Color(0.85, 0.70, 0.62)],
	[9.0, Color(1.0, 1.0, 1.0)],
	[17.0, Color(1.0, 1.0, 1.0)],
	[19.0, Color(0.92, 0.62, 0.50)],
	[21.0, Color(0.33, 0.32, 0.50)],
	[24.0, Color(0.20, 0.24, 0.45)],
]

func _ready() -> void:
	_seconds = _now_seconds()
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
		_modulate.color = overlay_color()

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

func overlay_color() -> Color:
	if not day_night_enabled:
		return Color(brightness, brightness, brightness, 1.0)

	var h := hours()
	for i in range(COLOR_KEYS.size() - 1):
		var a: Array = COLOR_KEYS[i]
		var b: Array = COLOR_KEYS[i + 1]
		if h >= a[0] and h <= b[0]:
			var span: float = b[0] - a[0]
			var t: float = (h - a[0]) / span if span > 0.0 else 0.0
			return _apply_brightness((a[1] as Color).lerp(b[1] as Color, t))
	return _apply_brightness(Color.WHITE)

func set_day_night_enabled(enabled: bool) -> void:
	day_night_enabled = enabled
	if _modulate != null:
		_modulate.color = overlay_color()

func set_brightness(value: float) -> void:
	brightness = clampf(value, 0.55, 1.45)
	if _modulate != null:
		_modulate.color = overlay_color()

func set_server_time(server_unix: float) -> void:
	server_offset = server_unix - Time.get_unix_time_from_system()

func _apply_brightness(color: Color) -> Color:
	return Color(
		clampf(color.r * brightness, 0.0, 1.45),
		clampf(color.g * brightness, 0.0, 1.45),
		clampf(color.b * brightness, 0.0, 1.45),
		color.a
	)
