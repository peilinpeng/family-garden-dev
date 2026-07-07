extends AnimatedSprite2D

@export var drift_radius := Vector2(10.0, 5.0)
@export var drift_seconds := 7.5
@export var interaction_area_path: NodePath = NodePath("../../MessageBottle")
@export var push_source_path: NodePath = NodePath("../DuckSprite")
@export var push_distance := 52.0
@export var push_strength := 18.0
@export var push_return_speed := 1.8

var _base_position := Vector2.ZERO
var _time := 0.0
var _interaction_area: Area2D = null
var _push_source: Node2D = null
var _push_offset := Vector2.ZERO

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base_position = position
	_interaction_area = get_node_or_null(interaction_area_path) as Area2D
	_push_source = get_node_or_null(push_source_path) as Node2D
	if sprite_frames != null and sprite_frames.has_animation(&"float_loop"):
		play(&"float_loop")

func _process(delta: float) -> void:
	_time += delta
	_update_push_offset(delta)
	var phase := TAU * _time / maxf(0.1, drift_seconds)
	var drift := Vector2(cos(phase) * drift_radius.x, sin(phase * 1.27) * drift_radius.y)
	position = _base_position + drift + _push_offset
	if _interaction_area != null:
		_interaction_area.global_position = global_position

func _update_push_offset(delta: float) -> void:
	if _push_source != null and is_instance_valid(_push_source):
		var delta_to_bottle := global_position - _push_source.global_position
		var distance := delta_to_bottle.length()
		if distance > 0.01 and distance < push_distance:
			var pressure := 1.0 - distance / push_distance
			_push_offset += delta_to_bottle.normalized() * push_strength * pressure * delta
			_push_offset = _push_offset.limit_length(push_strength)
	_push_offset = _push_offset.move_toward(Vector2.ZERO, push_return_speed * delta)
