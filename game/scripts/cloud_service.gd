extends Node
class_name CloudService

# Family Garden Supabase service.
# Uses Supabase REST API + Storage API through Godot HTTPRequest.
#
# Important:
# - This uses the anon public key only.
# - Do NOT put a service_role key in a Godot client.
# - MVP family_id is fixed: Happy_birthday_David.

const SUPABASE_URL: String = "https://cfocwdhlskwlozynmzvb.supabase.co"
const SUPABASE_ANON_KEY: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNmb2N3ZGhsc2t3bG96eW5tenZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5OTk2MTcsImV4cCI6MjA5NTU3NTYxN30.MyMa382XjzvbHB9CVgRm7E8pjVKqPsic0tCmAvTNz6Q"
const FAMILY_ID: String = "Happy_birthday_David"
const REST_BASE: String = SUPABASE_URL + "/rest/v1"
const STORAGE_BUCKET: String = "family-photos"

# ── 持久化后端接缝（迭代1a · 后端无关接口）─────────────────────────────────
# 默认无远端后端：persist/load/delete 为 no-op / 空，由 MemoryManager 本地存档兜底。
# 迭代1b 通过 set_persistence_backend 注入 CloudBase（或 Supabase）后端实现
# （需实现 persist_record(table,row) / load_table(table,query) / delete_record(table,id)），
# MemoryManager 的写入/读取出入口签名不变。
var _persist_backend: Object = null

## 启动:若 config/cloudbase.json 配了 endpoint,注入 CloudBase 后端并预拉云端;
## 未配置则保持本地(接缝全 no-op),游戏照常离线运行。
func _ready() -> void:
	if CloudBaseBackend.is_configured():
		var backend := CloudBaseBackend.new()
		add_child(backend)
		set_persistence_backend(backend)
		await get_tree().process_frame   # 等其它 autoload(MemoryManager 等)就绪
		await backend.bootstrap()

func set_persistence_backend(backend: Object) -> void:
	_persist_backend = backend

func persist_record(table: String, row: Dictionary) -> void:
	if _persist_backend != null and _persist_backend.has_method("persist_record"):
		_persist_backend.persist_record(table, row)

func load_table(table: String, query: String = "") -> Array:
	if _persist_backend != null and _persist_backend.has_method("load_table"):
		return _persist_backend.load_table(table, query)
	return []

func delete_record(table: String, row_id: String) -> void:
	if _persist_backend != null and _persist_backend.has_method("delete_record"):
		_persist_backend.delete_record(table, row_id)


func load_family_data() -> Dictionary:
	var places: Array = await select_table("travel_places", "family_id=eq.%s&order=created_at.asc" % _url_encode(FAMILY_ID))
	var postcards: Array = await select_table("postcards", "family_id=eq.%s&order=created_at.asc" % _url_encode(FAMILY_ID))
	var messages: Array = await select_table("messages", "family_id=eq.%s&order=created_at.asc" % _url_encode(FAMILY_ID))
	var mailbox_events: Array = await select_table("mailbox_events", "family_id=eq.%s&order=created_at.desc" % _url_encode(FAMILY_ID))

	return {
		"travel_places": places,
		"postcards": postcards,
		"messages": messages,
		"mailbox_events": mailbox_events,
	}


func select_table(table_name: String, query_string: String = "") -> Array:
	var url: String = REST_BASE + "/" + table_name
	if query_string != "":
		url += "?" + query_string

	var result: Dictionary = await _request_json(HTTPClient.METHOD_GET, url)
	if not bool(result.get("ok", false)):
		push_warning("Cloud select failed: %s %s" % [table_name, str(result)])
		return []

	var data: Variant = result.get("data", [])
	if typeof(data) == TYPE_ARRAY:
		return data

	return []


func insert_row(table_name: String, row: Dictionary) -> Dictionary:
	var payload: Dictionary = row.duplicate(true)
	payload["family_id"] = FAMILY_ID

	var result: Dictionary = await _request_json(
		HTTPClient.METHOD_POST,
		REST_BASE + "/" + table_name,
		payload,
		["Prefer: return=representation"]
	)

	if not bool(result.get("ok", false)):
		push_warning("Cloud insert failed: %s %s" % [table_name, str(result)])
		return {}

	var data: Variant = result.get("data", [])
	if typeof(data) == TYPE_ARRAY:
		var data_array: Array = data
		if data_array.size() > 0 and typeof(data_array[0]) == TYPE_DICTIONARY:
			return data_array[0]

	return {}


func update_row(table_name: String, row_id: String, patch: Dictionary) -> bool:
	var url: String = REST_BASE + "/" + table_name + "?id=eq." + _url_encode(row_id)
	var result: Dictionary = await _request_json(
		HTTPClient.METHOD_PATCH,
		url,
		patch,
		["Prefer: return=minimal"]
	)
	return bool(result.get("ok", false))


func delete_row(table_name: String, row_id: String) -> bool:
	var url: String = REST_BASE + "/" + table_name + "?id=eq." + _url_encode(row_id)
	var result: Dictionary = await _request_json(
		HTTPClient.METHOD_DELETE,
		url,
		{},
		["Prefer: return=minimal"]
	)
	return bool(result.get("ok", false))


