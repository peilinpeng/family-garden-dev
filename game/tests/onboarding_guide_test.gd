extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	MemoryManager._reset_all()
	MemoryManager.opening_seen = true
	MemoryManager.selected_role_key = "girl"
	MemoryManager.player_display_name = "佩林"
	MemoryManager.chapter1_tasks = {"open_box": true}
	StoryManager._pending_quest_intro = true
	_assert(StoryManager.consume_quest_intro(), "开场结束后应产生一次角色创建后的引导请求")
	_assert(not StoryManager.consume_quest_intro(), "开场引导请求只能被消费一次")

	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load("res://assets/backgrounds/shared_garden.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)

	var hud := GameHUD.new()
	add_child(hud)
	await get_tree().process_frame
	hud.set_context("garden")
	hud.start_onboarding_guide()
	await get_tree().process_frame
	_assert(hud.onboarding_guide_stage() == "quests", "进入花园后应先高亮任务入口")
	_assert(hud.onboarding_guide_target() == hud._quests_btn, "第一步目标应为底部任务按钮")
	await _capture("/tmp/family_garden_tutorial_step_quests.png")

	hud._on_quests_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(hud.onboarding_guide_stage() == "photo", "打开任务面板后应进入照片任务指引")
	var photo_action := hud.onboarding_guide_target() as Button
	_assert(photo_action != null and photo_action.name == "QuestAction_first_photo", "第二步应高亮第一张照片按钮")
	await _capture("/tmp/family_garden_tutorial_step_photo.png")

	if photo_action != null:
		photo_action.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(StoryManager.is_task_done("first_photo"), "点击照片按钮应完成第一张照片任务")
	_assert(hud.onboarding_guide_stage() == "map", "照片任务完成后应高亮地图入口")
	_assert(hud.onboarding_guide_target() == hud._map_btn, "第三步目标应为底部地图按钮")
	await _capture("/tmp/family_garden_tutorial_step_map.png")

	hud._on_map_pressed()
	await get_tree().process_frame
	_assert(hud.onboarding_guide_stage() == "", "点击地图后应结束强制高亮")
	_assert(MemoryManager.onboarding_guide_seen, "完成高亮流程后应保存已看状态")
	MemoryManager.onboarding_guide_seen = false
	MemoryManager.load_save()
	_assert(MemoryManager.onboarding_guide_seen, "重新读取存档后应保留已完成引导状态")

	background.queue_free()
	hud.queue_free()
	MemoryManager._reset_all()
	MemoryManager.save_game()
	await get_tree().process_frame
	if failures.is_empty():
		print("Onboarding guide tests passed: quests -> first photo -> map, persistence and click-through")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _capture(path: String) -> void:
	if not OS.has_environment("FG_CAPTURE_SCREENSHOTS"):
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
