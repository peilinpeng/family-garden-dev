extends Node2D
class_name FarmAnimal

## 通用农场动物状态机(idle/walk/eat/rest)+ 随机切换。
## - 活动范围限制在 pen 矩形内(牛圈 / 鸡圈)。
## - 与其它动物保持间距,避免诡异重叠(分离力)。
## - z_index = 脚底 Y,与建筑/玩家/彼此自动遮挡。
## - 幼崽可生长:grows=true 时,grow_seconds 后换成 adult_frames(如幼鸡→鸡)。

enum State { IDLE, WALK, EAT, REST }

@export var pen: Rect2 = Rect2(85, 520, 250, 62)   ## 中心点可活动矩形(屏幕坐标)
@export var speed: float = 26.0

@export_group("Growth")
@export var grows: bool = false                    ## 是否会长大(幼崽)
@export var grow_seconds: float = 600.0            ## 长大所需秒数(同 crop:10 分钟)
@export var adult_frames: SpriteFrames             ## 长大后的动画(如鸡)
@export var adult_scale: float = 1.0               ## 长大后的缩放

const SEPARATION_DIST := 34.0   ## 动物间最小中心距,小于则互相推开
const SEPARATION_PUSH := 22.0

var anim: AnimatedSprite2D
var state: int = State.IDLE
var state_time: float = 0.0
var target: Vector2
var age: float = 0.0
var _feet: float = 0.0   ## 精灵中心到脚底的偏移(用于 z 排序,和玩家脚底一致)

func _ready() -> void:
	anim = $Anim
	add_to_group("farm_animals")
	randomize()
	_recalc_feet()
	global_position = _clamp_to_pen(global_position)
	_enter(State.IDLE)

## AnimatedSprite2D 居中,脚底 = 中心 + 半个精灵高(随缩放/换帧变化)。
func _recalc_feet() -> void:
	var tex := anim.sprite_frames.get_frame_texture("idle", 0)
	if tex != null:
		_feet = tex.get_height() * anim.scale.y * 0.5

func _physics_process(delta: float) -> void:
	if grows:
		age += delta
		if age >= grow_seconds:
			_grow_up()

	state_time -= delta
	if state == State.WALK:
		var to := target - global_position
		if to.length() < 4.0 or state_time <= 0.0:
			_pick_next()
		else:
			var dir := to.normalized()
			global_position += dir * speed * delta
			anim.flip_h = dir.x < 0.0   # 素材朝右,向左走翻转
	elif state_time <= 0.0:
		_pick_next()

	_separate(delta)
	global_position = _clamp_to_pen(global_position)
	z_index = int(global_position.y + _feet)

## 与其它动物保持距离(简单分离力),避免站成一坨。
func _separate(delta: float) -> void:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("farm_animals"):
		if other == self:
			continue
		var d: Vector2 = global_position - (other as Node2D).global_position
		var dist := d.length()
		if dist > 0.01 and dist < SEPARATION_DIST:
			push += d.normalized() * (SEPARATION_DIST - dist) / SEPARATION_DIST
	if push != Vector2.ZERO:
		global_position += push * SEPARATION_PUSH * delta

func _grow_up() -> void:
	grows = false
	if adult_frames != null:
		anim.sprite_frames = adult_frames
		anim.scale = Vector2(adult_scale, adult_scale)
		_recalc_feet()
	_enter(State.IDLE)

func _clamp_to_pen(p: Vector2) -> Vector2:
	return Vector2(
		clampf(p.x, pen.position.x, pen.end.x),
		clampf(p.y, pen.position.y, pen.end.y))

func _pick_next() -> void:
	var r := randf()
	if r < 0.35:
		_enter(State.WALK)
	elif r < 0.60:
		_enter(State.EAT)
	elif r < 0.80:
		_enter(State.IDLE)
	else:
		_enter(State.REST)

func _enter(s: int) -> void:
	state = s
	match s:
		State.IDLE:
			anim.play("idle"); state_time = randf_range(4.0, 8.0)
		State.WALK:
			anim.play("walk"); state_time = randf_range(5.0, 9.0)
			target = Vector2(
				randf_range(pen.position.x, pen.end.x),
				randf_range(pen.position.y, pen.end.y))
		State.EAT:
			anim.play("eat"); state_time = randf_range(8.0, 14.0)
		State.REST:
			anim.play("rest"); state_time = randf_range(12.0, 22.0)
