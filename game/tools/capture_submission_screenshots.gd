extends Node

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const FARM_SCENE := preload("res://scenes/Farm.tscn")

var output_dir := ""
var main_scene: Node = null

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	output_dir = OS.get_environment("FG_SCREENSHOT_DIR").strip_edges()
	if output_dir == "":
		push_error("请设置 FG_SCREENSHOT_DIR 为截图输出目录。")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	GameClock.debug_start_hour = 14.0
	GameClock._seconds = 14.0 * 3600.0
	MemoryManager._reset_all()
	MemoryManager.selected_role_key = "girl"
	MemoryManager.player_display_name = "佩林"
	MemoryManager.save_game()

	main_scene = MAIN_SCENE.instantiate()
	get_tree().root.add_child(main_scene)
	await _wait_frames(18)
	if OS.get_environment("FG_CAPTURE_PORTRAIT_ONLY") == "1":
		SceneManager._update_orientation_overlay()
		await _capture("09_portrait_prompt.png", 18)
		print("竖屏提示截图已输出：", output_dir)
		get_tree().quit(0)
		return
	SceneManager._show_garden()
	if OS.get_environment("FG_CAPTURE_DENSE_GARDEN") == "1":
		_seed_dense_garden(17)
		SceneManager._refresh_current_memory_scene("garden")
		await _capture("10_memory_scale_17.png", 20)
		_seed_dense_garden(50)
		SceneManager._refresh_current_memory_scene("garden")
		await _capture("11_memory_scale_50.png", 20)
		_seed_dense_garden(100)
		SceneManager._refresh_current_memory_scene("garden")
		if SceneManager.world.has_node("FamilyPortraitBoard"):
			push_error("右下留言板上不应残留旧家庭画像。")
			get_tree().quit(1)
			return
		if SceneManager.gate4_guide_card == null or not SceneManager.gate4_guide_card.has_node("FamilyPortraitMiniature"):
			push_error("左上状态卡必须显示家庭迷你合影。")
			get_tree().quit(1)
			return
		await _capture("12_memory_scale_100.png", 20)
		var flower_items: Array = []
		for item in SceneManager._demo_memories:
			if item is Dictionary and String(item.get("archive_key", "")) == "flowers":
				flower_items.append(item)
		if not flower_items.is_empty():
			SceneManager._open_memory_archive("flowers", flower_items)
			await _capture("13_memory_archive.png", 12)
			SceneManager._close_active_panel()
			await _wait_frames(3)
			var linked_item := _first_linked_item(flower_items)
			if not linked_item.is_empty():
				SceneManager._open_memory_archive_item(linked_item)
				await _capture("14_memory_focus_card.png", 8)
				SceneManager._close_active_panel()
				await _capture("15_memory_focus_vine.png", 8)
				if _count_world_memory_links() == 0:
					push_error("选中有关联的记忆后应显示局部藤蔓。")
					get_tree().quit(1)
					return
				SceneManager._clear_memory_focus()
				await _wait_frames(3)
				if _count_world_memory_links() != 0:
					push_error("清除记忆焦点后不应残留藤蔓。")
					get_tree().quit(1)
					return
		print("17/50/100 条记忆压力截图已输出：", output_dir)
		get_tree().quit(0)
		return
	await _capture("01_garden_hero.png")

	SceneManager._show_role_select()
	await _capture("02_family_entry.png")

	SceneManager._close_active_panel()
	SceneManager._show_garden()
	var links := MemoryManager.get_memory_links("garden")
	if not links.is_empty():
		SceneManager._open_memory_link_panel(links[0])
		await _capture("03_memory_vine.png")

	var card := {
		"title": "和爸妈的海边家庭旅行",
		"description": "看起来是一次和爸爸、妈妈一起前往海边的家庭旅行。",
		"memory_type": "family_trip",
		"suggested_scene": "garden",
		"question": "这次海边家庭旅行中，印象最深的事情是什么？",
		"node_type": "memory_flower",
		"confidence": 0.92,
	}
	var draft := {
		"ok": true,
		"kind": "memory",
		"workflow_key": "submission-memory-card",
		"raw_text": "去年夏天，我们一起去了海边。",
		"input_type": "text",
		"card": card,
		"generation_meta": {
			"request_id": "submission_capture",
			"provider": "hunyuan",
			"model": "hy3-preview",
			"prompt_version": "memory-card-v1",
			"source": "ai",
		},
		"used_fallback": false,
		"upload_id": "",
		"image_url": "",
	}
	SceneManager._open_memory_draft_preview(draft)
	await _capture("04_ai_memory_card.png")
	SceneManager._close_active_panel()
	await _wait_frames(3)

	var analysis := AIClient.mock_room_analysis()
	var layout := RoomLayoutManager.plan(analysis)
	var room_draft := {
		"ok": true,
		"kind": "room",
		"workflow_key": "submission-room",
		"analysis": analysis,
		"layout": layout,
		"generation_meta": {
			"request_id": "submission_room_capture",
			"provider": "hunyuan",
			"model": "hunyuan-vision",
			"prompt_version": "room-analysis-v1",
			"source": "ai",
		},
		"used_fallback": false,
		"upload_id": "",
		"image_url": "",
	}
	SceneManager._open_room_draft_preview(room_draft)
	await _capture("05_room_semantic_preview.png")

	SceneManager._close_active_panel()
	RoomLayoutManager.generate(analysis, "", "submission-room", room_draft.generation_meta)
	SceneManager._enter_house("player", "我的房间")
	await _capture("06_generated_room.png")

	SceneManager._build_fishpond()
	await _wait_frames(12)
	SceneManager._open_bottle_panel({
		"id": "submission-bottle",
		"question": "小时候有没有一次和家人一起出门玩，让你现在还记得？",
		"state": "floating",
		"answer": "",
	})
	await _capture("07_bottle_question.png")

	SceneManager._close_active_panel()
	if main_scene != null and is_instance_valid(main_scene):
		main_scene.queue_free()
	await _wait_frames(4)
	var farm := FARM_SCENE.instantiate()
	get_tree().root.add_child(farm)
	await _capture("08_shared_farm.png", 24)

	print("比赛截图已输出：", output_dir)
	get_tree().quit(0)

