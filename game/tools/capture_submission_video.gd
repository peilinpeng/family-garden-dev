extends Node

## 比赛视频的确定性导演场景。
## 仅在 FAMILY_GARDEN_TEST=1 下运行，所有数据写入隔离测试存档；不访问真实家庭数据。

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const FARM_SCENE := preload("res://scenes/Farm.tscn")
const DEMO_TEXT := "去年夏天，我们一起去了海边。爸爸第一次学会用拍立得，妈妈在傍晚捡了很多贝壳。"

var main_scene: Node = null
var farm_scene: Node = null
var overlay_layer: CanvasLayer
var fade_rect: ColorRect
var title_card: Control
var title_label: Label
var subtitle_label: Label

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("FAMILY_GARDEN_TEST") != "1":
		push_error("正式录屏导演场景只允许在 FAMILY_GARDEN_TEST=1 的隔离环境运行。")
		get_tree().quit(1)
		return
	_setup_isolated_demo()
	await _ensure_main()
	_setup_overlay()

	await _shot_intro(18.0)
	await _shot_role_entry(18.0)
	await _shot_family_members(19.0)
	await _shot_memory_input(25.0)
	await _shot_memory_draft(15.0)
	await _shot_memory_growth(23.0)
	await _shot_memory_vine(22.0)
	await _shot_room_generation(38.0)
	await _shot_shared_farm(34.0)
	await _shot_bottle(30.0)
	await _shot_montage(18.0)
	await _shot_outro(10.0)

	# record_submission_video.sh 用 --quit-after 精确裁切到 8100 帧；这里保留尾帧避免提前退出。
	await get_tree().create_timer(30.0).timeout

func _setup_isolated_demo() -> void:
	GameClock.debug_start_hour = 14.0
	GameClock._seconds = 14.0 * 3600.0
	MemoryManager._reset_all()
	MemoryManager.selected_role_key = "girl"
	MemoryManager.player_display_name = "佩林"
	MemoryManager.opening_seen = true
	MemoryManager.onboarding_guide_seen = true
	MemoryManager.save_game()

func _ensure_main() -> void:
	if farm_scene != null and is_instance_valid(farm_scene):
		farm_scene.queue_free()
		farm_scene = null
		await _wait_frames(4)
	if main_scene == null or not is_instance_valid(main_scene):
		main_scene = MAIN_SCENE.instantiate()
		get_tree().root.add_child(main_scene)
		await _wait_frames(18)
	_set_main_content_visible(true)

func _ensure_farm() -> void:
	SceneManager._close_active_panel()
	_set_main_content_visible(false)
	if farm_scene == null or not is_instance_valid(farm_scene):
		farm_scene = FARM_SCENE.instantiate()
		get_tree().root.add_child(farm_scene)
		await _wait_frames(24)

func _set_main_content_visible(is_visible: bool) -> void:
	if main_scene == null or not is_instance_valid(main_scene):
		return
	var world := main_scene.get_node_or_null("World") as CanvasItem
	if world != null:
		world.visible = is_visible
	var ui := main_scene.get_node_or_null("UI") as CanvasLayer
	if ui != null:
		ui.visible = is_visible

func _setup_overlay() -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 200
	add_child(overlay_layer)

	title_card = Control.new()
	title_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(title_card)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("17241b")
	title_card.add_child(backdrop)
	var glow := ColorRect.new()
	glow.position = Vector2(210, 146)
	glow.size = Vector2(860, 428)
	glow.color = Color(0.86, 0.78, 0.55, 0.08)
	title_card.add_child(glow)
	title_label = Label.new()
	title_label.position = Vector2(150, 230)
	title_label.size = Vector2(980, 180)
	title_label.text = "FAMILY GARDEN\n家庭记忆，长成一座花园"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", Color("f7e9c5"))
	title_card.add_child(title_label)
	var tagline := Label.new()
	tagline.position = Vector2(180, 430)
	tagline.size = Vector2(920, 54)
	tagline.text = "AI 驱动的数字家庭第三空间"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 22)
	tagline.add_theme_color_override("font_color", Color(0.88, 0.79, 0.62, 0.92))
	title_card.add_child(tagline)

	# 仅在 FG_VIDEO_GUIDE_CAPTIONS=1 时显示镜头提示；审片版使用独立 SRT 与 MP4 内嵌字幕轨。
	subtitle_label = Label.new()
	subtitle_label.position = Vector2(92, 646)
	subtitle_label.size = Vector2(1096, 42)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86, 0.9))
	subtitle_label.visible = OS.get_environment("FG_VIDEO_GUIDE_CAPTIONS") == "1"
	overlay_layer.add_child(subtitle_label)

	fade_rect = ColorRect.new()
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 1.0
	overlay_layer.add_child(fade_rect)

func _shot_intro(duration: float) -> void:
	title_card.visible = true
	_set_guide("S01 · 项目定位与花园全景")
	await _fade_to(0.0, 0.4)
	await _hold(6.0)
	await _fade_to(1.0, 0.35)
	title_card.visible = false
	SceneManager._show_garden()
	await _wait_frames(12)
	# 隔离存档首次进入会提示种植家庭树；片头全景需要保持干净。
	SceneManager._close_active_panel()
	if SceneManager.game_hud != null and SceneManager.game_hud.has_open_panel():
		SceneManager.game_hud.close_current()
	await _fade_to(0.0, 0.35)
	await _hold(maxf(0.0, duration - 7.1))

