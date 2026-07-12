extends CharacterBody2D

@export var speed := 170.0
@export var character_id := ""   ## 设了就用该角色;留空则按存档 selected_role_key

const IDLE_BLINK_INTERVAL := 0.5  ## 朝下站定时,眨眼循环(睁-闭-睁)每帧停留秒数

var sprite: Sprite2D
var step_timer := 0.0
var step_index := 0
var facing_row := 0
var idle_timer := 0.0
var idle_frame := 0
var frame_rects: Array[Rect2] = []   ## 非等分网格贴图(如 girl)按精确裁切矩形取帧,优先于 hframes/vframes
var movement_locked := false   ## 场景切换渐隐过程中锁住输入,人物原地站定淡出

const IDLE_FRAME_INDEX := 1   ## 站立用每行中间列(两脚并拢);第 0/2 列是迈步帧

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
	sprite.scale = Vector2.ONE * float(def.get("scale", 0.46))
	frame_rects.clear()
	var raw_rects: Array = def.get("frame_rects", [])
	for r in raw_rects:
		if r is Array and r.size() >= 4:
			frame_rects.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	if frame_rects.size() > 0:
		# 精确矩形模式:图集不是等分网格(手工排的关键帧,行高/列宽都不一致),
		# 用 hframes/vframes 均分裁切会切到帽子/脚,所以直接按每帧真实包围盒取图。
		sprite.region_enabled = true
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.frame = 0
		# 紧包围盒图集(如 girl_2)脚底就在帧底边:阴影跟到视觉脚底(帧高×缩放的一半,精灵居中)。
		# 留白图集(papa 等)脚底在帧内偏上,保持场景里调好的原值不动。
		var shadow := get_node_or_null("Shadow") as Node2D
		if shadow != null and frame_rects.size() > 1:
			shadow.position.y = frame_rects[1].size.y * sprite.scale.y * 0.5
	else:
		sprite.region_enabled = false
		sprite.hframes = int(def.get("hframes", 3))
		sprite.vframes = int(def.get("vframes", 4))
	character_id = role_key

## 场景传送门渐隐切换时调用:锁住/解锁移动输入,人物原地站定不再乱走。
func set_movement_locked(locked: bool) -> void:
	movement_locked = locked
	if locked:
		velocity = Vector2.ZERO
		_update_walk_animation(0.0, false)

func _physics_process(delta: float) -> void:
	if movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

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
	var parent_canvas := get_parent() as CanvasItem
	z_index = 0 if parent_canvas != null and parent_canvas.y_sort_enabled else int(global_position.y + 18.0)

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

	# 贴图有第 5 行(眨眼待机帧)的判定:精确矩形模式看 frame_rects 是否够 15 个(5 行 x3 列),
	# 否则看老式 hframes/vframes 网格是否有 5 行。
	var has_idle_row := frame_rects.size() >= 15 or sprite.vframes >= 5

	if walking:
		idle_timer = 0.0
		idle_frame = 0
		step_timer += delta
		if step_timer > 0.13:   # 步频略快于原 0.16,走路观感更自然(与移速 170 匹配)
			step_timer = 0.0
			step_index = (step_index + 1) % 3
			if step_index == 0:   # 每走完一个完整步频循环响一次脚步声,不然太密集
				AudioManager.play_sfx("steps-5", -10.0)
		_set_frame(facing_row * 3 + step_index)
		return

	step_index = IDLE_FRAME_INDEX
	step_timer = 0.0

	# 朝下站定且有待机行时,播放睁-闭-睁的循环;其它朝向没有对应的待机行,
	# 退回原来的"保持中间步频帧"。
	if facing_row == 0 and has_idle_row:
		idle_timer += delta
		if idle_timer >= IDLE_BLINK_INTERVAL:
			idle_timer = 0.0
			idle_frame = (idle_frame + 1) % 3
		_set_frame(4 * 3 + idle_frame)
	else:
		idle_timer = 0.0
		idle_frame = 0
		_set_frame(facing_row * 3 + step_index)

## 按帧序号取图:优先用精确矩形(frame_rects),没有就退回 hframes/vframes 均分网格。
func _set_frame(index: int) -> void:
	if frame_rects.size() > index:
		sprite.frame = 0
		sprite.region_rect = frame_rects[index]
	else:
		sprite.frame = index
