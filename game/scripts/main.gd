extends Node2D

## Family Garden 入口/引导脚本（主场景根节点）。
## 职责精简：创建 world/ui_layer 容器并注入 SceneManager、驱动启动流程、
## 处理键鼠输入（需要 Node2D 的 get_global_mouse_position）并转发给 SceneManager。
## 数据层见 MemoryManager，云端见 CloudManager，场景/UI 见 SceneManager。
## 从原 2583 行 main.gd 拆分而来（增量 3 / feature/c-foundation）。

func _ready() -> void:
	var world := Node2D.new()
	world.name = "World"
	add_child(world)

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UI"
	ui_layer.layer = 20
	add_child(ui_layer)

	SceneManager.setup(world, ui_layer)
	SceneManager._setup_web_photo_bridge()
	MemoryManager.load_save()
	if MemoryManager.selected_role_key != "":
		AppearanceManager.ensure_current(MemoryManager.selected_role_key)
	await SceneManager._load_cloud_data()
	# 首次进入(或 debug 重置后)播放启动剧情;播完/跳过都会落 opening_seen,之后不再自动播。
	if not MemoryManager.opening_seen:
		await StoryManager.play_opening(self)
	if MemoryManager.selected_role_key == "":
		SceneManager._show_role_select()
	else:
		# 兼容先在离线模式创建角色、后来才启用 CloudBase 的旧存档。
		# ensure_cloud_identity 内部按本地令牌幂等判断：首次联网只注册一次，
		# 已有身份或未配置远端时均不会重复创建成员或破坏离线玩法。
		var canonical_role := CharacterDB.resolve(MemoryManager.selected_role_key)
		var display_name := MemoryManager.player_display_name.strip_edges()
		if display_name == "":
			display_name = CharacterDB.display_name(canonical_role)
		await CloudManager.ensure_cloud_identity(canonical_role, display_name)
		SceneManager.restore_last_saved_scene()
		# 已有角色但通过开发入口重播开场时，也继续进入同一套高亮引导。
		if StoryManager.consume_quest_intro() and SceneManager.game_hud != null:
			SceneManager.game_hud.start_onboarding_guide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		SceneManager.save_current_progress()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# 先关最上层的 HUD 主面板(资料/设置/背包),没有再关旧的 cozy/地图面板。
		if SceneManager.game_hud != null and SceneManager.game_hud.has_open_panel():
			SceneManager.game_hud.close_current()
			return
		SceneManager._close_active_panel()
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.__familyGardenRemovePhotoInput && window.__familyGardenRemovePhotoInput();", true)
		if SceneManager.adding_place:
			SceneManager.adding_place = false
			SceneManager._show_toast("已取消添加地点。")
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SHIFT):
		print("Mouse position: ", get_global_mouse_position())
		return
	if SceneManager.mode == "map" and SceneManager.adding_place and SceneManager.active_modal == null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := SceneManager.world.to_local(get_global_mouse_position())
		if pos.y < 650:
			SceneManager._open_add_place_form(pos)
		return
	if SceneManager.mode == "garden" and SceneManager.active_modal == null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SceneManager._clear_memory_focus()
	if SceneManager.mode == "garden" and SceneManager.plant_mode and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SceneManager._add_plant(SceneManager.world.to_local(get_global_mouse_position()), SceneManager.selected_plant_type)
		MemoryManager.save_game()
