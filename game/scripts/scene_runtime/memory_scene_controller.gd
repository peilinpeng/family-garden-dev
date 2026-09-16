extends "res://scripts/scene_runtime/scene_runtime_module.gd"

## 记忆节点、关系连线、档案与记忆卡。
## 仅由 SceneManager 创建；外部代码继续调用 SceneManager 兼容门面。

func _demo_other_members() -> Array:
	var others: Array = []
	for role_data in CHARACTER_DATA:
		var rk = String(role_data.get("role", ""))
		if rk != "" and rk != MemoryManager.selected_role_key:
			others.append(rk)
	return others

func _spawn_demo_memory_nodes() -> void:
	_demo_memories.clear()
	SlotManager.load_scene("garden")
	# 兼容空存档：首次进入花园时写入 3 条演示种子记忆；之后统一从数据层渲染。
	if MemoryManager.get_nodes_for_scene("garden").is_empty():
		# 种子记忆归属给其他家庭成员（≠当前玩家），这样玩家回答它们才算"跨成员互动"，分季背景才会随之升温。
		var uploaders = _demo_other_members()
		for i in range(3):
			var slot: Variant = SlotManager.allocate("garden", "memory_flower", "garden_seed_%d" % i)
			if slot == null:
				break
			var mem = MemoryManager.create_memory(AIClient.mock_memory_card(), "photo")
			if not uploaders.is_empty():
				mem["user_id"] = uploaders[i % uploaders.size()]  # 改上传者为别的成员
			MemoryManager.create_node(String(mem.get("id", "")), "garden", "memory_flower", String(slot.get("slot_id", "")))
		MemoryManager.save_game()  # 落盘改过的 user_id
	# 统一从数据层渲染（首次/再次进入一致）。
	_render_scene_nodes("garden", _demo_memories, _on_memory_clicked)
	_spawn_demo_memory_link()       # 空存档演示种子没有真实关联时补一条藤蔓
	_render_memory_links("garden")  # 默认保持安静，选中记忆后只画与它相关的藤蔓
	if _pending_memory_arrival_id != "":
		_play_memory_archive_arrival(_pending_memory_arrival_id)
		_pending_memory_arrival_id = ""
	print("[SceneManager] garden 记忆归档=", _demo_memories.size(), " 可见景观=", _garden_archive_count(), " 连线=", MemoryManager.get_memory_links("garden").size())

# 兼容演示种子：没有任何关联时补一条演示藤蔓；真实新记忆的关联由 AIWorkflowManager 增量创建。

func _spawn_demo_memory_link() -> void:
	if not MemoryManager.get_memory_links("garden").is_empty():
		return
	if _demo_memories.size() < 2:
		return
	var a = String(_demo_memories[0].get("memory_id", ""))
	var b = String(_demo_memories[-1].get("memory_id", ""))  # 连最分散的一对，连线更清晰
	if a == "" or b == "" or a == b:
		return
	var link: Dictionary = AIClient.mock_link()  # 仅用于空存档演示种子；真实 link 已由 Gate 4 工作流生成。
	MemoryManager.create_memory_link(a, b, "garden",
		String(link.get("relation_type", "same_place")), String(link.get("question", "")))

# 花园默认不铺开关系网；选中一段记忆后，只显示与它直接相关的藤蔓。

func _render_memory_links(scene: String) -> void:
	if scene == "garden" and _focused_memory_id == "":
		return
	for link in MemoryManager.get_memory_links(scene):
		if scene == "garden" and _focused_memory_id not in [
			String(link.get("memory_id", "")),
			String(link.get("linked_memory_id", "")),
		]:
			continue
		var a = _memory_flower_pos(scene, String(link.get("memory_id", "")))
		var b = _memory_flower_pos(scene, String(link.get("linked_memory_id", "")))
		if a == Vector2.INF or b == Vector2.INF:
			continue
		if scene == "garden" and a.distance_to(b) < 8.0:
			a += Vector2(-34, 0)
			b += Vector2(34, 0)
		_draw_link_line(a, b, link)

# 家庭画像进入左上状态卡，以实际角色组成迷你合影；右下木牌只保留留言板用途。

func _render_family_portrait() -> void:
	if world != null and is_instance_valid(world):
		var legacy_board = world.get_node_or_null("FamilyPortraitBoard")
		if legacy_board != null:
			legacy_board.queue_free()
	# 家庭成员入口已统一到 GameHUD 左上状态卡，指引面板不再重复渲染。

func _add_family_portrait_miniature(parent: Control) -> void:
	var fp: Dictionary = MemoryManager.family_portrait
	var members: Array = fp.get("members", []).duplicate()
	if members.is_empty() and MemoryManager.selected_role_key != "":
		members.append(MemoryManager.selected_role_key)
	var frame = Panel.new()
	frame.name = "FamilyPortraitMiniature"
	frame.position = Vector2(178, 14)
	frame.size = Vector2(132, 80)
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.tooltip_text = "查看家庭成员 · %d 位家人共同留下 %d 段记忆" % [
		members.size(),
		int(fp.get("memory_count", MemoryManager.memories.size())),
	]
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.89, 0.91, 0.71, 0.98)
	frame_style.border_color = Color(0.43, 0.31, 0.19, 0.92)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(4)
	frame_style.shadow_color = Color(0.18, 0.12, 0.07, 0.24)
	frame_style.shadow_size = 2
	frame_style.shadow_offset = Vector2(0, 2)
	frame.add_theme_stylebox_override("panel", frame_style)
	parent.add_child(frame)

	var sky = ColorRect.new()
	sky.position = Vector2(4, 4)
	sky.size = Vector2(124, 50)
	sky.color = Color(0.80, 0.89, 0.72, 0.92)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(sky)
	var ground = ColorRect.new()
	ground.position = Vector2(4, 54)
	ground.size = Vector2(124, 22)
	ground.color = Color(0.59, 0.72, 0.40, 0.90)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(ground)

	var caption_back = ColorRect.new()
	caption_back.position = Vector2(4, 4)
	caption_back.size = Vector2(124, 16)
	caption_back.color = Color(0.96, 0.92, 0.77, 0.88)
	caption_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(caption_back)
	var caption = Label.new()
	caption.text = "家人合影 · %d" % members.size()
	caption.position = Vector2(10, 3)
	caption.size = Vector2(112, 17)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 9)
	caption.add_theme_color_override("font_color", Color(0.32, 0.26, 0.16, 0.86))
	frame.add_child(caption)
	for pin_x in [9.0, 119.0]:
		var pin = ColorRect.new()
		pin.position = Vector2(pin_x, 8)
		pin.size = Vector2(4, 4)
		pin.color = Color(0.84, 0.50, 0.22, 0.96)
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(pin)

	var shown_count = mini(members.size(), 4)
	for index in range(shown_count):
		var texture = _family_portrait_frame_texture(String(members[index]))
		if texture == null:
			continue
		var avatar = Sprite2D.new()
		avatar.name = "FamilyAvatar_%d" % index
		avatar.texture = texture
		avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var x = 66.0 if shown_count == 1 else lerpf(24.0, 108.0, float(index) / float(shown_count - 1))
		avatar.position = Vector2(x, 54)
		avatar.scale = Vector2.ONE * (40.0 / float(texture.get_height()))
		frame.add_child(avatar)
	if shown_count == 0:
		var empty = Label.new()
		empty.text = "等待家人加入"
		empty.position = Vector2(8, 35)
		empty.size = Vector2(116, 20)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", Color(0.34, 0.28, 0.21, 0.78))
		frame.add_child(empty)
	frame.mouse_entered.connect(func() -> void: frame.modulate = Color(1.05, 1.03, 0.96, 1.0))
	frame.mouse_exited.connect(func() -> void: frame.modulate = Color.WHITE)
	frame.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_host._open_family_members_panel()
	)

