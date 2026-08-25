extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	MemoryManager._reset_all()
	MemoryManager.selected_role_key = "girl"

	var feminine := AppearanceManager.default_for_role("girl")
	feminine["hair_style"] = "soft_bob"
	feminine["hair_color"] = "midnight"
	feminine["outfit"] = "forest"
	AppearanceManager.set_current(feminine, "girl")
	_assert(bool(MemoryManager.character_appearance.get("enabled", false)), "确认捏脸后应启用全局外观")
	_assert(String(MemoryManager.character_appearance.get("hair_style", "")) == "soft_bob", "发型应写入存档模型")
	_assert(String(MemoryManager.character_appearance.get("hair_color", "")) == "midnight", "隐藏发色入口后仍应保留原存档值")

	var feminine_def := AppearanceManager.variant_definition(feminine, "girl")
	var feminine_texture := AppearanceManager.texture(feminine, "girl")
	_assert(feminine_texture != null and feminine_texture.resource_path.ends_with("girl_soft_bob_forest.png"), "隐藏发色功能后女体应显示自然棕成品图集")
	_assert((feminine_def.get("frame_rects", []) as Array).size() == 15, "女体短发应包含完整15帧")
	_assert(_rects_inside_texture(feminine_def.get("frame_rects", []), feminine_texture), "女体短发裁切不能越界")

	var player_a: CharacterBody2D = load("res://scenes/Player.tscn").instantiate()
	add_child(player_a)
	player_a.apply_character("girl")
	_assert(player_a.frame_rects.size() == 15, "玩家应加载捏脸发型的15帧")
	_assert(player_a.sprite.texture == feminine_texture, "玩家应使用捏脸选择的女体短发图集")
	_assert(player_a.sprite.material == null, "成品发色图集不应再挂载调色材质")
	player_a._set_frame(8)
	_assert(player_a.sprite.region_rect == player_a.frame_rects[8], "成品图集不能破坏方向动画裁切")

	var player_b: CharacterBody2D = load("res://scenes/Player.tscn").instantiate()
	add_child(player_b)
	player_b.apply_character("girl")
	_assert(player_b.sprite.texture == player_a.sprite.texture, "不同场景创建的玩家应读取同一全局外观")
	_assert(player_b.sprite.scale == player_a.sprite.scale, "不同场景的角色大小应一致")

	var avatar := AppearanceManager.avatar_texture(feminine, "girl")
	var feminine_avatar_rect: Array = feminine_def.get("frame_rects", [])[1]
	_assert(avatar != null and avatar.get_width() == int(feminine_avatar_rect[2]) and avatar.get_height() == int(feminine_avatar_rect[3]), "头像应使用同一套服装图集的站立帧")

	var masculine := AppearanceManager.default_for_role("boy")
	masculine["hair_style"] = "side_part"
	masculine["hair_color"] = "blonde"
	masculine["outfit"] = "ocean"
	# 复现曾出现“头顶变黑但刘海仍是棕色”的高反差组合，作为固定回归样例。
	var reported_combo := AppearanceManager.default_for_role("boy")
	reported_combo["hair_style"] = "tousled"
	reported_combo["hair_color"] = "dark"
	reported_combo["outfit"] = "sand"
	AppearanceManager.set_current(masculine, "boy")
	MemoryManager.selected_role_key = "boy"
	var masculine_texture := AppearanceManager.texture(masculine, "boy")
	var masculine_def := AppearanceManager.variant_definition(masculine, "boy")
	_assert(masculine_texture != null and masculine_texture.resource_path.ends_with("boy_sidepart_ocean.png"), "隐藏发色功能后男体应显示自然棕成品图集")
	_assert(_rects_inside_texture(masculine_def.get("frame_rects", []), masculine_texture), "男体侧分裁切不能越界")
	player_b.apply_character("boy")
	_assert(player_b.sprite.texture == masculine_texture, "切换身体与发型后玩家应立即使用对应图集")
	_assert(player_b.sprite.material == null, "男体成品发色图集也不应挂载调色材质")
	_assert(_all_visible_variants_are_valid(), "20 种可见角色组合都应使用自然棕完整图集和 15 帧动作")
	var remote_player: Node2D = load("res://scenes/RemotePlayer.tscn").instantiate()
	add_child(remote_player)
	remote_player.configure_presence("remote-custom", "boy", "路易", masculine)
	_assert(remote_player.sprite.texture == masculine_texture, "联机成员应显示对方选择的发型图集")
	_assert(remote_player.sprite.material == null, "联机成员应直接同步对方的完整成品图集")
	remote_player.visible = false
	if OS.has_environment("FG_CAPTURE_SCREENSHOTS"):
		player_a.position = Vector2(430, 360)
		player_b.position = Vector2(830, 360)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/family_garden_appearance_variants.png")

	MemoryManager.character_appearance = {}
	player_b.apply_character("father")
	_assert(player_b.sprite.texture == CharacterDB.texture("father"), "旧存档没有捏脸字段时必须保持原角色素材")
	_assert(player_b.sprite.material == null, "旧角色不应残留捏脸调色材质")

	var creator := CharacterCreatorPanel.new()
	add_child(creator)
	creator.setup("girl", "佩林", "家庭码", feminine)
	_assert(creator.get_child_count() > 0, "开场捏脸面板应可构建")
	var creator_text := _collect_ui_text(creator)
	_assert(not creator_text.contains("/") and not creator_text.contains("Character"), "角色编辑页不应残留英文并列文案")
	_assert(not creator_text.contains("发色") and not creator_text.contains("雾夜蓝"), "角色编辑页不应显示暂时停用的发色入口")
	var first_creator := CharacterCreatorPanel.new()
	add_child(first_creator)
	first_creator.setup("", "", "", {})
	_assert(_collect_ui_text(first_creator).contains("创建角色并进入花园"), "首次角色创建按钮应明确衔接进入花园")
	first_creator.queue_free()
	if OS.has_environment("FG_CAPTURE_SCREENSHOTS"):
		player_a.visible = false
		player_b.visible = false
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/family_garden_character_creator.png")
		creator.visible = false
		var male_creator := CharacterCreatorPanel.new()
		add_child(male_creator)
		male_creator.setup("papa", "亲", "family1", reported_combo)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/family_garden_character_creator_male.png")
		male_creator.queue_free()

	creator.visible = false
	var profile := ProfilePanel.new()
	add_child(profile)
	await get_tree().process_frame
	var profile_text := _collect_ui_text(profile)
	_assert(profile_text.contains("我的资料"), "个人资料页标题应使用简洁中文")
	_assert(not profile_text.contains("/") and not profile_text.contains("Family") and not profile_text.contains("Settings"), "个人资料页不应残留英文并列文案")
	for icon_text in ["🏡", "👪", "🎨", "⚙", "🏆"]:
		_assert(not profile_text.contains(icon_text), "个人资料页不应残留装饰图标 %s" % icon_text)
	if OS.has_environment("FG_CAPTURE_SCREENSHOTS"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/family_garden_profile_panel.png")
		profile.visible = false
		await _capture_appearance_matrix("outfit", "/tmp/family_garden_outfit_asset_matrix.png")
		await _capture_action_sheet(reported_combo, "papa", "/tmp/family_garden_baked_hair_all_actions.png")

	player_a.queue_free()
	player_b.queue_free()
	remote_player.queue_free()
	creator.queue_free()
	profile.queue_free()
	MemoryManager._reset_all()
	await get_tree().process_frame
	if failures.is_empty():
		print("Appearance system tests passed: hidden hair color, 20 visible variants, 15 frames, avatar, global player and legacy fallback")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _rects_inside_texture(rects: Array, texture: Texture2D) -> bool:
	if texture == null or rects.size() != 15:
		return false
	for raw in rects:
		if not (raw is Array and raw.size() >= 4):
			return false
		var rect := Rect2(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
		if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > texture.get_width() or rect.end.y > texture.get_height():
			return false
	return true

func _collect_ui_text(node: Node) -> String:
	var parts: Array[String] = []
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	elif node is LineEdit:
		parts.append((node as LineEdit).placeholder_text)
	for child in node.get_children():
		parts.append(_collect_ui_text(child))
	return "\n".join(parts)

func _all_visible_variants_are_valid() -> bool:
	var styles := [
		{"body": "feminine", "style": "braid_hat", "role": "girl"},
		{"body": "feminine", "style": "soft_bob", "role": "girl"},
		{"body": "masculine", "style": "tousled", "role": "boy"},
		{"body": "masculine", "style": "side_part", "role": "boy"},
	]
	var texture_paths: Dictionary = {}
	for definition in styles:
		for outfit_id in AppearanceManager.outfits().keys():
			var appearance := AppearanceManager.default_for_role(String(definition.role))
			appearance["body_type"] = String(definition.body)
			appearance["hair_style"] = String(definition.style)
			appearance["hair_color"] = "midnight"
			appearance["outfit"] = String(outfit_id)
			var texture := AppearanceManager.texture(appearance, String(definition.role))
			var variant := AppearanceManager.variant_definition(appearance, String(definition.role))
			var rects: Array = variant.get("frame_rects", [])
			if texture == null or not _rects_inside_texture(rects, texture):
				return false
			var display_height := float(variant.get("scale", 0.0)) * float((rects[0] as Array)[3])
			if display_height < 84.0 or display_height > 105.0 or not _all_frames_have_visible_pixels(texture, rects):
				return false
			if texture.resource_path.contains("__midnight") or texture_paths.has(texture.resource_path):
				return false
			texture_paths[texture.resource_path] = true
	return texture_paths.size() == 20

func _all_frames_have_visible_pixels(texture: Texture2D, rects: Array) -> bool:
	var source := texture.get_image()
	for raw_value in rects:
		var raw: Array = raw_value
		var visible_pixels := 0
		for y in range(int(raw[1]), int(raw[1]) + int(raw[3])):
			for x in range(int(raw[0]), int(raw[0]) + int(raw[2])):
				if source.get_pixel(x, y).a > 0.1:
					visible_pixels += 1
					if visible_pixels >= 100:
						break
			if visible_pixels >= 100:
				break
		if visible_pixels < 100:
			return false
	return true

func _capture_appearance_matrix(mode: String, output_path: String) -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var background := ColorRect.new()
	background.color = Color("#eef2d9")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var title := Label.new()
	title.text = "发色完整检查" if mode == "hair" else "真实服装素材完整检查"
	title.position = Vector2(0, 14)
	title.size = Vector2(1280, 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#3f3428"))
	root.add_child(title)

	var styles := [
		{"body": "feminine", "style": "braid_hat", "role": "girl", "label": "女性　草帽辫发"},
		{"body": "feminine", "style": "soft_bob", "role": "girl", "label": "女性　柔软短发"},
		{"body": "masculine", "style": "tousled", "role": "boy", "label": "男性　蓬松短发"},
		{"body": "masculine", "style": "side_part", "role": "boy", "label": "男性　温柔侧分"},
	]
	var choices: Array = AppearanceManager.hair_colors().keys() if mode == "hair" else AppearanceManager.outfits().keys()
	for row in styles.size():
		var definition: Dictionary = styles[row]
		var row_label := Label.new()
		row_label.text = String(definition.label)
		row_label.position = Vector2(18, 70 + row * 155)
		row_label.size = Vector2(146, 120)
		row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row_label.add_theme_font_size_override("font_size", 14)
		row_label.add_theme_color_override("font_color", Color("#4b3d2e"))
		root.add_child(row_label)
		for column in choices.size():
			var choice_id := String(choices[column])
			var appearance := AppearanceManager.default_for_role(String(definition.role))
			appearance["body_type"] = String(definition.body)
			appearance["hair_style"] = String(definition.style)
			if mode == "hair":
				appearance["hair_color"] = choice_id
				appearance["outfit"] = "original"
			else:
				appearance["hair_color"] = "brown"
				appearance["outfit"] = choice_id
			var card := Panel.new()
			card.position = Vector2(170 + column * 216, 62 + row * 155)
			card.size = Vector2(196, 142)
			var card_style := StyleBoxFlat.new()
			card_style.bg_color = Color("#fff6dc")
			card_style.border_color = Color("#c8a777")
			card_style.set_border_width_all(1)
			card_style.set_corner_radius_all(10)
			card.add_theme_stylebox_override("panel", card_style)
			root.add_child(card)
			var avatar := TextureRect.new()
			avatar.position = Vector2(8, 6)
			avatar.size = Vector2(180, 106)
			avatar.texture = AppearanceManager.avatar_texture(appearance, String(definition.role))
			avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			card.add_child(avatar)
			var label := Label.new()
			var source: Dictionary = AppearanceManager.hair_colors() if mode == "hair" else AppearanceManager.outfits()
			label.text = String(source.get(choice_id, {}).get("label", choice_id))
			label.position = Vector2(4, 112)
			label.size = Vector2(188, 24)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color("#4b3d2e"))
			card.add_child(label)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_path)
	root.queue_free()
	await get_tree().process_frame

func _capture_action_sheet(appearance: Dictionary, role_key: String, output_path: String) -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var background := ColorRect.new()
	background.color = Color("#eef2d9")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var title := Label.new()
	title.text = "乌木黑＋暖沙工装　全部动作检查"
	title.position = Vector2(0, 12)
	title.size = Vector2(1280, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#3f3428"))
	root.add_child(title)

	var source := AppearanceManager.texture(appearance, role_key).get_image()
	var rects := AppearanceManager.frame_rects(appearance, role_key)
	for index in rects.size():
		var raw: Array = rects[index]
		var rect := Rect2i(int(raw[0]), int(raw[1]), int(raw[2]), int(raw[3]))
		var image := source.get_region(rect)
		var frame := TextureRect.new()
		frame.position = Vector2(245 + (index % 3) * 280, 52 + (index / 3) * 130)
		frame.size = Vector2(230, 112)
		frame.texture = ImageTexture.create_from_image(image)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		root.add_child(frame)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_path)
	root.queue_free()
	await get_tree().process_frame

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
