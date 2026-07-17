extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	MemoryManager._reset_all()
	var farm := (load("res://scenes/Farm.tscn") as PackedScene).instantiate()
	add_child(farm)
	await get_tree().process_frame
	await get_tree().process_frame

	_assert(farm.doors.size() == 2, "农场应配置鸡栏和牛栏两扇门")
	for door in farm.doors:
		_assert(not bool(door.get("open", true)), "畜牧栏门初始应为关闭状态")
		_assert((door.node as CanvasItem).visible, "关闭的畜牧栏门应显示门图")
		var blocker := door.blocker as Rect2
		_assert(farm._walkable_point(blocker.get_center()), "门口中心在原始行走遮罩中应可通行")
		_assert(farm._door_blocks_feet(blocker.get_center()), "关闭的门应阻挡玩家脚底位置")

	if farm.doors.size() == 2:
		var chicken_door: Dictionary = farm.doors[0]
		var cow_door: Dictionary = farm.doors[1]

		# 门外和门内使用同一个距离判定，均可按 E 开门。
		farm.player.position = chicken_door.point + Vector2(0, 55)
		_assert(farm._try_door_interact(), "玩家在鸡栏门外按 E 应能开门")
		_assert(bool(chicken_door.open), "鸡栏门打开后应移除阻挡")
		_assert(not farm._door_blocks_feet((chicken_door.blocker as Rect2).get_center()), "打开的鸡栏门不应阻挡玩家")
		_assert(farm._position_walkable((chicken_door.blocker as Rect2).get_center() - farm.FEET_OFFSET),
			"鸡栏门打开后玩家应能穿过门口")

		farm.player.position = (chicken_door.blocker as Rect2).get_center() - farm.FEET_OFFSET
		farm._update_doors(farm.DOOR_AUTO_CLOSE_SECONDS + 0.1)
		_assert(bool(chicken_door.open), "玩家站在门框内时自动关门应延后，避免夹住角色")
		farm.player.position = chicken_door.point + Vector2(90, 0)
		farm._update_doors(farm.DOOR_CLOSE_RETRY_SECONDS + 0.1)
		_assert(not bool(chicken_door.open), "玩家离开门框后门应自动关闭")

		farm.player.position = cow_door.point + Vector2(0, -55)
		_assert(farm._try_door_interact(), "玩家在牛栏门内按 E 应能开门")
		_assert(farm._position_walkable((cow_door.blocker as Rect2).get_center() - farm.FEET_OFFSET),
			"牛栏门打开后玩家应能穿过门口")
		farm.player.position = cow_door.point + Vector2(90, 0)
		farm._update_doors(farm.DOOR_AUTO_CLOSE_SECONDS + 0.1)
		_assert(not bool(cow_door.open), "牛栏门打开 5 秒后应自动关闭")

	farm.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("Farm gate interaction tests passed: block, E-open and safe auto-close")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
