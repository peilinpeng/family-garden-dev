extends TextureRect

const CLOCK_DIR := "res://assets/ui/clock/"
const FRAME_FILES := [
	"0.png",
	"1.png",
	"2.png",
	"2-1.png",
	"3.png",
	"4.png",
	"5.png",
	"6.png",
	"7.png",
	"7-1.png",
	"8.png",
	"9.png",
	"9-1.png",
	"10.png",
	"10-1.png",
	"11.png",
	"12.png",
	"13.png",
	"14.png",
	"15.png",
	"16.png",
	"17.png",
	"18.png",
	"18-1.png",
]

@export_range(0, 23, 1) var current_hour: int = 5

var _frames: Array[Texture2D] = []
var _last_hour := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP
	custom_minimum_size = Vector2(112, 124)
	size = custom_minimum_size

	_load_frames()
	var clock := _game_clock()
	if clock != null and clock.has_signal("hour_changed") and clock.has_method("hours"):
		clock.connect("hour_changed", Callable(self, "_on_hour_changed"))
		_update_for_hour(int(clock.call("hours")))
	else:
		_update_for_hour(current_hour)

func _process(_delta: float) -> void:
	var clock := _game_clock()
	if clock == null or not clock.has_method("hours"):
		return
	var hour := int(clock.call("hours"))
	if hour != _last_hour:
		_update_for_hour(hour)

func _load_frames() -> void:
	_frames.clear()
	for file_name in FRAME_FILES:
		var texture := load(CLOCK_DIR + file_name) as Texture2D
		if texture == null:
			push_warning("[DayNightClockUI] Missing clock frame: %s" % [CLOCK_DIR + file_name])
		_frames.append(texture)

func _on_hour_changed(hour: int) -> void:
	_update_for_hour(hour)

func _update_for_hour(hour: int) -> void:
	current_hour = posmod(hour, 24)
	_last_hour = current_hour
	if _frames.is_empty():
		return
	var frame_index := posmod(current_hour - 5 + 24, 24)
	texture = _frames[frame_index]

func _game_clock() -> Node:
	return get_node_or_null("/root/GameClock")
