extends "res://scripts/scene_runtime/scene_runtime_module.gd"

## 留言板、家庭成员、信箱与 NPC 对话。
## 仅由 SceneManager 创建；外部代码继续调用 SceneManager 兼容门面。

func _open_animal_dialog(animal_id: String, display_name: String) -> void:
	var line = "花园里的小伙伴正在这里休息。"
	match animal_id:
		"cat":
			line = "Mimi 慢慢眨了眨眼，走几步，又准备蜷起来打个小盹。"
		"bird":
			line = "蓝色小鸟在花园边轻轻跳着，望着家庭树。"
		"dog":
			line = "Biscuit 开心地晃了晃，然后趴下来休息一会儿。"
	_show_cozy_panel(display_name, line, [{"text": "关闭", "action": "close"}])

func _open_message_board_panel() -> void:
	var body = "家人的留言都贴在这里。\n\n"
	if MemoryManager.garden_messages.is_empty():
		body += "还没有留言。给家人写下第一句话吧。"
	else:
		for message in MemoryManager.garden_messages:
			body += "• " + str(message.get("author", "家人")) + ": " + str(message.get("text", "")) + "\n\n"
	_show_cozy_panel(
		"留言板",
		body,
		[
			{"text": "+ 留言", "action": "add_message"},
			{"text": "关闭", "action": "close"}
		]
	)

func _open_add_message_form() -> void:
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay

	var panel = Panel.new()
	panel.position = Vector2(390, 170)
	panel.size = Vector2(500, 360)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title = Label.new()
	title.text = "新增留言"
	title.position = Vector2(30, 24)
	title.size = Vector2(440, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var author_label = Label.new()
	author_label.text = "来自"
	author_label.position = Vector2(32, 78)
	author_label.size = Vector2(420, 22)
	author_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(author_label)

	var author_input = LineEdit.new()
	author_input.placeholder_text = "Peilin, Papa, Mama..."
	author_input.text = MemoryManager.player_display_name if MemoryManager.player_display_name != "" else _host._default_name_for_role(MemoryManager.selected_role_key)
	author_input.position = Vector2(32, 104)
	author_input.size = Vector2(430, 36)
	panel.add_child(author_input)

	var message_label = Label.new()
	message_label.text = "留言"
	message_label.position = Vector2(32, 154)
	message_label.size = Vector2(420, 22)
	message_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(message_label)

	var message_input = TextEdit.new()
	message_input.placeholder_text = "给家人留一句小小的话..."
	message_input.position = Vector2(32, 180)
	message_input.size = Vector2(430, 90)
	panel.add_child(message_input)

	_host._add_panel_button(panel, "保存留言", Vector2(96, 296), Vector2(130, 40), "save_new_message", [author_input, message_input])
	_host._add_panel_button(panel, "取消", Vector2(274, 296), Vector2(120, 40), "message_board")

func _save_new_message(author_input: LineEdit, message_input: TextEdit) -> void:
	var author: String = author_input.text.strip_edges()
	if author == "":
		author = "家人"
	var text: String = message_input.text.strip_edges()
	if text == "":
		text = "花园里留下了一句小小的话。"

	var message_id: String = "message_" + str(Time.get_ticks_msec())
	if CloudManager != null:
		var cloud_message: Dictionary = await CloudManager.create_message(author, text, "")
		if not cloud_message.is_empty() and str(cloud_message.get("id", "")) != "":
			message_id = str(cloud_message.get("id", ""))

	var message = {
		"id": message_id,
		"author": author,
		"text": text,
		"created_at": Time.get_datetime_string_from_system(),
		"role": MemoryManager.selected_role_key
	}
	MemoryManager.garden_messages.append(message)
	MemoryManager.notify_family_activity()
	MemoryManager.save_game()
	_host._refresh_world_chat_feed()
	_open_message_board_panel()
	_host._show_toast("新留言已保存。")

func _open_postcards_panel() -> void:
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay

	var panel = Panel.new()
	panel.position = Vector2(300, 72)
	panel.size = Vector2(680, 590)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title = Label.new()
	title.text = "家庭明信片"
	title.position = Vector2(36, 26)
	title.size = Vector2(608, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "打开明信片，查看它带回来的照片和记忆。"
	subtitle.position = Vector2(36, 62)
	subtitle.size = Vector2(608, 24)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.43, 0.35, 0.27, 0.88))
	panel.add_child(subtitle)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(36, 98)
	scroll.size = Vector2(608, 390)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	if MemoryManager.postcards.is_empty():
		var empty_label = Label.new()
		empty_label.text = "还没有明信片。打开旅行地图，添加一个地点，就能寄回第一张。"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.custom_minimum_size = Vector2(570, 90)
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.21, 1.0))
		list.add_child(empty_label)
	else:
		for postcard in MemoryManager.postcards:
			if not (postcard is Dictionary):
				continue

			var postcard_id: String = str(postcard.get("id", ""))
			var card = Panel.new()
			card.custom_minimum_size = Vector2(570, 96)
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			_host._apply_small_card_style(card)
			list.add_child(card)

			var card_title = Label.new()
			var badge = "新 · " if bool(postcard.get("is_new", false)) else ""
			var has_photo = _host._photo_reference(postcard) != ""
			var photo_label = "有照片 · " if has_photo else "无照片 · "
			card_title.text = badge + photo_label + str(postcard.get("title", "明信片"))
			card_title.position = Vector2(18, 12)
			card_title.size = Vector2(420, 26)
			card_title.add_theme_font_size_override("font_size", 16)
			card_title.add_theme_color_override("font_color", Color(0.24, 0.20, 0.15, 1.0))
			card.add_child(card_title)

			var card_body = Label.new()
			card_body.text = str(postcard.get("message", ""))
			card_body.position = Vector2(18, 40)
			card_body.size = Vector2(420, 42)
			card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card_body.add_theme_font_size_override("font_size", 13)
			card_body.add_theme_color_override("font_color", Color(0.43, 0.35, 0.27, 0.92))
			card.add_child(card_body)

			var open_button = Button.new()
			open_button.text = "打开"
			open_button.position = Vector2(462, 29)
			open_button.size = Vector2(86, 36)
			open_button.mouse_filter = Control.MOUSE_FILTER_STOP
			_host._apply_button_style(open_button, false)
			_host._set_button_icon(open_button, "icon_postcard")
			open_button.pressed.connect(_open_postcard_detail_from_id.bind(postcard_id))
			card.add_child(open_button)

	_host._add_panel_button(panel, "旅行地图", Vector2(96, 520), Vector2(150, 40), "travel_map")
	_host._add_panel_button(panel, "关闭", Vector2(432, 520), Vector2(150, 40), "close")
	MemoryManager.mark_postcards_read()
	MemoryManager.save_game()

