extends Node2D

# Family Garden animal behaviour script.
# main.gd calls animal.setup({...}), so this script must keep setup(config).

var animal_id: String = "animal"
var display_name: String = "Animal"
var texture_path: String = ""

var home_position: Vector2 = Vector2.ZERO
var wander_radius: float = 80.0
var move_speed: float = 18.0
var target_height: float = 48.0

var sheet_hframes: int = 1
var sheet_vframes: int = 1

var frame_sets: Dictionary = {
	"idle": [0, 1],
	"walk": [2, 3, 4, 5],
	"sleep": [6, 7],
	"play": [8, 9, 10, 11],
}

var walk_bounds: Rect2 = Rect2(Vector2(0, 0), Vector2(1280, 720))
var blocked_rects: Array = []

var sprite: Sprite2D = null

var state: String = "idle"
var target_position: Vector2 = Vector2.ZERO
var state_timer: float = 0.0

var frame_timer: float = 0.0
var frame_index: int = 0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(config: Dictionary) -> void:
	animal_id = str(config.get("id", "animal"))
	display_name = str(config.get("name", "Animal"))
	texture_path = str(config.get("texture_path", ""))

	home_position = _as_vector2(config.get("home_position", config.get("pos", Vector2.ZERO)), Vector2.ZERO)
	global_position = home_position
	target_position = home_position

	target_height = float(config.get("target_height", config.get("height", 48.0)))
	sheet_hframes = max(1, int(config.get("hframes", 1)))
	sheet_vframes = max(1, int(config.get("vframes", 1)))

	wander_radius = float(config.get("wander_radius", 80.0))
	move_speed = float(config.get("move_speed", 18.0))

	var raw_frames = config.get("frames", {})
	if typeof(raw_frames) == TYPE_DICTIONARY:
		_set_frame_sets(raw_frames)

	var raw_bounds = config.get("bounds", walk_bounds)
	if raw_bounds is Rect2:
		walk_bounds = raw_bounds

	var raw_blocked = config.get("blocked_rects", [])
	if typeof(raw_blocked) == TYPE_ARRAY:
		blocked_rects = raw_blocked
	else:
		blocked_rects = []

	_build_sprite()


func _ready() -> void:
	rng.randomize()

	if home_position == Vector2.ZERO:
		home_position = global_position

	if target_position == Vector2.ZERO:
		target_position = home_position

	if not _is_walkable(global_position):
		global_position = _nearest_walkable_position(home_position)

	target_position = global_position
	_pick_next_state()


func _process(delta: float) -> void:
	if sprite == null:
		return

	state_timer -= delta
	frame_timer -= delta

	if state == "walk":
		_walk_toward_target(delta)

	if frame_timer <= 0.0:
		_advance_frame()

	if state_timer <= 0.0:
		_pick_next_state()

	z_index = int(global_position.y)


func _build_sprite() -> void:
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()

	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.hframes = sheet_hframes
	sprite.vframes = sheet_vframes

	if texture_path != "" and ResourceLoader.exists(texture_path):
		var texture: Texture2D = load(texture_path)
		sprite.texture = texture

		var frame_height: float = float(texture.get_height()) / float(sheet_vframes)
		if frame_height > 0.0:
			sprite.scale = Vector2.ONE * (target_height / frame_height)
	else:
		sprite.texture = _solid_texture(32, 32, Color(0.95, 0.86, 0.66, 1.0))
		sprite.scale = Vector2.ONE * 1.4

	add_child(sprite)
	_apply_current_frame()


func _pick_next_state() -> void:
	var roll: float = rng.randf()

	if roll < 0.38:
		_set_state("idle", rng.randf_range(5.0, 9.0))
	elif roll < 0.72:
		target_position = _pick_valid_target_position()
		if target_position.distance_to(global_position) < maxf(10.0, wander_radius * 0.22):
			_set_state("idle", rng.randf_range(3.0, 6.0))
		else:
			_set_state("walk", rng.randf_range(5.0, 8.0))
	elif roll < 0.90:
		if _has_state("sleep"):
			_set_state("sleep", rng.randf_range(8.0, 16.0))
		else:
			_set_state("idle", rng.randf_range(5.0, 9.0))
	else:
		if _has_state("play"):
			_set_state("play", rng.randf_range(5.0, 8.0))
		else:
			_set_state("idle", rng.randf_range(5.0, 9.0))


