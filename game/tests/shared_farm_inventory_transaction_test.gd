extends Node

class FakePersistence:
	extends Node

	var storehouse_stacks: Array = [
		{"id": "seed_corrato", "count": 1},
		{"id": "produce_corrato", "count": 2},
		{"id": "egg", "count": 1},
	]
	var storehouse_version := 1
	var farm_rows: Array = []
	var livestock_rows: Array = []
	var mutations: Array[Dictionary] = []
	var farm_actions: Array[Dictionary] = []

	func has_identity() -> bool:
		return true

	func persist_record(_table: String, _row: Dictionary) -> void:
		pass

	func load_table(table: String, _query: String = "") -> Array:
		match table:
			"inventories":
				return [{"id": "storehouse:test", "kind": "storehouse", "version": storehouse_version, "stacks": storehouse_stacks.duplicate(true)}]
			"farm_plots":
				return farm_rows.duplicate(true)
			"farm_livestock":
				return livestock_rows.duplicate(true)
		return []

	func mutate_storehouse(consumes: Array, grants: Array, operation_id: String) -> Dictionary:
		mutations.append({"consumes": consumes.duplicate(true), "grants": grants.duplicate(true), "operation_id": operation_id})
		for change in consumes:
			_remove(String(change.get("id", "")), int(change.get("quantity", 0)))
		for change in grants:
			_add(String(change.get("id", "")), int(change.get("quantity", 0)))
		storehouse_version += 1
		return {"ok": true, "id": "storehouse:test", "version": storehouse_version, "stacks": storehouse_stacks.duplicate(true)}

	func perform_farm_action(action: String, payload: Dictionary, operation_id: String) -> Dictionary:
		farm_actions.append({"action": action, "payload": payload.duplicate(true), "operation_id": operation_id})
		if action != "plant":
			return {"ok": false, "error": "unsupported fake action"}
		_remove("seed_" + String(payload.get("crop_id", "")), 1)
		storehouse_version += 1
		var plot := {
			"id": "farm_plot:test:%d" % int(payload.get("plot_index", -1)),
			"plot_index": int(payload.get("plot_index", -1)),
			"crop_id": String(payload.get("crop_id", "")),
			"planted_at_unix": 1800000000,
			"watered": false,
			"watered_at_unix": 0,
			"fertilized": false,
			"fertilized_at_unix": 0,
		}
		farm_rows = [plot]
		return {
			"ok": true,
			"plot": plot,
			"storehouse": {"id": "storehouse:test", "kind": "storehouse", "version": storehouse_version, "stacks": storehouse_stacks.duplicate(true)},
			"backpack": {},
		}

	func _remove(item_id: String, quantity: int) -> void:
		for i in range(storehouse_stacks.size() - 1, -1, -1):
			if String(storehouse_stacks[i].get("id", "")) != item_id:
				continue
			storehouse_stacks[i]["count"] = int(storehouse_stacks[i].get("count", 0)) - quantity
			if int(storehouse_stacks[i].get("count", 0)) <= 0:
				storehouse_stacks.remove_at(i)
			return

	func _add(item_id: String, quantity: int) -> void:
		for stack in storehouse_stacks:
			if String(stack.get("id", "")) == item_id:
				stack["count"] = int(stack.get("count", 0)) + quantity
				return
		storehouse_stacks.append({"id": item_id, "count": quantity})

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	var persistence := FakePersistence.new()
	get_tree().root.add_child(persistence)
	CloudManager.set_persistence_backend(persistence)
	InventoryManager.sync_from_cloud()
	FarmManager.sync_from_cloud([], [])

	var planted := await FarmManager.plant(3, "corrato")
	_assert(planted, "云端播种事务应成功")
	_assert(persistence.farm_actions.size() == 1, "播种只能提交一个服务端事务")
	_assert(InventoryManager.storehouse.count("seed_corrato") == 0, "客户端应应用服务端权威扣种结果")
	_assert(FarmManager.is_planted(3), "客户端应应用服务端权威地块结果")

	var crafted := await KitchenManager.craft("tomato_egg_dish")
	_assert(crafted, "厨房配方事务应成功")
	_assert(persistence.mutations.size() == 1, "一份配方只能提交一个共享仓事务")
	var mutation: Dictionary = persistence.mutations[0]
	_assert((mutation.get("consumes", []) as Array).size() == 2, "配方全部材料应在同一事务中扣除")
	_assert(InventoryManager.storehouse.count("produce_corrato") == 0, "权威快照应反映番茄扣除")
	_assert(InventoryManager.storehouse.count("egg") == 0, "权威快照应反映鸡蛋扣除")
	_assert(InventoryManager.storehouse.count("dish_tomato_egg") == 1, "权威快照应包含制作成品")

	CloudManager.set_persistence_backend(null)
	persistence.queue_free()
	if failures.is_empty():
		print("Shared farm/inventory transaction tests passed: authoritative snapshot, single mutation")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
