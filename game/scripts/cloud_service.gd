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
const WORLD_REFRESH_DEBOUNCE := 0.45
const WORLD_EVENT_TABLES := {
	"memories": true,
	"nodes": true,
	"answers": true,
	"rooms": true,
	"room_objects": true,
	"families": true,
	"travel_places": true,
	"postcards": true,
	"messages": true,
	"mailbox_events": true,
	"inventories": true,
	"farm_plots": true,
	"farm_livestock": true,
	"farm_activity_log": true,
}

signal cloud_world_changed(event: Dictionary)

# ── 持久化后端接缝（迭代1a · 后端无关接口）─────────────────────────────────
# 默认无远端后端：persist/load/delete 为 no-op / 空，由 MemoryManager 本地存档兜底。
# 迭代1b 通过 set_persistence_backend 注入 CloudBase（或 Supabase）后端实现
# （需实现 persist_record(table,row) / load_table(table,query) / delete_record(table,id)），
# MemoryManager 的写入/读取出入口签名不变。
var _persist_backend: Object = null
var _world_refresh_pending := false
var _world_refresh_running := false
var _latest_world_event: Dictionary = {}

## 启动:若 config/cloudbase.json 配了 endpoint,注入 CloudBase 后端;
## 若本设备已自助加入过(user://cloud_identity.json 里有令牌)则立刻预拉云端;
## 若还没加入(第一次玩),先不 bootstrap——等玩家选完角色/起完昵称,
## scene_manager 会调 ensure_cloud_identity() 自助注册 + 补上这次 bootstrap。
## 未配置 endpoint 则保持纯本地(接缝全 no-op),游戏照常离线运行。
func _ready() -> void:
	if OS.has_environment("FAMILY_GARDEN_TEST"):
		return
	_connect_presence_world_events()
	if CloudBaseBackend.is_configured():
		var backend := CloudBaseBackend.new()
		add_child(backend)
		set_persistence_backend(backend)
		await get_tree().process_frame   # 等其它 autoload(MemoryManager 等)就绪
		if backend.has_identity():
			await backend.bootstrap()
			await _flush_ai_outbox()
			await _cleanup_ai_images()

func set_persistence_backend(backend: Object) -> void:
	_persist_backend = backend

## 首次选角色后调用:若配置了 CloudBase 但本设备还没自助加入过,
## 用选中的角色+昵称注册一个云身份,再补跑一次 bootstrap 把数据同步起来。
## 已经加入过的设备(has_identity()==true)直接跳过,不会重复注册。
func ensure_cloud_identity(role: String, display_name: String, family_code: String = "") -> bool:
	if _persist_backend == null or not _persist_backend.has_method("has_identity"):
		return false
	if _persist_backend.has_identity():
		return true
	var fam_id: String = _persist_backend.family_id() if _persist_backend.family_id() != "" \
		else str(CloudBaseBackend.load_config().get("family_id", ""))
	if family_code.strip_edges() != "":
		fam_id = family_code.strip_edges()
	if fam_id == "":
		push_warning("[CloudBase] 未配置 family_id,无法自助加入")
		return false
	var joined: bool = await _persist_backend.join_family(fam_id, role, display_name)
	if joined:
		await _persist_backend.bootstrap()
		await _flush_ai_outbox()
		await _cleanup_ai_images()
		return true
	return false

func family_code() -> String:
	if GameIdentity != null and GameIdentity.is_ready():
		return str(GameIdentity.family_id)
	if _persist_backend != null and _persist_backend.has_method("family_id"):
		var fam_id := str(_persist_backend.family_id())
		if fam_id != "":
			return fam_id
	return str(CloudBaseBackend.load_config().get("family_id", ""))

