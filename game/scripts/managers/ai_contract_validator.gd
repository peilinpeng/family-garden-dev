class_name AIContractValidator
extends RefCounted

## Gate 1/2 JSON Schema 在 Godot 侧的轻量等价校验。
## 服务端仍是安全边界；本类负责防止非法/过时输出进入游戏数据层。

const ROUTES := [
	"generate-memory-card",
	"generate-bottle-question",
	"analyze-room-photo",
	"cross-memory-link",
	"moderate-user-content",
]
const MEMORY_TYPES := ["travel", "childhood", "home", "daily_life", "family_event", "personal_room", "old_memory"]
const SCENES := ["garden", "fishpond", "farm", "old_street", "room", "travel_area"]
const NODE_TYPES := ["memory_flower", "memory_seed", "photo_board", "bottle", "room_object", "postcard", "memory_link"]
const RELATION_TYPES := ["same_place", "same_people", "same_theme", "same_era"]
const ROOM_TYPES := ["bedroom", "study", "living_room", "kitchen_corner", "unknown"]
const ROOM_STYLES := ["warm_cozy", "simple", "nostalgic", "bright", "quiet"]
const ROOM_THEMES := ["study_corner", "reading_corner", "rest_corner", "family_corner", "memory_corner"]
const ROOM_OBJECT_TYPES := ["desk", "lamp", "plant", "photo_wall", "bed", "chair"]
const ROOM_ZONES := ["back_wall", "back_left", "back_center", "back_right", "left_side", "right_side", "front_left", "front_center", "front_right", "floor_center"]
const AVOID_TOPICS := ["conflict", "trauma", "health", "politics", "religion", "grief"]
const SUCCESS_SOURCES := ["ai", "fallback", "mock"]
const RESULT_TYPES := ["complete", "empty"]
const MEMORY_SCENES := ["garden", "fishpond"]

static func validate_request(route: String, payload: Variant) -> Dictionary:
	var errors: Array[String] = []
	if route not in ROUTES:
		errors.append("未知 AI 路由: %s" % route)
		return _result(errors)
	if not payload is Dictionary:
		errors.append("请求必须是 Dictionary")
		return _result(errors)
	var value := payload as Dictionary
	match route:
		"generate-memory-card":
			_validate_memory_card_request(value, errors)
		"generate-bottle-question":
			_validate_bottle_request(value, errors)
		"analyze-room-photo":
			_validate_room_request(value, errors)
		"cross-memory-link":
			_validate_link_request(value, errors)
		"moderate-user-content":
			_validate_moderation_request(value, errors)
	return _result(errors)

static func validate_envelope(route: String, envelope: Variant, request_payload: Dictionary = {}) -> Dictionary:
	var errors: Array[String] = []
	if route not in ROUTES:
		errors.append("未知 AI 路由: %s" % route)
		return _result(errors)
	if not envelope is Dictionary:
		errors.append("响应包络必须是 Dictionary")
		return _result(errors)
	var body := envelope as Dictionary
	if not body.has("ok") or typeof(body.get("ok")) != TYPE_BOOL:
		errors.append("响应缺少布尔字段 ok")
		return _result(errors)
	_validate_request_id(body.get("meta"), errors)
	if not bool(body.get("ok", false)):
		_validate_error(body.get("error"), errors)
		return _result(errors)
	_validate_success_meta(body.get("meta"), errors)
	var meta: Dictionary = body.get("meta") if body.get("meta") is Dictionary else {}
	var data: Variant = body.get("data")
	if data == null:
		if meta.get("result", "") != "empty":
			errors.append("data=null 时 meta.result 必须为 empty")
		return _result(errors)
	match route:
		"generate-memory-card":
			_validate_memory_card(data, errors)
		"generate-bottle-question":
			_validate_bottle_question(data, errors)
		"analyze-room-photo":
			_validate_room_analysis(data, errors)
		"cross-memory-link":
			_validate_memory_links(data, request_payload, errors)
		"moderate-user-content":
			_validate_moderation_result(data, errors)
	var expected_result := "empty" if route == "cross-memory-link" and data is Dictionary and (data as Dictionary).get("links", []).is_empty() else "complete"
	if String(meta.get("result", "")) != expected_result:
		errors.append("meta.result 与 data 内容不一致")
	return _result(errors)

