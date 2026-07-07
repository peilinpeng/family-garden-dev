extends Node

## Family Garden AI 客户端（Gate 3）。
## 对外方法返回经过 Gate 1 契约校验的 data；完整状态、来源与错误通过信号和 last_result 读取。

signal request_state_changed(route: String, state: String, result: Dictionary)

const STATE_IDLE := "idle"
const STATE_LOADING := "loading"
const STATE_SUCCESS := "success"
const STATE_FALLBACK := "fallback"
const STATE_ERROR := "error"
const STATE_CANCELLED := "cancelled"
const TECHNICAL_FALLBACK_CODES := ["AI_TIMEOUT", "AI_UPSTREAM_ERROR", "AI_INVALID_OUTPUT", "NETWORK_OFFLINE"]
const CACHEABLE_ROUTES := ["generate-memory-card", "analyze-room-photo", "cross-memory-link"]

class RequestTicket:
	extends RefCounted
	signal completed(result: Dictionary)
	var finished: bool = false
	var result: Dictionary = {}

var _backend: Object = null
var _owned_backend: Node = null
var _generation: int = 0
var _inflight: Dictionary = {}
var _cache: Dictionary = {}
var _last_results: Dictionary = {}

const MOCK_MEMORY_CARD := {
	"title": "一次家庭旅行",
	"description": "这是一段温暖的家庭旅行记忆。画面中有户外空间和轻松的氛围。",
	"memory_type": "travel",
	"suggested_scene": "garden",
	"question": "你还记得这次旅行中最开心的一件事吗？",
	"node_type": "memory_flower",
	"confidence": 1.0,
	"safety_note": "仅整理用户提供的信息，没有推断具体人物关系。",
}
const MOCK_ROOM_ANALYSIS := {
	"room_type": "bedroom",
	"style": "warm_cozy",
	"suggested_room_theme": "study_corner",
	"description": "这个房间适合生成一个温暖的学习角落。",
	"objects": [
		{"object_type": "desk", "zone": "back_left"},
		{"object_type": "lamp", "zone": "back_left"},
		{"object_type": "plant", "zone": "right_side"},
		{"object_type": "photo_wall", "zone": "back_wall"},
	],
	"safety_note": "仅描述可见空间与物件，没有推断居住者身份。",
}
const MOCK_BOTTLE_QUESTION := {
	"question": "你们上一次一起出去玩是什么时候？",
	"target_memory_type": "shared_memory",
	"suggested_scene": "fishpond",
	"prompt_type": "shared_memory",
	"tone": "warm",
	"safety_note": "问题保持开放和低压力，不预设家庭经历。",
}
const MOCK_LINK := {
	"links": [],
	"safety_note": "离线模式不创建未经验证的跨记忆连线。",
}

func _ready() -> void:
	var backend := AIHttpBackend.new()
	add_child(backend)
	_owned_backend = backend
	if backend.is_configured():
		set_backend(backend)
	_validate_mocks()

func set_backend(backend: Object) -> void:
	_backend = backend
	clear_cache()

func clear_backend() -> void:
	_backend = null
	clear_cache()

func cancel_all() -> void:
	_generation += 1
	if _backend != null and _backend.has_method("cancel_all"):
		_backend.cancel_all()
	for route in _last_results.keys():
		if String((_last_results[route] as Dictionary).get("state", "")) == STATE_LOADING:
			_set_result(String(route), _outcome(STATE_CANCELLED, String(route), null, {}, _local_error("CANCELLED", "请求已取消。", false), false))

func clear_cache() -> void:
	_cache.clear()

func last_result(route: String) -> Dictionary:
	return (_last_results.get(route, _outcome(STATE_IDLE, route, null, {}, {}, false)) as Dictionary).duplicate(true)

func state(route: String) -> String:
	return String(last_result(route).get("state", STATE_IDLE))

func mock_memory_card() -> Dictionary:
	return MOCK_MEMORY_CARD.duplicate(true)

func mock_room_analysis() -> Dictionary:
	return MOCK_ROOM_ANALYSIS.duplicate(true)

func mock_bottle_questions() -> Array:
	# 兼容阶段 1 的批量演示种子；真实 HTTP 接口每次只返回一个对象。
	return [String(MOCK_BOTTLE_QUESTION.question), "有没有一个和家人在水边度过的周末，你一直记得？"]

func mock_link() -> Dictionary:
	return {"relation_type": "same_place", "question": "这两段记忆好像在同一个地方？和家人聊聊那里的故事吧"}

