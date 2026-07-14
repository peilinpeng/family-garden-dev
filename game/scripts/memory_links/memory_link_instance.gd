class_name MemoryLinkInstance
extends Node2D

signal link_clicked(link_id: String)

const PATH_HELPER := preload("res://scripts/memory_links/memory_link_path.gd")
const BUTTERFLY_SHEET := preload("res://assets/memory_links/link_butterfly_day.png")
const NIGHT_BEE_SHEET := preload("res://assets/memory_links/link_bee_night.png")
const CARRIER_FRAME_COUNT := 8
const CARRIER_FRAME_SIZE := Vector2(443, 443)

class LinkCarrier:
	extends Node2D
	var style: String = "butterfly"
	var phase_offset: float = 0.0
	var alpha: float = 1.0
	var facing: float = 1.0
	var scale_factor: float = 1.0
	var _sprite: Sprite2D = null
	var _butterfly_frames: Array[Texture2D] = []
	var _night_bee_frames: Array[Texture2D] = []

	func configure_sheets(butterfly_sheet: Texture2D, night_bee_sheet: Texture2D) -> void:
		_butterfly_frames = _make_frames(butterfly_sheet)
		_night_bee_frames = _make_frames(night_bee_sheet)
		_sprite = Sprite2D.new()
		_sprite.name = "CarrierSprite"
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.centered = true
		add_child(_sprite)
		set_process(true)

	func _process(_delta: float) -> void:
		if _sprite == null:
			return
		var frame_index: int = int(Time.get_ticks_msec() / 115) % CARRIER_FRAME_COUNT
		if style == "night_bee":
			_sprite.texture = _night_bee_frames[frame_index] if not _night_bee_frames.is_empty() else null
		else:
			_sprite.texture = _butterfly_frames[frame_index] if not _butterfly_frames.is_empty() else null

	func _make_frames(sheet: Texture2D) -> Array[Texture2D]:
		var frames: Array[Texture2D] = []
		if sheet == null:
			return frames
		for frame_index in range(CARRIER_FRAME_COUNT):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(Vector2(float(frame_index) * CARRIER_FRAME_SIZE.x, 0.0), CARRIER_FRAME_SIZE)
			frames.append(frame)
		return frames

	func _draw() -> void:
		if _sprite != null and (_butterfly_frames.size() == CARRIER_FRAME_COUNT or _night_bee_frames.size() == CARRIER_FRAME_COUNT):
			return
		var t: float = Time.get_ticks_msec() / 1000.0 + phase_offset
		if style == "night_bee" or style == "firefly":
			var flicker: float = 0.72 + 0.28 * sin(t * 3.1)
			draw_circle(Vector2.ZERO, 18.0 * scale_factor, Color(0.88, 1.0, 0.46, 0.10 * alpha * flicker))
			draw_circle(Vector2.ZERO, 11.0 * scale_factor, Color(0.96, 1.0, 0.54, 0.22 * alpha * flicker))
			draw_circle(Vector2.ZERO, 6.0 * scale_factor, Color(1.0, 0.98, 0.62, 0.38 * alpha * flicker))
			draw_rect(Rect2(Vector2(-3, -3) * scale_factor, Vector2(6, 6) * scale_factor), Color(0.96, 1.0, 0.58, 0.92 * alpha))
			draw_rect(Rect2(Vector2(-1, -1) * scale_factor, Vector2(2, 2) * scale_factor), Color(1.0, 1.0, 0.88, 1.0 * alpha))
			return

		if style == "bee":
			var body_color := Color(0.95, 0.72, 0.22, 0.94 * alpha)
			var stripe_color := Color(0.22, 0.17, 0.12, 0.88 * alpha)
			var wing_color := Color(0.88, 0.96, 1.0, 0.42 * alpha)
			draw_rect(Rect2(Vector2(-5, -3) * scale_factor, Vector2(10, 6) * scale_factor), body_color)
			draw_rect(Rect2(Vector2(-2, -3) * scale_factor, Vector2(2, 6) * scale_factor), stripe_color)
			draw_rect(Rect2(Vector2(3, -3) * scale_factor, Vector2(2, 6) * scale_factor), stripe_color)
			draw_rect(Rect2(Vector2(-3, -7) * scale_factor, Vector2(5, 4) * scale_factor), wing_color)
			draw_rect(Rect2(Vector2(-1, 3) * scale_factor, Vector2(5, 4) * scale_factor), wing_color)
			return

		var flap: float = 2.0 + 2.0 * sin(t * 9.0)
		var wing_a := Color(0.96, 0.62, 0.70, 0.82 * alpha)
		var wing_b := Color(0.98, 0.82, 0.45, 0.78 * alpha)
		var body := Color(0.28, 0.22, 0.16, 0.86 * alpha)
		draw_rect(Rect2(Vector2(-2, -5 - flap) * scale_factor, Vector2(4, 10 + flap) * scale_factor), body)
		draw_rect(Rect2(Vector2(-9, -6 - flap) * scale_factor, Vector2(7, 6 + flap) * scale_factor), wing_a)
		draw_rect(Rect2(Vector2(2, -6 - flap) * scale_factor, Vector2(7, 6 + flap) * scale_factor), wing_b)
		draw_rect(Rect2(Vector2(-8, 1) * scale_factor, Vector2(6, 5 + flap * 0.5) * scale_factor), wing_b)
		draw_rect(Rect2(Vector2(2, 1) * scale_factor, Vector2(6, 5 + flap * 0.5) * scale_factor), wing_a)

	func update_visual(next_style: String, next_alpha: float, next_facing: float, next_scale: float) -> void:
		style = next_style
		alpha = next_alpha
		facing = next_facing
		scale_factor = next_scale
		scale.x = absf(scale.x) * facing
		if _sprite != null:
			_sprite.visible = style != "dotted_line"
			_sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
			var frame_display_height: float = 64.0 if style == "night_bee" else 58.0
			_sprite.scale = Vector2.ONE * (frame_display_height / CARRIER_FRAME_SIZE.y) * scale_factor
		queue_redraw()

