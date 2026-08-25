extends Node2D
class_name FarmerVendor

@export var watering_animation: StringName = &"eat"
@export var interaction_hint: String = "E 农场小铺"

var _anim: AnimatedSprite2D
var _hint_label: Label
var _feet_offset := 0.0

func _ready() -> void:
	_anim = get_node_or_null("Anim") as AnimatedSprite2D
	if _anim != null:
		_anim.play(watering_animation)
		var tex := _anim.sprite_frames.get_frame_texture(watering_animation, 0)
		if tex != null:
			_feet_offset = tex.get_height() * _anim.scale.y * 0.5
	_build_hint()
	_update_depth()

func _process(_delta: float) -> void:
	if _anim != null and _anim.animation != watering_animation:
		_anim.play(watering_animation)
	_update_depth()

func set_hint_visible(value: bool) -> void:
	if _hint_label != null:
		_hint_label.visible = value

func _update_depth() -> void:
	z_index = int(global_position.y + _feet_offset)

func _build_hint() -> void:
	_hint_label = Label.new()
	_hint_label.text = interaction_hint
	_hint_label.position = Vector2(-36, -86)
	_hint_label.size = Vector2(92, 22)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.24, 0.19, 0.12, 0.92))
	_hint_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.95, 0.80, 0.9))
	_hint_label.add_theme_constant_override("shadow_offset_x", 1)
	_hint_label.add_theme_constant_override("shadow_offset_y", 1)
	_hint_label.visible = false
	add_child(_hint_label)
