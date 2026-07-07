extends SceneTree

## 显式设置 FG_AI_REAL_SMOKE=1 才会调用真实云端，避免日常测试产生费用。
## 可选 FG_AI_IMAGE_URL：提供有效的腾讯可达 HTTPS 图片时一并验收视觉接口。
## 可选 FG_AI_ONLY_IMAGE=1：仅补测图片接口，避免重复产生三次文字模型费用。

var failures: Array[String] = []
var client: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("FG_AI_REAL_SMOKE") != "1":
		print("Gate 3 real smoke skipped: set FG_AI_REAL_SMOKE=1 explicitly")
		quit(0)
		return
	if String(CloudBaseBackend.load_identity().get("member_token", "")) == "":
		push_error("Gate 3 real smoke requires user://cloud_identity.json")
		quit(1)
		return
	client = load("res://scripts/managers/ai_client.gd").new()
	root.add_child(client)
	await process_frame

	if OS.get_environment("FG_AI_ONLY_IMAGE") != "1":
		var memory: Dictionary = await client.generate_memory_card("", "今天和家人在花园里一起种下了一棵小树。", "mem_gate3_real_text")
		_check_success("generate-memory-card", memory)

		var bottle: Dictionary = await client.generate_bottle_question({"scene": "fishpond", "target_memory_type": "shared_memory"})
		_check_success("generate-bottle-question", bottle)

		var source := {"id": "mem_gate3_source", "ai_card": {"title": "一起种树", "description": "一家人在花园里种树并合影。", "memory_type": "family_event"}}
		var candidate := {"id": "mem_gate3_candidate", "ai_card": {"title": "花园浇水", "description": "一家人在同一个花园里给小树浇水。", "memory_type": "family_event"}}
		var links: Dictionary = await client.cross_memory_link(source, [candidate])
		_check_success("cross-memory-link", links)

	var image_url := OS.get_environment("FG_AI_IMAGE_URL")
	if image_url != "":
		var room: Dictionary = await client.analyze_room_photo(image_url, "mem_gate3_real_room")
		_check_success("analyze-room-photo", room)
	elif OS.get_environment("FG_AI_ONLY_IMAGE") == "1":
		failures.append("FG_AI_ONLY_IMAGE=1 时必须同时设置 FG_AI_IMAGE_URL")
	else:
		print("Gate 3 real smoke: analyze-room-photo skipped (FG_AI_IMAGE_URL not set)")

	client.queue_free()
	if failures.is_empty():
		print("Gate 3 real smoke passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_success(route: String, data: Dictionary) -> void:
	var result: Dictionary = client.last_result(route)
	var meta: Dictionary = result.get("meta", {})
	if data.is_empty() and not (route == "cross-memory-link" and data.has("links")):
		failures.append("%s 返回空 data" % route)
	if String(result.get("state", "")) != "success":
		failures.append("%s state=%s error=%s" % [route, result.get("state", ""), result.get("error", {}).get("code", "")])
	if String(meta.get("source", "")) != "ai":
		failures.append("%s source=%s，不是实时 AI" % [route, meta.get("source", "")])
	print("Gate 3 real %s: state=%s source=%s request_id=%s" % [
		route,
		result.get("state", ""),
		meta.get("source", ""),
		meta.get("request_id", ""),
	])