func _family_portrait_frame_texture(role_key: String) -> Texture2D:
	var source = CharacterDB.texture(role_key)
	var definition: Dictionary = CharacterDB.get_def(role_key)
	if source == null or definition.is_empty():
		return null
	var atlas = AtlasTexture.new()
	atlas.atlas = source
	var rects: Array = definition.get("frame_rects", [])
	if rects.size() > 1 and rects[1] is Array and (rects[1] as Array).size() >= 4:
		var frame: Array = rects[1]
		atlas.region = Rect2(float(frame[0]), float(frame[1]), float(frame[2]), float(frame[3]))
		return atlas
	var hframes = maxi(1, int(definition.get("hframes", 3)))
	var vframes = maxi(1, int(definition.get("vframes", 4)))
	var cell_size = Vector2(float(source.get_width()) / float(hframes), float(source.get_height()) / float(vframes))
	atlas.region = Rect2(cell_size.x, 0, cell_size.x, cell_size.y)
	return atlas

# 花园记忆指向所属归档景观；其他场景仍沿用持久化 slot 落点。

func _memory_flower_pos(scene: String, memory_id: String) -> Vector2:
	for nd in MemoryManager.get_nodes_for_scene(scene):
		if String(nd.get("memory_id", "")) != memory_id or String(nd.get("node_type", "")) == "memory_link":
			continue
		if scene == "garden":
			var archive_key = NodeFactory.garden_archive_key(String(nd.get("node_type", "memory_flower")))
			return _garden_archive_position(archive_key)
		if String(nd.get("node_type", "")) == "memory_flower":
			var slot = SlotManager.get_slot(scene, String(nd.get("slot_id", "")))
			if not slot.is_empty():
				var p: Variant = slot.get("pos", null)
				if p is Array and (p as Array).size() >= 2:
					return Vector2(float(p[0]), float(p[1]))
	return Vector2.INF

# 一条连线：两花之间拱起的藤蔓线（盖在记忆花之上，避免被花遮住）+ 中点可点的关联详情。

