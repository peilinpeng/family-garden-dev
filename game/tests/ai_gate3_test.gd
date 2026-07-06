extends SceneTree

class FakeBackend:
	extends Node
	var calls: int = 0
	var delay_frames: int = 0
	var response: Dictionary = {}
	var cancelled: bool = false

	func request(_route: String, _payload: Dictionary) -> Dictionary:
		calls += 1
		for _frame in delay_frames:
			await get_tree().process_frame
		return response.duplicate(true)

	func cancel_all() -> void:
		cancelled = true

	func cache_ttl_seconds() -> float:
		return 60.0

	func cache_namespace() -> String:
		return "gate3-test"

var failures: Array[String] = []
var client: Node
var backend: FakeBackend

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	client = load("res://scripts/managers/ai_client.gd").new()
	root.add_child(client)
	await process_frame
	backend = FakeBackend.new()
	root.add_child(backend)
	client.set_backend(backend)

	_test_contract_validator()
	await _test_success_and_cache()
	await _test_fallback_policy()
	await _test_offline_mode()
	await _test_invalid_request_short_circuit()
	await _test_nested_memory_normalization()
	await _test_duplicate_coalescing()
	await _test_cancellation()
	await _test_request_after_cancellation()

	client.queue_free()
	backend.queue_free()
	if failures.is_empty():
		print("Gate 3 Godot tests passed: validator, envelope, state, fallback, cache, dedupe, cancel")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _test_contract_validator() -> void:
	var memory: Dictionary = client.mock_memory_card()
	_assert(AIContractValidator.validate_data("generate-memory-card", memory).ok, "memory mock 应通过")
	var bad_memory: Dictionary = memory.duplicate(true)
	bad_memory["suggested_scene"] = "moon"
	_assert(not AIContractValidator.validate_data("generate-memory-card", bad_memory).ok, "非法 scene 应拒绝")
	_assert(AIContractValidator.validate_data("analyze-room-photo", client.mock_room_analysis()).ok, "room mock 应通过")
	var bad_room: Dictionary = client.mock_room_analysis()
	bad_room.objects[0].zone = "back_wall"
	_assert(not AIContractValidator.validate_data("analyze-room-photo", bad_room).ok, "非照片墙 back_wall 应拒绝")
	var link_request := _link_payload()
	var duplicate_links := {
		"links": [
			_link("mem_new", "mem_old", "same_place"),
			_link("mem_old", "mem_new", "same_theme"),
		]
	}
	_assert(not AIContractValidator.validate_data("cross-memory-link", duplicate_links, link_request).ok, "同一记忆对重复连线应拒绝")
	var legacy_request := link_request.duplicate(true)
	legacy_request.erase("title")
	_assert(not AIContractValidator.validate_request("cross-memory-link", legacy_request).ok, "1.0 旧跨记忆请求应拒绝")
	var bad_meta := _success("generate-memory-card", memory, "req_bad_meta")
	bad_meta["meta"] = "broken"
	_assert(not AIContractValidator.validate_envelope("generate-memory-card", bad_meta).ok, "畸形 meta 应稳定拒绝而非触发客户端异常")
	var bad_bottle_request := {
		"scene": "fishpond",
		"target_memory_type": "shared_memory",
		"tone": "warm",
		"language": "zh-CN",
		"memory_stats": [{"memory_type": "travel", "count": 1.5}],
		"avoid_topics": ["conflict", "conflict"],
	}
	_assert(not AIContractValidator.validate_request("generate-bottle-question", bad_bottle_request).ok, "漂流瓶聚合计数和敏感主题必须逐项校验")

func _test_success_and_cache() -> void:
	backend.calls = 0
	backend.delay_frames = 0
	backend.response = _success("generate-memory-card", client.mock_memory_card(), "req_success")
	var first: Dictionary = await client.generate_memory_card("", "今天一起种树。", "mem_success")
	_assert(first.title == "一次家庭旅行", "真实成功应返回校验后的 data")
	_assert(client.state("generate-memory-card") == "success", "成功状态应为 success")
	_assert(client.last_result("generate-memory-card").meta.source == "ai", "成功来源应保留 ai")
	var second: Dictionary = await client.generate_memory_card("", "今天一起种树。", "mem_success")
	_assert(second == first, "相同稳定输入应命中内存缓存")
	_assert(backend.calls == 1, "缓存命中不应重复请求 backend")

func _test_fallback_policy() -> void:
	client.clear_cache()
	backend.response = _failure("AI_UPSTREAM_ERROR", true, "req_fallback")
	var fallback: Dictionary = await client.generate_bottle_question({"scene": "fishpond"})
	_assert(fallback.question != "", "技术错误应返回契约内 fallback")
	_assert(client.state("generate-bottle-question") == "fallback", "技术错误状态应为 fallback")
	_assert(client.last_result("generate-bottle-question").meta.fallback_reason == "AI_UPSTREAM_ERROR", "fallback 应保留原因")

	backend.response = _failure("CONTENT_UNSAFE", false, "req_unsafe")
	var unsafe: Dictionary = await client.generate_bottle_question({"scene": "fishpond", "target_memory_type": "travel"})
	_assert(unsafe.is_empty(), "内容安全失败不得被 mock 掩盖")
	_assert(client.state("generate-bottle-question") == "error", "内容安全失败应为 error")

