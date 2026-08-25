extends Node

const STAGE_TEXTURE_PATTERN := "res://assets/garden/family_tree/stage_%d.png"

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	MemoryManager._reset_all()

	var expected_stages := {
		0: 1,
		1: 2,
		2: 2,
		3: 3,
		5: 3,
		6: 4,
		9: 4,
		10: 5,
		99: 5,
	}
	for interaction_count in expected_stages:
		MemoryManager.cross_member_interaction_count = int(interaction_count)
		_assert(
			MemoryManager.family_tree_stage() == int(expected_stages[interaction_count]),
			"互动量 %d 应对应家庭树第 %d 阶段" % [interaction_count, expected_stages[interaction_count]]
		)

	MemoryManager._reset_all()
	_assert(MemoryManager.grant_family_tree_gift(), "新玩家应收到一次家庭树幼苗")
	_assert(not MemoryManager.grant_family_tree_gift(), "家庭树幼苗不能重复领取")
	_assert(not MemoryManager.has_planted_family_tree(), "领取幼苗后不应自动替玩家选择种植位置")
	MemoryManager.plants.append({
		"id": MemoryManager.FAMILY_TREE_ID,
		"type": "family_tree",
		"x": 640.0,
		"y": 420.0,
	})
	_assert(MemoryManager.has_planted_family_tree(), "固定家庭树记录应被识别为已种植")
	MemoryManager.plants.clear()
	_assert(not MemoryManager.has_planted_family_tree(), "收回家庭树后应允许重新种植")
	_assert(MemoryManager.family_tree_gift_received, "收回家庭树不能重复触发开局赠礼")

	var previous_height := 0
	var previous_display_height := 0.0
	var stage_thresholds := [0, 1, 3, 6, 10]
	for stage in range(1, 6):
		MemoryManager.cross_member_interaction_count = stage_thresholds[stage - 1]
		var texture := load(STAGE_TEXTURE_PATTERN % stage) as Texture2D
		_assert(texture != null, "第 %d 阶段家庭树贴图应成功导入" % stage)
		if texture == null:
			continue
		_assert(texture.get_width() > 0 and texture.get_height() > previous_height, "家庭树应随阶段逐步增高")
		previous_height = texture.get_height()
		var image := texture.get_image()
		_assert(image.get_pixel(0, 0).a == 0.0, "第 %d 阶段贴图背景必须透明" % stage)
		var display_height := float(texture.get_height()) * SceneManager._family_tree_display_scale()
		_assert(display_height > previous_display_height, "家庭树场景显示高度应随阶段逐步增长")
		previous_display_height = display_height

	_assert(previous_display_height >= 220.0, "最终家庭树应保持足够醒目的完整尺寸")
	MemoryManager.cross_member_interaction_count = 0

	var item := preload("res://scripts/placeable_item.gd").new()
	add_child(item)
	var seedling := load(STAGE_TEXTURE_PATTERN % 1) as Texture2D
	item.setup({
		"id": MemoryManager.FAMILY_TREE_ID,
		"type": "family_tree",
		"position": Vector2(500, 400),
		"display_scale": SceneManager._family_tree_display_scale(),
		"bottom_anchored": true,
	}, seedling)
	_assert(is_equal_approx(item.sprite.position.y + seedling.get_height() * item.sprite.scale.y * 0.5, 0.0), "树根应固定在种植坐标")
	_assert(seedling.get_height() * item.sprite.scale.y < 100.0, "第 1 阶段幼苗应低于成年角色的视觉高度")
	item.queue_free()

	MemoryManager._reset_all()
	await get_tree().process_frame
	if failures.is_empty():
		print("Family tree growth tests passed: 5 stages, unique gift, replant and root anchor")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