func _draw_link_line(a: Vector2, b: Vector2, link: Dictionary) -> void:
	var head = Vector2(0, -72)
	var arc = ((a + b) * 0.5 + head) + Vector2(0, -18)
	var relation_type = String(link.get("relation_type", "same_theme"))
	var link_color = _memory_link_color(relation_type)
	var link_label = _memory_link_label(relation_type)
	var confidence = float(link.get("confidence", 1.0))
	var answered = MemoryManager.is_memory_link_answered(link)
	var alpha = clampf(0.34 + confidence * 0.20 + (0.12 if answered else 0.0), 0.34, 0.72)

	var shadow = Line2D.new()
	shadow.name = "MemoryLinkShadow"
	shadow.points = PackedVector2Array([a + head + Vector2(0, 4), arc + Vector2(0, 4), b + head + Vector2(0, 4)])
	shadow.width = 5.0
	shadow.default_color = Color(0.12, 0.10, 0.08, 0.12)
	shadow.z_index = 340
	shadow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	shadow.end_cap_mode = Line2D.LINE_CAP_ROUND
	shadow.joint_mode = Line2D.LINE_JOINT_ROUND
	world.add_child(shadow)

	var line = Line2D.new()
	line.name = "MemoryLink"
	line.points = PackedVector2Array([a + head, arc, b + head])
	line.width = 3.5 if answered else 3.0
	line.default_color = Color(link_color.r, link_color.g, link_color.b, alpha)
	line.z_index = 341
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	world.add_child(line)

	var pulse = Line2D.new()
	pulse.name = "MemoryLinkPulse"
	pulse.points = PackedVector2Array([a + head, arc, b + head])
	pulse.width = 1.5 if answered else 1.0
	pulse.default_color = Color(1.0, 0.96, 0.78, 0.62 if answered else 0.36)
	pulse.z_index = 342
	pulse.begin_cap_mode = Line2D.LINE_CAP_ROUND
	pulse.end_cap_mode = Line2D.LINE_CAP_ROUND
	pulse.joint_mode = Line2D.LINE_JOINT_ROUND
	world.add_child(pulse)
	if OS.get_environment("FG_CAPTURE_SCREENSHOTS") != "1":
		var pulse_tween = create_tween()
		pulse_tween.set_loops()
		pulse_tween.tween_property(pulse, "modulate:a", 0.28 if answered else 0.18, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tween.tween_property(pulse, "modulate:a", 0.90 if answered else 0.58, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tween.tween_interval(LOOP_TWEEN_GUARD_INTERVAL)

	_add_memory_link_leaf((a + head).lerp(arc, 0.56), link_color, -0.42, answered)
	_add_memory_link_leaf(arc.lerp(b + head, 0.44), link_color, 0.42, answered)

	var mid = arc
	var area = Area2D.new()
	area.name = "MemoryLinkHotspot"
	area.position = mid
	area.z_index = 343
	area.input_pickable = true
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(104, 52)
	shape.shape = rect
	area.add_child(shape)

	var tag_panel = Panel.new()
	tag_panel.position = Vector2(-64, -54)
	tag_panel.size = Vector2(128, 34)
	tag_panel.visible = false
	tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_style = StyleBoxFlat.new()
	tag_style.bg_color = Color(0.92, 1.0, 0.84, 0.96) if answered else Color(1.0, 0.96, 0.82, 0.94)
	tag_style.border_color = Color(link_color.r, link_color.g, link_color.b, 0.95)
	tag_style.set_border_width_all(2)
	tag_style.set_corner_radius_all(5)
	tag_panel.add_theme_stylebox_override("panel", tag_style)
	area.add_child(tag_panel)

	var tag = Label.new()
	tag.text = link_label + (" · 已补写" if answered else " · 待补写")
	tag.position = Vector2(8, 7)
	tag.size = Vector2(112, 20)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(0.20, 0.17, 0.12, 0.96))
	tag_panel.add_child(tag)

	_add_memory_link_bloom(area, Vector2.ZERO, link_color)
	area.mouse_entered.connect(func() -> void: tag_panel.visible = true)
	area.mouse_exited.connect(func() -> void: tag_panel.visible = false)

	area.input_event.connect(func(_v: Node, e: InputEvent, _s: int) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_open_memory_link_panel(link))
	world.add_child(area)

func _add_memory_link_leaf(pos: Vector2, color: Color, rotation: float, answered: bool) -> void:
	var leaf = Polygon2D.new()
	leaf.name = "MemoryLinkLeaf"
	leaf.position = pos
	leaf.rotation = rotation
	leaf.z_index = 342
	leaf.polygon = PackedVector2Array([
		Vector2(0, -8),
		Vector2(12, -2),
		Vector2(0, 8),
		Vector2(-5, 0),
	])
	leaf.color = Color(color.r, color.g, color.b, 0.82 if answered else 0.56)
	world.add_child(leaf)

func _add_memory_link_bloom(parent: Node2D, pos: Vector2, color: Color) -> void:
	for i in range(5):
		var petal = Polygon2D.new()
		petal.name = "MemoryLinkBloomPetal"
		petal.position = pos
		petal.rotation = TAU * float(i) / 5.0
		petal.polygon = PackedVector2Array([
			Vector2(0, -10),
			Vector2(6, -2),
			Vector2(0, 4),
			Vector2(-6, -2),
		])
		petal.color = Color(1.0, 0.78, 0.58, 0.94)
		parent.add_child(petal)
	var center = Polygon2D.new()
	center.name = "MemoryLinkBloomCenter"
	center.position = pos
	center.polygon = PackedVector2Array([
		Vector2(0, -4),
		Vector2(4, 0),
		Vector2(0, 4),
		Vector2(-4, 0),
	])
	center.color = Color(color.r, color.g, color.b, 0.96)
	parent.add_child(center)

func _memory_link_color(relation_type: String) -> Color:
	match relation_type:
		"same_person":
			return Color(0.74, 0.38, 0.50, 1.0)
		"same_place":
			return Color(0.35, 0.55, 0.74, 1.0)
		"time_sequence":
			return Color(0.70, 0.55, 0.28, 1.0)
		"cause_effect":
			return Color(0.58, 0.45, 0.76, 1.0)
		"contrast":
			return Color(0.72, 0.46, 0.34, 1.0)
		_:
			return Color(0.46, 0.66, 0.36, 1.0)

func _memory_link_label(relation_type: String) -> String:
	match relation_type:
		"same_person":
			return "同一家人"
		"same_place":
			return "同一地点"
		"time_sequence":
			return "时间线索"
		"cause_effect":
			return "前因后果"
		"contrast":
			return "对照记忆"
		_:
			return "相似主题"

func _open_memory_link_panel(link: Dictionary) -> void:
	var live_link = MemoryManager.get_memory_link_by_id(String(link.get("id", "")))
	if live_link.is_empty():
		live_link = link
	var endpoints = MemoryManager.get_memory_link_endpoints(live_link)
	if not bool(endpoints.get("ok", false)):
		_host._show_toast("这条关联的记忆已经不存在。")
		return
	_host._close_active_panel()
	var memory_a: Dictionary = endpoints.get("memory_a", {})
	var memory_b: Dictionary = endpoints.get("memory_b", {})
	var card_a: Dictionary = memory_a.get("ai_card", {})
	var card_b: Dictionary = memory_b.get("ai_card", {})
	var relation_type = String(live_link.get("relation_type", "same_theme"))
	var relation_label = _memory_link_label(relation_type)
	var meta: Dictionary = live_link.get("generation_meta", {})
	var answered = MemoryManager.is_memory_link_answered(live_link)

	var overlay = _host._create_modal_overlay()
	active_modal = overlay
	var panel = Panel.new()
	panel.position = Vector2(250, 46)
	panel.size = Vector2(780, 628)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)

	var title = Label.new()
	title.text = "记忆藤蔓"
	title.position = Vector2(34, 24)
	title.size = Vector2(712, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var relation = Label.new()
	relation.text = "%s · 可信度 %d%% · %s" % [
		relation_label,
		roundi(float(live_link.get("confidence", 1.0)) * 100.0),
		"家人已补写" if answered else "等待家人补写",
	]
	relation.position = Vector2(34, 64)
	relation.size = Vector2(712, 24)
	relation.add_theme_font_size_override("font_size", 14)
	relation.add_theme_color_override("font_color", Color(0.34, 0.29, 0.22, 0.88))
	panel.add_child(relation)

	_add_memory_link_summary_card(panel, Vector2(34, 106), Vector2(306, 144), "记忆 A", card_a)
	_add_memory_link_summary_card(panel, Vector2(440, 106), Vector2(306, 144), "记忆 B", card_b)

	var vine = ColorRect.new()
	vine.position = Vector2(350, 174)
	vine.size = Vector2(80, 4)
	vine.color = Color(_memory_link_color(relation_type).r, _memory_link_color(relation_type).g, _memory_link_color(relation_type).b, 0.68)
	vine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vine)

	var bud = Panel.new()
	bud.position = Vector2(378, 162)
	bud.size = Vector2(26, 26)
	bud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bud_style = StyleBoxFlat.new()
	bud_style.bg_color = Color(0.92, 1.0, 0.82, 0.96) if answered else Color(1.0, 0.92, 0.72, 0.96)
	bud_style.border_color = Color(_memory_link_color(relation_type).r, _memory_link_color(relation_type).g, _memory_link_color(relation_type).b, 0.95)
	bud_style.set_border_width_all(2)
	bud_style.set_corner_radius_all(13)
	bud.add_theme_stylebox_override("panel", bud_style)
	panel.add_child(bud)

	var open_a = Button.new()
	open_a.text = "打开记忆 A"
	open_a.position = Vector2(118, 262)
	open_a.size = Vector2(138, 34)
	open_a.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_button_style(open_a, false)
	open_a.pressed.connect(_open_memory_from_link.bind(String(memory_a.get("id", ""))))
	panel.add_child(open_a)

	var open_b = Button.new()
	open_b.text = "打开记忆 B"
	open_b.position = Vector2(524, 262)
	open_b.size = Vector2(138, 34)
	open_b.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_button_style(open_b, false)
	open_b.pressed.connect(_open_memory_from_link.bind(String(memory_b.get("id", ""))))
	panel.add_child(open_b)

	var question_box = Panel.new()
	question_box.position = Vector2(34, 312)
	question_box.size = Vector2(712, 78)
	question_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host._apply_small_card_style(question_box)
	panel.add_child(question_box)

	var question_title = Label.new()
	question_title.text = "这根藤想问"
	question_title.position = Vector2(16, 10)
	question_title.size = Vector2(680, 18)
	question_title.add_theme_font_size_override("font_size", 12)
	question_title.add_theme_color_override("font_color", Color(0.44, 0.36, 0.26, 0.86))
	question_box.add_child(question_title)

	var question = Label.new()
	question.text = String(live_link.get("question", ""))
	question.position = Vector2(16, 30)
	question.size = Vector2(680, 38)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.add_theme_font_size_override("font_size", 15)
	question.add_theme_color_override("font_color", Color(0.18, 0.28, 0.22, 1.0))
	question_box.add_child(question)

	var answer_title = Label.new()
	answer_title.text = "家人的补写" if answered else "补上这段关系"
	answer_title.position = Vector2(34, 404)
	answer_title.size = Vector2(712, 22)
	answer_title.add_theme_font_size_override("font_size", 14)
	answer_title.add_theme_color_override("font_color", Color(0.28, 0.35, 0.24, 0.94))
	panel.add_child(answer_title)

	var answer_input = TextEdit.new()
	answer_input.text = String(live_link.get("followup_answer", ""))
	answer_input.placeholder_text = "写下这两段记忆之间还没有说完的话..."
	answer_input.position = Vector2(34, 430)
	answer_input.size = Vector2(712, 84)
	answer_input.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(answer_input)

	var status = _host._make_status_label(
		panel,
		Vector2(34, 520),
		Vector2(712, 24),
		"已保存的补写可以继续编辑。" if answered else "保存后，这根藤会在场景里点亮。"
	)

	var trace = Label.new()
	trace.text = "AI 来源：%s · 模型：%s · Prompt：%s" % [
		String(meta.get("source", meta.get("provider", "unknown"))),
		String(meta.get("model", "unknown")),
		String(meta.get("prompt_version", "unknown")),
	]
	trace.position = Vector2(34, 546)
	trace.size = Vector2(712, 22)
	trace.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trace.add_theme_font_size_override("font_size", 12)
	trace.add_theme_color_override("font_color", Color(0.43, 0.36, 0.28, 0.78))
	panel.add_child(trace)

	var save = Button.new()
	save.text = "更新补写" if answered else "保存补写"
	save.position = Vector2(242, 580)
	save.size = Vector2(140, 38)
	save.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_button_style(save, false)
	save.pressed.connect(_save_memory_link_followup.bind(String(live_link.get("id", "")), answer_input, save, status))
	panel.add_child(save)

	var close = Button.new()
	close.text = "关闭"
	close.position = Vector2(400, 580)
	close.size = Vector2(140, 40)
	close.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_button_style(close, false)
	close.pressed.connect(_host._close_active_panel)
	panel.add_child(close)

