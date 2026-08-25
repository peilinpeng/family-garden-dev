extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var farm := (load("res://scenes/Farm.tscn") as PackedScene).instantiate()
	add_child(farm)
	await get_tree().process_frame
	await get_tree().process_frame

	var status_panel := farm.get_node_or_null("FarmHUD/FarmStatusPanel") as Control
	_assert(status_panel != null, "农场状态面板应继续存在")
	if status_panel != null:
		_assert(status_panel.position.y >= 96.0, "农场状态面板不应再与左上玩家卡重叠")

	var card := PlayerProfileCard.new()
	add_child(card)
	await get_tree().process_frame
	var labels := card.find_children("*", "Label", true, false)
	_assert(labels.size() >= 2, "玩家卡应包含昵称与统计文字")
	for label_node in labels:
		var label := label_node as Label
		if label != null and label.position.x == 74.0:
			_assert(label.clip_text, "玩家卡文字必须限制在卡片范围内")
			_assert(label.position.x + label.size.x <= 242.0, "玩家卡文字必须为右侧人数按钮留出空间")

	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_E
	_assert(AudioManager._is_audio_unlock_event(key_event), "Web 端键盘操作应能解锁音频")
	var click_event := InputEventMouseButton.new()
	click_event.pressed = true
	click_event.button_index = MOUSE_BUTTON_LEFT
	_assert(AudioManager._is_audio_unlock_event(click_event), "Web 端鼠标点击应能解锁音频")
	_assert(not AudioManager._active_music_is_playing(), "未实际播放时不能把同一首 BGM 误判为已播放")
	_assert(AudioManager._music_players.size() == 2, "音频管理器应建立两个音乐播放器")
	for player in AudioManager._music_players:
		_assert(player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM,
			"音乐播放器必须强制使用 Stream，避免 Web Sample 模式静音")
	_assert(AudioManager._sfx_pool.size() == AudioManager.SFX_POOL_SIZE, "音频管理器应建立完整音效池")
	for player in AudioManager._sfx_pool:
		_assert(player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM,
			"音效播放器必须强制使用 Stream，避免 Web Sample 模式静音")

	if failures.is_empty():
		print("Web UI/audio regression tests passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