func _open_postcard_detail_from_id(postcard_id: String) -> void:
	var postcard = MemoryManager.find_postcard(postcard_id)
	if postcard.is_empty():
		_host._show_toast("没有找到这张明信片。")
		return

	var place_id: String = str(postcard.get("place_id", ""))
	var place = MemoryManager.find_place(place_id)
	var title_text = str(postcard.get("title", "明信片"))
	var message = str(postcard.get("message", "一段小小的记忆。"))
	var photo_reference = _host._photo_reference(postcard)

	if photo_reference == "" and not place.is_empty():
		photo_reference = _host._photo_reference(place)

	_host._open_postcard_detail_panel(title_text, message, photo_reference, place_id)

func _open_family_tree_panel() -> void:
	if game_hud != null and is_instance_valid(game_hud) and game_hud.has_method("open_family_tree"):
		game_hud.open_family_tree()
		return
	var stage = MemoryManager.family_tree_stage()
	var interactions = MemoryManager.cross_member_interaction_count
	var next_threshold = MemoryManager.family_tree_next_threshold()
	var planted_text = "已种在花园中" if MemoryManager.has_planted_family_tree() else "幼苗正在等待种植"
	var progress_text = "已长成最终形态" if next_threshold < 0 else "再完成 %d 次跨成员互动进入下一阶段" % max(0, next_threshold - interactions)
	var body = "家庭树 · 第 %d / 5 阶段\n%s\n家庭互动量：%d\n%s\n\n家庭成员：\n" % [stage, planted_text, interactions, progress_text]
	for role_data in CHARACTER_DATA:
		var role_key = str(role_data.get("role", ""))
		var member_name = MemoryManager.player_display_name if role_key == MemoryManager.selected_role_key else str(role_data.get("default_name", role_data.get("label", "家人")))
		var status = "当前玩家" if role_key == MemoryManager.selected_role_key else "花园访客"
		body += "• " + member_name + " — " + status + "\n"
	body += "\n树上的明信片：\n"
	if MemoryManager.postcards.is_empty():
		body += "• 还没有明信片。打开旅行地图寄回一张吧。\n"
	else:
		for postcard in MemoryManager.postcards:
			body += "• " + str(postcard.get("title", "明信片")) + "\n"
	var buttons: Array = []
	if MemoryManager.family_tree_gift_received and not MemoryManager.has_planted_family_tree():
		buttons.append({"text": "种下幼苗", "action": "plant_family_tree"})
	buttons.append({"text": "明信片", "action": "MemoryManager.postcards"})
	buttons.append({"text": "留言板", "action": "message_board"})
	if buttons.size() < 3:
		buttons.append({"text": "关闭", "action": "close"})
	_show_cozy_panel(
		"家庭树",
		body,
		buttons
	)