static func _validate_memory_card_request(value: Dictionary, errors: Array[String]) -> void:
	_string_field(value, "memory_id", 1, 128, errors)
	_enum_field(value, "input_type", ["photo", "text", "postcard", "bottle_answer"], errors)
	_enum_field(value, "language", ["zh-CN", "en-US"], errors)
	var image_url := String(value.get("image_url", ""))
	var upload_id := String(value.get("upload_id", ""))
	var raw_text := String(value.get("raw_text", ""))
	if image_url == "" and upload_id == "" and raw_text == "":
		errors.append("upload_id、image_url 与 raw_text 至少提供一个")
	if image_url != "" and (not image_url.begins_with("https://") or image_url.length() > 2048):
		errors.append("image_url 必须是长度不超过 2048 的 HTTPS URL")
	if upload_id != "" and not _valid_upload_id(upload_id):
		errors.append("upload_id 格式无效")
	if raw_text != "" and (raw_text.length() < 1 or raw_text.length() > 2000):
		errors.append("raw_text 长度必须为 1..2000")

static func _validate_bottle_request(value: Dictionary, errors: Array[String]) -> void:
	_enum_field(value, "scene", SCENES, errors)
	_enum_field(value, "target_memory_type", ["shared_memory"] + MEMORY_TYPES, errors)
	_enum_field(value, "tone", ["warm"], errors)
	_enum_field(value, "language", ["zh-CN", "en-US"], errors)
	if value.has("target_member_id"):
		_string_field(value, "target_member_id", 1, 128, errors)
	if value.has("memory_stats"):
		var stats: Variant = value.get("memory_stats")
		if not stats is Array or (stats as Array).size() > 8:
			errors.append("memory_stats 必须是最多 8 项 Array")
		else:
			for index in (stats as Array).size():
				var stat: Variant = (stats as Array)[index]
				if not stat is Dictionary:
					errors.append("memory_stats[%d] 必须是 Dictionary" % index)
					continue
				var item := stat as Dictionary
				_enum_field(item, "memory_type", MEMORY_TYPES, errors, "memory_stats[%d]." % index)
				var count: Variant = item.get("count")
				if typeof(count) != TYPE_INT or int(count) < 0 or int(count) > 10000:
					errors.append("memory_stats[%d].count 必须是 0..10000 的整数" % index)
	if value.has("avoid_topics"):
		var topics: Variant = value.get("avoid_topics")
		if not topics is Array or (topics as Array).size() > 10:
			errors.append("avoid_topics 必须是最多 10 项 Array")
		else:
			var seen: Dictionary = {}
			for index in (topics as Array).size():
				var topic: Variant = (topics as Array)[index]
				if topic not in AVOID_TOPICS:
					errors.append("avoid_topics[%d] 不是允许值" % index)
				elif seen.has(topic):
					errors.append("avoid_topics 不能包含重复项")
				seen[topic] = true

static func _validate_room_request(value: Dictionary, errors: Array[String]) -> void:
	_string_field(value, "memory_id", 1, 128, errors)
	_enum_field(value, "language", ["zh-CN", "en-US"], errors)
	var image_url := String(value.get("image_url", ""))
	var upload_id := String(value.get("upload_id", ""))
	if image_url == "" and upload_id == "":
		errors.append("房间分析必须提供 upload_id 或 image_url")
	if image_url != "" and (not image_url.begins_with("https://") or image_url.length() > 2048):
		errors.append("image_url 必须是长度不超过 2048 的 HTTPS URL")
	if upload_id != "" and not _valid_upload_id(upload_id):
		errors.append("upload_id 格式无效")

static func _validate_moderation_request(value: Dictionary, errors: Array[String]) -> void:
	_enum_field(value, "kind", ["memory_card_edit", "memory_answer", "memory_link_followup", "bottle_answer"], errors)
	_enum_field(value, "language", ["zh-CN", "en-US"], errors)
	var texts: Variant = value.get("texts")
	if not texts is Array or (texts as Array).is_empty() or (texts as Array).size() > 8:
		errors.append("texts 必须包含 1..8 项")
		return
	for index in (texts as Array).size():
		if typeof((texts as Array)[index]) != TYPE_STRING or String((texts as Array)[index]).length() < 1 or String((texts as Array)[index]).length() > 2000:
			errors.append("texts[%d] 长度必须为 1..2000" % index)