func _pick_valid_target_position() -> Vector2:
	var min_distance: float = maxf(14.0, wander_radius * 0.45)

	for i in range(24):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(min_distance, wander_radius)
		var candidate: Vector2 = home_position + Vector2(cos(angle), sin(angle)) * dist

		if candidate.distance_to(global_position) < min_distance:
			continue

		if _is_walkable(candidate):
			return candidate

	if _is_walkable(home_position):
		return home_position

	return global_position


func _set_state(new_state: String, duration: float) -> void:
	if not _has_state(new_state):
		new_state = "idle"

	if not _has_state(new_state):
		return

	state = new_state
	state_timer = duration
	frame_index = 0
	frame_timer = 0.0
	_apply_current_frame()


func _walk_toward_target(delta: float) -> void:
	var direction: Vector2 = target_position - global_position

	if direction.length() < 5.0:
		_set_state("idle", rng.randf_range(3.0, 6.0))
		return

	var next_position: Vector2 = global_position + direction.normalized() * move_speed * delta

	if not _is_walkable(next_position):
		_set_state("idle", rng.randf_range(3.0, 6.0))
		return

	global_position = next_position

	if abs(direction.x) > 1.0 and sprite != null:
		sprite.flip_h = direction.x < 0.0


func _is_walkable(point: Vector2) -> bool:
	if not walk_bounds.has_point(point):
		return false

	for rect_value in blocked_rects:
		if rect_value is Rect2:
			var rect: Rect2 = rect_value
			if rect.has_point(point):
				return false

	return true


func _nearest_walkable_position(fallback: Vector2) -> Vector2:
	if _is_walkable(fallback):
		return fallback

	var radii: Array = [24.0, 48.0, 72.0, 96.0, 128.0, 160.0]
	for radius in radii:
		for step in range(16):
			var angle: float = TAU * float(step) / 16.0
			var candidate: Vector2 = fallback + Vector2(cos(angle), sin(angle)) * float(radius)
			if _is_walkable(candidate):
				return candidate

	return fallback


func _advance_frame() -> void:
	var state_frames: Array = _get_state_frames(state)

	if state_frames.is_empty():
		return

	frame_index += 1
	if frame_index >= state_frames.size():
		frame_index = 0

	_apply_current_frame()

	if state == "walk":
		frame_timer = 0.30
	elif state == "play":
		frame_timer = 0.34
	elif state == "sleep":
		frame_timer = 0.70
	else:
		frame_timer = 0.55


func _apply_current_frame() -> void:
	if sprite == null:
		return

	var state_frames: Array = _get_state_frames(state)
	if state_frames.is_empty():
		return

	var safe_index: int = clampi(frame_index, 0, state_frames.size() - 1)
	var frame_number: int = int(state_frames[safe_index])
	var max_frame_number: int = max(0, sheet_hframes * sheet_vframes - 1)

	frame_number = clampi(frame_number, 0, max_frame_number)
	sprite.frame = frame_number


func _get_state_frames(state_name: String) -> Array:
	if typeof(frame_sets) != TYPE_DICTIONARY:
		return []

	if not frame_sets.has(state_name):
		return []

	var raw_frames = frame_sets.get(state_name, [])
	if typeof(raw_frames) != TYPE_ARRAY:
		return []

	return raw_frames


func _has_state(state_name: String) -> bool:
	var state_frames: Array = _get_state_frames(state_name)
	return not state_frames.is_empty()


func _set_frame_sets(raw_config: Dictionary) -> void:
	var cleaned: Dictionary = {}

	for key in raw_config.keys():
		var state_name: String = str(key)
		var raw_value = raw_config[key]

		if typeof(raw_value) != TYPE_ARRAY:
			continue

		var source_array: Array = raw_value
		var cleaned_frames: Array[int] = []

		for frame_value in source_array:
			if typeof(frame_value) == TYPE_INT or typeof(frame_value) == TYPE_FLOAT:
				cleaned_frames.append(int(frame_value))

		if not cleaned_frames.is_empty():
			cleaned[state_name] = cleaned_frames

	if not cleaned.is_empty():
		frame_sets = cleaned


func set_frame_config(config: Dictionary) -> void:
	_set_frame_sets(config)

	if not _has_state(state):
		if _has_state("idle"):
			state = "idle"
		else:
			var keys: Array = frame_sets.keys()
			if not keys.is_empty():
				state = str(keys[0])

	frame_index = 0
	_apply_current_frame()


func set_blocked_rects(rects: Array) -> void:
	blocked_rects = rects


func _as_vector2(value, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value

	return fallback


func _solid_texture(width: int, height: int, color: Color) -> Texture2D:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