func _flush_ai_outbox() -> void:
	var workflow := get_node_or_null("/root/AIWorkflowManager")
	var memory_manager := get_node_or_null("/root/MemoryManager")
	var had_pending: bool = false
	if memory_manager != null:
		had_pending = not memory_manager.ai_sync_outbox.is_empty()
	if workflow != null and workflow.has_method("flush_ai_sync_outbox"):
		await workflow.flush_ai_sync_outbox()
		if had_pending and memory_manager.ai_sync_outbox.is_empty() and _persist_backend != null and _persist_backend.has_method("refresh"):
			await _persist_backend.refresh()
			memory_manager.pull_remote()
		if workflow.has_method("retry_pending_links"):
			await workflow.retry_pending_links(2)

func _cleanup_ai_images() -> void:
	if _persist_backend != null and _persist_backend.has_method("cleanup_orphan_images"):
		await _persist_backend.cleanup_orphan_images()

func list_family_members() -> Array:
	if _persist_backend != null and _persist_backend.has_method("list_family_members"):
		return await _persist_backend.list_family_members()
	return []

func persist_record(table: String, row: Dictionary) -> void:
	if _persist_backend != null and _persist_backend.has_method("persist_record"):
		_persist_backend.persist_record(table, row)
		_announce_world_changed(table, str(row.get("id", "")), "upsert", row)

func persist_ai_record_confirmed(table: String, row: Dictionary) -> Dictionary:
	if _persist_backend != null and _persist_backend.has_method("persist_record_confirmed"):
		var result: Dictionary = await _persist_backend.persist_record_confirmed(table, row)
		if bool(result.get("ok", false)):
			_announce_world_changed(table, str(result.get("id", row.get("id", ""))), "upsert", row)
		return result
	persist_record(table, row)
	return {"ok": true, "id": str(row.get("id", "")), "local_only": true}

func load_table(table: String, query: String = "") -> Array:
	if _persist_backend != null and _persist_backend.has_method("load_table"):
		return _persist_backend.load_table(table, query)
	return []

func delete_record(table: String, row_id: String) -> void:
	if _persist_backend != null and _persist_backend.has_method("delete_record"):
		_persist_backend.delete_record(table, row_id)
		_announce_world_changed(table, row_id, "delete", {})

func delete_ai_record_confirmed(table: String, row_id: String) -> Dictionary:
	if _persist_backend != null and _persist_backend.has_method("delete_record_confirmed"):
		var result: Dictionary = await _persist_backend.delete_record_confirmed(table, row_id)
		if bool(result.get("ok", false)):
			_announce_world_changed(table, row_id, "delete", {})
		return result
	delete_record(table, row_id)
	return {"ok": true, "local_only": true}

func load_farm_plots() -> Array:
	return load_table("farm_plots")

func save_farm_plot(row: Dictionary) -> void:
	persist_record("farm_plots", row)

func save_farm_plot_confirmed(row: Dictionary) -> Dictionary:
	if _persist_backend != null and _persist_backend.has_method("persist_record_confirmed"):
		var res: Dictionary = await _persist_backend.persist_record_confirmed("farm_plots", row)
		if bool(res.get("ok", false)):
			var row_id := str(res.get("id", row.get("id", "")))
			_announce_world_changed("farm_plots", row_id, "upsert", row)
		return res
	save_farm_plot(row)
	return {"ok": true, "id": str(row.get("id", ""))}

func delete_farm_plot(row_id: String) -> void:
	delete_record("farm_plots", row_id)

func delete_farm_plot_confirmed(row_id: String) -> Dictionary:
	if _persist_backend != null and _persist_backend.has_method("delete_record_confirmed"):
		var res: Dictionary = await _persist_backend.delete_record_confirmed("farm_plots", row_id)
		if bool(res.get("ok", false)):
			_announce_world_changed("farm_plots", row_id, "delete", {})
		return res
	delete_farm_plot(row_id)
	return {"ok": true}

