extends Area2D

signal item_deleted(item_id: String)
signal item_moved(item_id: String, new_position: Vector2)

var item_id := ""
var item_type := "flower"
var dragging := false
var drag_offset := Vector2.ZERO
var sprite: Sprite2D
var display_scale := 0.0
var bottom_anchored := false

func setup(data: Dictionary, texture: Texture2D = null) -> void:
	item_id = str(data.get("id", "item_" + str(Time.get_ticks_msec())))
	item_type = str(data.get("type", "flower"))
	position = data.get("position", Vector2.ZERO)
	display_scale = float(data.get("display_scale", 0.0))
	bottom_anchored = bool(data.get("bottom_anchored", false))
	input_pickable = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 28.0
	shape.shape = circle
	add_child(shape)

	if texture != null:
		sprite = Sprite2D.new()
		add_child(sprite)
		set_texture(texture, display_scale, bottom_anchored)

func set_texture(texture: Texture2D, requested_scale: float = 0.0, anchor_to_bottom: bool = false) -> void:
	if sprite == null:
		return
	sprite.texture = texture
	sprite.centered = true
	var scale_factor := requested_scale
	if scale_factor <= 0.0:
		var max_side = max(float(texture.get_width()), float(texture.get_height()))
		var target_size := 56.0
		scale_factor = target_size / max_side if max_side > 0.0 else 1.0
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = Vector2(0.0, -float(texture.get_height()) * scale_factor * 0.5) if anchor_to_bottom else Vector2.ZERO

func _ready() -> void:
	input_event.connect(_on_input_event)
	set_process(true)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = true
			drag_offset = global_position - get_global_mouse_position()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			item_deleted.emit(item_id)
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = false
		item_moved.emit(item_id, position)

func _process(_delta: float) -> void:
	if dragging:
		global_position = get_global_mouse_position() + drag_offset
		item_moved.emit(item_id, position)

func _draw() -> void:
	if sprite != null:
		return

	if item_type == "tree":
		draw_circle(Vector2(0, -12), 24, Color(0.58, 0.75, 0.47, 1.0))
		draw_rect(Rect2(Vector2(-5, -2), Vector2(10, 28)), Color(0.55, 0.35, 0.20, 1.0))
	elif item_type == "mushroom":
		draw_rect(Rect2(Vector2(-6, -4), Vector2(12, 22)), Color(0.95, 0.86, 0.68, 1.0))
		draw_circle(Vector2(0, -8), 18, Color(0.78, 0.34, 0.28, 1.0))
		draw_circle(Vector2(-6, -10), 3, Color(1.0, 0.93, 0.75, 1.0))
		draw_circle(Vector2(6, -8), 3, Color(1.0, 0.93, 0.75, 1.0))
	elif item_type == "sign":
		draw_rect(Rect2(Vector2(-3, 0), Vector2(6, 25)), Color(0.65, 0.43, 0.25, 1.0))
		draw_rect(Rect2(Vector2(-20, -14), Vector2(40, 24)), Color(0.94, 0.78, 0.48, 1.0))
	elif item_type == "pond":
		draw_circle(Vector2.ZERO, 26, Color(0.42, 0.78, 0.88, 0.9))
		draw_circle(Vector2(10, -4), 18, Color(0.64, 0.88, 0.94, 0.55))
	else:
		# Simple flower placeholder.
		draw_rect(Rect2(Vector2(-2, -2), Vector2(4, 24)), Color(0.42, 0.62, 0.32, 1.0))
		draw_circle(Vector2(0, -8), 5, Color(0.95, 0.70, 0.78, 1.0))
		draw_circle(Vector2(-6, -4), 5, Color(0.95, 0.70, 0.78, 1.0))
		draw_circle(Vector2(6, -4), 5, Color(0.95, 0.70, 0.78, 1.0))
		draw_circle(Vector2(0, 0), 5, Color(0.95, 0.70, 0.78, 1.0))
		draw_circle(Vector2(0, -4), 3, Color(0.95, 0.83, 0.34, 1.0))
