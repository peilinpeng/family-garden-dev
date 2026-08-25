class_name AIHttpBackend
extends Node

## CloudBase ai_gateway 的 Godot HTTP 适配层。
## 只读取公开项目配置和 user:// 设备身份；不接触任何云服务密钥。

const CONFIG_PATH := "res://config/ai.json"
const DEFAULT_TIMEOUT_SECONDS := 45.0

var _config: Dictionary = {}
var _generation: int = 0
var _active: Dictionary = {}

func _init(config_override: Dictionary = {}) -> void:
	_config = config_override.duplicate(true) if not config_override.is_empty() else load_config()

static func load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func is_configured() -> bool:
	return bool(_config.get("enabled", false)) and String(_config.get("endpoint", "")).begins_with("https://")

func cache_ttl_seconds() -> float:
	return maxf(0.0, float(_config.get("cache_ttl_seconds", 0.0)))

func cache_namespace() -> String:
	return String(_config.get("cache_namespace", ""))

func cancel_all() -> void:
	# 不强制 free 正在 await 的 HTTPRequest，避免悬挂协程；递增代次后旧响应只会返回 CANCELLED。
	_generation += 1

func request(route_path: String, payload: Dictionary) -> Dictionary:
	return await _request_internal(route_path, payload, "")

func request_with_key(route_path: String, payload: Dictionary, idempotency_key: String) -> Dictionary:
	return await _request_internal(route_path, payload, idempotency_key)

func _request_internal(route_path: String, payload: Dictionary, idempotency_key: String) -> Dictionary:
	var identity := CloudBaseBackend.load_identity()
	var token := String(identity.get("member_token", ""))
	var request_id := _new_request_id(idempotency_key, token)
	if not is_configured():
		return _failure("NETWORK_OFFLINE", "AI 后端未启用。", true, request_id)
	if token == "":
		return _failure("UNAUTHORIZED", "尚未取得成员身份。", false, request_id)
	var action := route_path.trim_suffix("/").get_file()
	if action == "":
		return _failure("INVALID_REQUEST", "AI 路由无效。", false, request_id)
	var body := payload.duplicate(true)
	body["action"] = action
	var request := HTTPRequest.new()
	request.timeout = maxf(1.0, float(_config.get("timeout_seconds", DEFAULT_TIMEOUT_SECONDS)))
	add_child(request)
	var generation := _generation
	_active[request_id] = request
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token,
		"X-Request-ID: " + request_id,
	])
	var start_error := request.request(
		String(_config.get("endpoint", "")),
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	if start_error != OK:
		_active.erase(request_id)
		request.queue_free()
		return _failure("NETWORK_OFFLINE", "AI 请求无法启动。", true, request_id)
	var completed: Array = await request.request_completed
	_active.erase(request_id)
	request.queue_free()
	if generation != _generation:
		return _failure("CANCELLED", "AI 请求已取消。", false, request_id)
	var result_code := int(completed[0])
	var status_code := int(completed[1])
	var bytes := completed[3] as PackedByteArray
	if result_code == HTTPRequest.RESULT_TIMEOUT:
		return _failure("AI_TIMEOUT", "AI 请求超时。", true, request_id)
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return _failure("NETWORK_OFFLINE", "AI 网络请求失败。", true, request_id)
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return _failure("AI_INVALID_OUTPUT", "AI 响应不是合法 JSON。", true, request_id)
	var envelope := parsed as Dictionary
	if status_code < 200 or status_code >= 300:
		if envelope.has("ok"):
			return envelope
		return _failure("AI_UPSTREAM_ERROR", "AI 服务返回异常状态。", true, request_id)
	return envelope

func _new_request_id(idempotency_key: String = "", member_token: String = "") -> String:
	if idempotency_key != "":
		var member_scope := member_token.sha256_text().left(16) if member_token != "" else "anonymous"
		return "godot_" + (idempotency_key + "|" + member_scope).sha256_text().left(48)
	return "godot_%d_%08x" % [Time.get_ticks_msec(), randi()]

func _failure(code: String, message: String, retryable: bool, request_id: String) -> Dictionary:
	return {
		"ok": false,
		"error": {"code": code, "message": message, "retryable": retryable},
		"meta": {"request_id": request_id},
	}