func _add_memory_link_summary_card(parent: Control, pos: Vector2, card_size: Vector2, heading: String, card: Dictionary) -> void:
	var box = Panel.new()
	box.position = pos
	box.size = card_size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host._apply_small_card_style(box)
	parent.add_child(box)

	var label = Label.new()
	label.text = heading
	label.position = Vector2(16, 12)
	label.size = Vector2(card_size.x - 32, 20)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.45, 0.36, 0.25, 0.86))
	box.add_child(label)

	var title = Label.new()
	title.text = String(card.get("title", "记忆"))
	title.position = Vector2(16, 38)
	title.size = Vector2(card_size.x - 32, 28)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.23, 0.18, 0.13, 1.0))
	box.add_child(title)

	var desc = Label.new()
	desc.text = String(card.get("description", ""))
	desc.position = Vector2(16, 76)
	desc.size = Vector2(card_size.x - 32, 72)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.32, 0.27, 0.21, 0.92))
	box.add_child(desc)

func _open_memory_from_link(memory_id: String) -> void:
	var mem = _find_rendered_memory_by_memory_id(memory_id)
	if mem.is_empty():
		_host._show_toast("这段记忆不在当前场景里。")
		return
	if mode == "garden":
		_focused_memory_id = memory_id
		_refresh_memory_link_visuals("garden")
	_open_memory_card(mem)

func _find_rendered_memory_by_memory_id(memory_id: String) -> Dictionary:
	for mem in _demo_memories:
		if String(mem.get("memory_id", "")) == memory_id:
			return mem
	for mem in _fishpond_memories:
		if String(mem.get("memory_id", "")) == memory_id:
			return mem
	return {}

func _save_memory_link_followup(link_id: String, input: TextEdit, button: Button, status: Label) -> void:
	var text = input.text.strip_edges()
	if text == "":
		_host._set_status(status, "先写一点补充，再保存。", true)
		return
	_host._set_button_busy(button, "正在保存...")
	_host._set_status(status, "正在把这段补写长到藤蔓上...")
	var result = await AIWorkflowManager.save_memory_link_followup(link_id, text)
	if not bool(result.get("ok", false)):
		_host._set_button_ready(button)
		_host._set_status(status, _host._result_error_message(result, "保存失败，请重试。"), true)
		return
	_refresh_memory_link_visuals(mode)
	var updated = bool(result.get("updated", false))
	var link_message = "记忆藤蔓已更新。" if updated else "记忆藤蔓已点亮。"
	if bool(result.get("sync_pending", false)):
		link_message += " 已保存在本机，联网后会自动同步。"
	_host._show_toast(link_message)
	_open_memory_link_panel(result.get("link", {}))

func _refresh_memory_link_visuals(scene: String) -> void:
	if world == null or not is_instance_valid(world):
		return
	_clear_memory_link_nodes()
	_render_memory_links(scene)

func _clear_memory_focus() -> void:
	_focused_memory_id = ""
	if world != null and is_instance_valid(world):
		_clear_memory_link_nodes()

func _clear_memory_link_nodes() -> void:
	for child in world.get_children():
		var child_name = String(child.name)
		if child_name.begins_with("MemoryLink"):
			child.queue_free()

func _refresh_current_memory_scene(scene: String) -> void:
	if world == null or not is_instance_valid(world):
		return
	var cache = _demo_memories if scene == "garden" else _fishpond_memories
	for item in cache:
		if item is Dictionary:
			var live: Variant = item.get("node", null)
			if live != null and is_instance_valid(live):
				live.queue_free()
	cache.clear()
	for child in world.get_children():
		if child.is_in_group("world_memory_node"):
			child.queue_free()
	_clear_memory_link_nodes()
	SlotManager.reset(scene)
	if scene == "garden":
		_render_scene_nodes("garden", _demo_memories, _on_memory_clicked)
		_render_memory_links(scene)
	if scene == "garden":
		MemoryManager.maybe_recompute_family_portrait()
		_render_family_portrait()
	_host._show_gate4_scene_guide(scene)

# 从数据层渲染某场景已落库的节点：回填 slot 占用、按状态决定形态、装入交互缓存。
# cache 项：{ id(node_id), memory_id, card, state, answer, node }；click_cb 绑 node_id。