func create_place_with_postcard(title: String, note: String, map_x: float, map_y: float, member_id: String = "", photo_path: String = "") -> Dictionary:
	var member_value: Variant = null
	if member_id != "":
		member_value = member_id

	var photo_value: Variant = null
	if photo_path != "":
		photo_value = photo_path

	var place: Dictionary = await insert_row("travel_places", {
		"member_id": member_value,
		"title": title,
		"note": note,
		"map_x": map_x,
		"map_y": map_y,
		"photo_path": photo_value,
	})

	if place.is_empty():
		return {}

	var place_id: String = str(place.get("id", ""))

	var postcard: Dictionary = await insert_row("postcards", {
		"place_id": place_id,
		"member_id": member_value,
		"title": "Postcard from " + title,
		"message": note,
		"photo_path": photo_value,
		"is_new": true,
	})

	var target_value: Variant = null
	if not postcard.is_empty():
		target_value = postcard.get("id", null)

	await insert_row("mailbox_events", {
		"type": "postcard",
		"title": "New postcard from " + title,
		"message": note,
		"target_id": target_value,
		"is_read": false,
	})

	return {
		"place": place,
		"postcard": postcard,
	}


func delete_place_and_postcards(place_id: String) -> void:
	var postcard_url: String = REST_BASE + "/postcards?place_id=eq." + _url_encode(place_id)
	await _request_json(HTTPClient.METHOD_DELETE, postcard_url, {}, ["Prefer: return=minimal"])
	await delete_row("travel_places", place_id)


func create_message(author_name: String, body: String, member_id: String = "") -> Dictionary:
	var member_value: Variant = null
	if member_id != "":
		member_value = member_id

	var message: Dictionary = await insert_row("messages", {
		"member_id": member_value,
		"author_name": author_name,
		"body": body,
	})

	var target_value: Variant = null
	if not message.is_empty():
		target_value = message.get("id", null)

	await insert_row("mailbox_events", {
		"type": "message",
		"title": "New garden note",
		"message": body,
		"target_id": target_value,
		"is_read": false,
	})

	return message


func mark_mailbox_read() -> bool:
	var url: String = REST_BASE + "/mailbox_events?family_id=eq.%s&is_read=eq.false" % _url_encode(FAMILY_ID)
	var result: Dictionary = await _request_json(
		HTTPClient.METHOD_PATCH,
		url,
		{"is_read": true},
		["Prefer: return=minimal"]
	)
	return bool(result.get("ok", false))


func has_unread_mailbox_events() -> bool:
	var events: Array = await select_table(
		"mailbox_events",
		"family_id=eq.%s&is_read=eq.false&select=id&type=neq.none&limit=1" % _url_encode(FAMILY_ID)
	)
	return events.size() > 0


func upload_photo_from_path(local_path: String, remote_name_prefix: String = "photo") -> String:
	var file := FileAccess.open(local_path, FileAccess.READ)
	if file == null:
		push_warning("Could not open photo: " + local_path)
		return ""

	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	var ext: String = local_path.get_extension().to_lower()
	var content_type: String = _content_type_for_extension(ext)
	var original_name: String = local_path.get_file()

	return await upload_photo_bytes_with_name(bytes, original_name, remote_name_prefix, content_type)


func upload_photo_bytes_with_name(bytes: PackedByteArray, original_file_name: String, remote_name_prefix: String = "photo", content_type: String = "image/jpeg") -> String:
	if bytes.is_empty():
		push_warning("No photo bytes to upload.")
		return ""

	var normalized_content_type: String = _normalize_content_type(content_type, original_file_name)
	var ext: String = original_file_name.get_extension().to_lower()
	if ext == "":
		ext = _extension_for_content_type(normalized_content_type)

	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var safe_prefix: String = _safe_storage_name(remote_name_prefix)
	if safe_prefix == "":
		safe_prefix = "photo"

	var remote_path: String = "%s/places/%s_%s.%s" % [FAMILY_ID, safe_prefix, stamp, ext]

	print("[CloudService] Uploading photo bytes: path=", remote_path, " bytes=", bytes.size(), " content_type=", normalized_content_type)
	var ok: bool = await upload_photo_bytes(bytes, remote_path, normalized_content_type)
	if not ok:
		return ""

	return STORAGE_BUCKET + "/" + remote_path


func upload_photo_bytes(bytes: PackedByteArray, remote_path: String, content_type: String = "image/jpeg") -> bool:
	if bytes.is_empty():
		push_warning("No photo bytes to upload.")
		return false

	var normalized_content_type: String = _normalize_content_type(content_type, remote_path)
	var encoded_path: String = _encode_storage_path(remote_path)
	var url: String = SUPABASE_URL + "/storage/v1/object/" + STORAGE_BUCKET + "/" + encoded_path

	var result: Dictionary = await _storage_raw_request(url, HTTPClient.METHOD_POST, bytes, normalized_content_type)
	if bool(result.get("ok", false)):
		return true

	var status_code: int = int(result.get("status", 0))
	if status_code == 409 or status_code == 405:
		print("[CloudService] POST upload failed with status ", status_code, "; retrying with PUT.")
		result = await _storage_raw_request(url, HTTPClient.METHOD_PUT, bytes, normalized_content_type)
		if bool(result.get("ok", false)):
			return true

	push_warning("Storage upload failed: status=%s result=%s body=%s" % [str(result.get("status", 0)), str(result.get("result", 0)), str(result.get("raw", ""))])
	return false


