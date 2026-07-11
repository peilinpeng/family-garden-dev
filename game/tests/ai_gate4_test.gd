extends Node

const ROOM_SCENE_GENERATOR := preload("res://scripts/managers/room_scene_generator.gd")

class FakePersistence:
	extends Node
	var uploads: Dictionary = {}
	var persisted: Array = []
	var deleted: Array = []
	var upload_count := 0

	func persist_record(table: String, row: Dictionary) -> void:
		persisted.append({"table": table, "row": row.duplicate(true)})

	func load_table(_table: String, _query: String = "") -> Array:
		return []

	func delete_record(table: String, row_id: String) -> void:
		deleted.append({"table": table, "id": row_id})

	func upload_image(bytes: PackedByteArray, content_type: String) -> Dictionary:
		upload_count += 1
		var upload_id := "upload_test_%d" % upload_count
		uploads[upload_id] = {"bytes": bytes, "content_type": content_type}
		return {"ok": true, "upload_id": upload_id, "image_url": "https://example.test/%s.jpg" % upload_id}

	func resolve_image(upload_id: String) -> Dictionary:
		return {"ok": uploads.has(upload_id), "image_url": "https://example.test/%s.jpg" % upload_id}

	func delete_image(upload_id: String) -> bool:
		return uploads.erase(upload_id)

class FakeAIBackend:
	extends Node
	var calls: Dictionary = {}

	func request(path: String, payload: Dictionary) -> Dictionary:
		var route := path.get_file()
		calls[route] = int(calls.get(route, 0)) + 1
		var data: Dictionary = {}
		match route:
			"generate-memory-card":
				data = AIClient.mock_memory_card()
			"generate-bottle-question":
				data = AIClient.MOCK_BOTTLE_QUESTION.duplicate(true)
				data["question"] = "第 %d 次生成：你最想和家人重温哪段温暖时光？" % int(calls[route])
			"analyze-room-photo":
				data = AIClient.mock_room_analysis()
			"cross-memory-link":
				var candidates: Array = payload.get("candidates", [])
				data = {"links": []}
				if not candidates.is_empty():
					data.links.append({
						"memory_id_a": String(payload.get("memory_id", "")),
						"memory_id_b": String(candidates[0].get("memory_id", "")),
						"relation_type": "same_theme",
						"confidence": 0.86,
						"question": "这两段记忆里，有没有相似的家庭温度？",
						"node_type": "memory_link",
					})
		return {
			"ok": true,
			"data": data,
			"meta": {
				"request_id": "gate4_" + route,
				"provider": "fake",
				"model": "fake-model",
				"prompt_version": route + "-test",
				"source": "ai",
				"result": "empty" if route == "cross-memory-link" and data.get("links", []).is_empty() else "complete",
			},
		}

	func cache_namespace() -> String:
		return "gate4-test"

	func cache_ttl_seconds() -> float:
		return 0.0

var failures: Array[String] = []
var persistence: FakePersistence
var ai_backend: FakeAIBackend

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	persistence = FakePersistence.new()
	get_tree().root.add_child(persistence)
	CloudManager.set_persistence_backend(persistence)
	ai_backend = FakeAIBackend.new()
	get_tree().root.add_child(ai_backend)
	AIClient.set_backend(ai_backend)
	MemoryManager._reset_all()
	MemoryManager.selected_role_key = "player"

	_test_image_preparation()
	_test_memory_visual_assets()
	_test_family_portrait_miniature()
	await _test_memory_draft_and_idempotency()
	await _test_bottle_recovery_and_answer_idempotency()
	await _test_room_preview_commit_and_editing()
	_test_delete_memory_cascades_links()

	if failures.is_empty():
		print("Gate 4 Godot tests passed: image, visuals, draft, commit, bottle, room, links, delete")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _test_image_preparation() -> void:
	var image := Image.create(2200, 1100, false, Image.FORMAT_RGB8)
	image.fill(Color(0.35, 0.62, 0.42))
	var prepared := AIImageUploadService.prepare(image.save_png_to_buffer(), "image/png")
	_assert(prepared.ok, "合法 PNG 应可预处理")
	_assert(prepared.content_type == "image/jpeg", "上传应统一重编码并去元数据")
	_assert(maxi(prepared.output_size.x, prepared.output_size.y) <= 1600, "图片长边必须限制到 1600")
	_assert(not AIImageUploadService.prepare(PackedByteArray([1, 2, 3]), "image/gif").ok, "GIF 必须拒绝")

