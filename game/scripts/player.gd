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
var frame_offsets: Array[Vector2] = []
var frame_rects: Array[Rect2] = []   ## 非等分网格贴图(如 girl)按精确裁切矩形取帧,优先于 hframes/vframes
var movement_locked := false   ## 场景切换渐隐过程中锁住输入,人物原地站定淡出

const IDLE_FRAME_INDEX := 0

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
	else:
		sprite.region_enabled = false
		sprite.hframes = int(def.get("hframes", 3))
		sprite.vframes = int(def.get("vframes", 4))
	_rebuild_frame_offsets()
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
		if step_timer > 0.16:
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
		sprite.region_rect = frame_rects[index]
	else:
		sprite.frame = index
	if frame_offsets.size() > index:
		sprite.offset = frame_offsets[index]
	else:
		sprite.offset = Vector2.ZERO

func _rebuild_frame_offsets() -> void:
	frame_offsets.clear()
	if sprite == null or sprite.texture == null:
		return
	var image: Image = sprite.texture.get_image()
	if image == null:
		return
	var frame_count: int = frame_rects.size()
	if frame_count <= 0:
		frame_count = max(1, sprite.hframes * sprite.vframes)
	var frame_data: Array = []
	frame_data.resize(frame_count)
	var row_targets: Dictionary = {}
	for i in range(frame_count):
		var rect: Rect2 = _frame_source_rect(i)
		var bbox: Rect2 = _alpha_bbox(image, rect)
		if bbox.size == Vector2.ZERO:
			frame_data[i] = {"valid": false}
			continue
		var row: int = _frame_row(i)
		var rect_center: Vector2 = rect.position + rect.size * 0.5
		var local_center_x: float = bbox.position.x + bbox.size.x * 0.5 - rect_center.x
		var local_bottom: float = bbox.position.y + bbox.size.y - rect_center.y
		frame_data[i] = {
			"valid": true,
			"row": row,
			"local_center_x": local_center_x,
			"local_bottom": local_bottom
		}
		if not row_targets.has(row):
			row_targets[row] = {"center_sum": 0.0, "count": 0, "bottom": local_bottom}
		var target: Dictionary = row_targets[row]
		target["center_sum"] = float(target["center_sum"]) + local_center_x
		target["count"] = int(target["count"]) + 1
		target["bottom"] = max(float(target["bottom"]), local_bottom)
		row_targets[row] = target
	for i in range(frame_count):
		var data: Dictionary = frame_data[i]
		if not bool(data.get("valid", false)):
			frame_offsets.append(Vector2.ZERO)
			continue
		var row: int = int(data.get("row", 0))
		var target: Dictionary = row_targets.get(row, {})
		var target_center: float = float(target.get("center_sum", 0.0)) / float(max(1, int(target.get("count", 1))))
		var target_bottom: float = float(target.get("bottom", data.get("local_bottom", 0.0)))
		frame_offsets.append(Vector2(
			target_center - float(data.get("local_center_x", 0.0)),
			target_bottom - float(data.get("local_bottom", 0.0))
		))

func _frame_source_rect(index: int) -> Rect2:
	if frame_rects.size() > index:
		return frame_rects[index]
	var cols: int = max(1, sprite.hframes)
	var rows: int = max(1, sprite.vframes)
	var frame_size: Vector2 = Vector2(
		float(sprite.texture.get_width()) / float(cols),
		float(sprite.texture.get_height()) / float(rows)
	)
	var col: int = index % cols
	var row: int = floori(float(index) / float(cols))
	return Rect2(Vector2(float(col) * frame_size.x, float(row) * frame_size.y), frame_size)

func _frame_row(index: int) -> int:
	if frame_rects.size() > 0:
		return floori(float(index) / 3.0)
	return floori(float(index) / float(max(1, sprite.hframes)))

func _alpha_bbox(image: Image, rect: Rect2) -> Rect2:
	var x0: int = clampi(int(floor(rect.position.x)), 0, image.get_width())
	var y0: int = clampi(int(floor(rect.position.y)), 0, image.get_height())
	var x1: int = clampi(int(ceil(rect.position.x + rect.size.x)), 0, image.get_width())
	var y1: int = clampi(int(ceil(rect.position.y + rect.size.y)), 0, image.get_height())
	var min_x: int = x1
	var min_y: int = y1
	var max_x: int = x0
	var max_y: int = y0
	var found: bool = false
	for y in range(y0, y1):
		for x in range(x0, x1):
			if image.get_pixel(x, y).a <= 0.05:
				continue
			found = true
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x + 1)
			max_y = maxi(max_y, y + 1)
	if not found:
		return Rect2(rect.position, Vector2.ZERO)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
