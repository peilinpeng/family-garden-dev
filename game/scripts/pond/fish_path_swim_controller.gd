extends PathFollow2D

@export var speed := 22.0
@export var initial_progress_ratio := 0.0
@export var fish_node_path: NodePath = NodePath("../../Fish05_01")

const DIRECTION_EPSILON := 0.25

var _fish: AnimatedSprite2D
var _last_global_position := Vector2.ZERO

func _ready() -> void:
	rotates = false
	loop = true
	progress_ratio = initial_progress_ratio
	_fish = get_node_or_null(fish_node_path) as AnimatedSprite2D
	_last_global_position = global_position
	if _fish != null:
		_fish.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_fish.global_position = global_position
		_fish.z_index = 0
		_fish.play(&"swim_right")

func _process(delta: float) -> void:
	progress += speed * delta
	var movement := global_position - _last_global_position
	_last_global_position = global_position
	if _fish == null:
		return
	_fish.global_position = global_position
	_fish.z_index = 0
	if movement.length_squared() <= DIRECTION_EPSILON * DIRECTION_EPSILON:
		return
	var animation_name := _animation_for_delta(movement)
	if _fish.animation != animation_name:
		_fish.play(animation_name)

func _animation_for_delta(delta: Vector2) -> StringName:
	var abs_x := absf(delta.x)
	var abs_y := absf(delta.y)
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