func _test_memory_visual_assets() -> void:
	var slot := {"slot_id": "visual_test", "pos": [320, 320]}
	var bud := NodeFactory.make_memory_node(AIClient.mock_memory_card(), slot, Callable(), "new")
	var bloom := NodeFactory.make_memory_node(AIClient.mock_memory_card(), slot, Callable(), "grown")
	var bud_texture := (bud.get_node("Sprite") as Sprite2D).texture
	var bloom_texture := (bloom.get_node("Sprite") as Sprite2D).texture
	_assert(bud_texture != null and bloom_texture != null, "记忆花苞与开放状态必须有可渲染资产")
	_assert(bud_texture != bloom_texture, "花苞与开放状态应使用不同视觉资产")
	for node_type in ["photo_board", "postcard"]:
		var board_card := {"node_type": node_type, "suggested_scene": "garden"}
		var board := NodeFactory.make_memory_node(board_card, slot, Callable(), "new")
		_assert((board.get_node("Sprite") as Sprite2D).texture != null, "%s 必须有受控木牌资产" % node_type)
		_assert(board.has_node("BoardSemanticIcon"), "%s 必须带可识别语义图标" % node_type)
		board.queue_free()
	var archive_keys := ["flowers", "photos", "postcards"]
	for archive_key in archive_keys:
		var archive := NodeFactory.make_memory_archive(String(archive_key), slot, Callable(), "grown")
		_assert((archive.get_node("Sprite") as Sprite2D).texture != null, "%s 归档景观必须可渲染" % archive_key)
		if archive_key == "flowers":
			_assert(not (archive.get_node("Sprite") as Sprite2D).visible, "记忆花圃应复用背景花丛，不再叠加独立花盆")
			_assert(archive.has_node("ArchiveAmbientGlow") and archive.has_node("ArchiveHoverGlow"), "背景花圃必须有轻量可发现反馈")
			var archive_shape := archive.get_node("ClickArea/Shape") as CollisionShape2D
			var archive_rect := archive_shape.shape as RectangleShape2D
			_assert(archive_rect != null and archive_rect.size.x >= 180.0 and archive_rect.size.y >= 120.0, "背景花圃点击区必须覆盖整片花丛")
		else:
			_assert(not (archive.get_node("Sprite") as Sprite2D).visible, "%s 归档不应继续显示通用木牌" % archive_key)
			_assert(archive.has_node("ArchiveVisual") and archive.has_node("ArchiveObjectGlow"), "%s 必须使用回忆角专属景观物件" % archive_key)
		archive.queue_free()
	_assert(NodeFactory.garden_archive_key("memory_flower") == "flowers", "记忆花必须归入花圃")
	_assert(NodeFactory.garden_archive_key("photo_board") == "photos", "照片牌必须归入家庭影像")
	_assert(NodeFactory.garden_archive_key("postcard") == "postcards", "明信片必须归入远方来信")
	var slots_text := FileAccess.get_file_as_string("res://assets/manifest/slots_garden.json")
	var slots_data: Variant = JSON.parse_string(slots_text)
	var archive_slot_count := 0
	if slots_data is Dictionary:
		for raw_slot in slots_data.get("slots", []):
			if raw_slot is Dictionary and String(raw_slot.get("visual_role", "")) == "archive":
				archive_slot_count += 1
	_assert(archive_slot_count == 3, "花园长期可见记忆景观必须固定为三个")
	bud.queue_free()
	bloom.queue_free()