static func _validate_link_request(value: Dictionary, errors: Array[String]) -> void:
	_string_field(value, "memory_id", 1, 128, errors)
	_string_field(value, "title", 1, 40, errors)
	_string_field(value, "description", 1, 300, errors)
	_enum_field(value, "memory_type", MEMORY_TYPES, errors)
	_enum_field(value, "language", ["zh-CN", "en-US"], errors)
	var candidates: Variant = value.get("candidates")
	if not candidates is Array or (candidates as Array).size() < 1 or (candidates as Array).size() > 20:
		errors.append("candidates 必须包含 1..20 项")
		return
	for index in (candidates as Array).size():
		var candidate: Variant = (candidates as Array)[index]
		if not candidate is Dictionary:
			errors.append("candidates[%d] 必须是 Dictionary" % index)
			continue
		var item := candidate as Dictionary
		_string_field(item, "memory_id", 1, 128, errors, "candidates[%d]." % index)
		_string_field(item, "title", 1, 40, errors, "candidates[%d]." % index)
		_string_field(item, "description", 1, 300, errors, "candidates[%d]." % index)
		_enum_field(item, "memory_type", MEMORY_TYPES, errors, "candidates[%d]." % index)

static func validate_data(route: String, data: Variant, request_payload: Dictionary = {}) -> Dictionary:
	var meta := {
		"request_id": "req_client_validation",
		"provider": "mock",
		"model": "mock",
		"prompt_version": "client-validation",
		"source": "mock",
		"result": "empty" if data == null or (route == "cross-memory-link" and data is Dictionary and (data as Dictionary).get("links", []).is_empty()) else "complete",
	}
	return validate_envelope(route, {"ok": true, "data": data, "meta": meta}, request_payload)

static func _validate_memory_card(data: Variant, errors: Array[String]) -> void:
	if not data is Dictionary:
		errors.append("memory-card data 必须是 Dictionary")
		return
	var value := data as Dictionary
	_string_field(value, "title", 1, 40, errors)
	_string_field(value, "description", 1, 300, errors)
	_string_field(value, "question", 8, 120, errors)
	_enum_field(value, "memory_type", MEMORY_TYPES, errors)
	_enum_field(value, "suggested_scene", MEMORY_SCENES, errors)
	_enum_field(value, "node_type", ["memory_flower", "memory_seed", "photo_board", "postcard"], errors)
	_number_range(value, "confidence", 0.0, 1.0, errors)

static func _validate_bottle_question(data: Variant, errors: Array[String]) -> void:
	if not data is Dictionary:
		errors.append("bottle-question data 必须是 Dictionary")
		return
	var value := data as Dictionary
	_string_field(value, "question", 1, 120, errors)
	_enum_field(value, "target_memory_type", ["shared_memory"] + MEMORY_TYPES, errors)
	_enum_field(value, "suggested_scene", SCENES, errors)
	_enum_field(value, "prompt_type", ["shared_memory", "personal_memory", "directed_memory"], errors)
	_enum_field(value, "tone", ["warm"], errors)

static func _validate_room_analysis(data: Variant, errors: Array[String]) -> void:
	if not data is Dictionary:
		errors.append("room-analysis data 必须是 Dictionary")
		return
	var value := data as Dictionary
	_enum_field(value, "room_type", ROOM_TYPES, errors)
	_enum_field(value, "style", ROOM_STYLES, errors)
	_enum_field(value, "suggested_room_theme", ROOM_THEMES, errors)
	_string_field(value, "description", 1, 240, errors)
	var objects: Variant = value.get("objects")
	if not objects is Array or (objects as Array).size() < 1 or (objects as Array).size() > 8:
		errors.append("objects 必须包含 1..8 项")
		return
	for index in (objects as Array).size():
		var item: Variant = (objects as Array)[index]
		if not item is Dictionary:
			errors.append("objects[%d] 必须是 Dictionary" % index)
			continue
		var object := item as Dictionary
		_enum_field(object, "object_type", ROOM_OBJECT_TYPES, errors, "objects[%d]." % index)
		_enum_field(object, "zone", ROOM_ZONES, errors, "objects[%d]." % index)
		var object_type := String(object.get("object_type", ""))
		var zone := String(object.get("zone", ""))
		if object_type == "photo_wall" and zone != "back_wall":
			errors.append("photo_wall 只能使用 back_wall")
		elif object_type != "photo_wall" and zone == "back_wall":
			errors.append("非 photo_wall 物件不能使用 back_wall")