func mutate_storehouse_confirmed(consumes: Array, grants: Array, operation_id: String) -> Dictionary:
	if _persist_backend != null and _persist_backend.has_method("mutate_storehouse"):
		var res: Dictionary = await _persist_backend.mutate_storehouse(consumes, grants, operation_id)
		if bool(res.get("ok", false)):
			_announce_world_changed("inventories", str(res.get("id", "storehouse")), "upsert", {"kind": "storehouse"})
		return res
	return {"ok": false, "local_only": true, "error": "cloud backend unavailable"}

func perform_farm_action_confirmed(action: String, payload: Dictionary, operation_id: String) -> Dictionary:
	if _persist_backend != null and _persist_backend.has_method("perform_farm_action"):
		var res: Dictionary = await _persist_backend.perform_farm_action(action, payload, operation_id)
		if bool(res.get("ok", false)):
			_announce_world_changed("inventories", "storehouse", "upsert", {"kind": "storehouse"})
			var table := "farm_livestock" if action == "collect_livestock" else "farm_plots"
			var row_id := str(res.get("deleted_plot_id", ""))
			if row_id == "" and res.get("plot", null) is Dictionary:
				row_id = str((res["plot"] as Dictionary).get("id", ""))
			if row_id == "" and res.get("livestock", null) is Dictionary:
				row_id = str((res["livestock"] as Dictionary).get("id", ""))
			_announce_world_changed(table, row_id, "delete" if res.has("deleted_plot_id") else "upsert", {})
		return res
	return {"ok": false, "local_only": true, "error": "cloud backend unavailable"}

func has_cloud_records() -> bool:
	return _use_cloudbase_records()

func upload_ai_image(bytes: PackedByteArray, content_type: String) -> Dictionary:
	if _persist_backend == null or not _persist_backend.has_method("upload_image"):
		return {"ok": false, "error": "CloudBase 图片上传未配置"}
	return await _persist_backend.upload_image(bytes, content_type)

func resolve_ai_image(upload_id: String) -> Dictionary:
	if _persist_backend == null or not _persist_backend.has_method("resolve_image"):
		return {"ok": false, "error": "CloudBase 图片解析未配置"}
	return await _persist_backend.resolve_image(upload_id)

func delete_ai_image(upload_id: String) -> bool:
	if _persist_backend == null or not _persist_backend.has_method("delete_image"):
		return false
	return await _persist_backend.delete_image(upload_id)

## M1 旅行照片入口：先统一解码/重编码以移除 EXIF 等元数据，再交给身份网关。
## 业务记录只保存 upload_id；返回的临时 URL 不会写入存档或共享表。
func upload_private_photo(bytes: PackedByteArray, content_type: String) -> Dictionary:
	if _persist_backend == null or not _persist_backend.has_method("upload_image"):
		return {"ok": false, "error": {"code": "CLOUD_UNAVAILABLE", "message": "家庭云端尚未就绪。"}}
	var prepared: Dictionary = AIImageUploadService.prepare(bytes, content_type)
	if not bool(prepared.get("ok", false)):
		return prepared
	var uploaded: Dictionary = await _persist_backend.upload_image(
		prepared.get("bytes", PackedByteArray()),
		String(prepared.get("content_type", "image/jpeg")),
		"travel"
	)
	if not bool(uploaded.get("ok", false)):
		return uploaded
	var upload_id := String(uploaded.get("upload_id", ""))
	if upload_id == "":
		return {"ok": false, "error": {"code": "UPLOAD_INVALID_RESPONSE", "message": "云端未返回有效图片引用。"}}
	return {
		"ok": true,
		"upload_id": upload_id,
		"source_size": prepared.get("source_size", Vector2i.ZERO),
		"output_size": prepared.get("output_size", Vector2i.ZERO),
		"source_bytes": int(prepared.get("source_bytes", 0)),
		"output_bytes": int(prepared.get("output_bytes", 0)),
	}

func resolve_private_photo(upload_id: String) -> Dictionary:
	if _persist_backend == null or not _persist_backend.has_method("resolve_image"):
		return {"ok": false, "error": "CloudBase 图片解析未配置"}
	return await _persist_backend.resolve_image(upload_id)