func _render_scene_nodes(scene: String, cache: Array, click_cb: Callable) -> void:
	if scene == "garden":
		_render_garden_archives(cache)
		return
	var groups: Dictionary = {}
	var scene_nodes: Array = MemoryManager.get_nodes_for_scene(scene)
	for raw_node in scene_nodes:
		if not (raw_node is Dictionary):
			continue
		var nd: Dictionary = raw_node
		if String(nd.get("node_type", "")) == "memory_link":
			continue  # 连线节点不是落点物，由 _render_memory_links 单独画
		var slot_id = String(nd.get("slot_id", ""))
		if slot_id == "":
			continue
		if not groups.has(slot_id):
			groups[slot_id] = []
		(groups[slot_id] as Array).append(nd)
	for slot_id in groups:
		var stack: Array = groups[slot_id]
		if stack.is_empty():
			continue
		var slot = SlotManager.get_slot(scene, slot_id)
		if slot.is_empty():
			continue
		var items: Array = []
		var visual_state = "new"
		for raw_node in stack:
			if not (raw_node is Dictionary):
				continue
			var stored_node: Dictionary = raw_node
			var memory_id = String(stored_node.get("memory_id", ""))
			var mem = MemoryManager.get_memory(memory_id)
			var state = String(stored_node.get("state", "new"))
			if state == "grown":
				visual_state = "grown"
			items.append({
				"id": String(stored_node.get("id", "")),
				"memory_id": memory_id,
				"card": mem.get("ai_card", {}),
				"state": state,
				"answer": MemoryManager.get_answer_for_memory(memory_id),
				"node": null,
			})
		if items.is_empty():
			continue
		var representative: Dictionary = items[-1]
		var node_id = String(representative.get("id", ""))
		SlotManager.occupy(scene, String(slot_id), node_id)
		var on_click = click_cb.bind(node_id) if items.size() == 1 else _open_memory_cluster.bind(items)
		var live = NodeFactory.make_memory_node(representative.get("card", {}), slot, on_click, visual_state)
		live.add_to_group("world_memory_node")
		_add_memory_tag(live, visual_state)
		if items.size() > 1:
			_add_memory_cluster_badge(live, items.size())
		var target_scale = Vector2.ONE if visual_state == "grown" else Vector2(0.78, 0.78)
		live.scale = target_scale
		world.add_child(live)
		_animate_scene_node_arrival(live, target_scale)
		for item in items:
			(item as Dictionary)["node"] = live
			cache.append(item)

func _render_garden_archives(cache: Array) -> void:
	MemoryManager.migrate_fishpond_memories_to_garden()
	var archives = {
		"flowers": [],
		"photos": [],
		"postcards": [],
	}
	for raw_node in MemoryManager.get_nodes_for_scene("garden"):
		if not (raw_node is Dictionary):
			continue
		var stored_node: Dictionary = raw_node
		if String(stored_node.get("node_type", "")) == "memory_link":
			continue
		var memory_id = String(stored_node.get("memory_id", ""))
		var memory = MemoryManager.get_memory(memory_id)
		if memory.is_empty():
			continue
		var archive_key = NodeFactory.garden_archive_key(String(stored_node.get("node_type", "memory_flower")))
		var item = {
			"id": String(stored_node.get("id", "")),
			"memory_id": memory_id,
			"card": memory.get("ai_card", {}),
			"state": String(stored_node.get("state", "new")),
			"answer": MemoryManager.get_answer_for_memory(memory_id),
			"owner_id": String(memory.get("user_id", "")),
			"created_at": String(memory.get("created_at", stored_node.get("created_at", ""))),
			"input_type": String(memory.get("input_type", "text")),
			"archive_key": archive_key,
			"node": null,
		}
		(archives[archive_key] as Array).append(item)

	for raw_key in GARDEN_ARCHIVE_ORDER:
		var archive_key = String(raw_key)
		var items: Array = archives.get(archive_key, [])
		# 记忆花圃是默认固定景观，即使尚无记忆也必须存在；另外两类档案仍按内容出现。
		if items.is_empty() and archive_key != "flowers":
			continue
		items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("created_at", "")) > String(b.get("created_at", "")))
		var visual_state = "grown" if archive_key == "flowers" else "new"
		for item in items:
			if String((item as Dictionary).get("state", "new")) == "grown":
				visual_state = "grown"
				break
		var slot = SlotManager.get_slot("garden", String(GARDEN_ARCHIVES[archive_key].get("slot_id", "")))
		if slot.is_empty():
			continue
		var live = NodeFactory.make_memory_archive(
			archive_key,
			slot,
			_open_memory_archive.bind(archive_key, items),
			visual_state
		)
		live.add_to_group("world_memory_node")
		live.scale = Vector2.ONE
		_add_garden_archive_caption(live, archive_key, items.size())
		world.add_child(live)
		for item in items:
			(item as Dictionary)["node"] = live
			cache.append(item)

func _garden_archive_position(archive_key: String) -> Vector2:
	var archive: Dictionary = GARDEN_ARCHIVES.get(archive_key, GARDEN_ARCHIVES["flowers"])
	var slot = SlotManager.get_slot("garden", String(archive.get("slot_id", "")))
	var pos: Variant = slot.get("pos", [930, 548])
	if pos is Array and (pos as Array).size() >= 2:
		return Vector2(float(pos[0]), float(pos[1]))
	return Vector2(930, 548)

func _garden_archive_count() -> int:
	var keys = {}
	for item in _demo_memories:
		if item is Dictionary:
			keys[String(item.get("archive_key", "flowers"))] = true
	return keys.size()

func _add_garden_archive_caption(node: Node2D, archive_key: String, count: int) -> void:
	var archive: Dictionary = GARDEN_ARCHIVES.get(archive_key, {})
	var caption = Panel.new()
	caption.name = "ArchiveCaption"
	caption.position = Vector2(-68, -174 if archive_key == "flowers" else -108)
	caption.size = Vector2(136, 42)
	caption.visible = false
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.96, 0.82, 0.96)
	style.border_color = Color(0.42, 0.52, 0.30, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	caption.add_theme_stylebox_override("panel", style)
	node.add_child(caption)
	var title = Label.new()
	title.text = String(archive.get("title", "记忆"))
	title.position = Vector2(8, 4)
	title.size = Vector2(120, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.24, 0.19, 0.13, 0.96))
	caption.add_child(title)
	var summary = Label.new()
	summary.text = "%d 段记忆" % count
	summary.position = Vector2(8, 21)
	summary.size = Vector2(120, 16)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_theme_font_size_override("font_size", 10)
	summary.add_theme_color_override("font_color", Color(0.34, 0.30, 0.22, 0.84))
	caption.add_child(summary)
	var click_area = node.get_node_or_null("ClickArea") as Area2D
	if click_area != null:
		var hover_glow = node.get_node_or_null("ArchiveHoverGlow") as CanvasItem
		click_area.mouse_entered.connect(func() -> void:
			caption.visible = true
			if hover_glow != null:
				hover_glow.visible = true
		)
		click_area.mouse_exited.connect(func() -> void:
			caption.visible = false
			if hover_glow != null:
				hover_glow.visible = false
		)

