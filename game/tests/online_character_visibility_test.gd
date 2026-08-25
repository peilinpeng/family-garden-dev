extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	MemoryManager._reset_all()
	MemoryManager.selected_role_key = "girl"
	MemoryManager.player_display_name = "本机玩家"

	var world := Node2D.new()
	world.name = "World"
	add_child(world)
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)
	SceneManager.setup(world, ui_layer)
	SceneManager._show_garden()
	await get_tree().process_frame
	await get_tree().process_frame

	_assert(_nodes_named_with_prefix(world, "NPC_").is_empty(), "主花园不应生成静态假家人")
	_assert(get_tree().get_nodes_in_group("player").size() == 1, "主花园初始只应显示一个本机玩家")

	SceneManager._clear_world()
	await get_tree().process_frame
	var farm := (load("res://scenes/Farm.tscn") as PackedScene).instantiate()
	add_child(farm)
	await get_tree().process_frame
	await get_tree().process_frame

	_assert(farm.remote_players.is_empty(), "农场初始不应生成离线占位家人")
	_assert(_remote_player_nodes(farm).is_empty(), "未收到 Presence 在线事件时不应显示其他玩家")
	_assert(not FileAccess.get_file_as_string("res://scripts/farm/farm.gd").contains("plot_action_icon"),
		"农场不应再创建偏移的田块世界操作图标")

	# 浇水是基础操作：即使背包和共享仓都没有浇水壶，也不应让旧存档卡关。
	while InventoryManager.has("tool_wateringcan", 1, false):
		InventoryManager.take("tool_wateringcan", 1, false)
	while InventoryManager.has("tool_wateringcan", 1, true):
		InventoryManager.take("tool_wateringcan", 1, true)
	MemoryManager.farm_plots = [{
		"plot": 0,
		"crop_id": "corrato",
		"planted_at": Time.get_unix_time_from_system(),
		"watered": false,
		"watered_at": 0.0,
		"fertilized": false,
		"fertilized_at": 0.0,
	}]
	farm.crop_rows[0] = MemoryManager.farm_plots[0]
	_assert(not farm._plot_hint(0).contains("需要浇水壶"), "缺少浇水壶时不应显示卡关文案")
	await farm._try_existing_crop(0)
	_assert(FarmManager.is_watered(0), "没有浇水壶时仍应能正常给作物浇水")

	var peer := {
		"member_id": "remote-member-test",
		"scene_id": "farm",
		"role": "boy",
		"display_name": "在线家人",
		"position": {"x": 620.0, "y": 420.0},
		"direction": "down",
		"animation_state": "idle",
		"sequence": 1,
		"appearance": {},
	}
	farm._on_presence_peer_joined(peer)
	await get_tree().process_frame
	_assert(farm.remote_players.size() == 1, "收到真实在线事件后应创建一个远端玩家")
	_assert(_remote_player_nodes(farm).size() == 1, "真实在线家人应显示对应角色")

	farm._on_presence_peer_left("remote-member-test")
	await get_tree().process_frame
	_assert(farm.remote_players.is_empty(), "家人离线后应从远端玩家缓存中移除")
	_assert(_remote_player_nodes(farm).is_empty(), "家人离线后对方角色应立即消失")

	if failures.is_empty():
		print("Online character visibility tests passed: local only until presence join")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _nodes_named_with_prefix(root: Node, prefix: String) -> Array[Node]:
	var result: Array[Node] = []
	for child in root.get_children():
		if str(child.name).begins_with(prefix):
			result.append(child)
		result.append_array(_nodes_named_with_prefix(child, prefix))
	return result

func _remote_player_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in root.get_children():
		if child.get_script() == preload("res://scripts/farm/remote_player.gd"):
			result.append(child)
		result.append_array(_remote_player_nodes(child))
	return result

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