func _use_cloudbase_records() -> bool:
	return _persist_backend != null \
		and _persist_backend.has_method("has_identity") \
		and _persist_backend.has_identity() \
		and _persist_backend.has_method("load_table") \
		and _persist_backend.has_method("persist_record")

func _cloudbase_row_id(prefix: String) -> String:
	return "%s_%d_%d" % [prefix, Time.get_ticks_msec(), randi() % 1000000]

func _connect_presence_world_events() -> void:
	if PresenceChannel == null:
		return
	if not PresenceChannel.world_changed.is_connected(_on_presence_world_changed):
		PresenceChannel.world_changed.connect(_on_presence_world_changed)

func _is_world_event_table(table: String) -> bool:
	return WORLD_EVENT_TABLES.has(table)

func _should_broadcast_world_change(table: String, row_id: String, action: String, row: Dictionary) -> bool:
	if not _is_world_event_table(table):
		return false
	if table == "inventories":
		var kind := str(row.get("kind", ""))
		if action == "upsert" and kind != "storehouse":
			return false
		if action == "delete" and row_id == "backpack":
			return false
	return true

func _announce_world_changed(table: String, row_id: String, action: String, row: Dictionary) -> void:
	if not _should_broadcast_world_change(table, row_id, action, row):
		return
	if PresenceChannel != null and PresenceChannel.has_method("announce_world_changed"):
		PresenceChannel.announce_world_changed(table, row_id, action)

func _on_presence_world_changed(event: Dictionary) -> void:
	var table := str(event.get("table", ""))
	if not _is_world_event_table(table):
		return
	_latest_world_event = event.duplicate(true)
	_world_refresh_pending = true
	if _world_refresh_running:
		return
	_world_refresh_running = true
	call_deferred("_run_world_refresh")

func _run_world_refresh() -> void:
	while _world_refresh_pending:
		_world_refresh_pending = false
		var event := _latest_world_event.duplicate(true)
		await get_tree().create_timer(WORLD_REFRESH_DEBOUNCE).timeout
		if _persist_backend != null and _persist_backend.has_method("refresh"):
			await _persist_backend.refresh()
		var mem := get_node_or_null("/root/MemoryManager")
		if mem != null and mem.has_method("pull_remote"):
			mem.pull_remote()
		var inv := get_node_or_null("/root/InventoryManager")
		if inv != null and inv.has_method("sync_from_cloud"):
			inv.sync_from_cloud()
		cloud_world_changed.emit(event)
	_world_refresh_running = false


func load_family_data() -> Dictionary:
	if _use_cloudbase_records():
		return {
			"travel_places": load_table("travel_places"),
			"postcards": load_table("postcards"),
			"messages": load_table("messages"),
			"mailbox_events": load_table("mailbox_events"),
		}

	if _persist_backend != null and _persist_backend.has_method("has_identity"):
		return {
			"travel_places": [],
			"postcards": [],
			"messages": [],
			"mailbox_events": [],
		}

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


