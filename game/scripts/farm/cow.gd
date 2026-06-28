extends Node2D

## 牛:简单状态机(idle/walk/eat/rest)+ 随机切换。
## 活动范围被限制在 cowhouse 牛圈内(pen 矩形,可在编辑器里调)。
## z_index = 脚底 Y,与 cowhouse/玩家自动遮挡。

enum State { IDLE, WALK, EAT, REST }

## 牛中心点可活动的矩形(屏幕坐标)。默认是 cowhouse 院子,按需在 Inspector 里拖。
@export var pen: Rect2 = Rect2(90, 525, 240, 55)
@export var speed: float = 26.0

var anim: AnimatedSprite2D
var state: int = State.IDLE
var state_time: float = 0.0
var target: Vector2

func _ready() -> void:
	anim = $Anim
	randomize()
	# 出生点夹到圈内,避免摆错位置跑出去
	global_position = _clamp_to_pen(global_position)
	_enter(State.IDLE)

func _physics_process(delta: float) -> void:
	state_time -= delta
	if state == State.WALK:
		var to := target - global_position
		if to.length() < 4.0 or state_time <= 0.0:
			_pick_next()
		else:
			var dir := to.normalized()
			global_position += dir * speed * delta
			anim.flip_h = dir.x < 0.0   # 素材朝右,向左走时翻转
	elif state_time <= 0.0:
		_pick_next()
	global_position = _clamp_to_pen(global_position)
	z_index = int(global_position.y)

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
