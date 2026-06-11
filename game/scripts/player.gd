extends CharacterBody2D

@export var speed := 170.0

var sprite: Sprite2D
var step_timer := 0.0
var step_index := 1
var facing_row := 0

func _ready() -> void:
	sprite = get_node_or_null("Sprite2D")

func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0

	if direction.length() > 0.0:
		direction = direction.normalized()
		velocity = direction * speed
		_set_facing(direction)
		_update_walk_animation(delta, true)
	else:
		velocity = Vector2.ZERO
		_update_walk_animation(delta, false)

	move_and_slide()
	z_index = int(global_position.y)

func _set_facing(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		facing_row = 2 if direction.x > 0.0 else 1
	else:
		facing_row = 0 if direction.y > 0.0 else 3

func _update_walk_animation(delta: float, walking: bool) -> void:
	if sprite == null:
		return
	if sprite.texture == null:
		return

	sprite.hframes = 3
	sprite.vframes = 4

	if walking:
		step_timer += delta
		if step_timer > 0.16:
			step_timer = 0.0
			step_index = (step_index + 1) % 3
	else:
		step_index = 1
		step_timer = 0.0

	sprite.frame = facing_row * 3 + step_index