func _capture(file_name: String, settle_frames: int = 14) -> void:
	await _wait_frames(settle_frames)
	await get_tree().create_timer(0.8).timeout
	for _index in range(3):
		RenderingServer.force_draw(true)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := output_dir.path_join(file_name)
	var error := image.save_png(path)
	if error != OK:
		push_error("截图保存失败：%s，错误码 %d" % [path, error])
	else:
		print("已保存截图：", path)

func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _seed_dense_garden(target_count: int) -> void:
	var existing_count := MemoryManager.get_nodes_for_scene("garden").filter(
		func(node: Variant) -> bool: return node is Dictionary and String(node.get("node_type", "")) != "memory_link"
	).size()
	for index in range(existing_count, target_count):
		var card := AIClient.mock_memory_card()
		card["title"] = "家庭片段 %03d" % (index + 1)
		var node_type := "memory_flower"
		var slot_id := "garden_archive_flowers"
		if index % 7 == 5:
			node_type = "photo_board"
			slot_id = "garden_archive_photos"
		elif index % 7 == 6:
			node_type = "postcard"
			slot_id = "garden_archive_postcards"
		card["node_type"] = node_type
		var memory := MemoryManager.create_memory(card, "text")
		MemoryManager.create_node(
			String(memory.get("id", "")),
			"garden",
			node_type,
			slot_id
		)
	MemoryManager.save_game()

func _first_linked_item(items: Array) -> Dictionary:
	for raw_item in items:
		if raw_item is Dictionary and MemoryManager.count_memory_links_for_memory(String(raw_item.get("memory_id", "")), "garden") > 0:
			return raw_item
	return {}

func _count_world_memory_links() -> int:
	var count := 0
	for child in SceneManager.world.get_children():
		if String(child.name).begins_with("MemoryLink"):
			count += 1
	return count
