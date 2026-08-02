extends Node

class FakePersistence:
	extends Node

	var uploads: Dictionary = {}
	var persisted: Array[Dictionary] = []
	var deleted_place_id := ""

	func has_identity() -> bool:
		return true

	func load_table(_table: String, _query: String = "") -> Array:
		return []

	func persist_record(table: String, row: Dictionary) -> void:
		persisted.append({"table": table, "row": row.duplicate(true)})

	func upload_image(bytes: PackedByteArray, content_type: String, purpose: String = "ai") -> Dictionary:
		var upload_id := "upload_0123456789abcdef0123456789abcdef"
		uploads[upload_id] = {
			"bytes": bytes,
			"content_type": content_type,
			"purpose": purpose,
		}
		return {
			"ok": true,
			"upload_id": upload_id,
			"image_url": "https://temporary.example.test/private.jpg",
		}

	func resolve_image(upload_id: String) -> Dictionary:
		return {
			"ok": uploads.has(upload_id),
			"image_url": "https://temporary.example.test/private.jpg",
		}

	func delete_place_bundle(place_id: String) -> Dictionary:
		deleted_place_id = place_id
		uploads.clear()
		return {
			"ok": true,
			"place_id": place_id,
			"postcard_ids": ["postcard_test"],
			"event_ids": ["event_test"],
			"deleted_upload_ids": ["upload_0123456789abcdef0123456789abcdef"],
		}

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	var persistence := FakePersistence.new()
	get_tree().root.add_child(persistence)
	CloudManager.set_persistence_backend(persistence)

	var image := Image.create(640, 480, false, Image.FORMAT_RGB8)
	image.fill(Color(0.32, 0.58, 0.42))
	var upload: Dictionary = await CloudManager.upload_private_photo(
		image.save_png_to_buffer(),
		"image/png"
	)
	_assert(bool(upload.get("ok", false)), "旅行照片应通过私有上传入口")
	var upload_id := String(upload.get("upload_id", ""))
	_assert(upload_id.begins_with("upload_"), "客户端只接收可持久化的 upload_id")
	_assert(not upload.has("image_url"), "临时签名 URL 不得从上传入口进入业务数据")
	var stored_upload: Dictionary = persistence.uploads.get(upload_id, {})
	_assert(String(stored_upload.get("content_type", "")) == "image/jpeg", "旅行照片应统一重编码为 JPEG")
	_assert(String(stored_upload.get("purpose", "")) == "travel", "旅行照片必须标记 travel 用途")

	var created: Dictionary = await CloudManager.create_place_with_postcard(
		"隐私测试地点",
		"只保存受控引用",
		320.0,
		240.0,
		"",
		upload_id
	)
	_assert(created.has("place") and created.has("postcard"), "旅行地点和明信片应正常创建")
	var checked_media_rows := 0
	for entry in persistence.persisted:
		if String(entry.get("table", "")) not in ["travel_places", "postcards"]:
			continue
		checked_media_rows += 1
		var row: Dictionary = entry.get("row", {})
		_assert(String(row.get("photo_upload_id", "")) == upload_id, "共享记录必须保存 photo_upload_id")
		_assert(not row.has("photo_path"), "新共享记录不得保存公开 photo_path")
		_assert(not row.values().has("https://temporary.example.test/private.jpg"), "共享记录不得保存临时签名 URL")
	_assert(checked_media_rows == 2, "地点与明信片两条共享记录都必须经过隐私字段校验")

	var resolved: Dictionary = await CloudManager.resolve_private_photo(upload_id)
	_assert(bool(resolved.get("ok", false)), "展示照片时应通过身份网关临时解析")
	_assert(String(resolved.get("image_url", "")).begins_with("https://"), "受控解析必须返回 HTTPS 临时 URL")
	_assert(
		SceneManager._photo_reference({"photo_upload_id": upload_id, "photo_path": "legacy/path.jpg"}) == upload_id,
		"受控引用必须优先于历史 photo_path"
	)
	var resolved_url: String = await SceneManager._resolve_photo_url(upload_id)
	_assert(resolved_url == "https://temporary.example.test/private.jpg", "照片展示必须按 upload_id 获取临时 URL")

	var deleted: Dictionary = await CloudManager.delete_place_and_postcards(String(created.place.id))
	_assert(bool(deleted.get("ok", false)), "删除地点应走服务端级联删除")
	_assert(persistence.deleted_place_id == String(created.place.id), "级联删除必须定位正确地点")
	_assert(persistence.uploads.is_empty(), "地点删除后对应私有照片应被回收")

	persistence.queue_free()
	if failures.is_empty():
		print("Photo privacy tests passed: preprocess, private reference, resolve, cascade delete")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
