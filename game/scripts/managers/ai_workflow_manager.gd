extends Node

## Gate 4 产品工作流：把上传、AI 草稿、用户确认和数据提交分开。
## prepare_* 永不写 memories/nodes/rooms；commit_* 通过 workflow_key 保证幂等。

signal workflow_state_changed(workflow: String, state: String, detail: Dictionary)

const LINK_CONFIDENCE_THRESHOLD := 0.65
const MAX_LINK_CANDIDATES := 12
const SUPPORTED_MEMORY_SCENES := ["garden", "fishpond"]

func prepare_memory_draft(raw_text: String, image_bytes: PackedByteArray = PackedByteArray(), content_type: String = "") -> Dictionary:
	var text := raw_text.strip_edges()
	if text.length() > 2000:
		return _failure("TEXT_TOO_LONG", "文字不能超过 2000 个字符。")
	if text == "" and image_bytes.is_empty():
		return _failure("EMPTY_INPUT", "请输入文字或选择照片。")
	var workflow_key := _workflow_key("memory", text, image_bytes)
	var image := await _upload_if_present("memory", image_bytes, content_type)
	if not image_bytes.is_empty() and not bool(image.get("ok", false)):
		return image
	_emit("memory", "generating", {"workflow_key": workflow_key})
	var outcome: Dictionary = await AIClient.request_memory_card(String(image.get("upload_id", "")), text, "draft_" + workflow_key.left(24))
	var card := _dictionary_or_empty(outcome.get("data"))
	if card.is_empty():
		return _failure_from_outcome(outcome)
	var draft := {
		"ok": true,
		"kind": "memory",
		"workflow_key": workflow_key,
		"raw_text": text,
		"input_type": "photo" if text == "" else ("text" if image_bytes.is_empty() else "photo"),
		"card": card.duplicate(true),
		"generation_meta": _dictionary_or_empty(outcome.get("meta")).duplicate(true),
		"used_fallback": bool(outcome.get("used_fallback", false)),
		"upload_id": String(image.get("upload_id", "")),
		"image_url": "",
	}
	_emit("memory", "draft_ready", draft)
	return draft

func commit_memory_draft(draft: Dictionary, edited_card: Dictionary, wait_for_links: bool = false) -> Dictionary:
	await flush_ai_sync_outbox()
	await retry_pending_links(2)
	if String(draft.get("kind", "")) != "memory":
		return _failure("INVALID_DRAFT", "这不是记忆卡草稿。")
	var validation := AIContractValidator.validate_data("generate-memory-card", edited_card)
	if not bool(validation.get("ok", false)):
		return _failure("INVALID_CARD", "; ".join(validation.get("errors", [])))
	var card := edited_card.duplicate(true)
	var workflow_key := String(draft.get("workflow_key", ""))
	for existing_memory in MemoryManager.memories:
		if existing_memory is Dictionary and String(existing_memory.get("workflow_key", "")) == workflow_key:
			var existing_node: Dictionary = {}
			for candidate_node in MemoryManager.nodes:
				if candidate_node is Dictionary and String(candidate_node.get("workflow_key", "")) == "memory_node:" + workflow_key:
					existing_node = candidate_node
					break
			return {"ok": true, "memory": existing_memory, "node": existing_node, "duplicate": true}
	var moderation := await AIClient.moderate_user_content([
		String(card.get("title", "")),
		String(card.get("description", "")),
		String(card.get("question", "")),
		String(card.get("guess", "")),
	], "memory_card_edit")
	if String(moderation.get("state", "")) != AIClient.STATE_SUCCESS:
		return _failure_from_outcome(moderation)
	var scene := String(card.get("suggested_scene", "garden"))
	if scene not in SUPPORTED_MEMORY_SCENES:
		scene = "garden"
		card["suggested_scene"] = scene
	var node_type := String(card.get("node_type", "memory_flower"))
	if scene == "fishpond" and node_type not in ["memory_flower", "photo_board"]:
		node_type = "memory_flower"
	if scene == "garden" and node_type not in ["memory_flower", "memory_seed", "photo_board", "postcard"]:
		node_type = "memory_flower"
	card["node_type"] = node_type
	_prepare_slots(scene)
	var slot: Variant = SlotManager.allocate(scene, node_type, "pending_" + workflow_key.left(16))
	if slot == null and scene != "garden":
		scene = "garden"
		node_type = "memory_flower"
		card["suggested_scene"] = scene
		card["node_type"] = node_type
		_prepare_slots(scene)
		slot = SlotManager.allocate(scene, node_type, "pending_" + workflow_key.left(16))
	if slot == null:
		return _failure("NO_SLOT", "当前场景没有可用的记忆位置。")
	var memory := MemoryManager.create_memory(
		card,
		String(draft.get("input_type", "text")),
		String(draft.get("raw_text", "")),
		"",
		draft.get("generation_meta", {}),
		workflow_key,
		String(draft.get("upload_id", "")),
	)
	var node := MemoryManager.create_node(String(memory.get("id", "")), scene, node_type, String(slot.get("slot_id", "")), "", "memory_node:" + workflow_key)
	var synced := await _confirm_records([
		{"table": "memories", "row": memory},
		{"table": "nodes", "row": node},
	])
	if wait_for_links:
		await create_links_for_memory(memory)
	else:
		_create_links_after_commit(memory.duplicate(true))
	MemoryManager.maybe_recompute_family_portrait()
	_emit("memory", "committed", {"memory": memory, "node": node})
	return {"ok": true, "memory": memory, "node": node, "sync_pending": not synced}