func _offer_family_tree_welcome_gift() -> void:
	if mode != "garden" or MemoryManager.selected_role_key == "":
		return
	if MemoryManager.has_planted_family_tree():
		return
	MemoryManager.grant_family_tree_gift()
	if MemoryManager.family_tree_planting_hint_seen:
		return
	MemoryManager.family_tree_planting_hint_seen = true
	MemoryManager.save_game()
	_host._show_toast("家庭树幼苗等待种植 · 点击底部“建造”→“家庭树”")
	if game_hud != null and is_instance_valid(game_hud) and game_hud.has_method("open_family_tree"):
		game_hud.open_family_tree()
		return
	_show_cozy_panel(
		"送给你的家庭树幼苗",
		"欢迎来到家庭花园。\n\n这株幼苗会记录家人之间真实的互动，并逐渐长成一棵属于你们的家庭树。你可以先为它选择一个喜欢的位置。",
		[
			{"text": "现在种下", "action": "plant_family_tree"},
			{"text": "稍后再种", "action": "close"}
		]
	)

func _begin_family_tree_placement() -> void:
	_host._close_active_panel()
	# 先记录“已经从面板主动进入种植”，避免从厨房等场景切回花园后，
	# 延迟执行的首次提示再次打开面板并打断正在进行的放置。
	MemoryManager.family_tree_gift_received = true
	MemoryManager.family_tree_planting_hint_seen = true
	MemoryManager.save_game()
	if mode != "garden":
		_host._show_garden()
	if MemoryManager.has_planted_family_tree():
		_host._show_toast("家庭树已经种在花园里了。")
		return
	selected_plant_type = "family_tree"
	plant_mode = true
	_host._update_plant_button()
	_host._show_toast("点击花园中的空地，种下家庭树幼苗。")

func begin_family_tree_placement() -> void:
	_begin_family_tree_placement()

func _open_family_members_panel() -> void:
	var family_code = CloudManager.family_code() if CloudManager != null and CloudManager.has_method("family_code") else ""
	var members: Array = []
	if CloudManager != null and CloudManager.has_method("list_family_members"):
		members = await CloudManager.list_family_members()
	var online = _online_family_members()
	var body = "家庭邀请码：" + (family_code if family_code != "" else "离线家庭") + "\n\n"
	if members.is_empty():
		body += "还没有从云端同步到家庭成员。\n"
		if GameIdentity != null and GameIdentity.is_ready():
			members.append({
				"member_id": GameIdentity.member_id,
				"role": GameIdentity.role,
				"display_name": GameIdentity.display_name,
			})
		else:
			members.append({
				"member_id": "local",
				"role": MemoryManager.selected_role_key,
				"display_name": MemoryManager.player_display_name,
			})
	body += "家庭成员：\n"
	for raw in members:
		if not (raw is Dictionary):
			continue
		var member: Dictionary = raw
		var member_id = str(member.get("member_id", ""))
		var display_name = str(member.get("display_name", "")).strip_edges()
		if display_name == "":
			display_name = _role_display_name(str(member.get("role", "")))
		var role = _role_display_name(str(member.get("role", "")))
		var online_text = "在线" if online.has(member_id) else "离线"
		var scene_text = ""
		if online.has(member_id):
			var peer: Dictionary = online[member_id]
			scene_text = " · " + _scene_display_name(str(peer.get("scene_id", "")))
		body += "• %s（%s） — %s%s\n" % [display_name, role, online_text, scene_text]
	body += "\n同一成员在多台设备同时进入时，会优先显示最新连接；旧连接会自动退出。"
	_show_cozy_panel(
		"家庭成员",
		body,
		[
			{"text": "留言板", "action": "message_board"},
			{"text": "家庭树", "action": "family_tree"},
			{"text": "关闭", "action": "close"}
		]
	)

