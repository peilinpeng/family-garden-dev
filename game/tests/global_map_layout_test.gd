extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node2D.new()
	world.name = "World"
	add_child(world)
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)
	SceneManager.setup(world, ui_layer)
	await get_tree().process_frame

	SceneManager._show_global_map()
	await get_tree().process_frame
	await get_tree().process_frame

	var view := SceneManager.global_map_ui
	_assert(view != null, "打开世界地图后应创建 GlobalMapView")
	if view != null:
		_assert(view.get_parent() == SceneManager.ui_root, "世界地图应挂在居中的 1280×720 UI 根节点下")
		_assert(view.position.is_equal_approx(Vector2.ZERO), "世界地图在设计画布内应从左上角开始")
		_assert(view.size.is_equal_approx(SceneManager.GAME_SIZE), "世界地图尺寸应固定为 1280×720")
		var viewport_size := get_viewport().get_visible_rect().size
		var expected_margin := Vector2(
			maxf(0.0, (viewport_size.x - SceneManager.GAME_SIZE.x) * 0.5),
			maxf(0.0, (viewport_size.y - SceneManager.GAME_SIZE.y) * 0.5)
		)
		_assert(SceneManager.ui_root.position.is_equal_approx(expected_margin),
			"非 16:9 窗口中地图应保持比例并在额外空间内居中")

		var background := view.get_node_or_null("GlobalMapBackground") as TextureRect
		_assert(background != null, "世界地图应载入背景图")
		if background != null:
			_assert(background.size.is_equal_approx(SceneManager.GAME_SIZE), "地图背景不得随窗口比例变形")
			_assert(background.texture != null and background.texture.get_size().is_equal_approx(SceneManager.GAME_SIZE),
				"地图背景素材应保持原始 1280×720 比例")

		var sign := view.get_node_or_null("Decoration_familygarden_sign") as TextureRect
		_assert(sign != null, "世界地图应载入 familygarden 路标图层")
		if sign != null:
			_assert(sign.size.is_equal_approx(SceneManager.GAME_SIZE), "路标透明图层应与地图画布严格对齐")
			_assert(sign.texture != null and sign.texture.get_size().is_equal_approx(SceneManager.GAME_SIZE),
				"familygarden 路标素材应以原始 1280×720 尺寸导入")

		var original_care_mode := SettingsManager.care_mode
		SettingsManager.care_mode = true
		SettingsManager._apply_care_mode()
		await get_tree().process_frame
		_assert(view.size.is_equal_approx(SceneManager.GAME_SIZE), "关怀模式不得改变世界地图的 1280×720 画布")
		SettingsManager.care_mode = original_care_mode
		SettingsManager._apply_care_mode()

	if failures.is_empty():
		print("Global map layout tests passed: fixed 1280x720 canvas and familygarden sign")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