func _create_links_after_commit(memory: Dictionary) -> void:
	await create_links_for_memory(memory)

func discard_draft(draft: Dictionary) -> void:
	var upload_id := String(draft.get("upload_id", ""))
	if upload_id != "":
		await CloudManager.delete_ai_image(upload_id)

func create_links_for_memory(memory: Dictionary) -> Array:
	var source_id := String(memory.get("id", ""))
	MemoryManager.set_memory_link_status(source_id, "generating")
	var ranked: Array = []
	for index in range(MemoryManager.memories.size() - 1, -1, -1):
		var candidate: Variant = MemoryManager.memories[index]
		if not candidate is Dictionary or String(candidate.get("id", "")) == source_id:
			continue
		var card: Variant = candidate.get("ai_card", {})
		if not card is Dictionary or card.is_empty() or _already_linked(source_id, String(candidate.get("id", ""))):
			continue
		ranked.append({"memory": candidate, "score": _candidate_relevance(memory, candidate, MemoryManager.memories.size() - 1 - index)})
	ranked.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	var candidates: Array = []
	for item in ranked.slice(0, MAX_LINK_CANDIDATES):
		candidates.append(item.get("memory", {}))
	if candidates.is_empty():
		MemoryManager.set_memory_link_status(source_id, "complete")
		return []
	_emit("links", "generating", {"memory_id": source_id})
	var outcome := await AIClient.request_memory_links(memory, candidates)
	var result := _dictionary_or_empty(outcome.get("data"))
	var meta := _dictionary_or_empty(outcome.get("meta"))
	if String(outcome.get("state", "")) in [AIClient.STATE_ERROR, AIClient.STATE_CANCELLED]:
		var outcome_error := _dictionary_or_empty(outcome.get("error"))
		MemoryManager.set_memory_link_status(source_id, "pending" if bool(outcome_error.get("retryable", false)) else "failed")
		return []
	var created: Array = []
	for raw_link in result.get("links", []):
		if not raw_link is Dictionary or float(raw_link.get("confidence", 0.0)) < LINK_CONFIDENCE_THRESHOLD:
			continue
		var a := String(raw_link.get("memory_id_a", ""))
		var b := String(raw_link.get("memory_id_b", ""))
		if a == b or source_id not in [a, b] or _already_linked(a, b):
			continue
		var other := b if a == source_id else a
		if MemoryManager.get_memory(other).is_empty():
			continue
		if String(raw_link.get("relation_type", "")) == "same_people" and not _supports_people_relation(memory, MemoryManager.get_memory(other)):
			continue
		var link := MemoryManager.create_memory_link(a, b, String(memory.get("ai_card", {}).get("suggested_scene", "garden")), String(raw_link.get("relation_type", "same_theme")), String(raw_link.get("question", "")), float(raw_link.get("confidence", 0.0)), meta)
		if not link.is_empty():
			await _confirm_records([{"table": "nodes", "row": link}])
			created.append(link)
	_emit("links", "complete", {"created": created.size()})
	MemoryManager.set_memory_link_status(source_id, "complete")
	return created