func _storage_raw_request(url: String, method: int, bytes: PackedByteArray, content_type: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.accept_gzip = false
	add_child(request)

	var headers: PackedStringArray = PackedStringArray([
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY,
		"Content-Type: " + content_type,
		"Cache-Control: 3600",
		"x-upsert: true"
	])

	var err: int = request.request_raw(url, headers, method, bytes)
	if err != OK:
		request.queue_free()
		push_warning("Storage request failed to start: " + str(err))
		return {
			"ok": false,
			"status": 0,
			"result": err,
			"raw": "request_start_failed_" + str(err),
		}

	var response: Array = await request.request_completed
	request.queue_free()

	var result_code: int = int(response[0])
	var status_code: int = int(response[1])
	var raw_body: PackedByteArray = response[3]
	var text: String = raw_body.get_string_from_utf8()
	var ok: bool = result_code == HTTPRequest.RESULT_SUCCESS and status_code >= 200 and status_code < 300
	print("[CloudService] Storage response: method=", method, " status=", status_code, " result=", result_code, " body=", text)

	return {
		"ok": ok,
		"status": status_code,
		"result": result_code,
		"raw": text,
	}


func public_url_from_photo_path(photo_path: String) -> String:
	var clean_path: String = photo_path
	if clean_path.begins_with(STORAGE_BUCKET + "/"):
		clean_path = clean_path.substr(STORAGE_BUCKET.length() + 1)

	return SUPABASE_URL + "/storage/v1/object/public/" + STORAGE_BUCKET + "/" + _encode_storage_path(clean_path)


func _request_json(method: int, url: String, body: Variant = null, extra_headers: Array = []) -> Dictionary:
	var request := HTTPRequest.new()
	request.accept_gzip = false
	add_child(request)

	var headers: PackedStringArray = PackedStringArray([
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY,
		"Content-Type: application/json",
	])

	for header in extra_headers:
		headers.append(str(header))

	var body_text: String = ""
	if body != null:
		body_text = JSON.stringify(body)

	var err: int = request.request(url, headers, method, body_text)
	if err != OK:
		request.queue_free()
		return {
			"ok": false,
			"status": 0,
			"error": "request_start_failed_" + str(err),
			"data": null,
		}

	var response: Array = await request.request_completed
	request.queue_free()

	var result_code: int = int(response[0])
	var status_code: int = int(response[1])
	var raw_body: PackedByteArray = response[3]
	var text: String = raw_body.get_string_from_utf8()

	var parsed: Variant = null
	if text.strip_edges() != "":
		parsed = JSON.parse_string(text)

	var ok: bool = result_code == HTTPRequest.RESULT_SUCCESS and status_code >= 200 and status_code < 300
	return {
		"ok": ok,
		"status": status_code,
		"data": parsed,
		"raw": text,
	}


func _normalize_content_type(content_type: String, file_name: String = "") -> String:
	var clean_type: String = content_type.strip_edges().to_lower()
	if clean_type == "" or clean_type == "application/octet-stream":
		var ext: String = file_name.get_extension().to_lower()
		return _content_type_for_extension(ext)
	if clean_type == "image/jpg":
		return "image/jpeg"
	if clean_type == "image/png" or clean_type == "image/jpeg" or clean_type == "image/webp":
		return clean_type
	return "image/jpeg"


func _safe_storage_name(value: String) -> String:
	var safe: String = value.strip_edges().to_lower()
	safe = safe.replace(" ", "_")
	safe = safe.replace("/", "_")
	safe = safe.replace("\\", "_")
	safe = safe.replace(":", "-")
	safe = safe.replace("?", "")
	safe = safe.replace("#", "")
	safe = safe.replace("&", "and")
	return safe


func _encode_storage_path(path: String) -> String:
	var parts: PackedStringArray = path.split("/", false)
	var encoded_parts: PackedStringArray = PackedStringArray()
	for part in parts:
		encoded_parts.append(str(part).uri_encode())
	return "/".join(encoded_parts)


func _content_type_for_extension(ext: String) -> String:
	match ext:
		"png":
			return "image/png"
		"webp":
			return "image/webp"
		"jpg", "jpeg":
			return "image/jpeg"
		_:
			return "application/octet-stream"


func _extension_for_content_type(content_type: String) -> String:
	match content_type:
		"image/png":
			return "png"
		"image/webp":
			return "webp"
		"image/jpeg", "image/jpg":
			return "jpg"
		_:
			return "jpg"


func _url_encode(value: String) -> String:
	return value.uri_encode()