func _add_memory_cluster_badge(node: Node2D, count: int) -> void:
	var badge = Panel.new()
	badge.name = "MemoryClusterBadge"
	badge.position = Vector2(20, -108)
	badge.size = Vector2(34, 24)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.30, 0.43, 0.28, 0.94)
	style.border_color = Color(1.0, 0.93, 0.70, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	badge.add_theme_stylebox_override("panel", style)
	node.add_child(badge)
	var label = Label.new()
	label.text = "×%d" % count
	label.position = Vector2(4, 2)
	label.size = Vector2(26, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.84, 1.0))
	badge.add_child(label)

func _open_memory_archive(archive_key: String, items: Array) -> void:
	_clear_memory_focus()
	_host._close_active_panel()
	var archive: Dictionary = GARDEN_ARCHIVES.get(archive_key, GARDEN_ARCHIVES["flowers"])
	var overlay = _host._create_modal_overlay()
	active_modal = overlay
	var panel = Panel.new()
	panel.position = Vector2(260, 60)
	panel.size = Vector2(760, 600)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)

	var title = Label.new()
	title.text = String(archive.get("title", "家庭记忆"))
	title.position = Vector2(36, 24)
	title.size = Vector2(650, 36)
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "%s · 共 %d 段" % [String(archive.get("subtitle", "")), items.size()]
	subtitle.position = Vector2(36, 64)
	subtitle.size = Vector2(650, 24)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.38, 0.31, 0.23, 0.82))
	panel.add_child(subtitle)

	var filter_bar = Panel.new()
	filter_bar.position = Vector2(34, 102)
	filter_bar.size = Vector2(692, 68)
	filter_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filter_bar.add_theme_stylebox_override("panel", _archive_filter_bar_style())
	panel.add_child(filter_bar)

	var member_label = Label.new()
	member_label.text = "家人"
	member_label.position = Vector2(14, 7)
	member_label.size = Vector2(196, 18)
	member_label.add_theme_font_size_override("font_size", 11)
	member_label.add_theme_color_override("font_color", Color(0.36, 0.29, 0.21, 0.88))
	filter_bar.add_child(member_label)
	var member_select = OptionButton.new()
	member_select.position = Vector2(12, 27)
	member_select.size = Vector2(210, 34)
	member_select.add_item("全部家人")
	member_select.set_item_metadata(0, "")
	_host._apply_button_style(member_select, false)
	var owners = {}
	for raw_item in items:
		if raw_item is Dictionary:
			var owner_id = String(raw_item.get("owner_id", ""))
			if owner_id != "":
				owners[owner_id] = _host._role_display_name(owner_id)
	var owner_ids: Array = owners.keys()
	owner_ids.sort()
	for owner_id in owner_ids:
		member_select.add_item(String(owners[owner_id]))
		member_select.set_item_metadata(member_select.item_count - 1, String(owner_id))
	filter_bar.add_child(member_select)

	var state_label = Label.new()
	state_label.text = "状态"
	state_label.position = Vector2(244, 7)
	state_label.size = Vector2(196, 18)
	state_label.add_theme_font_size_override("font_size", 11)
	state_label.add_theme_color_override("font_color", Color(0.36, 0.29, 0.21, 0.88))
	filter_bar.add_child(state_label)
	var state_select = OptionButton.new()
	state_select.position = Vector2(242, 27)
	state_select.size = Vector2(190, 34)
	for state_item in [["全部状态", ""], ["等待回应", "new"], ["已经开花", "grown"]]:
		state_select.add_item(String(state_item[0]))
		state_select.set_item_metadata(state_select.item_count - 1, String(state_item[1]))
	_host._apply_button_style(state_select, false)
	filter_bar.add_child(state_select)

	var order_note = Label.new()
	order_note.text = "最新记忆优先"
	order_note.position = Vector2(458, 27)
	order_note.size = Vector2(216, 34)
	order_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	order_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	order_note.add_theme_font_size_override("font_size", 11)
	order_note.add_theme_color_override("font_color", Color(0.43, 0.37, 0.29, 0.68))
	filter_bar.add_child(order_note)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(34, 184)
	scroll.size = Vector2(692, 352)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	var empty_label = Label.new()
	empty_label.text = "这个筛选下还没有内容。换个条件看看吧。"
	empty_label.position = Vector2(44, 316)
	empty_label.size = Vector2(672, 40)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.visible = false
	empty_label.add_theme_font_size_override("font_size", 13)
	empty_label.add_theme_color_override("font_color", Color(0.43, 0.36, 0.27, 0.74))
	panel.add_child(empty_label)

	var refresh = func(_index: int = 0) -> void:
		_populate_memory_archive_list(list, empty_label, items, member_select, state_select, archive_key)
	member_select.item_selected.connect(refresh)
	state_select.item_selected.connect(refresh)
	refresh.call()

	var footer = Label.new()
	footer.text = "点击任意卡片查看完整内容与记忆关联"
	footer.position = Vector2(34, 552)
	footer.size = Vector2(692, 24)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.43, 0.36, 0.27, 0.64))
	panel.add_child(footer)

