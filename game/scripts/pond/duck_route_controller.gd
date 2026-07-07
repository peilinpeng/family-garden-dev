extends PathFollow2D

@export var speed := 20.0
@export var initial_progress_ratio := 0.0
@export var duck_node_path: NodePath = NodePath("../../DuckSprite")
@export var water_shape_path: NodePath = NodePath("../../../Collision/WaterCollision/WaterCollisionPolygon")
@export var water_move_seconds := Vector2(2.4, 4.8)
@export var water_action_seconds := Vector2(0.55, 0.9)
@export var water_edge_margin := 32.0

const MOVE_EPSILON := 0.25
const DUCK_CONTACT_OFFSET := Vector2(0, -54)
const WATER_SURFACE_Z := 10

var _duck: AnimatedSprite2D
var _water_shape: CollisionShape2D
var _last_global_position := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _is_water_action := false
var _state_time_left := 0.0
var _current_speed := 0.0
var _next_action_is_splash := true

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
		_duck.offset = DUCK_CONTACT_OFFSET
		_duck.global_position = global_position
		_duck.z_index = WATER_SURFACE_Z
	_start_swim_state()

func _process(delta: float) -> void:
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		if _is_water_action:
			_start_swim_state()
		else:
			_start_water_action_state()

	if not _is_water_action:
		progress += _current_speed * delta

	var movement := global_position - _last_global_position
	_last_global_position = global_position
	if _duck == null:
		return
	_duck.global_position = global_position
	_duck.z_index = WATER_SURFACE_Z
	if movement.length_squared() > MOVE_EPSILON * MOVE_EPSILON:
		_duck.flip_h = movement.x < 0.0
	if not _is_water_action and _duck.animation != &"water_swim":
		_play_animation(&"water_swim", true)

func _start_swim_state() -> void:
	_is_water_action = false
	_current_speed = speed * _rng.randf_range(0.78, 1.18)
	_state_time_left = _random_range(water_move_seconds)
	_play_animation(&"water_swim", true, _rng.randf_range(0.9, 1.1))

func _start_water_action_state() -> void:
	_is_water_action = true
	_current_speed = 0.0
	_state_time_left = _random_range(water_action_seconds)
	if _next_action_is_splash:
		_play_animation(&"water_splash", true, _rng.randf_range(0.95, 1.15))
	else:
		_play_animation(&"water_dive", true, _rng.randf_range(0.9, 1.05))
	_next_action_is_splash = not _next_action_is_splash

func _is_in_water() -> bool:
	if _water_shape == null or _water_shape.shape == null:
		return false
	var polygon_shape := _water_shape.shape as ConvexPolygonShape2D
	if polygon_shape == null:
		return false
	var local_position := _water_shape.to_local(global_position)
	if not Geometry2D.is_point_in_polygon(local_position, polygon_shape.points):
		return false
	return _distance_to_polygon_edge(local_position, polygon_shape.points) >= water_edge_margin

func _distance_to_polygon_edge(point: Vector2, points: PackedVector2Array) -> float:
	var best := INF
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		best = minf(best, Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point))
	return best

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
