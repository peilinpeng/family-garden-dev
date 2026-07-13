extends Control

class FakePersistence:
	extends Node
	func persist_record(_table: String, _row: Dictionary) -> void:
		pass
	func persist_record_confirmed(_table: String, row: Dictionary) -> Dictionary:
		return {"ok": true, "id": String(row.get("id", ""))}
	func load_table(_table: String, _query: String = "") -> Array:
		return []

class FakeAIBackend:
	extends Node
	func request(path: String, _payload: Dictionary) -> Dictionary:
		var route := path.get_file()
		var data: Dictionary = AIClient.MOCK_KITCHEN_DISH.duplicate(true) if route == "generate-kitchen-dish" else {"approved": true, "safety_note": "test pass"}
		return {
			"ok": true,
			"data": data,
			"meta": {"request_id": "kitchen_panel_test", "provider": "fake", "model": "fake", "prompt_version": "test", "source": "ai", "result": "complete"},
		}
	func cache_namespace() -> String:
		return "kitchen-panel-test"
	func cache_ttl_seconds() -> float:
		return 0.0

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var persistence := FakePersistence.new()
	get_tree().root.add_child(persistence)
	CloudManager.set_persistence_backend(persistence)
	var ai_backend := FakeAIBackend.new()
	get_tree().root.add_child(ai_backend)
	AIClient.set_backend(ai_backend)
	MemoryManager._reset_all()
	InventoryManager.storehouse.from_array([
		{"id": "produce_corrato", "count": 4},
		{"id": "produce_tomelone", "count": 3},
		{"id": "produce_peanks", "count": 2},
		{"id": "produce_cauliviol", "count": 2},
		{"id": "produce_bottarries", "count": 2},
		{"id": "produce_safruma", "count": 2},
	])
	var panel := KitchenCookingPanel.new()
	add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame

	_assert(panel.add_ingredient("produce_corrato"), "点击食材应能加入锅中")
	_assert(panel.add_ingredient("produce_corrato"), "重复食材应增加数量")
	_assert(panel.add_ingredient("produce_tomelone"), "第二种食材应能加入锅中")
	_assert(panel.add_ingredient("produce_peanks"), "第三种食材应能加入锅中")
	var selected := panel.selected_ingredients()
	_assert(selected.size() == 3, "锅中应合并为三种食材")
	_assert(_quantity_of(selected, "produce_corrato") == 2, "重复加入的番茄数量应为二")
	var too_many := KitchenManager.validate_ai_ingredients([
		{"id": "produce_corrato", "qty": 1},
		{"id": "produce_tomelone", "qty": 1},
		{"id": "produce_peanks", "qty": 1},
		{"id": "produce_cauliviol", "qty": 1},
		{"id": "produce_bottarries", "qty": 1},
		{"id": "produce_safruma", "qty": 1},
	])
	_assert(not too_many.ok and String(too_many.error.code) == "INVALID_INGREDIENTS", "一次烹饪必须限制为最多五种食材")
	var over_stock := KitchenManager.validate_ai_ingredients([{"id": "produce_corrato", "qty": 99}])
	_assert(not over_stock.ok and String(over_stock.error.code) == "INGREDIENTS_CHANGED", "食材数量不能超过共享仓库存")

	await get_tree().process_frame
	var capture_path := OS.get_environment("KITCHEN_CAPTURE_PATH")
	if capture_path != "":
		_assert(_save_capture(capture_path), "烹饪面板视觉验收截图应能保存")

	var tomato_before := InventoryManager.storehouse.count("produce_corrato")
	panel._start_cooking()
	await get_tree().process_frame
	_assert(panel._cooking, "发起请求后面板应立即进入烹饪状态")
	_assert(panel._effects.cooking, "AI 等待期间锅内效果应持续播放")
	await get_tree().create_timer(KitchenCookingPanel.MIN_COOK_SECONDS + 0.35).timeout
	_assert(panel._state == "success", "互动面板应能完成 AI 料理并进入揭晓状态")
	_assert(not panel._latest_dish.is_empty(), "互动面板应展示已保存的料理结果")
	_assert(InventoryManager.storehouse.count("produce_corrato") == tomato_before - 2, "互动面板成功后应按锅中数量扣料")
	if capture_path != "":
		for _frame in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var result_path := capture_path.get_basename() + "_success.png"
		_assert(_save_capture(result_path), "料理结果视觉验收截图应能保存")
	panel.queue_free()
	persistence.queue_free()
	ai_backend.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("Kitchen cooking panel tests passed: selection, merge, limits, stock, render")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _quantity_of(ingredients: Array, item_id: String) -> int:
	for raw in ingredients:
		if raw is Dictionary and String((raw as Dictionary).get("id", "")) == item_id:
			return int((raw as Dictionary).get("qty", 0))
	return 0

func _save_capture(path: String) -> bool:
	var image: Image = get_viewport().get_texture().get_image()
	var saved := image != null and image.save_png(path) == OK
	image = null
	return saved

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
