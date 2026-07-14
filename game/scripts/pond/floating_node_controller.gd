extends Node2D

@export var drift_radius := Vector2(8.0, 4.0)
@export var drift_seconds := 7.0
@export var phase_offset := 0.0

var _base_position := Vector2.ZERO
var _time := 0.0

func _ready() -> void:
	_base_position = position

func _process(delta: float) -> void:
	_time += delta
	var phase := TAU * _time / maxf(0.1, drift_seconds) + phase_offset
	position = _base_position + Vector2(
		cos(phase) * drift_radius.x,
		sin(phase * 1.23) * drift_radius.y
	)