func _test_family_portrait_miniature() -> void:
	var previous := MemoryManager.family_portrait.duplicate(true)
	MemoryManager.family_portrait = {
		"version": 1,
		"member_count": 2,
		"memory_count": 12,
		"members": ["papa", "mama"],
	}
	var host := Panel.new()
	SceneManager._add_family_portrait_miniature(host)
	_assert(host.has_node("FamilyPortraitMiniature"), "家庭画像必须进入左上状态卡")
	var portrait := host.get_node_or_null("FamilyPortraitMiniature")
	_assert(portrait != null and portrait.has_node("FamilyAvatar_0") and portrait.has_node("FamilyAvatar_1"), "两位家人必须显示为两张独立角色立绘")
	_assert(portrait != null and not portrait.has_node("FamilyAvatar_2"), "两人合影不应生成多余角色")
	_assert(SceneManager._family_portrait_frame_texture("papa") != null, "爸爸画像必须能裁出正面静止帧")
	_assert(SceneManager._family_portrait_frame_texture("girl") != null, "主角画像必须能使用精确裁剪框")
	host.queue_free()
	MemoryManager.family_portrait = previous

func _test_memory_draft_and_idempotency() -> void:
	var seed := MemoryManager.create_memory(AIClient.mock_memory_card(), "text", "旧记忆", "", {}, "seed-memory")
	var before := MemoryManager.memories.size()
	var text_draft: Dictionary = await AIWorkflowManager.prepare_memory_draft("今天和家人一起种了一棵树。")
	_assert(text_draft.ok, "仅文字应生成草稿")
	_assert(MemoryManager.memories.size() == before, "生成草稿前不得落库")

	var image := Image.create(128, 96, false, Image.FORMAT_RGB8)
	image.fill(Color(0.7, 0.5, 0.3))
	var jpg := image.save_jpg_to_buffer()
	var photo_draft: Dictionary = await AIWorkflowManager.prepare_memory_draft("", jpg, "image/jpeg")
	_assert(photo_draft.ok and photo_draft.upload_id != "", "仅图片应生成草稿并受控上传")
	var combo_draft: Dictionary = await AIWorkflowManager.prepare_memory_draft("图文组合记忆", jpg, "image/jpeg")
	_assert(combo_draft.ok, "图文组合应生成草稿")
	await AIWorkflowManager.discard_draft(photo_draft)
	await AIWorkflowManager.discard_draft(combo_draft)

	var committed: Dictionary = await AIWorkflowManager.commit_memory_draft(text_draft, text_draft.card, true)
	_assert(committed.ok, "合法草稿应可确认")
	var memory_count := MemoryManager.memories.size()
	var node_count := MemoryManager.nodes.size()
	var duplicate: Dictionary = await AIWorkflowManager.commit_memory_draft(text_draft, text_draft.card, true)
	_assert(duplicate.ok, "重复确认应返回既有结果")
	_assert(MemoryManager.memories.size() == memory_count and MemoryManager.nodes.size() == node_count, "重复确认不得生成重复 memory/node/link")
	_assert(MemoryManager.get_memory_links("garden").size() == 1, "新记忆应创建一条合格跨记忆关联")
	_assert(MemoryManager.count_memory_links_for_memory(String(committed.memory.get("id", "")), "garden") == 1, "新记忆应可统计到自己的关联")
	var endpoints := MemoryManager.get_memory_link_endpoints(MemoryManager.get_memory_links("garden")[0])
	_assert(bool(endpoints.get("ok", false)), "关联详情应能查到两端记忆")
	_assert(String(endpoints.get("memory_a", {}).get("id", "")) != String(endpoints.get("memory_b", {}).get("id", "")), "关联两端不能是同一条记忆")
	var link_id := String(MemoryManager.get_memory_links("garden")[0].get("id", ""))
	var answered: Dictionary = MemoryManager.answer_memory_link(link_id, "这两段记忆都和一家人在花园里的陪伴有关。")
	_assert(answered.ok and not bool(answered.get("updated", false)), "关联回答应可首次保存")
	_assert(MemoryManager.is_memory_link_answered(answered.link), "保存后关联应进入已回答状态")
	var link_count := MemoryManager.get_memory_links("garden").size()
	var updated: Dictionary = MemoryManager.answer_memory_link(link_id, "更新后的补充：它们都在讲一家人的陪伴。")
	_assert(updated.ok and bool(updated.get("updated", false)), "关联回答应可更新")
	_assert(MemoryManager.get_memory_links("garden").size() == link_count, "更新关联回答不得创建新 link")
	_assert(String(updated.link.get("followup_answer", "")) == "更新后的补充：它们都在讲一家人的陪伴。", "关联回答应保存最新文本")
	_assert(not MemoryManager.answer_memory_link(link_id, "").ok, "空关联回答必须拒绝")
	_assert(String(seed.get("id", "")) != String(committed.memory.get("id", "")), "新旧记忆 ID 应不同")

