extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	MemoryManager._reset_all()
	MemoryManager.selected_role_key = "girl"
	MemoryManager.player_display_name = "测试玩家"
	MemoryManager.chapter1_tasks = {
		"open_box": true,
		"first_photo": true,
		"garden_edit": true,
	}

	var world := Node2D.new()
	world.name = "World"
	add_child(world)
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)
	SceneManager.setup(world, ui_layer)

	var panel := QuestPanel.new()
	add_child(panel)
	await get_tree().process_frame
	var farm_button := panel.find_child("QuestTravel_farm", true, false) as Button
	_assert(farm_button != null, "当前农场任务应显示可点击的去农场按钮")
	_assert(farm_button == null or farm_button.text == "去农场", "农场快捷按钮文字应为去农场")

	var close_events := [false]
	panel.close_requested.connect(func() -> void: close_events[0] = true)
	if farm_button != null:
		farm_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(bool(close_events[0]), "点击去农场后应先请求关闭任务面板")
	_assert(SceneManager.mode == "farm", "点击去农场后应直接切换到农场场景")
	_assert(world.get_child_count() > 0, "快捷前往农场后应加载农场内容")

	SceneManager._clear_world()
	panel.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("Quest panel travel tests passed: farm hint is a working direct-travel button")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