var link_data: Dictionary = {}
var source_memory_id: String = ""
var target_memory_id: String = ""
var source_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var relation_strength: float = 0.55
var active_time_mode: String = "both"
var visual_style: String = "butterfly"
var visible_when: String = "always"
var time_mode: String = "day"
var selected_memory_id: String = ""
var relation_mode_enabled: bool = false
var debug_enabled: bool = false
var highlighted: bool = false
var curve: Curve2D = null
var carrier_nodes: Array[LinkCarrier] = []
var carrier_progress: Array[float] = []
var carrier_direction: Array[float] = []
var carrier_speed: Array[float] = []
var carrier_phase: Array[float] = []

var _debug_label: Label = null
var _click_area: Area2D = null

func setup(data: Dictionary, source_pos: Vector2, target_pos: Vector2, config: Dictionary = {}) -> void:
	link_data = data.duplicate(true)
	source_memory_id = String(data.get("source_memory_id", data.get("memory_id", "")))
	target_memory_id = String(data.get("target_memory_id", data.get("linked_memory_id", "")))
	source_position = source_pos
	target_position = target_pos
	relation_strength = _parse_strength(data.get("relation_strength", data.get("strength", data.get("relation_type", "medium"))))
	active_time_mode = String(data.get("active_time_mode", "both")).to_lower()
	visual_style = String(data.get("visual_style", _style_from_config(config))).to_lower()
	visible_when = String(data.get("visible_when", "always")).to_lower()
	var raw_curve_points: Array = []
	var raw_points: Variant = data.get("curve_points", [])
	if raw_points is Array:
		raw_curve_points = raw_points
	curve = PATH_HELPER.build_curve(source_position, target_position, raw_curve_points)
	_build_click_area()
	_rebuild_carriers()
	_update_debug_label()
	_refresh_visibility()
	queue_redraw()

func set_time_mode(next_time_mode: String) -> void:
	time_mode = next_time_mode.to_lower()
	_refresh_visibility()