func _online_family_members() -> Dictionary:
	var result: Dictionary = {}
	if GameIdentity != null and GameIdentity.is_ready():
		result[GameIdentity.member_id] = {
			"member_id": GameIdentity.member_id,
			"role": GameIdentity.role,
			"display_name": GameIdentity.display_name,
			"scene_id": mode,
		}
	if PresenceChannel != null and PresenceChannel.has_method("peers"):
		for raw_peer in PresenceChannel.peers():
			if raw_peer is Dictionary:
				var peer: Dictionary = raw_peer
				var member_id = str(peer.get("member_id", ""))
				if member_id != "":
					result[member_id] = peer
	return result

func _role_display_name(role_key: String) -> String:
	var resolved = CharacterDB.resolve(role_key) if CharacterDB != null else role_key
	if CharacterDB != null:
		return CharacterDB.display_name(resolved)
	return resolved

func _scene_display_name(scene_id: String) -> String:
	match scene_id:
		"farm":
			return "农场"
		"garden":
			return "花园"
		"fishpond":
			return "鱼塘"
		"room":
			return "房间"
		_:
			return "花园"

func _open_mailbox_panel() -> void:
	var unread_count: int = MemoryManager.count_unread_postcards()
	var body = ""
	if unread_count > 0:
		body = "有新的家人来信。\n\n"
		for postcard in MemoryManager.postcards:
			if bool(postcard.get("is_new", false)):
				body += "• " + str(postcard.get("title", "新明信片")) + "\n"
	else:
		body = "现在没有新来信。\n\n在旅行地图添加地点，就能寄一张新的明信片回花园。"
	MemoryManager.mark_postcards_read(false)
	MemoryManager.clear_mailbox_alert()
	if CloudManager != null:
		await CloudManager.mark_mailbox_read()
	MemoryManager.save_game()
	_show_cozy_panel(
		"邮箱",
		body,
		[
			{"text": "查看明信片", "action": "MemoryManager.postcards"},
			{"text": "旅行地图", "action": "travel_map"},
			{"text": "关闭", "action": "close"}
		]
	)

func _open_npc_dialog(npc_id: String, display_name: String) -> void:
	var line = "今天的花园很安静。"
	match npc_id:
		"papa":
			line = "今天花园很安静，能在这里看到大家，感觉很好。"
		"mama":
			line = "花开得很好，这里像一个小小的家。"
		"boy":
			line = "我找到一个很安静的角落。也许我们可以一起留下一张明信片。"
		"girl":
			line = "我把一段小小的记忆带回了花园。"
	_show_cozy_panel(display_name, line, [{"text": "关闭", "action": "close"}])

func _show_cozy_panel(panel_title: String, body_text: String, buttons: Array) -> void:
	_host._close_active_panel()
	var overlay = _host._create_modal_overlay()
	active_modal = overlay

	var panel = Panel.new()
	panel.position = Vector2(380, 150)
	panel.size = Vector2(520, 380)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_host._apply_panel_style(panel)
	overlay.add_child(panel)
	_add_panel_close_button(panel)

	var title = Label.new()
	title.text = panel_title
	title.position = Vector2(34, 28)
	title.size = Vector2(450, 36)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 1.0))
	panel.add_child(title)

	var body = RichTextLabel.new()
	body.text = body_text
	body.position = Vector2(34, 82)
	body.size = Vector2(452, 200)
	body.fit_content = false
	body.scroll_active = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.bbcode_enabled = false
	body.add_theme_font_size_override("normal_font_size", 16)
	body.add_theme_color_override("default_color", Color(0.30, 0.26, 0.21, 1.0))
	panel.add_child(body)

	var button_count: int = buttons.size()
	var gap: int = 14
	var button_width: int = 128
	var total_width: float = float(button_count * button_width + max(0, button_count - 1) * gap)
	var start_x: float = (520.0 - total_width) / 2.0
	for i in range(button_count):
		var button_data: Dictionary = buttons[i]
		_host._add_panel_button(panel, str(button_data.get("text", "OK")), Vector2(start_x + i * 142, 310), Vector2(128, 40), str(button_data.get("action", "close")))

func _add_panel_close_button(panel: Panel) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	if panel.has_node("PanelCloseButton"):
		return

	var close_btn = Button.new()
	close_btn.name = "PanelCloseButton"
	close_btn.text = "×"
	close_btn.size = Vector2(34, 30)
	close_btn.position = Vector2(maxf(8.0, panel.size.x - 46.0), 12)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.focus_mode = Control.FOCUS_NONE
	_host._apply_button_style(close_btn, false)
	close_btn.pressed.connect(_host._close_active_panel)
	panel.add_child(close_btn)
