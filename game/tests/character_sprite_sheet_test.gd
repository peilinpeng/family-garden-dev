extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	var definition: Dictionary = CharacterDB.get_def("partner")
	var texture: Texture2D = CharacterDB.texture("partner")
	var rects: Array = definition.get("frame_rects", [])

	_assert(not definition.is_empty(), "伙伴角色配置应存在")
	_assert(int(definition.get("hframes", 0)) == 3, "boy 新图集应为 3 列")
	_assert(int(definition.get("vframes", 0)) == 5, "boy 新图集应为 5 行")
	_assert(texture != null, "boy.png 应成功导入 Godot")
	_assert(rects.size() == 15, "boy 新图集应配置完整 15 帧")
	_assert(is_equal_approx(float(definition.get("scale", 0.0)), 0.54), "伙伴显示比例应与主角视觉高度接近")

	if texture != null:
		for index in rects.size():
			var raw_rect: Variant = rects[index]
			_assert(raw_rect is Array and raw_rect.size() >= 4, "boy 第 %d 帧裁切配置应有效" % index)
			if not (raw_rect is Array and raw_rect.size() >= 4):
				continue
			var rect := Rect2(float(raw_rect[0]), float(raw_rect[1]), float(raw_rect[2]), float(raw_rect[3]))
			_assert(rect.position.x >= 0.0 and rect.position.y >= 0.0, "boy 第 %d 帧不能从图外开始" % index)
			_assert(rect.end.x <= texture.get_width() and rect.end.y <= texture.get_height(), "boy 第 %d 帧不能超出原图" % index)
			_assert(rect.size == Vector2(100.0, 180.0), "boy 第 %d 帧应使用统一尺寸，防止动画跳动" % index)
			var source_image := texture.get_image()
			var has_top_residue := false
			for source_y in range(int(rect.position.y), int(rect.position.y) + 8):
				for source_x in range(int(rect.position.x), int(rect.end.x)):
					if source_image.get_pixel(source_x, source_y).a > 0.0:
						has_top_residue = true
						break
				if has_top_residue:
					break
			_assert(not has_top_residue, "boy 第 %d 帧顶部不应夹带上一行残留像素" % index)

	var player: CharacterBody2D = load("res://scenes/Player.tscn").instantiate()
	add_child(player)
	player.apply_character("partner")
	_assert(player.frame_rects.size() == 15, "Player 应使用 boy 的 15 帧精确裁切")
	_assert(player.sprite != null and player.sprite.region_enabled, "Player 应开启精确裁切模式")
	_assert(player.sprite.scale.is_equal_approx(Vector2.ONE * 0.54), "玩家选择伙伴时应使用校正后的显示大小")
	_assert(is_equal_approx((player.get_node("Shadow") as Node2D).position.y, 48.6), "玩家伙伴的阴影应落在脚底")
	for offset_index in player.frame_offsets.size():
		var offset: Vector2 = player.frame_offsets[offset_index]
		_assert(offset.length() <= 3.1, "boy 第 %d 帧的人物中心和脚底应保持稳定，当前偏移 %s" % [offset_index, offset])
	for frame_index in [0, 4, 8, 11, 13]:
		player._set_frame(frame_index)
		_assert(player.sprite.region_rect == player.frame_rects[frame_index], "方向/待机帧 %d 应映射到正确区域" % frame_index)

	var avatar: Texture2D = CharacterDB.avatar_texture("partner")
	_assert(avatar is AtlasTexture, "伙伴头像应从新图集裁出 AtlasTexture")
	if avatar is AtlasTexture and rects.size() > 1:
		var idle_rect: Array = rects[1]
		_assert(avatar.region == Rect2(float(idle_rect[0]), float(idle_rect[1]), float(idle_rect[2]), float(idle_rect[3])), "伙伴头像应使用朝下站立帧")

	var remote_player: Node2D = load("res://scenes/RemotePlayer.tscn").instantiate()
	add_child(remote_player)
	remote_player.configure_presence("test-member", "partner", "伙伴")
	_assert(remote_player._frame_rects.size() == 15, "联机角色切换为伙伴时也应重新载入 15 帧裁切")
	_assert(remote_player.sprite.region_enabled, "联机伙伴应开启精确裁切模式")
	_assert(remote_player.sprite.region_rect == remote_player._frame_rects[1], "联机伙伴初始帧应完整显示朝下站立姿势")
	_assert(is_equal_approx((remote_player.get_node("Shadow") as Node2D).position.y, 48.6), "联机伙伴的阴影应落在脚底")

	var garden_npc: CharacterBody2D = SceneManager._create_character(
		"伙伴",
		"res://assets/characters/boy.png",
		Vector2.ZERO,
		false,
		3,
		5,
		rects,
		float(definition.get("scale", 0.46))
	)
	garden_npc.set_script(preload("res://scripts/npc_wander.gd"))
	garden_npc.set_meta("sprite_hframes", 3)
	garden_npc.set_meta("sprite_vframes", 5)
	garden_npc.call("set_frame_rects", rects)
	add_child(garden_npc)
	await get_tree().process_frame
	_assert(garden_npc.sprite_hframes == 3 and garden_npc.sprite_vframes == 5, "Garden 伙伴 NPC 应保留 3x5 逻辑动画网格")
	_assert(garden_npc.sprite.hframes == 1 and garden_npc.sprite.vframes == 1, "Garden 精确裁切渲染应保持 1x1")
	_assert(garden_npc.sprite.scale.is_equal_approx(Vector2.ONE * 0.54), "Garden 伙伴 NPC 应使用校正后的显示大小")
	_assert(is_equal_approx((garden_npc.get_node("Shadow") as Node2D).position.y, 48.6), "Garden 伙伴 NPC 的阴影应落在脚底")
	for facing_row in range(4):
		garden_npc.facing_row = facing_row
		garden_npc._update_walk_animation(0.0, false)
		_assert(garden_npc.sprite.region_rect == garden_npc._frame_rects[facing_row * 3 + 1], "Garden 伙伴 NPC 的方向 %d 应显示对应站立帧" % facing_row)
	garden_npc.facing_row = 0
	garden_npc.step_index = 0
	garden_npc._update_walk_animation(0.25, true)
	_assert(garden_npc.sprite.region_rect == garden_npc._frame_rects[1], "Garden 伙伴 NPC 应推进三步行走帧")

	player.queue_free()
	remote_player.queue_free()
	garden_npc.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("Character sprite sheet tests passed: partner boy 3x5 crop and import")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