func generate_memory_card(image_url: String, text: String = "", memory_id: String = "") -> Dictionary:
	var resolved_id := memory_id if memory_id != "" else _local_id("memory")
	var payload := {"memory_id": resolved_id, "input_type": "photo" if image_url != "" else "text", "language": "zh-CN"}
	if image_url != "":
		payload["image_url"] = image_url
	if text.strip_edges() != "":
		payload["raw_text"] = text.strip_edges()
	return await _data_call("generate-memory-card", payload, MOCK_MEMORY_CARD)

func analyze_room_photo(image_url: String, memory_id: String = "") -> Dictionary:
	var payload := {
		"memory_id": memory_id if memory_id != "" else _local_id("room"),
		"image_url": image_url,
		"language": "zh-CN",
	}
	return await _data_call("analyze-room-photo", payload, MOCK_ROOM_ANALYSIS)

func generate_bottle_question(context: Dictionary = {}) -> Dictionary:
	var payload := {
		"scene": String(context.get("scene", "fishpond")),
		"target_memory_type": String(context.get("target_memory_type", "shared_memory")),
		"tone": "warm",
		"language": String(context.get("language", "zh-CN")),
	}
	for optional in ["target_member_id", "memory_stats", "avoid_topics"]:
		if context.has(optional):
			payload[optional] = context[optional]
	return await _data_call("generate-bottle-question", payload, MOCK_BOTTLE_QUESTION)

func cross_memory_link(memory: Variant, candidates: Array = []) -> Dictionary:
	var source: Dictionary = memory.duplicate(true) if memory is Dictionary else MemoryManager.get_memory(String(memory))
	var source_summary := _memory_summary(source)
	var normalized_candidates: Array = []
	for candidate in candidates:
		if candidate is Dictionary:
			normalized_candidates.append(_memory_summary(candidate as Dictionary))
	var payload := {
		"memory_id": String(source_summary.get("memory_id", memory if memory is String else "")),
		"title": String(source_summary.get("title", "")),
		"description": String(source_summary.get("description", "")),
		"memory_type": String(source_summary.get("memory_type", "")),
		"candidates": normalized_candidates,
		"language": "zh-CN",
	}
	return await _data_call("cross-memory-link", payload, MOCK_LINK)

func _memory_summary(memory: Dictionary) -> Dictionary:
	var card: Dictionary = memory.get("ai_card", {}) if memory.get("ai_card", {}) is Dictionary else {}
	return {
		"memory_id": String(memory.get("memory_id", memory.get("id", ""))),
		"title": String(memory.get("title", card.get("title", ""))),
		"description": String(memory.get("description", card.get("description", ""))),
		"memory_type": String(memory.get("memory_type", card.get("memory_type", ""))),
	}

func _data_call(route: String, payload: Dictionary, fallback: Variant) -> Variant:
	var outcome := await _call(route, payload, fallback)
	var data: Variant = outcome.get("data")
	if data is Dictionary or data is Array:
		return data.duplicate(true)
	return {} if fallback is Dictionary else []

func _call(route: String, payload: Dictionary, fallback: Variant) -> Dictionary:
	var cache_key := _request_key(route, payload)
	var inflight_key := "%d:%s" % [_generation, cache_key]
	var cached := _cached(cache_key)
	if not cached.is_empty():
		_set_result(route, cached)
		return cached
	if _inflight.has(inflight_key):
		var pending := _inflight[inflight_key] as RequestTicket
		if pending.finished:
			return pending.result.duplicate(true)
		return (await pending.completed as Dictionary).duplicate(true)
	var ticket := RequestTicket.new()
	_inflight[inflight_key] = ticket
	var generation := _generation
	_set_result(route, _outcome(STATE_LOADING, route, null, {}, {}, false))
	var outcome := await _perform_call(route, payload, fallback, generation)
	ticket.result = outcome.duplicate(true)
	ticket.finished = true
	ticket.completed.emit(ticket.result)
	_inflight.erase(inflight_key)
	if outcome.get("state") == STATE_SUCCESS and route in CACHEABLE_ROUTES:
		_store_cache(cache_key, outcome)
	# cancel_all 已同步发布 cancelled；旧代回调不得覆盖随后发起的新请求状态。
	if generation == _generation:
		_set_result(route, outcome)
	return outcome

