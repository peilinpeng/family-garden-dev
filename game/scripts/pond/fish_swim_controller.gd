extends AnimatedSprite2D

const DEFAULT_OFFSETS := "0,0;96,18;42,74;-64,56;-112,-8;-18,-62"
const DIRECTIONS := [
	"up",
	"up_right",
	"right",
	"down_right",
	"down",
	"down_left",
	"left",
	"up_left",
]
const ACTUAL_FRAME_FOR_DIRECTION := {
	"up": "up",
	"up_right": "up_left",
	"right": "left",
	"down_right": "down_left",
	"down": "down",
	"down_left": "down_right",
	"left": "right",
	"up_left": "up_right",
}
const DIRECTION_EPSILON := 0.35
const WIGGLE_AMPLITUDE_DEGREES := 2.0
const WIGGLE_PERIOD_SECONDS := 0.7

var _anchor_position := Vector2.ZERO
var _points: Array[Vector2] = []
var _target_index := 1
var _speed := 18.0
var _delay := 0.0
var _wiggle_time := 0.0
var _is_moving := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anchor_position = position
	_speed = float(get_meta("swim_speed", _speed))
	_delay = float(get_meta("swim_delay", 0.0))
	if sprite_frames == null:
		sprite_frames = _build_sprite_frames(str(get_meta("variant_path", "")))
	_points = _parse_offsets(str(get_meta("swim_offsets", DEFAULT_OFFSETS)))
	if _points.is_empty():
		_points = _parse_offsets(DEFAULT_OFFSETS)
	if sprite_frames != null and sprite_frames.has_animation(animation):
		play(animation)

func _build_sprite_frames(variant_path: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for direction in DIRECTIONS:
		var anim_name := StringName("swim_" + direction)
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, true)
		frames.set_animation_speed(anim_name, 8.0)
		var actual_frame_direction := str(ACTUAL_FRAME_FOR_DIRECTION.get(direction, direction))
		var frame_path := "%s/koi_fish_swim_%s_01.png" % [variant_path, actual_frame_direction]
		var texture := load(frame_path) if ResourceLoader.exists(frame_path) else null
		if texture != null:
			frames.add_frame(anim_name, texture)
	return frames

func _process(delta: float) -> void:
	if _delay > 0.0:
		_delay -= delta
		_apply_tail_wiggle(delta, false)
		return
	if _points.size() < 2:
		_apply_tail_wiggle(delta, false)
		return

	var target := _anchor_position + _points[_target_index]
	var before := position
	position = position.move_toward(target, _speed * delta)
	var movement := position - before
	_is_moving = movement.length_squared() > DIRECTION_EPSILON * DIRECTION_EPSILON
	if _is_moving:
		_play_direction(movement)
	_apply_tail_wiggle(delta, _is_moving)

	if position.distance_to(target) < 1.0:
		_target_index = (_target_index + 1) % _points.size()

func _parse_offsets(raw: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for pair in raw.split(";", false):
		var xy := pair.split(",", false)
		if xy.size() >= 2:
			result.append(Vector2(float(xy[0]), float(xy[1])).round())
	return result

func _play_direction(delta: Vector2) -> void:
	var anim := _animation_for_delta(delta)
	if animation != anim and sprite_frames != null and sprite_frames.has_animation(anim):
		play(anim)

func _animation_for_delta(delta: Vector2) -> StringName:
	var abs_x := absf(delta.x)
	var abs_y := absf(delta.y)
	if abs_x <= DIRECTION_EPSILON and abs_y <= DIRECTION_EPSILON:
		return animation

	if abs_x > abs_y * 1.35:
		return &"swim_right" if delta.x > 0.0 else &"swim_left"
	if abs_y > abs_x * 1.35:
		return &"swim_down" if delta.y > 0.0 else &"swim_up"
	if delta.x > 0.0 and delta.y < 0.0:
		return &"swim_up_right"
	if delta.x > 0.0 and delta.y > 0.0:
		return &"swim_down_right"
	if delta.x < 0.0 and delta.y > 0.0:
		return &"swim_down_left"
	return &"swim_up_left"

func _apply_tail_wiggle(delta: float, moving: bool) -> void:
	_wiggle_time += delta
	var amplitude := WIGGLE_AMPLITUDE_DEGREES if moving else WIGGLE_AMPLITUDE_DEGREES * 0.35
	var phase := TAU * (_wiggle_time / WIGGLE_PERIOD_SECONDS)
	rotation_degrees = sin(phase) * amplitude