func retry_pending_links(limit: int = 3) -> int:
	var retried := 0
	for memory in MemoryManager.memories:
		if retried >= limit:
			break
		if memory is Dictionary and String(memory.get("link_status", "")) == "pending":
			retried += 1
			await create_links_for_memory(memory)
	return retried

func ensure_bottles(target_count: int = 2) -> Array:
	_prepare_slots("fishpond")
	var bottles := MemoryManager.get_bottles()
	var attempts := 0
	while bottles.size() < target_count and attempts < target_count * 3:
		attempts += 1
		var slot: Variant = SlotManager.allocate("fishpond", "bottle", "pending_bottle_%d" % attempts)
		if slot == null:
			break
		_emit("bottle", "generating", {"attempt": attempts})
		var outcome := await AIClient.request_bottle_question({
			"scene": "fishpond",
			"target_memory_type": "shared_memory",
			"memory_stats": _memory_stats(),
		})
		var card := _dictionary_or_empty(outcome.get("data"))
		if card.is_empty():
			SlotManager.release("fishpond", String(slot.get("slot_id", "")))
			break
		var bottle := MemoryManager.create_bottle(card, String(slot.get("slot_id", "")), _dictionary_or_empty(outcome.get("meta")))
		if bottle.is_empty() or bottles.any(func(item): return String(item.get("id", "")) == String(bottle.get("id", ""))):
			SlotManager.release("fishpond", String(slot.get("slot_id", "")))
			continue
		await _confirm_records([{"table": "nodes", "row": bottle}])
		bottles.append(bottle)
	_emit("bottle", "complete", {"count": bottles.size()})
	return bottles

func answer_bottle(bottle_id: String, answer_text: String) -> Dictionary:
	var text := answer_text.strip_edges()
	if text == "":
		return _failure("EMPTY_ANSWER", "请先写下回答。")
	if text.length() > 2000:
		return _failure("TEXT_TOO_LONG", "回答不能超过 2000 个字符。")
	var bottle: Dictionary = {}
	for item in MemoryManager.get_bottles():
		if String(item.get("id", "")) == bottle_id:
			bottle = item
			break
	if bottle.is_empty():
		return _failure("BOTTLE_NOT_FOUND", "这个漂流瓶不存在。")
	var existing_id := String(bottle.get("answer_memory_id", ""))
	if existing_id != "":
		return {"ok": true, "memory": MemoryManager.get_memory(existing_id), "duplicate": true}
	var moderation := await AIClient.moderate_user_content([text], "bottle_answer")
	if String(moderation.get("state", "")) != AIClient.STATE_SUCCESS:
		return _failure_from_outcome(moderation)
	_prepare_slots("fishpond")
	var slot: Variant = SlotManager.allocate("fishpond", "memory_flower", bottle_id + "_memory")
	if slot == null:
		return _failure("NO_SLOT", "鱼塘岸边暂时没有空位。")
	var question := String(bottle.get("question", ""))
	var card := {
		"title": "漂流瓶里的家庭记忆",
		"description": text.left(300),
		"memory_type": "daily_life",
		"suggested_scene": "fishpond",
		"question": question if question.length() >= 8 else "关于这段家庭记忆，你还想补充什么？",
		"node_type": "memory_flower",
		"confidence": 1.0,
		"safety_note": "内容由家庭成员主动填写。",
	}
	var workflow_key := "bottle_answer:" + bottle_id
	var memory := MemoryManager.create_memory(card, "bottle_answer", text, "", bottle.get("generation_meta", {}), workflow_key)
	if MemoryManager.mark_bottle_answered(bottle_id, text, String(memory.get("id", ""))):
		var node := MemoryManager.create_node(String(memory.get("id", "")), "fishpond", "memory_flower", String(slot.get("slot_id", "")), "", "bottle_node:" + bottle_id)
		MemoryManager.answer_memory(String(memory.get("id", "")), text)
		var records: Array = [{"table": "memories", "row": memory}, {"table": "nodes", "row": node}]
		for answer in MemoryManager.answers:
			if answer is Dictionary and String(answer.get("memory_id", "")) == String(memory.get("id", "")):
				records.append({"table": "answers", "row": answer})
		var synced := await _confirm_records(records)
		return {"ok": true, "memory": memory, "duplicate": false, "sync_pending": not synced}
	else:
		MemoryManager.delete_memory(String(memory.get("id", "")))
		SlotManager.release("fishpond", String(slot.get("slot_id", "")))
		return _failure("SAVE_FAILED", "漂流瓶回答没有成功保存。")