func create_place_with_postcard(title: String, note: String, map_x: float, map_y: float, member_id: String = "", photo_upload_id: String = "", legacy_photo_path: String = "") -> Dictionary:
	if _use_cloudbase_records():
		var stamp := Time.get_datetime_string_from_system()
		var place_id := _cloudbase_row_id("place")
		var postcard_id := _cloudbase_row_id("postcard")
		var event_id := _cloudbase_row_id("mailbox_event")
		var member_value := member_id
		var place := {
			"id": place_id,
			"member_id": member_value,
			"title": title,
			"note": note,
			"map_x": map_x,
			"map_y": map_y,
			"photo_upload_id": photo_upload_id,
			"created_at": stamp,
		}
		var postcard := {
			"id": postcard_id,
			"place_id": place_id,
			"member_id": member_value,
			"title": "来自%s的明信片" % title,
			"message": note,
			"photo_upload_id": photo_upload_id,
			"is_new": true,
			"created_at": stamp,
		}
		var event := {
			"id": event_id,
			"type": "postcard",
			"title": "来自%s的新明信片" % title,
			"message": note,
			"target_id": postcard_id,
			"is_read": false,
			"created_at": stamp,
		}
		persist_record("travel_places", place)
		persist_record("postcards", postcard)
		persist_record("mailbox_events", event)
		return {"place": place, "postcard": postcard}

	var member_value: Variant = null
	if member_id != "":
		member_value = member_id

	var photo_value: Variant = null
	if legacy_photo_path != "":
		photo_value = legacy_photo_path

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
		"title": "来自%s的明信片" % title,
		"message": note,
		"photo_path": photo_value,
		"is_new": true,
	})

	var target_value: Variant = null
	if not postcard.is_empty():
		target_value = postcard.get("id", null)

	await insert_row("mailbox_events", {
		"type": "postcard",
		"title": "来自%s的新明信片" % title,
		"message": note,
		"target_id": target_value,
		"is_read": false,
	})

	return {
		"place": place,
		"postcard": postcard,
	}


func delete_place_and_postcards(place_id: String) -> Dictionary:
	if _use_cloudbase_records():
		if not _persist_backend.has_method("delete_place_bundle"):
			return {"ok": false, "error": "CloudBase 地点级联删除未配置"}
		var result: Dictionary = await _persist_backend.delete_place_bundle(place_id)
		if bool(result.get("ok", false)):
			for postcard_id in result.get("postcard_ids", []):
				_announce_world_changed("postcards", str(postcard_id), "delete", {})
			for event_id in result.get("event_ids", []):
				_announce_world_changed("mailbox_events", str(event_id), "delete", {})
			_announce_world_changed("travel_places", place_id, "delete", {})
		return result

	if place_id.begins_with("place_"):
		return {"ok": true, "local_only": true}
	var postcard_url: String = REST_BASE + "/postcards?place_id=eq." + _url_encode(place_id)
	await _request_json(HTTPClient.METHOD_DELETE, postcard_url, {}, ["Prefer: return=minimal"])
	var deleted := await delete_row("travel_places", place_id)
	return {"ok": deleted}


func create_message(author_name: String, body: String, member_id: String = "") -> Dictionary:
	if _use_cloudbase_records():
		var stamp := Time.get_datetime_string_from_system()
		var message_id := _cloudbase_row_id("message")
		var event_id := _cloudbase_row_id("mailbox_event")
		var message := {
			"id": message_id,
			"member_id": member_id,
			"author_name": author_name,
			"body": body,
			"created_at": stamp,
		}
		var event := {
			"id": event_id,
			"type": "message",
			"title": "新的花园留言",
			"message": body,
			"target_id": message_id,
			"is_read": false,
			"created_at": stamp,
		}
		persist_record("messages", message)
		persist_record("mailbox_events", event)
		return message

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
		"title": "新的花园留言",
		"message": body,
		"target_id": target_value,
		"is_read": false,
	})

	return message


func mark_mailbox_read() -> bool:
	if _use_cloudbase_records():
		for event in load_table("mailbox_events"):
			if event is Dictionary and not bool(event.get("is_read", true)):
				var updated := (event as Dictionary).duplicate(true)
				updated["is_read"] = true
				persist_record("mailbox_events", updated)
		return true

	var url: String = REST_BASE + "/mailbox_events?family_id=eq.%s&is_read=eq.false" % _url_encode(FAMILY_ID)
	var result: Dictionary = await _request_json(
		HTTPClient.METHOD_PATCH,
		url,
		{"is_read": true},
		["Prefer: return=minimal"]
	)
	return bool(result.get("ok", false))


func has_unread_mailbox_events() -> bool:
	if _use_cloudbase_records():
		for event in load_table("mailbox_events"):
			if event is Dictionary and not bool(event.get("is_read", true)):
				return true
		return false

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