func _shot_role_entry(duration: float) -> void:
	await _transition_to(func() -> void: SceneManager._show_role_select())
	_set_guide("S02 · 使用演示姓名和演示家庭邀请码进入")
	await _hold(duration - 0.7)

func _shot_family_members(duration: float) -> void:
	await _transition_to(_show_demo_family_panel)
	_set_guide("S03 · 家庭成员、在线状态与所在场景")
	await _hold(duration - 0.7)

func _shot_memory_input(duration: float) -> void:
	await _transition_to(func() -> void: SceneManager._open_memory_creator(false, DEMO_TEXT))
	_set_guide("S04 · 图文记忆输入与 AI 整理过程")
	_set_first_label("未选择照片", "已选择：01_family_trip.jpg（演示素材）")
	await _hold(14.0)
	_set_first_label("确认草稿前不会创建记忆。", "AI 正在整理记忆草稿…")
	_set_first_button("生成可编辑草稿", "正在生成…")
	await _hold(maxf(0.0, duration - 14.7))

func _shot_memory_draft(duration: float) -> void:
	await _transition_to(func() -> void: SceneManager._open_memory_draft_preview(_memory_draft()))
	_set_guide("S05 · 草稿可编辑；确认后才写入家庭空间")
	await _hold(duration - 0.7)

func _shot_memory_growth(duration: float) -> void:
	await _transition_to(_show_new_memory)
	_set_guide("S06 · 新记忆花生长并可再次打开")
	await _hold(14.0)
	var memory := MemoryManager.get_memory("mem_submission_video_memory")
	if not memory.is_empty():
		SceneManager._open_memory_card(memory)
	await _hold(maxf(0.0, duration - 14.7))

func _shot_memory_vine(duration: float) -> void:
	await _transition_to(_show_memory_vine)
	_set_guide("S07 · AI 提出关联建议，关系由家人补写确认")
	await _hold(duration - 0.7)

func _shot_room_generation(duration: float) -> void:
	await _transition_to(func() -> void: SceneManager._open_room_draft_preview(_room_draft()))
	_set_guide("S08 · 语义识别不输出坐标；客户端受控生成")
	await _hold(20.0)
	await _fade_to(1.0, 0.35)
	SceneManager._close_active_panel()
	var analysis := AIClient.mock_room_analysis()
	RoomLayoutManager.generate(analysis, "", "submission-video-room", _room_draft().generation_meta)
	SceneManager._enter_house("player", "我的房间")
	await _wait_frames(12)
	await _fade_to(0.0, 0.35)
	await _hold(maxf(0.0, duration - 20.7))

func _shot_shared_farm(duration: float) -> void:
	await _fade_to(1.0, 0.35)
	await _ensure_farm()
	await _fade_to(0.0, 0.35)
	_set_guide("S09 · 家庭共享农场与同步反馈")
	await _hold(20.0)
	_show_farm_sync_banner()
	await _hold(maxf(0.0, duration - 20.7))

func _shot_bottle(duration: float) -> void:
	await _fade_to(1.0, 0.35)
	await _ensure_main()
	SceneManager._build_fishpond()
	await _wait_frames(16)
	SceneManager._open_bottle_panel({
		"id": "submission-video-bottle",
		"question": "小时候有没有一次和家人一起出门玩，让你现在还记得？",
		"state": "floating",
		"answer": "",
	})
	await _fade_to(0.0, 0.35)
	_set_guide("S10 · 漂流瓶让一次认真谈心从轻巧问题开始")
	await _hold(18.0)
	_set_first_text_edit("小时候爸爸常带我去河边散步，我们会在桥下停下来听水声。")
	_set_first_button("保存回答", "保存为岸边记忆")
	await _hold(maxf(0.0, duration - 18.7))

func _shot_montage(duration: float) -> void:
	await _transition_to(func() -> void: SceneManager._show_garden())
	_set_guide("S11 · 花园、房间、农场与鱼塘形成完整闭环")
	await _hold(4.2)
	SceneManager._enter_house("player", "我的房间")
	await _hold(4.2)
	SceneManager._build_fishpond()
	await _hold(4.2)
	SceneManager._show_garden()
	await _hold(maxf(0.0, duration - 13.3))

func _shot_outro(duration: float) -> void:
	await _fade_to(1.0, 0.35)
	title_label.text = "FAMILY GARDEN\n让家庭记忆真正长成一座花园"
	title_card.visible = true
	await _fade_to(0.0, 0.35)
	_set_guide("S12 · 项目价值收束")
	await _hold(duration - 0.7)

func _transition_to(action: Callable) -> void:
	await _fade_to(1.0, 0.35)
	action.call()
	await _wait_frames(8)
	await _fade_to(0.0, 0.35)

func _fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade_rect, "modulate:a", alpha, seconds)
	await tween.finished

