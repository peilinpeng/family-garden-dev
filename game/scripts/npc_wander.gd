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
var sprite_hframes: int = 3
var sprite_vframes: int = 4
var _frame_rects: Array[Rect2] = []   ## 非等分网格贴图(如 girl_2)按精确裁切矩形取帧,优先于 hframes/vframes
var _label_check_timer := 0.0
var _label_alpha := 0.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	if sprite != null:
		if _frame_rects.size() > 0:
			# 精确裁切时 Sprite2D 必须保持 1x1；方向与步态使用独立的逻辑网格。
			# 不能从 sprite.hframes/vframes 反推，否则会把 3x5 动画误判成 1x1。
			sprite_hframes = maxi(1, int(get_meta("sprite_hframes", 3)))
			var inferred_rows := ceili(float(_frame_rects.size()) / float(sprite_hframes))
			sprite_vframes = maxi(1, int(get_meta("sprite_vframes", inferred_rows)))
			sprite.region_enabled = true
			sprite.hframes = 1
			sprite.vframes = 1
			sprite.frame = 0
		else:
			sprite_hframes = maxi(1, int(get_meta("sprite_hframes", sprite.hframes)))
			sprite_vframes = maxi(1, int(get_meta("sprite_vframes", sprite.vframes)))
			sprite.hframes = sprite_hframes
			sprite.vframes = sprite_vframes

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
	_update_name_label(delta)


## 姓名只在玩家靠近时出现，既保留人物辨识，也让花园远景保持干净。
func _update_name_label(delta: float) -> void:
	_label_check_timer -= delta
	var should_show := false
	if _label_check_timer <= 0.0:
		_label_check_timer = 0.12
		var player := get_tree().get_first_node_in_group("player") as Node2D
		should_show = player != null and global_position.distance_to(player.global_position) <= 118.0
		set_meta("show_name_label", should_show)
	else:
		should_show = bool(get_meta("show_name_label", false))
	_label_alpha = move_toward(_label_alpha, 1.0 if should_show else 0.0, delta * 6.0)
	for node_name in ["NameLabel", "OnlineStatus"]:
		var label := get_node_or_null(node_name) as CanvasItem
		if label == null:
			continue
		label.visible = _label_alpha > 0.02
		label.modulate.a = _label_alpha


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

	if walking:
		step_timer += delta
		if step_timer > 0.24:
			step_timer = 0.0
			step_index = (step_index + 1) % sprite_hframes
	else:
		step_index = mini(1, sprite_hframes - 1)
		step_timer = 0.0

	var row := clampi(facing_row, 0, maxi(0, sprite_vframes - 1))
	var index := row * sprite_hframes + step_index
	if _frame_rects.size() > index:
		sprite.frame = 0
		sprite.region_rect = _frame_rects[index]
	else:
		# 兼容脚本刚挂载、精确裁剪帧尚未注入的首帧；永远不向 Sprite2D 写越界 frame。
		var frame_count := maxi(1, sprite.hframes * sprite.vframes)
		sprite.frame = clampi(index, 0, frame_count - 1)


func set_blocked_rects(rects: Array) -> void:
	blocked_rects = rects


## 非等分网格贴图(如 girl_2)按精确裁切矩形取帧;传空数组则退回 hframes/vframes 均分网格。
func set_frame_rects(rects: Array) -> void:
	_frame_rects.clear()
	for r in rects:
		if r is Array and r.size() >= 4:
			_frame_rects.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	if sprite != null and _frame_rects.size() > 0:
		sprite.region_enabled = true
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.frame = 0