func save_memory_answer(memory_id: String, answer_text: String) -> Dictionary:
	var text := answer_text.strip_edges()
	if text == "":
		return _failure("EMPTY_ANSWER", "请先写下回答。")
	if text.length() > 2000:
		return _failure("TEXT_TOO_LONG", "回答不能超过 2000 个字符。")
	if MemoryManager.get_memory(memory_id).is_empty():
		return _failure("MEMORY_NOT_FOUND", "这段记忆已经不存在。")
	var moderation := await AIClient.moderate_user_content([text], "memory_answer")
	if String(moderation.get("state", "")) != AIClient.STATE_SUCCESS:
		return _failure_from_outcome(moderation)
	MemoryManager.answer_memory(memory_id, text)
	var records: Array = []
	for answer in MemoryManager.answers:
		if answer is Dictionary and String(answer.get("memory_id", "")) == memory_id:
			records = [{"table": "answers", "row": answer}]
	for node in MemoryManager.nodes:
		if node is Dictionary and String(node.get("memory_id", "")) == memory_id:
			records.append({"table": "nodes", "row": node})
	var synced := await _confirm_records(records)
	return {"ok": true, "sync_pending": not synced}

func save_memory_link_followup(link_id: String, answer_text: String) -> Dictionary:
	var text := answer_text.strip_edges()
	if text == "":
		return _failure("EMPTY_ANSWER", "先写一点补充，再保存。")
	if text.length() > 1200:
		return _failure("ANSWER_TOO_LONG", "补充内容不能超过 1200 个字。")
	var moderation := await AIClient.moderate_user_content([text], "memory_link_followup")
	if String(moderation.get("state", "")) != AIClient.STATE_SUCCESS:
		return _failure_from_outcome(moderation)
	var result := MemoryManager.answer_memory_link(link_id, text)
	if not bool(result.get("ok", false)):
		return result
	var synced := await _confirm_records([{"table": "nodes", "row": result.get("link", {})}])
	result["sync_pending"] = not synced
	return result

func prepare_room_draft(image_bytes: PackedByteArray, content_type: String) -> Dictionary:
	if image_bytes.is_empty():
		return _failure("EMPTY_IMAGE", "请先选择房间照片。")
	var workflow_key := _workflow_key("room", "", image_bytes)
	var image := await _upload_if_present("room", image_bytes, content_type)
	if not bool(image.get("ok", false)):
		return image
	_emit("room", "analyzing", {"workflow_key": workflow_key})
	var outcome: Dictionary = await AIClient.request_room_analysis(String(image.get("upload_id", "")), "room_" + workflow_key.left(24))
	var analysis := _dictionary_or_empty(outcome.get("data"))
	if analysis.is_empty():
		await CloudManager.delete_ai_image(String(image.get("upload_id", "")))
		return _failure_from_outcome(outcome)
	var layout := RoomLayoutManager.plan(analysis)
	if not bool(layout.get("ok", false)):
		await CloudManager.delete_ai_image(String(image.get("upload_id", "")))
		return _failure("INVALID_LAYOUT", "识别结果没有可安全摆放的家具。")
	var draft := {
		"ok": true,
		"kind": "room",
		"workflow_key": workflow_key,
		"analysis": analysis.duplicate(true),
		"layout": layout,
		"generation_meta": _dictionary_or_empty(outcome.get("meta")).duplicate(true),
		"used_fallback": bool(outcome.get("used_fallback", false)),
		"upload_id": String(image.get("upload_id", "")),
		"image_url": "",
	}
	_emit("room", "draft_ready", draft)
	return draft