func set_selected_memory(memory_id: String) -> void:
	selected_memory_id = memory_id
	highlighted = selected_memory_id != "" and (selected_memory_id == source_memory_id or selected_memory_id == target_memory_id)
	_refresh_visibility()

func set_relation_mode(enabled: bool) -> void:
	relation_mode_enabled = enabled
	_refresh_visibility()

func set_debug_mode(enabled: bool) -> void:
	debug_enabled = enabled
	_update_debug_label()
	_refresh_visibility()

func _process(delta: float) -> void:
	if not visible:
		return
	var effective_style: String = _effective_style()
	var active: bool = _is_time_active()
	for i in range(carrier_nodes.size()):
		var carrier: LinkCarrier = carrier_nodes[i]
		carrier.visible = active and effective_style != "dotted_line"
		if not carrier.visible:
			continue
		var progress: float = carrier_progress[i] + carrier_direction[i] * carrier_speed[i] * delta
		if progress > 1.0:
			progress = 1.0
			carrier_direction[i] = -1.0
		elif progress < 0.0:
			progress = 0.0
			carrier_direction[i] = 1.0
		carrier_progress[i] = progress

		var point: Vector2 = PATH_HELPER.sample(curve, progress)
		var tangent: Vector2 = PATH_HELPER.tangent(curve, progress)
		var wobble: float = sin(Time.get_ticks_msec() / 650.0 + carrier_phase[i]) * (2.0 + relation_strength * 3.0)
		carrier.position = point + Vector2(0.0, wobble)
		carrier.rotation = clampf(tangent.angle(), -0.45, 0.45) * 0.35
		var alpha: float = _carrier_alpha()
		var facing: float = 1.0 if tangent.x >= 0.0 else -1.0
		var visual_scale: float = 0.72 + relation_strength * 0.22
		carrier.update_visual(effective_style, alpha, facing, visual_scale)
	queue_redraw()

func _draw() -> void:
	if curve == null:
		return
	var draw_path: bool = debug_enabled or highlighted or relation_mode_enabled or _effective_style() == "dotted_line"
	if not draw_path:
		return

	var alpha: float = 0.18
	var dot_size: float = 2.0
	if highlighted:
		alpha = 0.34
		dot_size = 3.0
	if relation_mode_enabled:
		alpha = maxf(alpha, 0.26)
	if debug_enabled:
		alpha = 0.70
		dot_size = 2.5

	var color: Color = Color(0.66, 0.78, 0.45, alpha)
	if time_mode == "night":
		color = Color(0.78, 0.92, 0.62, alpha)
	var length: float = curve.get_baked_length()
	var steps: int = maxi(8, int(length / 18.0))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		if i % 2 == 1 and not debug_enabled:
			continue
		var point: Vector2 = PATH_HELPER.sample(curve, t)
		draw_rect(Rect2(point - Vector2.ONE * dot_size * 0.5, Vector2.ONE * dot_size), color)

	if debug_enabled:
		var last_point: Vector2 = PATH_HELPER.sample(curve, 0.0)
		for i in range(1, steps + 1):
			var t: float = float(i) / float(steps)
			var point: Vector2 = PATH_HELPER.sample(curve, t)
			draw_line(last_point, point, Color(0.40, 0.62, 0.30, 0.55), 1.0)
			last_point = point

