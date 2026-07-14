class_name MemoryLinkVisualizer
extends Node2D

signal link_clicked(link_id: String, link_data: Dictionary)

const LINK_INSTANCE_SCRIPT := preload("res://scripts/memory_links/memory_link_instance.gd")
const CONFIG_PATH := "res://assets/memory_links/memory_link_config.json"

var memory_nodes: Dictionary = {}
var memory_positions: Dictionary = {}
var link_rows: Array[Dictionary] = []
var instances: Array[MemoryLinkInstance] = []
var time_mode: String = "day"
var selected_memory_id: String = ""
var relation_mode_enabled: bool = false
var debug_enabled: bool = false
var config: Dictionary = {}

var _link_root: Node2D = null
var _particle_root: Node2D = null
var _debug_root: Node2D = null
var _clock_poll_seconds: float = 0.0

func _ready() -> void:
	name = "MemoryLinkRoot"
	z_as_relative = false
	z_index = 3600
	_ensure_roots()
	config = _load_config()
	_attach_clock()
	set_process(true)
	set_process_unhandled_input(true)

func setup(node_map: Dictionary, links: Array, next_config: Dictionary = {}) -> void:
	_ensure_roots()
	memory_nodes.clear()
	memory_positions.clear()
	for key in node_map.keys():
		var memory_id: String = String(key)
		var raw_node: Variant = node_map[key]
		if raw_node is Node2D:
			var node: Node2D = raw_node
			memory_nodes[memory_id] = node
			memory_positions[memory_id] = _anchor_for_node(node)
		elif raw_node is Vector2:
			memory_positions[memory_id] = raw_node

	link_rows.clear()
	for raw_link in links:
		if raw_link is Dictionary:
			link_rows.append(_normalize_link(raw_link))

	if not next_config.is_empty():
		for key in next_config.keys():
			config[key] = next_config[key]
	rebuild()

func register_memory_node(memory_id: String, node: Node2D) -> void:
	if memory_id == "" or node == null:
		return
	memory_nodes[memory_id] = node
	memory_positions[memory_id] = _anchor_for_node(node)

func set_links(links: Array) -> void:
	link_rows.clear()
	for raw_link in links:
		if raw_link is Dictionary:
			link_rows.append(_normalize_link(raw_link))
	rebuild()

func rebuild() -> void:
	_ensure_roots()
	for instance in instances:
		if is_instance_valid(instance):
			instance.queue_free()
	instances.clear()

	for link in link_rows:
		var source_id: String = String(link.get("source_memory_id", ""))
		var target_id: String = String(link.get("target_memory_id", ""))
		if source_id == "" or target_id == "":
			continue
		if not memory_positions.has(source_id) or not memory_positions.has(target_id):
			continue
		var source_pos: Vector2 = memory_positions[source_id]
		var target_pos: Vector2 = memory_positions[target_id]
		var instance := LINK_INSTANCE_SCRIPT.new() as MemoryLinkInstance
		instance.name = "Link_%s_%s" % [source_id, target_id]
		instance.setup(link, source_pos, target_pos, config)
		instance.set_time_mode(time_mode)
		instance.set_selected_memory(selected_memory_id)
		instance.set_relation_mode(relation_mode_enabled)
		instance.set_debug_mode(debug_enabled)
		instance.link_clicked.connect(_on_instance_clicked.bind(link))
		_link_root.add_child(instance)
		instances.append(instance)
	_update_memory_highlights()

func set_time_mode(next_time_mode: String) -> void:
	var normalized: String = _normalize_time_mode(next_time_mode)
	if normalized == time_mode:
		return
	time_mode = normalized
	for instance in instances:
		if is_instance_valid(instance):
			instance.set_time_mode(time_mode)

func set_selected_memory(memory_id: String) -> void:
	selected_memory_id = memory_id
	for instance in instances:
		if is_instance_valid(instance):
			instance.set_selected_memory(selected_memory_id)
	_update_memory_highlights()

func set_relation_mode(enabled: bool) -> void:
	relation_mode_enabled = enabled
	for instance in instances:
		if is_instance_valid(instance):
			instance.set_relation_mode(relation_mode_enabled)

func set_debug_mode(enabled: bool) -> void:
	debug_enabled = enabled
	for instance in instances:
		if is_instance_valid(instance):
			instance.set_debug_mode(debug_enabled)