static func _validate_memory_links(data: Variant, request_payload: Dictionary, errors: Array[String]) -> void:
	if not data is Dictionary:
		errors.append("memory-link data 必须是 Dictionary")
		return
	var links: Variant = (data as Dictionary).get("links")
	if not links is Array or (links as Array).size() > 3:
		errors.append("links 必须是 0..3 项 Array")
		return
	var allowed_ids: Dictionary = {}
	var source_id := String(request_payload.get("memory_id", ""))
	if source_id != "":
		allowed_ids[source_id] = true
	for candidate in request_payload.get("candidates", []):
		if candidate is Dictionary:
			allowed_ids[String((candidate as Dictionary).get("memory_id", ""))] = true
	var pairs: Dictionary = {}
	for index in (links as Array).size():
		var item: Variant = (links as Array)[index]
		if not item is Dictionary:
			errors.append("links[%d] 必须是 Dictionary" % index)
			continue
		var link := item as Dictionary
		_string_field(link, "memory_id_a", 1, 128, errors, "links[%d]." % index)
		_string_field(link, "memory_id_b", 1, 128, errors, "links[%d]." % index)
		_enum_field(link, "relation_type", RELATION_TYPES, errors, "links[%d]." % index)
		_enum_field(link, "node_type", ["memory_link"], errors, "links[%d]." % index)
		_number_range(link, "confidence", 0.0, 1.0, errors, "links[%d]." % index)
		_string_field(link, "question", 1, 140, errors, "links[%d]." % index)
		var a := String(link.get("memory_id_a", ""))
		var b := String(link.get("memory_id_b", ""))
		if a != "" and a == b:
			errors.append("记忆不能与自身建立连线")
		if not allowed_ids.is_empty() and (not allowed_ids.has(a) or not allowed_ids.has(b)):
			errors.append("连线引用了请求外 memory_id")
		var ordered := [a, b]
		ordered.sort()
		var pair_key := JSON.stringify(ordered)
		if pairs.has(pair_key):
			errors.append("同一对记忆只能保留一条连线")
		pairs[pair_key] = true

static func _validate_moderation_result(data: Variant, errors: Array[String]) -> void:
	if not data is Dictionary or (data as Dictionary).get("approved") != true:
		errors.append("内容审核结果必须 approved=true")

static func _validate_request_id(meta: Variant, errors: Array[String]) -> void:
	if not meta is Dictionary:
		errors.append("响应缺少 meta")
		return
	_string_field(meta as Dictionary, "request_id", 1, 128, errors, "meta.")

static func _validate_success_meta(meta: Variant, errors: Array[String]) -> void:
	if not meta is Dictionary:
		return
	var value := meta as Dictionary
	_string_field(value, "provider", 1, 64, errors, "meta.")
	_string_field(value, "model", 1, 128, errors, "meta.")
	_string_field(value, "prompt_version", 1, 64, errors, "meta.")
	_enum_field(value, "source", SUCCESS_SOURCES, errors, "meta.")
	_enum_field(value, "result", RESULT_TYPES, errors, "meta.")
	if value.get("source") == "fallback" and String(value.get("fallback_reason", "")) == "":
		errors.append("fallback 响应缺少 fallback_reason")

static func _validate_error(error: Variant, errors: Array[String]) -> void:
	if not error is Dictionary:
		errors.append("失败响应缺少 error")
		return
	var value := error as Dictionary
	_string_field(value, "code", 1, 64, errors, "error.")
	_string_field(value, "message", 1, 240, errors, "error.")
	if typeof(value.get("retryable")) != TYPE_BOOL:
		errors.append("error.retryable 必须是 bool")

static func _string_field(value: Dictionary, key: String, minimum: int, maximum: int, errors: Array[String], prefix: String = "") -> void:
	if typeof(value.get(key)) != TYPE_STRING:
		errors.append("%s%s 必须是 String" % [prefix, key])
		return
	var length := String(value.get(key)).length()
	if length < minimum or length > maximum:
		errors.append("%s%s 长度必须为 %d..%d" % [prefix, key, minimum, maximum])

static func _enum_field(value: Dictionary, key: String, allowed: Array, errors: Array[String], prefix: String = "") -> void:
	if value.get(key) not in allowed:
		errors.append("%s%s 不是允许值" % [prefix, key])

static func _number_range(value: Dictionary, key: String, minimum: float, maximum: float, errors: Array[String], prefix: String = "") -> void:
	var number: Variant = value.get(key)
	if typeof(number) != TYPE_INT and typeof(number) != TYPE_FLOAT:
		errors.append("%s%s 必须是数字" % [prefix, key])
		return
	if float(number) < minimum or float(number) > maximum:
		errors.append("%s%s 必须位于 %.1f..%.1f" % [prefix, key, minimum, maximum])

static func _result(errors: Array[String]) -> Dictionary:
	return {"ok": errors.is_empty(), "errors": errors}

static func _valid_upload_id(value: String) -> bool:
	if not value.begins_with("upload_") or value.length() != 39:
		return false
	return value.trim_prefix("upload_").is_valid_hex_number(false)