func _test_offline_mode() -> void:
	client.clear_backend()
	var offline: Dictionary = await client.generate_memory_card("", "离线家庭记忆。", "mem_offline")
	_assert(not offline.is_empty(), "无 backend 时应保持离线可玩")
	_assert(client.state("generate-memory-card") == "fallback", "离线模式应明确标记 fallback")
	_assert(client.last_result("generate-memory-card").meta.fallback_reason == "NETWORK_OFFLINE", "离线 fallback 应记录 NETWORK_OFFLINE")
	client.set_backend(backend)

func _test_invalid_request_short_circuit() -> void:
	var calls_before := backend.calls
	var invalid: Dictionary = await client.analyze_room_photo("http://example.com/room.png", "mem_invalid")
	_assert(invalid.is_empty(), "非 HTTPS 图片请求应返回空 data")
	_assert(client.state("analyze-room-photo") == "error", "非法请求应为 error")
	_assert(client.last_result("analyze-room-photo").error.code == "INVALID_REQUEST", "非法请求应有稳定错误码")
	_assert(backend.calls == calls_before, "非法请求不得发送到 backend")

func _test_nested_memory_normalization() -> void:
	backend.delay_frames = 0
	backend.response = _success("cross-memory-link", {"links": []}, "req_link_normalized")
	var source := {"id": "mem_source", "ai_card": {"title": "种树", "description": "一家人在花园里种树。", "memory_type": "family_event"}}
	var candidate := {"id": "mem_candidate", "ai_card": {"title": "浇水", "description": "一家人在花园里浇水。", "memory_type": "family_event"}}
	var result: Dictionary = await client.cross_memory_link(source, [candidate])
	_assert(result.has("links"), "嵌套 ai_card 记忆应转换为 1.1 请求并成功调用")
	_assert(client.state("cross-memory-link") == "success", "规范化跨记忆请求应为 success")

func _test_duplicate_coalescing() -> void:
	client.clear_cache()
	backend.calls = 0
	backend.delay_frames = 3
	backend.response = _success("generate-memory-card", client.mock_memory_card(), "req_dedupe")
	client.generate_memory_card("", "相同并发输入。", "mem_dedupe")
	client.generate_memory_card("", "相同并发输入。", "mem_dedupe")
	for _frame in 6:
		await process_frame
	_assert(backend.calls == 1, "相同并发输入必须合并为一个 backend 请求")
	_assert(client.state("generate-memory-card") == "success", "合并请求完成后应为 success")

func _test_cancellation() -> void:
	client.clear_cache()
	backend.delay_frames = 4
	backend.response = _success("generate-memory-card", client.mock_memory_card(), "req_cancel")
	client.generate_memory_card("", "即将切场景。", "mem_cancel")
	await process_frame
	client.cancel_all()
	for _frame in 6:
		await process_frame
	_assert(backend.cancelled, "cancel_all 应通知 backend")
	_assert(client.state("generate-memory-card") == "cancelled", "旧回调必须被标记为 cancelled")

func _test_request_after_cancellation() -> void:
	client.clear_cache()
	backend.calls = 0
	backend.delay_frames = 4
	backend.response = _success("generate-memory-card", client.mock_memory_card(), "req_old_generation")
	client.generate_memory_card("", "跨代请求。", "mem_generation")
	await process_frame
	client.cancel_all()
	backend.delay_frames = 0
	backend.response = _success("generate-memory-card", client.mock_memory_card(), "req_new_generation")
	var fresh: Dictionary = await client.generate_memory_card("", "跨代请求。", "mem_generation")
	_assert(not fresh.is_empty(), "取消后相同输入应能立即发起新请求")
	_assert(backend.calls == 2, "新代请求不得合并到已取消的旧请求")
	_assert(client.state("generate-memory-card") == "success", "新代请求应独立成功")
	for _frame in 5:
		await process_frame
	_assert(client.state("generate-memory-card") == "success", "旧代回调不得覆盖新代成功状态")

func _success(route: String, data: Dictionary, request_id: String) -> Dictionary:
	return {
		"ok": true,
		"data": data.duplicate(true),
		"meta": {
			"request_id": request_id,
			"provider": "fake",
			"model": "fake-model",
			"prompt_version": route + "-test",
			"source": "ai",
			"result": "empty" if route == "cross-memory-link" and data.get("links", []).is_empty() else "complete",
		},
	}

func _failure(code: String, retryable: bool, request_id: String) -> Dictionary:
	return {
		"ok": false,
		"error": {"code": code, "message": "test failure", "retryable": retryable},
		"meta": {"request_id": request_id},
	}

func _link_payload() -> Dictionary:
	return {
		"memory_id": "mem_new",
		"title": "新记忆",
		"description": "一家人在花园里种树。",
		"memory_type": "family_event",
		"candidates": [{"memory_id": "mem_old", "title": "旧记忆", "description": "一家人在花园里浇水。", "memory_type": "family_event"}],
		"language": "zh-CN",
	}

func _link(a: String, b: String, relation: String) -> Dictionary:
	return {
		"memory_id_a": a,
		"memory_id_b": b,
		"relation_type": relation,
		"confidence": 0.8,
		"question": "这两段记忆发生在同一个地方吗？",
		"node_type": "memory_link",
	}

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