func commit_room_draft(draft: Dictionary) -> Dictionary:
	await flush_ai_sync_outbox()
	if String(draft.get("kind", "")) != "room":
		return _failure("INVALID_DRAFT", "这不是房间分析草稿。")
	var workflow_key := String(draft.get("workflow_key", ""))
	var source := MemoryManager.create_memory({}, "room_photo", "", "", draft.get("generation_meta", {}), "room_source:" + workflow_key, String(draft.get("upload_id", "")))
	var existing := MemoryManager.get_room_for_user(MemoryManager.selected_role_key)
	if not existing.is_empty() and String(existing.get("workflow_key", "")) == "room:" + workflow_key:
		return {"ok": true, "room": existing, "source_memory": source, "duplicate": true}
	var room := RoomLayoutManager.generate(draft.get("analysis", {}), String(source.get("id", "")), "room:" + workflow_key, draft.get("generation_meta", {})) \
		if existing.is_empty() else RoomLayoutManager.replace(String(existing.get("id", "")), draft.get("analysis", {}), String(source.get("id", "")), "room:" + workflow_key, draft.get("generation_meta", {}))
	if room.is_empty():
		return _failure("LAYOUT_FAILED", "房间布局没有成功写入。")
	var records: Array = [
		{"table": "memories", "row": source},
		{"table": "rooms", "row": room},
	]
	for object in MemoryManager.get_room_objects(String(room.get("id", ""))):
		records.append({"table": "room_objects", "row": object})
	var synced := await _confirm_records(records)
	if not existing.is_empty():
		var old_source_id := String(existing.get("source_memory_id", ""))
		if old_source_id != "" and old_source_id != String(source.get("id", "")):
			MemoryManager.delete_memory(old_source_id)
	_emit("room", "committed", {"room": room})
	return {"ok": true, "room": room, "source_memory": source, "sync_pending": not synced}

func resolve_memory_image(memory: Dictionary) -> String:
	var upload_id := String(memory.get("upload_id", ""))
	if upload_id == "":
		return String(memory.get("image_url", ""))
	var result: Dictionary = await CloudManager.resolve_ai_image(upload_id)
	return String(result.get("image_url", "")) if bool(result.get("ok", false)) else ""

func _upload_if_present(workflow: String, bytes: PackedByteArray, content_type: String) -> Dictionary:
	if bytes.is_empty():
		return {"ok": true, "upload_id": "", "image_url": ""}
	_emit(workflow, "preparing_image", {"source_bytes": bytes.size()})
	var prepared := AIImageUploadService.prepare(bytes, content_type)
	if not bool(prepared.get("ok", false)):
		return prepared
	_emit(workflow, "uploading", {"output_bytes": prepared.get("output_bytes", 0)})
	var uploaded: Dictionary = await CloudManager.upload_ai_image(prepared.get("bytes", PackedByteArray()), String(prepared.get("content_type", "")))
	if not bool(uploaded.get("ok", false)):
		return _failure("UPLOAD_FAILED", _cloud_upload_error_message(uploaded.get("error", "")))
	return uploaded

func _prepare_slots(scene: String) -> void:
	SlotManager.load_scene(scene)
	for node in MemoryManager.get_nodes_for_scene(scene):
		var slot_id := String(node.get("slot_id", ""))
		if slot_id != "":
			SlotManager.occupy(scene, slot_id, String(node.get("id", "")))

func flush_ai_sync_outbox() -> bool:
	var pending := MemoryManager.ai_sync_outbox.duplicate(true)
	var all_synced := true
	for item in pending:
		if not item is Dictionary:
			continue
		var table := String(item.get("table", ""))
		var operation := String(item.get("operation", "upsert"))
		var row: Dictionary = item.get("row", {})
		var row_id := String(item.get("row_id", row.get("id", "")))
		var result: Dictionary
		if operation == "delete":
			result = await CloudManager.delete_ai_record_confirmed(table, row_id)
		elif operation == "delete_image":
			result = {"ok": await CloudManager.delete_ai_image(row_id)}
		else:
			result = await CloudManager.persist_ai_record_confirmed(table, row)
		if bool(result.get("ok", false)):
			MemoryManager.remove_ai_sync(table, row_id)
		else:
			all_synced = false
	return all_synced

func _confirm_records(records: Array) -> bool:
	var all_synced := true
	for item in records:
		if not item is Dictionary:
			continue
		var table := String(item.get("table", ""))
		var row: Dictionary = item.get("row", {})
		var result: Dictionary = await CloudManager.persist_ai_record_confirmed(table, row)
		if bool(result.get("ok", false)):
			MemoryManager.remove_ai_sync(table, String(row.get("id", "")))
		else:
			MemoryManager.queue_ai_sync(table, row)
			all_synced = false
	return all_synced

