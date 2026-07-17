extends Node

const FIXED_ROLES := ["father", "mother", "grandfather", "grandmother"]
const EXPECTED_NAMES := {
	"father": "爸爸",
	"mother": "妈妈",
	"grandfather": "爷爷（外公）",
	"grandmother": "奶奶（外婆）",
}

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	MemoryManager._reset_all()

	for role in FIXED_ROLES:
		_test_definition(role)
		await _test_local_player(role)
		await _test_remote_player(role)

	var creator := CharacterCreatorPanel.new()
	add_child(creator)
	creator.setup("", "新成员", "", {})
	_assert(creator.ROLE_OPTIONS.size() == 6, "角色选择栏应显示六个家庭身份")
	creator._select_role("grandfather")
	_assert(not bool(creator._appearance.get("enabled", true)), "爷爷角色不应被捏脸系统覆盖")
	_assert(creator._fixed_role_note.visible, "固定角色应显示完整形象说明")
	_assert(not creator._hair_choice_root.visible and not creator._outfit_choice_root.visible, "固定角色应隐藏发型和服装选项")
	creator._select_role("girl")
	_assert(bool(creator._appearance.get("enabled", false)), "女儿角色仍应支持现有外观系统")
	_assert(not creator._fixed_role_note.visible, "可定制角色不应显示固定形象说明")
	_assert(creator._hair_choice_root.visible and creator._outfit_choice_root.visible, "可定制角色应继续显示发型和服装选项")
	creator.queue_free()

	MemoryManager._reset_all()
	await get_tree().process_frame
	if failures.is_empty():
		print("Family role character tests passed: 4 fixed roles, 15 frames, local/remote walking and 6-role creator")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _test_definition(role: String) -> void:
	var definition: Dictionary = CharacterDB.get_def(role)
	var texture := CharacterDB.texture(role)
	var rects: Array = definition.get("frame_rects", [])
	_assert(not definition.is_empty(), "%s 角色配置应存在" % role)
	_assert(String(definition.get("name", "")) == String(EXPECTED_NAMES[role]), "%s 中文名称应正确" % role)
	_assert(texture != null, "%s 动作图集应成功导入" % role)
	_assert(int(definition.get("hframes", 0)) == 3 and int(definition.get("vframes", 0)) == 5, "%s 应使用 3×5 动作布局" % role)
	_assert(rects.size() == 15, "%s 应生成完整 15 帧裁切" % role)
	_assert(not AppearanceManager.supports_customization(role), "%s 应使用固定完整形象" % role)
	_assert(not bool(AppearanceManager.normalize({"enabled": true}, role).get("enabled", true)), "%s 即使读取旧外观存档也不能被覆盖" % role)
	if texture == null:
		return
	_assert(texture.get_width() == 720 and texture.get_height() == 1600, "%s 图集尺寸应为 720×1600" % role)
	for index in rects.size():
		var raw: Array = rects[index]
		var rect := Rect2i(int(raw[0]), int(raw[1]), int(raw[2]), int(raw[3]))
		_assert(rect.size == Vector2i(240, 320), "%s 第 %d 帧尺寸应统一" % [role, index])
		_assert(rect.end.x <= texture.get_width() and rect.end.y <= texture.get_height(), "%s 第 %d 帧不能越界" % [role, index])
		_assert(_visible_pixel_count(texture, rect) >= 1000, "%s 第 %d 帧应包含完整人物" % [role, index])

func _test_local_player(role: String) -> void:
	MemoryManager.character_appearance = {"enabled": true, "hair_style": "tousled", "outfit": "forest"}
	var player: CharacterBody2D = load("res://scenes/Player.tscn").instantiate()
	add_child(player)
	player.apply_character(role)
	_assert(player.sprite.texture == CharacterDB.texture(role), "%s 本地玩家应使用固定角色图集" % role)
	_assert(player.frame_rects.size() == 15 and player.sprite.region_enabled, "%s 本地玩家应启用 15 帧精确裁切" % role)
	_assert(player.sprite.scale.is_equal_approx(Vector2.ONE * 0.35), "%s 本地玩家显示比例应正确" % role)
	_assert(is_equal_approx((player.get_node("Shadow") as Node2D).position.y, 56.0), "%s 阴影应对齐脚底" % role)
	for frame_index in [1, 4, 7, 10, 13]:
		player._set_frame(frame_index)
		_assert(player.sprite.region_rect == player.frame_rects[frame_index], "%s 行走/待机帧 %d 应映射正确" % [role, frame_index])
	player.queue_free()
	await get_tree().process_frame

func _test_remote_player(role: String) -> void:
	var remote: Node2D = load("res://scenes/RemotePlayer.tscn").instantiate()
	add_child(remote)
	remote.configure_presence("member-" + role, role, String(EXPECTED_NAMES[role]), {"enabled": true, "outfit": "forest"})
	_assert(remote.sprite.texture == CharacterDB.texture(role), "%s 在线玩家应使用固定角色图集" % role)
	_assert(remote._frame_rects.size() == 15 and remote.sprite.region_enabled, "%s 在线玩家应启用 15 帧裁切" % role)
	remote.set_presence_target(Vector2.ZERO, "right", "walk", 1)
	remote._animate(0.0, Vector2.RIGHT * 20.0)
	_assert(remote.sprite.region_rect == remote._frame_rects[7], "%s 在线向右行走应使用正确方向帧" % role)
	remote.queue_free()
	await get_tree().process_frame

func _visible_pixel_count(texture: Texture2D, rect: Rect2i) -> int:
	var image := texture.get_image()
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if image.get_pixel(x, y).a > 0.1:
				count += 1
	return count

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
