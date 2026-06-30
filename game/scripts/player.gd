extends CharacterBody2D

@export var speed := 170.0
@export var character_id := ""   ## 设了就用该角色;留空则按存档 selected_role_key

var sprite: Sprite2D
var step_timer := 0.0
var step_index := 1
var facing_row := 0

func _ready() -> void:
	sprite = get_node_or_null("Sprite2D")
	if character_id != "":
		apply_character(character_id)

## 数据驱动换角色:从 CharacterDB 取贴图/帧网格/缩放套到 Sprite2D。
func apply_character(role_key: String) -> void:
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	var db := get_node_or_null("/root/CharacterDB")
	if db == null or sprite == null:
		return
	var def: Dictionary = db.get_def(role_key)
	if def.is_empty():
		return
	var tex: Texture2D = db.texture(role_key)
	if tex != null:
		sprite.texture = tex
	sprite.hframes = int(def.get("hframes", 3))
	sprite.vframes = int(def.get("vframes", 4))
	sprite.scale = Vector2.ONE * float(def.get("scale", 0.46))
	character_id = role_key

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
	# 用脚底(碰撞体中心 +18)做排序枢轴,遮挡翻转点更贴近视觉
	z_index = int(global_position.y + 18.0)

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
