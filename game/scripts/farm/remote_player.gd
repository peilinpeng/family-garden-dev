extends Node2D

## 远端家庭成员的可视化。联机时由 presence 用 set_target() 喂位置(见 docs/43);
## 现在没有联机 → 开 placeholder_wander 当占位成员在花园里溜达。
## 复用 CharacterDB,同一套角色配置;z = 脚底 Y,与场景正确遮挡。

@export var role_key := "father"
@export var display_name := ""
@export var placeholder_wander := false
@export var wander_area := Rect2()

var sprite: Sprite2D
var label: Label
var target: Vector2
var _step_timer := 0.0
var _step := 1
var _facing := 0
var _wander_timer := 0.0

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
		sprite.hframes = int(def.get("hframes", 3))
		sprite.vframes = int(def.get("vframes", 4))
		sprite.scale = Vector2.ONE * float(def.get("scale", 0.46))
		if display_name == "":
			display_name = str(def.get("name", role_key))
	label = Label.new()
	label.text = display_name
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(90, 16)
	label.position = Vector2(-45, -58)
	add_child(label)

## 联机:由 presence 喂入目标位置。
func set_target(pos: Vector2) -> void:
	target = pos

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
		if _step_timer > 0.16:
			_step_timer = 0.0
			_step = (_step + 1) % 3
	else:
		_step = 1
	sprite.frame = _facing * sprite.hframes + _step