func _process(delta: float) -> void:
	_clock_poll_seconds += delta
	if _clock_poll_seconds < 0.75:
		return
	_clock_poll_seconds = 0.0
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock != null and clock.has_method("phase"):
		set_time_mode(String(clock.call("phase")))
	for memory_id in memory_nodes.keys():
		var raw_node: Variant = memory_nodes[memory_id]
		if raw_node is Node2D and is_instance_valid(raw_node):
			memory_positions[String(memory_id)] = _anchor_for_node(raw_node)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			set_debug_mode(not debug_enabled)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F9:
			set_relation_mode(not relation_mode_enabled)
			get_viewport().set_input_as_handled()

func _ensure_roots() -> void:
	if _link_root == null or not is_instance_valid(_link_root):
		_link_root = Node2D.new()
		_link_root.name = "LinkInstances"
		add_child(_link_root)
	if _particle_root == null or not is_instance_valid(_particle_root):
		_particle_root = Node2D.new()
		_particle_root.name = "LinkParticles"
		add_child(_particle_root)
	if _debug_root == null or not is_instance_valid(_debug_root):
		_debug_root = Node2D.new()
		_debug_root.name = "DebugLayer"
		add_child(_debug_root)

func _attach_clock() -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock == null:
		return
	if clock.has_method("phase"):
		set_time_mode(String(clock.call("phase")))
	var callback := Callable(self, "set_time_mode")
	if clock.has_signal("phase_changed") and not clock.is_connected("phase_changed", callback):
		clock.connect("phase_changed", callback)

func _normalize_link(raw_link: Dictionary) -> Dictionary:
	var link: Dictionary = raw_link.duplicate(true)
	if not link.has("source_memory_id"):
		link["source_memory_id"] = String(link.get("memory_id", ""))
	if not link.has("target_memory_id"):
		link["target_memory_id"] = String(link.get("linked_memory_id", ""))
	if not link.has("relation_strength"):
		link["relation_strength"] = _strength_from_relation(String(link.get("relation_type", "medium")))
	if not link.has("active_time_mode"):
		link["active_time_mode"] = "both"
	if not link.has("visual_style"):
		link["visual_style"] = _default_day_style(String(link.get("id", "")))
	if not link.has("visible_when"):
		link["visible_when"] = "always"
	return link

func _strength_from_relation(relation_type: String) -> float:
	var text: String = relation_type.to_lower()
	if text.find("strong") >= 0 or text.find("family") >= 0:
		return 0.86
	if text.find("weak") >= 0:
		return 0.30
	return 0.58

func _default_day_style(seed_text: String) -> String:
	var raw_styles: Variant = config.get("day_styles", ["butterfly"])
	var styles: Array = []
	if raw_styles is Array:
		for raw_style in raw_styles:
			styles.append(String(raw_style))
	else:
		styles.append("butterfly")
	if styles.is_empty():
		return "butterfly"
	return String(styles[int(abs(hash(seed_text))) % styles.size()])

func _normalize_time_mode(value: String) -> String:
	var text: String = value.to_lower()
	if text == "night":
		return "night"
	return "day"

func _anchor_for_node(node: Node2D) -> Vector2:
	var scale_y: float = maxf(absf(node.scale.y), 0.55)
	return node.global_position + Vector2(0.0, -72.0 * scale_y)

func _update_memory_highlights() -> void:
	for key in memory_nodes.keys():
		var memory_id: String = String(key)
		var raw_node: Variant = memory_nodes[key]
		if not (raw_node is Node2D):
			continue
		var node: Node2D = raw_node
		if not is_instance_valid(node):
			continue
		if not node.has_meta("memory_link_base_modulate"):
			node.set_meta("memory_link_base_modulate", node.modulate)
		var base: Color = node.get_meta("memory_link_base_modulate") as Color
		var related: bool = _is_memory_related_to_selection(memory_id)
		if selected_memory_id != "" and related:
			node.modulate = base.lerp(Color(1.18, 1.10, 0.86, base.a), 0.55)
		else:
			node.modulate = base

func _is_memory_related_to_selection(memory_id: String) -> bool:
	if selected_memory_id == "":
		return false
	if memory_id == selected_memory_id:
		return true
	for link in link_rows:
		var source_id: String = String(link.get("source_memory_id", ""))
		var target_id: String = String(link.get("target_memory_id", ""))
		if (source_id == selected_memory_id and target_id == memory_id) or (target_id == selected_memory_id and source_id == memory_id):
			return true
	return false

func _on_instance_clicked(link_id: String, link: Dictionary) -> void:
	link_clicked.emit(link_id, link)

func _load_config() -> Dictionary:
	var fallback: Dictionary = {
		"day_styles": ["butterfly"],
		"night_style": "night_bee"
	}
	if not FileAccess.file_exists(CONFIG_PATH):
		return fallback
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return fallback
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var data: Dictionary = parsed
		for key in fallback.keys():
			if not data.has(key):
				data[key] = fallback[key]
		return data
	return fallback