func _hold(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout

func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _set_guide(text: String) -> void:
	subtitle_label.text = text

func _show_demo_family_panel() -> void:
	SceneManager._show_garden()
	SceneManager._show_cozy_panel(
		"家庭成员",
		"家庭邀请码：DEMO-FAMILY\n\n家庭成员：\n• 佩林（孩子） — 在线 · 花园\n• 妈妈（妈妈） — 在线 · 农场\n• 爸爸（爸爸） — 离线\n\n家庭数据按邀请码隔离；状态用于演示界面，不包含真实身份信息。",
		[{"text": "留言板", "action": "message_board"}, {"text": "家庭树", "action": "family_tree"}, {"text": "关闭", "action": "close"}]
	)

func _show_new_memory() -> void:
	SceneManager._close_active_panel()
	var card := _memory_card()
	var memory := MemoryManager.create_memory(card, "text", DEMO_TEXT, "", _memory_draft().generation_meta, "submission_video_memory")
	MemoryManager.create_node(String(memory.get("id", "")), "garden", "memory_flower", "garden_slot_flowerbed_01", "", "submission_video_node")
	SceneManager._pending_memory_arrival_id = String(memory.get("id", ""))
	SceneManager._show_garden()

func _show_memory_vine() -> void:
	SceneManager._close_active_panel()
	SceneManager._show_garden()
	var links := MemoryManager.get_memory_links("garden")
	if links.is_empty():
		var memories := MemoryManager.memories
		if memories.size() >= 2:
			MemoryManager.create_memory_link(
				String(memories[0].get("id", "")),
				String(memories[1].get("id", "")),
				"garden",
				"同一地点",
				"两次旅行里，家人还记得哪些相同的细节？",
				0.91,
				{"source": "demo_fixture", "prompt_version": "memory-link-v1"}
			)
			links = MemoryManager.get_memory_links("garden")
	if not links.is_empty():
		SceneManager._open_memory_link_panel(links[0])

func _show_farm_sync_banner() -> void:
	if farm_scene != null and is_instance_valid(farm_scene):
		var banner := Label.new()
		banner.position = Vector2(360, 74)
		banner.size = Vector2(560, 54)
		banner.text = "家人的农场更新已同步"
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		banner.add_theme_font_size_override("font_size", 24)
		banner.add_theme_color_override("font_color", Color("fff2ce"))
		var panel := Panel.new()
		panel.position = banner.position
		panel.size = banner.size
		SceneManager._apply_panel_style(panel)
		farm_scene.add_child(panel)
		banner.position = Vector2.ZERO
		panel.add_child(banner)

func _memory_card() -> Dictionary:
	return {
		"title": "和爸妈的海边家庭旅行",
		"description": "去年夏天，一家人在傍晚沿着海边散步，爸爸第一次用拍立得记录下没有人看镜头的一刻。",
		"memory_type": "family_trip",
		"suggested_scene": "garden",
		"question": "这次海边家庭旅行中，印象最深的事情是什么？",
		"node_type": "memory_flower",
		"confidence": 0.92,
	}

func _memory_draft() -> Dictionary:
	return {
		"ok": true,
		"kind": "memory",
		"workflow_key": "submission_video_memory",
		"raw_text": DEMO_TEXT,
		"input_type": "text",
		"card": _memory_card(),
		"generation_meta": {
			"request_id": "submission-video-fixture",
			"provider": "recording_fixture",
			"model": "演示数据（不作为真实 AI 调用证据）",
			"prompt_version": "memory-card-v1",
			"source": "demo_fixture",
		},
		"used_fallback": false,
		"upload_id": "",
		"image_url": "",
	}

func _room_draft() -> Dictionary:
	var analysis := AIClient.mock_room_analysis()
	return {
		"ok": true,
		"kind": "room",
		"workflow_key": "submission-video-room",
		"analysis": analysis,
		"layout": RoomLayoutManager.plan(analysis),
		"generation_meta": {
			"request_id": "submission-video-room-fixture",
			"provider": "recording_fixture",
			"model": "演示数据（不作为真实 AI 调用证据）",
			"prompt_version": "room-analysis-v1",
			"source": "demo_fixture",
		},
		"used_fallback": false,
		"upload_id": "",
		"image_url": "",
	}

func _set_first_label(expected: String, replacement: String) -> void:
	var node := _find_control(func(candidate: Control) -> bool: return candidate is Label and (candidate as Label).text == expected)
	if node is Label:
		(node as Label).text = replacement

func _set_first_button(expected: String, replacement: String) -> void:
	var node := _find_control(func(candidate: Control) -> bool: return candidate is Button and (candidate as Button).text == expected)
	if node is Button:
		(node as Button).text = replacement
		(node as Button).disabled = true

func _set_first_text_edit(value: String) -> void:
	var node := _find_control(func(candidate: Control) -> bool: return candidate is TextEdit)
	if node is TextEdit:
		(node as TextEdit).text = value

func _find_control(predicate: Callable) -> Control:
	var root := get_tree().root
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var current: Node = queue.pop_front()
		if current is Control and predicate.call(current):
			return current as Control
		for child in current.get_children():
			queue.append(child)
	return null
