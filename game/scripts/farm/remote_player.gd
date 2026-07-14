extends Node2D

## 远端家庭成员的可视化。联机时由 presence 用 set_target() 喂位置(见 docs/43);
## 现在没有联机 → 开 placeholder_wander 当占位成员在花园里溜达。
## 复用 CharacterDB,同一套角色配置;z = 脚底 Y,与场景正确遮挡。

@export var role_key := "father"
@export var display_name := ""
@export var member_id := ""
@export var placeholder_wander := false
@export var wander_area := Rect2()

var sprite: Sprite2D
var label: Label
var target: Vector2
var last_sequence := 0
var _step_timer := 0.0
var _step := 1
var _facing := 0
var _wander_timer := 0.0
var _frame_rects: Array[Rect2] = []   ## 非等分网格贴图(如 girl_2)按精确裁切矩形取帧,优先于 hframes/vframes

func _ready() -> void:
	target = global_position
	randomize()
	_build()

func _build() -> void:
	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = load("res://assets/characters/shadow.png")
	shadow.position = Vector2(0, 30)
	shadow.scale = Vector2(0.28, 0.16)
	shadow.modulate = Color(1, 1, 1, 0.8)
	add_child(shadow)

	sprite = Sprite2D.new()
	add_child(sprite)
	var db := get_node_or_null("/root/CharacterDB")
	if db != null:
		var def: Dictionary = db.get_def(role_key)
		var tex: Texture2D = db.texture(role_key)
		if tex != null:
			sprite.texture = tex
		sprite.scale = Vector2.ONE * float(def.get("scale", 0.46))
		_frame_rects.clear()
		var raw_rects: Array = def.get("frame_rects", [])
		for r in raw_rects:
			if r is Array and r.size() >= 4:
				_frame_rects.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
		if _frame_rects.size() > 0:
			sprite.region_enabled = true
			sprite.hframes = 1
			sprite.vframes = 1
			sprite.frame = 0
			sprite.region_rect = _frame_rects[1] if _frame_rects.size() > 1 else _frame_rects[0]
			shadow.position.y = sprite.region_rect.size.y * sprite.scale.y * 0.5
		else:
			sprite.region_enabled = false
			sprite.hframes = int(def.get("hframes", 3))
			sprite.vframes = int(def.get("vframes", 4))
		if display_name == "":
			display_name = str(def.get("name", role_key))
	label = Label.new()
	label.text = display_name
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(90, 16)
	label.position = Vector2(-45, -58)
	add_child(label)

func configure_presence(peer_member_id: String, peer_role: String, peer_name: String, appearance: Dictionary = {}) -> void:
	member_id = peer_member_id
	role_key = CharacterDB.resolve(peer_role) if CharacterDB != null else peer_role
	display_name = peer_name if peer_name.strip_edges() != "" else CharacterDB.display_name(role_key)
	placeholder_wander = false
	if label != null:
		label.text = display_name
		label.modulate = Color(0.16, 0.28, 0.22, 1.0)
	if sprite != null:
		var db := get_node_or_null("/root/CharacterDB")
		if db != null:
			var def: Dictionary
			var tex: Texture2D
			var appearance_manager := get_node_or_null("/root/AppearanceManager")
			var clean_appearance: Dictionary = {}
			if appearance_manager != null and bool(appearance.get("enabled", false)):
				clean_appearance = appearance_manager.normalize(appearance, role_key)
				def = appearance_manager.variant_definition(clean_appearance, role_key)
				tex = appearance_manager.texture(clean_appearance, role_key)
			else:
				def = db.get_def(role_key)
				tex = db.texture(role_key)
			if tex != null:
				sprite.texture = tex
			sprite.scale = Vector2.ONE * float(def.get("scale", 0.46))
			if clean_appearance.is_empty():
				sprite.material = null
			_frame_rects.clear()
			var raw_rects: Array = def.get("frame_rects", [])
			for rect_value in raw_rects:
				if rect_value is Array and rect_value.size() >= 4:
					_frame_rects.append(Rect2(float(rect_value[0]), float(rect_value[1]), float(rect_value[2]), float(rect_value[3])))
			if _frame_rects.size() > 0:
				sprite.region_enabled = true
				sprite.hframes = 1
				sprite.vframes = 1
				sprite.frame = 0
				sprite.region_rect = _frame_rects[1] if _frame_rects.size() > 1 else _frame_rects[0]
				# 联机角色同样直接使用对方组合对应的完整图集。
				sprite.material = null
				var shadow := get_node_or_null("Shadow") as Node2D
				if shadow != null:
					shadow.position.y = sprite.region_rect.size.y * sprite.scale.y * 0.5
			else:
				sprite.region_enabled = false
				sprite.hframes = int(def.get("hframes", 3))
				sprite.vframes = int(def.get("vframes", 4))
				sprite.frame = mini(1, sprite.hframes * sprite.vframes - 1)

## 联机:由 presence 喂入目标位置。旧序列会丢弃,避免网络乱序导致回滚。
func set_target(pos: Vector2) -> void:
	target = pos

func set_presence_target(pos: Vector2, direction: String, animation_state: String, sequence: int) -> void:
	if sequence < last_sequence:
		return
	last_sequence = sequence
	target = pos
	match direction:
		"left":
			_facing = 1
		"right":
			_facing = 2
		"up":
			_facing = 3
		_:
			_facing = 0
	if animation_state == "idle":
		_step = 1

func _process(delta: float) -> void:
	if placeholder_wander and wander_area.size != Vector2.ZERO:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = randf_range(3.0, 7.0)
			target = Vector2(
				randf_range(wander_area.position.x, wander_area.end.x),
				randf_range(wander_area.position.y, wander_area.end.y))
	var prev := global_position
	global_position = global_position.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
	var v := (global_position - prev) / maxf(delta, 0.001)
	_animate(delta, v)
	z_index = int(global_position.y + 18)

func _animate(delta: float, v: Vector2) -> void:
	if sprite == null or sprite.texture == null:
		return
	if v.length() > 6.0:
		if absf(v.x) > absf(v.y):
			_facing = 2 if v.x > 0.0 else 1
		else:
			_facing = 0 if v.y > 0.0 else 3
		_step_timer += delta
		if _step_timer > 0.13:   # 与本地玩家(player.gd)步频一致,走路观感更自然
			_step_timer = 0.0
			_step = (_step + 1) % 3
	else:
		_step = 1
	var index := _facing * 3 + _step
	if _frame_rects.size() > index:
		sprite.frame = 0
		sprite.region_rect = _frame_rects[index]
	else:
		sprite.frame = index
