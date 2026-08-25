extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var opening := OpeningNarrativeLayer.new()
	add_child(opening)
	await get_tree().process_frame
	opening._enter_box()
	await get_tree().process_frame
	_assert(opening._box_rect.position == OpeningNarrativeLayer.BOX_CLOSED_POSITION, "关闭木箱应保持原始位置")
	var continue_hint := opening._root.get_node_or_null("ContinueHint") as Label
	_assert(continue_hint != null and not continue_hint.visible, "木箱幕应隐藏会与创建按钮重叠的全局点击提示")

	opening._open_box()
	await get_tree().create_timer(2.7).timeout
	_assert(opening._box_rect.position.distance_to(OpeningNarrativeLayer.BOX_OPEN_POSITION) < 1.0, "打开木箱后应下移到目标位置")
	for item in OpeningNarrativeLayer.BOX_ITEMS:
		var holder := opening._stage.get_node_or_null("BoxItem_%s" % str(item["id"])) as Control
		_assert(holder != null, "开箱后应生成物品 %s" % str(item["id"]))
		if holder != null:
			_assert(absf(holder.position.y - OpeningNarrativeLayer.BOX_ITEM_SLOT_Y) < 1.0, "物品 %s 应使用下移后的落点" % str(item["id"]))
	var create_button := opening._stage.get_node_or_null("CreateGardenButton") as Button
	_assert(create_button != null and create_button.position.y >= 620.0, "创建按钮应保持在箱子下方的底部操作区")

	if OS.has_environment("FG_CAPTURE_SCREENSHOTS"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/family_garden_opening_box_layout.png")

	opening.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("Opening narrative layout tests passed: opened box and five items use separated vertical positions")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
