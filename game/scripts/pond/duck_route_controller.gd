extends PathFollow2D

@export var speed := 20.0
@export var initial_progress_ratio := 0.0
@export var duck_node_path: NodePath = NodePath("DuckSprite")
@export_range(0.0, 1.0, 0.01) var water_start_ratio := 0.32
@export_range(0.0, 1.0, 0.01) var water_end_ratio := 0.72
@export_range(0.0, 1.0, 0.01) var idle_start_ratio := 0.92

const MOVE_EPSILON := 0.25

var _duck: AnimatedSprite2D
var _last_global_position := Vector2.ZERO

func _ready() -> void:
	rotates = false
	loop = true
	progress_ratio = initial_progress_ratio
	_duck = get_node_or_null(duck_node_path) as AnimatedSprite2D
	_last_global_position = global_position
	if _duck != null:
		_duck.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_duck.play(_animation_for_progress())

func _process(delta: float) -> void:
	progress += speed * delta
	var movement := global_position - _last_global_position
	_last_global_position = global_position
	if _duck == null:
		return
	_duck.z_index = int(global_position.y)
	if movement.length_squared() > MOVE_EPSILON * MOVE_EPSILON:
		_duck.flip_h = movement.x < 0.0
	var animation_name := _animation_for_progress()
	if _duck.animation != animation_name:
		_duck.play(animation_name)

func _animation_for_progress() -> StringName:
	if progress_ratio >= idle_start_ratio:
		return &"land_idle"
	if progress_ratio >= water_start_ratio and progress_ratio <= water_end_ratio:
		return &"water_swim"
	return &"land_walk"
