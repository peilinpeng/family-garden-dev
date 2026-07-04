extends PathFollow2D

@export var speed := 20.0
@export var initial_progress_ratio := 0.0
@export var duck_node_path: NodePath = NodePath("../../DuckSprite")
@export var water_shape_path: NodePath = NodePath("../../../Collision/WaterCollision/WaterCollisionPolygon")
@export var land_move_seconds := Vector2(2.0, 4.2)
@export var land_rest_seconds := Vector2(0.7, 1.8)
@export var water_move_seconds := Vector2(2.4, 4.8)
@export var water_rest_seconds := Vector2(0.9, 2.2)

const MOVE_EPSILON := 0.25

var _duck: AnimatedSprite2D
var _water_shape: CollisionShape2D
var _last_global_position := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _is_resting := false
var _state_time_left := 0.0
var _current_speed := 0.0
var _current_surface_is_water := false

func _ready() -> void:
	rotates = false
	loop = true
	progress_ratio = initial_progress_ratio
	_rng.randomize()
	_duck = get_node_or_null(duck_node_path) as AnimatedSprite2D
	_water_shape = get_node_or_null(water_shape_path) as CollisionShape2D
	_last_global_position = global_position
	if _duck != null:
		_duck.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_duck.global_position = global_position
		_duck.z_index = 0
	_start_move_state()

func _process(delta: float) -> void:
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		if _is_resting:
			_start_move_state()
		else:
			_start_rest_state()

	if not _is_resting:
		progress += _current_speed * delta

	var movement := global_position - _last_global_position
	_last_global_position = global_position
	if _duck == null:
		return
	_duck.global_position = global_position
	_duck.z_index = 0
	if movement.length_squared() > MOVE_EPSILON * MOVE_EPSILON:
		_duck.flip_h = movement.x < 0.0
	if not _is_resting:
		_update_move_animation_for_surface()

func _start_move_state() -> void:
	_is_resting = false
	_current_speed = speed * _rng.randf_range(0.78, 1.18)
	_current_surface_is_water = _is_in_water()
	_state_time_left = _random_range(water_move_seconds if _current_surface_is_water else land_move_seconds)
	_update_move_animation_for_surface(true)

func _start_rest_state() -> void:
	_is_resting = true
	_current_speed = 0.0
	_current_surface_is_water = _is_in_water()
	_state_time_left = _random_range(water_rest_seconds if _current_surface_is_water else land_rest_seconds)
	if _current_surface_is_water:
		_hold_random_frame(&"water_swim")
	else:
		_hold_random_frame(&"land_idle")

func _update_move_animation_for_surface(force_new_speed := false) -> void:
	var in_water := _is_in_water()
	if in_water != _current_surface_is_water or force_new_speed:
		_current_surface_is_water = in_water
		_play_animation(&"water_swim" if in_water else &"land_walk", true, _rng.randf_range(0.75, 1.12))

func _is_in_water() -> bool:
	if _water_shape == null or _water_shape.shape == null:
		return false
	var polygon_shape := _water_shape.shape as ConvexPolygonShape2D
	if polygon_shape == null:
		return false
	var local_position := _water_shape.to_local(global_position)
	return Geometry2D.is_point_in_polygon(local_position, polygon_shape.points)

func _random_range(range: Vector2) -> float:
	return _rng.randf_range(range.x, range.y)

func _play_animation(animation_name: StringName, playing: bool, speed_scale: float = 1.0) -> void:
	if _duck == null:
		return
	_duck.speed_scale = speed_scale
	if _duck.animation != animation_name:
		_duck.play(animation_name)
	elif playing and not _duck.is_playing():
		_duck.play()
	if not playing:
		_duck.pause()

func _hold_random_frame(animation_name: StringName) -> void:
	if _duck == null:
		return
	if _duck.animation != animation_name:
		_duck.play(animation_name)
	var frame_count := _duck.sprite_frames.get_frame_count(animation_name)
	if frame_count > 0:
		_duck.frame = _rng.randi_range(0, frame_count - 1)
	_duck.frame_progress = 0.0
	_duck.pause()