func _already_linked(a: String, b: String) -> bool:
	var pair := [a, b]
	pair.sort()
	var key := String(pair[0]) + "|" + String(pair[1])
	for link in MemoryManager.nodes:
		if link is Dictionary and String(link.get("node_type", "")) == "memory_link" \
			and String(link.get("pair_key", "")) == key:
			return true
	return false

func _memory_stats() -> Array:
	var counts: Dictionary = {}
	for memory in MemoryManager.memories:
		var card: Variant = memory.get("ai_card", {}) if memory is Dictionary else {}
		if card is Dictionary:
			var memory_type := String(card.get("memory_type", ""))
			if memory_type in AIContractValidator.MEMORY_TYPES:
				counts[memory_type] = int(counts.get(memory_type, 0)) + 1
	var result: Array = []
	for memory_type in counts:
		result.append({"memory_type": memory_type, "count": counts[memory_type]})
	return result.slice(0, 8)

func _candidate_relevance(source: Dictionary, candidate: Dictionary, recency_rank: int) -> float:
	var source_card: Dictionary = source.get("ai_card", {})
	var candidate_card: Dictionary = candidate.get("ai_card", {})
	var score := maxf(0.0, 1.0 - float(recency_rank) * 0.025)
	if String(source_card.get("memory_type", "")) == String(candidate_card.get("memory_type", "")):
		score += 1.4
	var source_text := String(source_card.get("title", "")) + String(source_card.get("description", ""))
	var candidate_text := String(candidate_card.get("title", "")) + String(candidate_card.get("description", ""))
	var source_terms := _text_bigrams(source_text)
	var overlap := 0
	for term in source_terms:
		if candidate_text.contains(String(term)):
			overlap += 1
	score += minf(2.0, float(overlap) * 0.18)
	return score

func _text_bigrams(text: String) -> Array:
	var clean := text.replace(" ", "").replace("，", "").replace("。", "").replace("！", "").replace("？", "")
	var result: Array = []
	for index in range(maxi(0, clean.length() - 1)):
		var term := clean.substr(index, 2)
		if not term in result:
			result.append(term)
	return result.slice(0, 40)

func _supports_people_relation(a: Dictionary, b: Dictionary) -> bool:
	var a_card: Dictionary = a.get("ai_card", {})
	var b_card: Dictionary = b.get("ai_card", {})
	var a_text := String(a_card.get("title", "")) + String(a_card.get("description", ""))
	var b_text := String(b_card.get("title", "")) + String(b_card.get("description", ""))
	for term in ["爸爸", "妈妈", "爷爷", "奶奶", "哥哥", "姐姐", "弟弟", "妹妹", "家人"]:
		if a_text.contains(term) and b_text.contains(term):
			return true
	return false

func _workflow_key(kind: String, text: String, bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update((kind + "\n" + text).to_utf8_buffer())
	if not bytes.is_empty():
		context.update(bytes)
	return context.finish().hex_encode()

func _failure_from_ai(route: String) -> Dictionary:
	var outcome := AIClient.last_result(route)
	return _failure_from_outcome(outcome)

func _failure_from_outcome(outcome: Dictionary) -> Dictionary:
	var error := _dictionary_or_empty(outcome.get("error"))
	return _failure(String(error.get("code", "AI_FAILED")), String(error.get("message", "AI 暂时不可用。")))

func _dictionary_or_empty(value: Variant) -> Dictionary:
	return (value as Dictionary) if value is Dictionary else {}

func _failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message}}

func _cloud_upload_error_message(raw_error: Variant) -> String:
	var text := String(raw_error).strip_edges()
	if text == "":
		return "图片上传失败，请检查网络后重试。"
	if text.contains("未配置"):
		return "图片上传还没有连接到 CloudBase，请先完成云端配置。"
	if text.contains("401") or text.contains("invalid") or text.contains("token"):
		return "云端身份已失效，请重新进入角色身份后再试。"
	if text.contains("too large") or text.contains("over size") or text.contains("payload"):
		return "图片上传失败，文件仍然过大，请换一张照片。"
	return "图片上传失败，请检查网络后重试。"

func _emit(workflow: String, state: String, detail: Dictionary) -> void:
	workflow_state_changed.emit(workflow, state, detail.duplicate(true))
