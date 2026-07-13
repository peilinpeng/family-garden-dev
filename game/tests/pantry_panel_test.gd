extends Control

class FakePersistence:
	extends Node
	func persist_record(_table: String, _row: Dictionary) -> void:
		pass
	func load_table(_table: String, _query: String = "") -> Array:
		return []

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var persistence := FakePersistence.new()
	get_tree().root.add_child(persistence)
	CloudManager.set_persistence_backend(persistence)
	InventoryManager.storehouse.from_array([
		{"id": "produce_corrato", "count": 6},
		{"id": "produce_bottarries", "count": 5},
		{"id": "sugar", "count": 2},
		{"id": "honey", "count": 3},
		{"id": "bread", "count": 1},
		{"id": "seed_corrato", "count": 7},
		{"id": "dish_tomato_egg", "count": 4},
		{"id": "dish_strawberry_jam", "count": 1},
	])

	var panel := PantryPanel.new()
	add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(panel.card_size == Vector2(920, 590), "储藏面板应使用新版宽卡片布局")
	_assert(panel._visible_items().size() == 8, "全部分类应显示八种家庭食品")
	_assert(panel._selected_item_id != "", "打开面板后应默认选中第一项")
	_assert(panel._detail_box.get_child_count() >= 5, "选中物品后右侧应展示详情")
	var capture_path := OS.get_environment("PANTRY_CAPTURE_PATH")
	if capture_path != "":
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		_assert(image != null and image.save_png(capture_path) == OK, "储藏面板视觉验收截图应能保存")

	panel._select_category("produce")
	_assert(panel._visible_items().size() == 5, "食材分类应只显示共享食材")
	panel._select_category("processed")
	var processed: Array = panel._visible_items()
	_assert(processed.size() == 1 and String(processed[0].get("id", "")) == "dish_strawberry_jam", "加工品分类应显示储藏加工产物")

	var berries_before := InventoryManager.storehouse.count("produce_bottarries")
	var sugar_before := InventoryManager.storehouse.count("sugar")
	var jam_before := InventoryManager.storehouse.count("dish_strawberry_jam")
	panel._craft_recipe("strawberry_jam")
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(InventoryManager.storehouse.count("produce_bottarries") == berries_before - 3, "制作果酱应扣除三份瓶子莓")
	_assert(InventoryManager.storehouse.count("sugar") == sugar_before - 1, "制作果酱应扣除一份糖")
	_assert(InventoryManager.storehouse.count("dish_strawberry_jam") == jam_before + 1, "制作果酱后成品应进入共享仓")

	panel.queue_free()
	persistence.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("Pantry panel tests passed: categories, cards, detail, recipe craft")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
