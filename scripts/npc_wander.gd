extends CharacterBody2D

@export var home_position: Vector2 = Vector2.ZERO
@export var wander_radius: float = 85.0
@export var move_speed: float = 34.0
@export var walk_bounds: Rect2 = Rect2(Vector2(35, 100), Vector2(1210, 560))

var blocked_rects: Array = []
var target_position: Vector2 = Vector2.ZERO
var state: String = "idle"
var state_timer: float = 0.0

var step_timer: float = 0.0
var step_index: int = 1
var facing_row: int = 0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()

	if home_position == Vector2.ZERO:
		home_position = global_position

	target_position = global_position
	_pick_next_state()


func _physics_process(delta: float) -> void:
	state_timer -= delta

	if state == "walk":
		var direction: Vector2 = target_position - global_position

		if direction.length() < 6.0:
			_set_state("idle", rng.randf_range(3.5, 7.0))
		else:
			direction = direction.normalized()
			velocity = direction * move_speed
			_set_facing(direction)
			_update_walk_animation(delta, true)
			move_and_slide()

			if get_slide_collision_count() > 0:
				_set_state("idle", rng.randf_range(3.0, 6.0))
	else:
		velocity = Vector2.ZERO
		_update_walk_animation(delta, false)

	if state_timer <= 0.0:
		_pick_next_state()

	z_index = int(global_position.y)


func _pick_next_state() -> void:
	var roll: float = rng.randf()

	if roll < 0.62:
		_set_state("idle", rng.randf_range(4.0, 8.0))
	else:
		target_position = _pick_target()

		if target_position.distance_to(global_position) < 12.0:
			_set_state("idle", rng.randf_range(3.0, 6.0))
		else:
			_set_state("walk", rng.randf_range(5.0, 8.0))


func _pick_target() -> Vector2:
	var min_distance: float = maxf(18.0, wander_radius * 0.35)

	for i in range(24):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(min_distance, wander_radius)
		var candidate: Vector2 = home_position + Vector2(cos(angle), sin(angle)) * dist

		if candidate.distance_to(global_position) < min_distance:
			continue

		if _is_point_allowed(candidate):
			return candidate

	if _is_point_allowed(home_position):
		return home_position

	return global_position


func _is_point_allowed(point: Vector2) -> bool:
	if not walk_bounds.has_point(point):
		return false

	for rect_value in blocked_rects:
		if rect_value is Rect2:
			var rect: Rect2 = rect_value
			if rect.has_point(point):
				return false

	return true


func _set_state(new_state: String, duration: float) -> void:
	state = new_state
	state_timer = duration


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
		if step_timer > 0.24:
			step_timer = 0.0
			step_index = (step_index + 1) % 3
	else:
		step_index = 1
		step_timer = 0.0

	sprite.frame = facing_row * 3 + step_index


func set_blocked_rects(rects: Array) -> void:
	blocked_rects = rects
