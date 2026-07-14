extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var kitchen: Variant = load("res://scenes/KitchenNew.tscn").instantiate()
	add_child(kitchen)
	await get_tree().process_frame
	await get_tree().process_frame

	var mask: Image = load("res://assets/kitchen_new/walkable_area.png").get_image()
	_assert(mask != null and not mask.is_empty(), "KitchenNew 应能加载行走遮罩")
	if mask != null and not mask.is_empty():
		for y in range(0, mask.get_height(), 16):
			for x in range(0, mask.get_width(), 16):
				var point := Vector2(x, y)
				var expected: bool = mask.get_pixel(x, y).a > kitchen.WALKABLE_ALPHA_THRESHOLD
				_assert(kitchen._walkable(point) == expected, "行走判断应与遮罩一致: (%d, %d)" % [x, y])

	_assert(kitchen._walkable(Vector2(640, 340)), "原餐桌粗略矩形不应误伤遮罩允许区域")
	_assert(kitchen._walkable(Vector2(1000, 400)), "原池塘粗略矩形不应误伤石板路")
	_assert(kitchen._walkable(Vector2(1100, 300)), "原柳树粗略矩形不应覆盖遮罩允许区域")
	_assert(not kitchen._walkable(Vector2(-1, 400)), "遮罩左侧越界位置不可行走")
	_assert(not kitchen._walkable(Vector2(1280, 400)), "遮罩右侧越界位置不可行走")

	kitchen.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("KitchenNew walkable tests passed: mask is the single source of truth")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