func _perform_call(route: String, payload: Dictionary, fallback: Variant, generation: int) -> Dictionary:
	var request_validation := AIContractValidator.validate_request(route, payload)
	if not bool(request_validation.get("ok", false)):
		return _outcome(STATE_ERROR, route, null, {}, _local_error("INVALID_REQUEST", "; ".join(request_validation.get("errors", [])), false), false)
	if _backend == null or not _backend.has_method("request"):
		return _fallback_outcome(route, payload, fallback, "NETWORK_OFFLINE", "AI 后端未启用。")
	var envelope: Variant = await _backend.request("/api/ai/" + route, payload)
	if generation != _generation:
		return _outcome(STATE_CANCELLED, route, null, {}, _local_error("CANCELLED", "请求已取消。", false), false)
	var validation := AIContractValidator.validate_envelope(route, envelope, payload)
	if not bool(validation.get("ok", false)):
		return _fallback_outcome(route, payload, fallback, "AI_INVALID_OUTPUT", "; ".join(validation.get("errors", [])))
	var body := envelope as Dictionary
	if bool(body.get("ok", false)):
		var meta := body.get("meta", {}) as Dictionary
		var state_name := STATE_FALLBACK if String(meta.get("source", "")) == "fallback" else STATE_SUCCESS
		return _outcome(state_name, route, body.get("data"), meta, {}, state_name == STATE_FALLBACK)
	var error := body.get("error", {}) as Dictionary
	var code := String(error.get("code", "INTERNAL_ERROR"))
	if code in TECHNICAL_FALLBACK_CODES:
		return _fallback_outcome(route, payload, fallback, code, String(error.get("message", "AI 服务暂时不可用。")), body.get("meta", {}))
	if code == "CANCELLED":
		return _outcome(STATE_CANCELLED, route, null, body.get("meta", {}), error, false)
	return _outcome(STATE_ERROR, route, null, body.get("meta", {}), error, false)

func _fallback_outcome(route: String, payload: Dictionary, fallback: Variant, reason: String, message: String, upstream_meta: Dictionary = {}) -> Dictionary:
	var data: Variant = _dup(fallback)
	var validation := AIContractValidator.validate_data(route, data, payload)
	if not bool(validation.get("ok", false)):
		return _outcome(STATE_ERROR, route, null, upstream_meta, _local_error("INTERNAL_ERROR", "本地 fallback 不符合契约。", false, validation.get("errors", [])), false)
	var meta := {
		"request_id": String(upstream_meta.get("request_id", _local_id("fallback"))),
		"provider": "mock",
		"model": "mock",
		"prompt_version": "client-fallback-1",
		"source": "fallback",
		"result": "empty" if route == "cross-memory-link" and data is Dictionary and (data as Dictionary).get("links", []).is_empty() else "complete",
		"fallback_reason": reason,
	}
	return _outcome(STATE_FALLBACK, route, data, meta, _local_error(reason, message, true), true)

func _outcome(state_name: String, route: String, data: Variant, meta: Dictionary, error: Dictionary, used_fallback: bool) -> Dictionary:
	return {
		"state": state_name,
		"route": route,
		"data": _dup(data),
		"meta": meta.duplicate(true),
		"error": error.duplicate(true),
		"used_fallback": used_fallback,
	}

func _set_result(route: String, result: Dictionary) -> void:
	_last_results[route] = result.duplicate(true)
	request_state_changed.emit(route, String(result.get("state", STATE_ERROR)), result.duplicate(true))

func _request_key(route: String, payload: Dictionary) -> String:
	var cache_scope: String = String(_backend.cache_namespace()) if _backend != null and _backend.has_method("cache_namespace") else "local"
	return "%s:%s:%s" % [cache_scope, route, JSON.stringify(payload).sha256_text()]

func _cached(key: String) -> Dictionary:
	if not _cache.has(key):
		return {}
	var entry := _cache[key] as Dictionary
	if float(entry.get("expires_at", 0.0)) <= Time.get_unix_time_from_system():
		_cache.erase(key)
		return {}
	return (entry.get("outcome", {}) as Dictionary).duplicate(true)

func _store_cache(key: String, outcome: Dictionary) -> void:
	var ttl: float = float(_backend.cache_ttl_seconds()) if _backend != null and _backend.has_method("cache_ttl_seconds") else 0.0
	if ttl <= 0.0:
		return
	_cache[key] = {"expires_at": Time.get_unix_time_from_system() + ttl, "outcome": outcome.duplicate(true)}

func _validate_mocks() -> void:
	var samples := {
		"generate-memory-card": MOCK_MEMORY_CARD,
		"generate-bottle-question": MOCK_BOTTLE_QUESTION,
		"analyze-room-photo": MOCK_ROOM_ANALYSIS,
		"cross-memory-link": MOCK_LINK,
	}
	for route in samples:
		var validation := AIContractValidator.validate_data(String(route), samples[route])
		if not bool(validation.get("ok", false)):
			push_error("[AIClient] %s fallback 不符合契约: %s" % [route, validation.get("errors", [])])

func _local_error(code: String, message: String, retryable: bool, details: Array = []) -> Dictionary:
	var error := {"code": code, "message": message.left(240), "retryable": retryable}
	if not details.is_empty():
		error["details"] = details.slice(0, 10)
	return error

func _local_id(prefix: String) -> String:
	return "%s_%d_%08x" % [prefix, Time.get_ticks_msec(), randi()]

func _dup(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