func _populate_memory_archive_list(list: VBoxContainer, empty_label: Label, items: Array, member_select: OptionButton, state_select: OptionButton, archive_key: String = "flowers") -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var owner_filter = String(member_select.get_selected_metadata())
	var state_filter = String(state_select.get_selected_metadata())
	var visible_count = 0
	for raw_item in items:
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item
		if owner_filter != "" and String(item.get("owner_id", "")) != owner_filter:
			continue
		if state_filter != "" and String(item.get("state", "new")) != state_filter:
			continue
		var card: Dictionary = item.get("card", {})
		var owner_id = String(item.get("owner_id", ""))
		var owner_name = _host._role_display_name(owner_id) if owner_id != "" else "家人"
		var created_at = String(item.get("created_at", ""))
		var date_text = created_at.left(10) if created_at.length() >= 10 else "未记录日期"
		var is_grown = String(item.get("state", "new")) == "grown"
		var state_text = "已开花" if is_grown else "待回应"
		var link_count = MemoryManager.count_memory_links_for_memory(String(item.get("memory_id", "")), "garden")
		var row = Panel.new()
		row.custom_minimum_size = Vector2(664, 78)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_stylebox_override("panel", _archive_row_style(is_grown))
		list.add_child(row)

		var icon_panel = Panel.new()
		icon_panel.position = Vector2(12, 13)
		icon_panel.size = Vector2(52, 52)
		icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_panel.add_theme_stylebox_override("panel", _archive_icon_style(archive_key))
		row.add_child(icon_panel)
		var icon = TextureRect.new()
		icon.position = Vector2(9, 9)
		icon.size = Vector2(34, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_key = "icon_camera" if archive_key == "photos" else ("icon_postcard" if archive_key == "postcards" else "icon_tree")
		icon.texture = _host._safe_texture(str(ASSETS.get(icon_key, "")))
		icon_panel.add_child(icon)

		var item_title = Label.new()
		item_title.text = String(card.get("title", "一段家庭记忆")).strip_edges()
		if item_title.text == "":
			item_title.text = "一段家庭记忆"
		item_title.position = Vector2(78, 11)
		item_title.size = Vector2(448, 25)
		item_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		item_title.add_theme_font_size_override("font_size", 15)
		item_title.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 0.98))
		item_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(item_title)

		var relation_text = " · %d 条关联" % link_count if link_count > 0 else ""
		var metadata = Label.new()
		metadata.text = "%s · %s%s" % [owner_name, date_text, relation_text]
		metadata.position = Vector2(78, 42)
		metadata.size = Vector2(448, 20)
		metadata.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		metadata.add_theme_font_size_override("font_size", 12)
		metadata.add_theme_color_override("font_color", Color(0.43, 0.35, 0.27, 0.82))
		metadata.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(metadata)

		var status_panel = Panel.new()
		status_panel.position = Vector2(548, 23)
		status_panel.size = Vector2(92, 32)
		status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_panel.add_theme_stylebox_override("panel", _archive_status_style(is_grown))
		row.add_child(status_panel)
		var status_label = Label.new()
		status_label.text = state_text
		status_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_label.add_theme_font_size_override("font_size", 11)
		status_label.add_theme_color_override("font_color", Color(0.27, 0.28, 0.17, 0.94) if is_grown else Color(0.48, 0.33, 0.17, 0.94))
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_panel.add_child(status_label)

		var hit = Button.new()
		hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hit.text = ""
		hit.flat = true
		hit.focus_mode = Control.FOCUS_ALL
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.tooltip_text = item_title.text
		hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		hit.add_theme_stylebox_override("hover", _archive_row_hover_style())
		hit.add_theme_stylebox_override("pressed", _archive_row_pressed_style())
		hit.add_theme_stylebox_override("focus", _archive_row_hover_style())
		hit.pressed.connect(_open_memory_archive_item.bind(item))
		row.add_child(hit)
		visible_count += 1
	empty_label.visible = visible_count == 0

func _archive_filter_bar_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.94, 0.88, 0.72, 0.42)
	style.border_color = Color(0.56, 0.43, 0.28, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style

func _archive_row_style(active: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.975, 0.90, 0.92)
	style.border_color = Color(0.48, 0.58, 0.31, 0.48) if active else Color(0.62, 0.48, 0.31, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	style.shadow_color = Color(0.18, 0.12, 0.07, 0.11)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style

func _archive_icon_style(archive_key: String) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.92, 0.84, 0.66, 0.72) if archive_key == "photos" else Color(0.86, 0.89, 0.72, 0.72)
	style.border_color = Color(0.57, 0.43, 0.28, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	return style

func _archive_status_style(active: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.80, 0.87, 0.63, 0.78) if active else Color(0.94, 0.82, 0.60, 0.72)
	style.border_color = Color(0.43, 0.54, 0.29, 0.40) if active else Color(0.62, 0.44, 0.24, 0.38)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style

func _archive_row_hover_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.94, 0.72, 0.16)
	style.border_color = Color(0.80, 0.58, 0.30, 0.76)
	style.set_border_width_all(2)
	style.set_corner_radius_all(11)
	return style

func _archive_row_pressed_style() -> StyleBoxFlat:
	var style = _archive_row_hover_style()
	style.bg_color = Color(0.82, 0.88, 0.66, 0.24)
	return style

func _open_memory_archive_item(item: Dictionary) -> void:
	_focused_memory_id = String(item.get("memory_id", ""))
	_refresh_memory_link_visuals("garden")
	_open_memory_card(item)

func _open_memory_cluster(items: Array) -> void:
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay
	var panel = Panel.new()
	panel.position = Vector2(360, 104)
	panel.size = Vector2(560, 512)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)
	var title = Label.new()
	title.text = "这一簇记忆"
	title.position = Vector2(34, 26)
	title.size = Vector2(470, 32)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)
	var subtitle = Label.new()
	subtitle.text = "%d 段家庭记忆在这里一起开花" % items.size()
	subtitle.position = Vector2(34, 62)
	subtitle.size = Vector2(470, 24)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.38, 0.31, 0.23, 0.82))
	panel.add_child(subtitle)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(34, 104)
	scroll.size = Vector2(492, 322)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for raw_item in items:
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item
		var card: Dictionary = item.get("card", {})
		var row = Button.new()
		row.text = "%s\n%s" % [String(card.get("title", "一段家庭记忆")), "已回应" if String(item.get("state", "new")) == "grown" else "等待家人回应"]
		row.custom_minimum_size = Vector2(470, 68)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		_host._apply_button_style(row, String(item.get("state", "new")) == "grown")
		row.pressed.connect(_open_memory_card.bind(item))
		list.add_child(row)
	_host._add_panel_button(panel, "关闭", Vector2(218, 448), Vector2(124, 38), "close")

# 占位和正式美术都保留一个轻量状态标记，帮助玩家识别可互动的 AI 记忆。

func _add_memory_tag(node: Node2D, state: String) -> void:
	var tag = Label.new()
	tag.name = "DemoTag"
	tag.text = "已确认" if state == "grown" else "待回应"
	tag.visible = false
	tag.position = Vector2(-34, -112)
	tag.size = Vector2(68, 20)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_constant_override("outline_size", 3)
	tag.add_theme_color_override("font_outline_color", Color(1.0, 0.96, 0.82, 0.92))
	tag.add_theme_color_override("font_color", Color(0.24, 0.18, 0.13, 0.92))
	node.add_child(tag)
	var click_area = node.get_node_or_null("ClickArea") as Area2D
	if click_area != null:
		click_area.mouse_entered.connect(func() -> void: tag.visible = true)
		click_area.mouse_exited.connect(func() -> void: tag.visible = false)

func _animate_scene_node_arrival(node: Node2D, target_scale: Vector2) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.modulate.a = 0.0
	node.scale = target_scale * 0.82
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "scale", target_scale, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _play_memory_archive_arrival(memory_id: String) -> void:
	var item = _find_rendered_memory_by_memory_id(memory_id)
	if item.is_empty() or world == null or not is_instance_valid(world):
		return
	var target = _garden_archive_position(String(item.get("archive_key", "flowers")))
	var bloom = NodeFactory.make_memory_node(
		{"node_type": "memory_flower", "suggested_scene": "garden"},
		{"slot_id": "arrival", "pos": [640, 490]},
		Callable(),
		"new"
	)
	bloom.name = "MemoryArrivalBloom"
	bloom.z_index = 620
	bloom.scale = Vector2(0.34, 0.34)
	bloom.modulate.a = 0.0
	world.add_child(bloom)
	var tween = create_tween()
	tween.tween_property(bloom, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bloom, "scale", Vector2(0.78, 0.78), 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.42)
	tween.tween_property(bloom, "position", target, 0.86).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(bloom, "scale", Vector2(0.30, 0.30), 0.86).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(bloom, "modulate:a", 0.0, 0.72).set_delay(0.14)
	tween.finished.connect(bloom.queue_free)

