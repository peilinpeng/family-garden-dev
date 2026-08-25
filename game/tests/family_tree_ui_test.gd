extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	MemoryManager._reset_all()
	# 模拟已领取但尚未种植的旧存档。
	MemoryManager.family_tree_gift_received = true
	MemoryManager.family_tree_planting_hint_seen = false
	MemoryManager.cross_member_interaction_count = 3

	var tree_panel := FamilyTreePanel.new()
	var plant_state := {"requested": false}
	tree_panel.plant_requested.connect(func() -> void: plant_state["requested"] = true)
	add_child(tree_panel)
	await get_tree().process_frame
	var tree_text := _collect_ui_text(tree_panel)
	_assert(tree_text.contains("家庭树"), "家庭树应有独立面板标题")
	_assert(tree_text.contains("第 3 阶段"), "家庭树面板应显示当前成长阶段")
	_assert(tree_text.contains("家庭互动量  3"), "家庭树面板应显示真实互动量")
	_assert(tree_text.contains("种下幼苗"), "已领取但未种植的旧存档应显示种植入口")
	var plant_button := tree_panel.find_child("FamilyTreePlantButton", true, false) as Button
	_assert(plant_button != null and not plant_button.disabled, "未种植时操作按钮应可用")
	if OS.has_environment("FG_CAPTURE_SCREENSHOTS"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/family_garden_family_tree_panel.png")
	if plant_button != null:
		plant_button.pressed.emit()
	_assert(bool(plant_state.requested), "家庭树面板的种植按钮应发出种植请求")
	tree_panel.queue_free()
	SceneManager.mode = "garden"
	SceneManager.begin_family_tree_placement()
	_assert(SceneManager.plant_mode and SceneManager.selected_plant_type == "family_tree", "旧存档应能直接恢复家庭树种植模式")
	_assert(MemoryManager.family_tree_planting_hint_seen, "主动种植后不应再被首次提示打断")
	SceneManager.plant_mode = false
	SceneManager.selected_plant_type = "tree"

	var profile := ProfilePanel.new()
	var profile_state := {"requested": false}
	profile.family_tree_requested.connect(func() -> void: profile_state["requested"] = true)
	add_child(profile)
	await get_tree().process_frame
	var profile_tree_button := profile.find_child("ProfileFamilyTreeButton", true, false) as Button
	_assert(profile_tree_button != null, "角色资料页应提供直接家庭树入口")
	if profile_tree_button != null:
		profile_tree_button.pressed.emit()
	_assert(bool(profile_state.requested), "角色资料页家庭树按钮应能打开家庭树")
	profile.queue_free()

	var builder := preload("res://scripts/garden_builder/garden_build_manager.gd").new()
	var builder_ui := CanvasLayer.new()
	add_child(builder_ui)
	add_child(builder)
	builder.ui_layer = builder_ui
	builder._build_toolbar()
	await get_tree().process_frame
	var build_entry := builder.toolbar.find_child("FamilyTreeEntryButton", true, false) as Button
	_assert(build_entry != null and build_entry.text == "家庭树", "花园建造菜单应有明显的家庭树入口")
	builder.queue_free()
	builder_ui.queue_free()

	MemoryManager._reset_all()
	await get_tree().process_frame
	if failures.is_empty():
		print("Family tree UI tests passed: dedicated panel, profile shortcut, builder entry and legacy unplanted save")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _collect_ui_text(node: Node) -> String:
	var parts: Array[String] = []
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_collect_ui_text(child))
	return "\n".join(parts)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