func _test_bottle_recovery_and_answer_idempotency() -> void:
	var bottles: Array = await AIWorkflowManager.ensure_bottles(2)
	_assert(bottles.size() == 2, "应异步补齐两个真实漂流瓶")
	var count := MemoryManager.get_bottles().size()
	await AIWorkflowManager.ensure_bottles(2)
	_assert(MemoryManager.get_bottles().size() == count, "重入鱼塘不得重复生成漂流瓶")
	var bottle_id := String(bottles[0].get("id", ""))
	var first: Dictionary = await AIWorkflowManager.answer_bottle(bottle_id, "我们一起在湖边看过日落。")
	var memory_count := MemoryManager.memories.size()
	var answer_count := MemoryManager.answers.size()
	var second: Dictionary = await AIWorkflowManager.answer_bottle(bottle_id, "重复回答")
	_assert(first.ok and second.ok and second.duplicate, "第二次回答应识别为幂等重复")
	_assert(MemoryManager.memories.size() == memory_count and MemoryManager.answers.size() == answer_count, "重复回答不得创建岸边记忆或 answer")

func _test_room_preview_commit_and_editing() -> void:
	var image := Image.create(320, 240, false, Image.FORMAT_RGB8)
	image.fill(Color(0.75, 0.72, 0.62))
	var draft: Dictionary = await AIWorkflowManager.prepare_room_draft(image.save_jpg_to_buffer(), "image/jpeg")
	_assert(draft.ok, "房间图片应完成上传、分析和安全布局预览")
	var before := MemoryManager.rooms.size()
	_assert(before == 0, "房间预览阶段不得落库")
	var committed: Dictionary = await AIWorkflowManager.commit_room_draft(draft)
	_assert(committed.ok and MemoryManager.rooms.size() == 1, "确认后应创建一个房间")
	_assert(ROOM_SCENE_GENERATOR.has_scene_schema(MemoryManager.rooms[0]), "确认后应保存可重建的语义房间 schema")
	var object_count := MemoryManager.room_objects.size()
	await AIWorkflowManager.commit_room_draft(draft)
	_assert(MemoryManager.rooms.size() == 1 and MemoryManager.room_objects.size() == object_count, "重复确认房间不得重复写入")
	var first_object: Dictionary = MemoryManager.room_objects[0]
	_assert(RoomLayoutManager.move_object(String(first_object.id), String(first_object.zone)), "家具应可移动/重分配到合法区域")
	_assert(MemoryManager.delete_room_object(String(first_object.id)), "单件家具应可删除")
	_assert(MemoryManager.room_objects.size() == object_count - 1, "删除家具应即时更新数据")

func _test_delete_memory_cascades_links() -> void:
	var links := MemoryManager.get_memory_links("garden")
	if links.is_empty():
		_assert(false, "删除级联测试需要已有连线")
		return
	var memory_id := String(links[0].get("memory_id", ""))
	_assert(MemoryManager.delete_memory(memory_id), "记忆应可删除")
	_assert(not MemoryManager.nodes.any(func(node): return String(node.get("memory_id", "")) == memory_id or String(node.get("linked_memory_id", "")) == memory_id), "删除记忆必须级联清理节点与连线")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