func _pulse_memory_archive(node: Variant) -> void:
	if node == null or not is_instance_valid(node):
		return
	var archive: Node2D = node
	var tween = create_tween()
	tween.tween_property(archive, "scale", Vector2(1.08, 1.08), 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(archive, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _find_demo_memory(mem_id: String) -> Dictionary:
	for m in _demo_memories:
		if String(m.get("id", "")) == mem_id:
			return m
	return {}

func _on_memory_clicked(mem_id: String) -> void:
	var mem = _find_demo_memory(mem_id)
	if not mem.is_empty():
		_open_memory_card(mem)

# 记忆卡片 UI —— "可见的诚实"：AI 推测=浅灰+问号；家人确认=正常深色。

func _open_memory_card(mem: Dictionary) -> void:
	_host._close_active_panel()
	var card: Dictionary = mem.get("card", {})
	var overlay = _host._create_modal_overlay()
	active_modal = overlay

	var panel = Panel.new()
	panel.position = Vector2(360, 120)
	panel.size = Vector2(560, 484)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_host._add_panel_close_button(panel)

	var title = Label.new()
	title.text = String(card.get("title", "记忆"))
	title.position = Vector2(34, 24)
	title.size = Vector2(490, 34)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var desc = Label.new()
	desc.text = String(card.get("description", ""))
	desc.position = Vector2(34, 68)
	desc.size = Vector2(492, 70)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(desc)

	# AI 推测保持浅灰与问号，明确区别于家人确认的事实（可见的诚实）。
	var guess = Label.new()
	guess.text = "AI 推测：" + String(card.get("guess", "")) + "  ？（待家人确认）"
	guess.position = Vector2(34, 144)
	guess.size = Vector2(492, 24)
	guess.add_theme_font_size_override("font_size", 13)
	guess.add_theme_color_override("font_color", Color(0.60, 0.57, 0.52, 1.0))
	panel.add_child(guess)

	var q = Label.new()
	q.text = String(card.get("question", ""))
	q.position = Vector2(34, 182)
	q.size = Vector2(492, 50)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.add_theme_font_size_override("font_size", 16)
	q.add_theme_color_override("font_color", Color(0.20, 0.30, 0.24, 1.0))
	panel.add_child(q)

	if String(mem.get("state", "new")) == "new":
		var input = TextEdit.new()
		input.placeholder_text = "写下你的回忆…"
		input.position = Vector2(34, 244)
		input.size = Vector2(492, 112)
		panel.add_child(input)
		_host._add_panel_button(panel, "取消", Vector2(150, 376), Vector2(120, 40), "close")
		var submit = Button.new()
		submit.text = "回答"
		submit.position = Vector2(290, 376)
		submit.size = Vector2(120, 40)
		submit.mouse_filter = Control.MOUSE_FILTER_STOP
		_host._apply_button_style(submit, false)
		submit.pressed.connect(_submit_memory_answer.bind(String(mem.get("id", "")), input))
		panel.add_child(submit)
	else:
		var ans_title = Label.new()
		ans_title.text = "家人的回答（已确认）"
		ans_title.position = Vector2(34, 244)
		ans_title.size = Vector2(492, 22)
		ans_title.add_theme_font_size_override("font_size", 13)
		ans_title.add_theme_color_override("font_color", Color(0.35, 0.45, 0.35, 1.0))
		panel.add_child(ans_title)
		var ans = Label.new()
		ans.text = String(mem.get("answer", ""))
		ans.position = Vector2(34, 270)
		ans.size = Vector2(492, 88)
		ans.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ans.add_theme_font_size_override("font_size", 16)
		ans.add_theme_color_override("font_color", Color(0.20, 0.17, 0.13, 1.0))
		panel.add_child(ans)
		_host._add_panel_button(panel, "关闭", Vector2(220, 376), Vector2(120, 40), "close")

func _submit_memory_answer(mem_id: String, input: TextEdit) -> void:
	var mem = _find_demo_memory(mem_id)
	if mem.is_empty():
		return
	var text: String = input.text.strip_edges()
	if text == "":
		_host._show_toast("写点什么再回答吧～")
		return
	var result = await AIWorkflowManager.save_memory_answer(String(mem.get("memory_id", "")), text)
	if not bool(result.get("ok", false)):
		_host._show_toast(_host._result_error_message(result, "回答保存失败。"))
		return
	mem["answer"] = text
	mem["state"] = "grown"
	# 跨成员互动计数（回答别人上传的记忆）→ 升温则刷新分季背景。
	var bumped = MemoryManager.register_cross_member_answer(String(mem.get("memory_id", "")), MemoryManager.selected_role_key)
	_host._close_active_panel()
	if mode == "garden":
		_pulse_memory_archive(mem.get("node"))
	else:
		_grow_memory_node(mem.get("node"))
	if bumped:
		_host._update_season_overlay()
		_host._refresh_family_tree_visual()
		var season_message = "记忆开花了 · 花园更繁茂了（%s）" % _season_cn(MemoryManager.garden_season())
		if bool(result.get("sync_pending", false)):
			season_message += " · 联网后自动同步"
		_host._show_toast(season_message)
	else:
		_host._show_toast("记忆开花了。已保存在本机，联网后会自动同步。" if bool(result.get("sync_pending", false)) else "记忆开花了。")
	if MemoryManager.maybe_recompute_family_portrait():  # 参与成员变化 → 重画家庭画像木牌
		_render_family_portrait()

func _season_cn(season: String) -> String:
	match season:
		"autumn": return "秋"
		"summer": return "夏"
		_: return "春"

# 生长动画：花苞 → 开放（≤3 秒）。占位单贴图用缩放近似 seed→bud→bloom。

func _grow_memory_node(node: Variant, target_scale: Vector2 = Vector2.ONE) -> void:
	if node == null or not is_instance_valid(node):
		return
	var n: Node2D = node
	if n.has_node("DemoTag"):
		var tag = n.get_node("DemoTag") as Label
		tag.text = "已确认"
	NodeFactory.apply_memory_state(n, "grown")
	n.scale = target_scale * 0.25
	var t = create_tween()
	t.tween_property(n, "scale", target_scale * 0.7, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "scale", target_scale, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ── 全局导航地图（导航页 / World Map）──────────────────────────────
# 一张拍平的世界插画，四个抠图图层正好压在底图对应区域上。鼠标悬浮时该图层
# 抬起（高亮 + 下方柔和阴影），点击进入对应场景（走统一入口 goto_scene）。
