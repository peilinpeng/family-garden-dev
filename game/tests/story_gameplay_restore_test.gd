extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	_test_parent_variants()
	_test_fishing_restore()
	_test_farm_guidance_assets()
	_test_three_chapters()
	if failures.is_empty():
		print("Story gameplay restore tests passed: parents, fishing, farm guidance and three chapters")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _test_parent_variants() -> void:
	for role in ["father", "mother"]:
		var appearance := AppearanceManager.default_for_role(role)
		for outfit in ["original", "forest", "berry", "ocean", "sand"]:
			appearance["outfit"] = outfit
			var texture := AppearanceManager.texture(appearance, role)
			_assert(texture != null, "%s 的 %s 服装应有统一风格图集" % [role, outfit])
			_assert(texture.resource_path.contains("/characters/parents/"), "%s 不应回退到旧 papa/mama 素材" % role)
			_assert(AppearanceManager.frame_rects(appearance, role).size() == 15, "%s 应保留 15 帧动作" % role)

func _test_fishing_restore() -> void:
	var pond: Node = (load("res://scenes/pond/pond_area.tscn") as PackedScene).instantiate()
	_assert(pond.get_node_or_null("FishingSpot") is Area2D, "池塘场景应保留 FishingSpot")
	pond.queue_free()
	for method in ["_register_pond_fishing_spot", "_start_fishing_sequence", "_pick_fishing_result", "_open_caught_bottle_content"]:
		_assert(SceneManager.has_method(method), "SceneManager 应恢复钓鱼方法 %s" % method)
	for path in [
		"res://assets/pond/props/fishing_rod.png",
		"res://assets/pond/props/fishing_bobber.png",
		"res://assets/pond/bottle/bottle_float_01.png",
	]:
		_assert(ResourceLoader.exists(path), "钓鱼素材缺失：" + path)

func _test_farm_guidance_assets() -> void:
	for action in ["seed", "water", "fertilize", "grow", "harvest"]:
		_assert(ResourceLoader.exists("res://assets/farm/action_icons/%s.png" % action), "农场动作图标缺失：" + action)
	var picker := SeedSelectionPanel.new()
	picker.target_plot = 0
	add_child(picker)
	_assert(picker.has_signal("seed_planted"), "种子选择栏应把播种结果回传农场")
	picker.queue_free()

func _test_three_chapters() -> void:
	_assert(StoryManager.CHAPTERS.size() == 3, "主线应包含三章")
	_assert(StoryManager.tasks(1).size() == 7, "第一章应覆盖编辑、种植、料理循环")
	_assert(StoryManager.tasks(2).size() == 4, "第二章应覆盖钓鱼、漂流瓶、留点和明信片")
	_assert(StoryManager.tasks(3).size() == 3, "第三章应在第一次 AI 房间生成结束")
	var flower: Dictionary = StoryManager.CARDS.get("first_memory_flower", {})
	_assert(str(flower.get("desc", "")).contains("河边的风吹过衣角"), "第一朵记忆花应保存指定生活片段")
	var milestones := StoryManager.milestone_status()
	_assert(milestones.size() == 2, "主线后应提供等级 2 和等级 3 成长目标")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