func _build_click_area() -> void:
	if _click_area != null and is_instance_valid(_click_area):
		_click_area.queue_free()
	_click_area = Area2D.new()
	_click_area.name = "MemoryLinkHitArea"
	_click_area.position = PATH_HELPER.sample(curve, 0.5)
	_click_area.input_pickable = true
	_click_area.monitoring = true
	_click_area.monitorable = true
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 28.0
	shape_node.shape = shape
	_click_area.add_child(shape_node)
	_click_area.input_event.connect(func(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			link_clicked.emit(String(link_data.get("id", ""))))
	add_child(_click_area)

func _rebuild_carriers() -> void:
	for carrier in carrier_nodes:
		if is_instance_valid(carrier):
			carrier.queue_free()
	carrier_nodes.clear()
	carrier_progress.clear()
	carrier_direction.clear()
	carrier_speed.clear()
	carrier_phase.clear()

	var count: int = _carrier_count()
	var base_speed: float = lerpf(0.035, 0.075, relation_strength)
	for i in range(count):
		var carrier := LinkCarrier.new()
		carrier.name = "Carrier_%d" % i
		carrier.phase_offset = float(i) * 0.73 + float(abs(hash(str(link_data.get("id", "")))) % 100) / 80.0
		carrier.configure_sheets(BUTTERFLY_SHEET, NIGHT_BEE_SHEET)
		add_child(carrier)
		carrier_nodes.append(carrier)
		carrier_progress.append(fposmod(float(i) / float(count) + float(abs(hash(source_memory_id + target_memory_id)) % 37) / 100.0, 1.0))
		carrier_direction.append(1.0 if i % 2 == 0 else -1.0)
		carrier_speed.append(base_speed * (0.86 + float(i) * 0.11))
		carrier_phase.append(float(i) * 1.9)

func _update_debug_label() -> void:
	if _debug_label != null and is_instance_valid(_debug_label):
		_debug_label.queue_free()
	_debug_label = null
	if not debug_enabled:
		return
	_debug_label = Label.new()
	_debug_label.name = "DebugLabel"
	_debug_label.text = "%s -> %s\n%s / %.2f" % [source_memory_id, target_memory_id, _effective_style(), relation_strength]
	_debug_label.position = PATH_HELPER.sample(curve, 0.5) + Vector2(10, -24)
	_debug_label.size = Vector2(260, 44)
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.add_theme_font_size_override("font_size", 11)
	_debug_label.add_theme_color_override("font_color", Color(0.20, 0.28, 0.18, 0.88))
	add_child(_debug_label)

func _refresh_visibility() -> void:
	var allowed_by_rule: bool = true
	match visible_when:
		"selected":
			allowed_by_rule = highlighted or debug_enabled
		"nearby":
			allowed_by_rule = highlighted or relation_mode_enabled or debug_enabled
		"relation_mode":
			allowed_by_rule = relation_mode_enabled or highlighted or debug_enabled
		_:
			allowed_by_rule = true
	visible = allowed_by_rule and (_is_time_active() or debug_enabled)
	if _debug_label != null and is_instance_valid(_debug_label):
		_debug_label.visible = debug_enabled
	queue_redraw()

func _is_time_active() -> bool:
	if active_time_mode == "both" or active_time_mode == "":
		return true
	if active_time_mode == "day":
		return time_mode != "night"
	if active_time_mode == "night":
		return time_mode == "night"
	return true

func _effective_style() -> String:
	if time_mode == "night":
		return "night_bee"
	if visual_style == "dotted_line":
		return "dotted_line"
	return "butterfly"

func _carrier_count() -> int:
	if relation_strength >= 0.78:
		return 3
	if relation_strength >= 0.48:
		return 2
	return 1

func _carrier_alpha() -> float:
	if time_mode == "night":
		if debug_enabled:
			return 1.0
		if highlighted:
			return 1.0
		if relation_mode_enabled:
			return 0.90
		return 0.72
	if debug_enabled:
		return 1.0
	if highlighted:
		return 0.95
	if relation_mode_enabled:
		return 0.78
	return 0.42

func _parse_strength(value: Variant) -> float:
	if value is float or value is int:
		return clampf(float(value), 0.0, 1.0)
	var text: String = String(value).to_lower()
	match text:
		"weak", "low":
			return 0.28
		"strong", "high":
			return 0.92
		"medium", "mid":
			return 0.58
		_:
			if text.find("same") >= 0 or text.find("family") >= 0:
				return 0.62
			return 0.50

func _style_from_config(config: Dictionary) -> String:
	var day_styles: Variant = config.get("day_styles", [])
	if day_styles is Array and (day_styles as Array).size() > 0:
		var styles_size: int = (day_styles as Array).size()
		var style_index: int = int(abs(hash(str(link_data.get("id", "")))) % styles_size)
		return String((day_styles as Array)[style_index])
	return "butterfly"
