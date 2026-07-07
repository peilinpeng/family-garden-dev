@tool
extends Node2D

## KitchenNew 场景控制器(独立场景,可用 F6 单独运行)。
## 负责:1) 按 Objects 下每个装饰物的 SortAnchor(可在编辑器拖动)设置遮挡排序 z_index
##      2) 用 walkable_area.png 当遮罩,逐像素限制玩家行走范围(碰撞),做法与 farm.gd 一致
##
## @tool:拖动 Objects 下任意装饰物的 SortAnchor 时,编辑器里实时更新遮挡关系。
## walkable_area 在画面上不显示:只当 Image 读,不需要把图加进场景树。

const FEET_OFFSET := Vector2(0, 18)  ## 玩家脚底相对其原点的偏移(同 Player 碰撞体)

var walk_img: Image
var player: CharacterBody2D
var last_safe: Vector2

func _ready() -> void:
	_sync_object_z()
	if Engine.is_editor_hint():
		return  # 编辑器里只同步遮挡排序,不跑游戏逻辑
	AudioManager.play_music("kitchen")  # res://music/kitchen.mp3;同一首曲子重复调用不会重播(AudioManager 内部去重)
	walk_img = load("res://assets/kitchen_new/walkable_area.png").get_image()
	_spawn_player()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_sync_object_z()

## 把每个装饰物的 z_index 设为它 SortAnchor 的全局 Y,与玩家脚底 Y 一比即得正确遮挡。
func _sync_object_z() -> void:
	var objs := get_node_or_null("Objects")
	if objs != null:
		_apply_anchor_z(objs)

func _apply_anchor_z(n: Node) -> void:
	for child in n.get_children():
		if child is Node2D:
			var anchor := child.get_node_or_null("SortAnchor") as Node2D
			if anchor != null:
				(child as CanvasItem).z_index = int(anchor.global_position.y)
			_apply_anchor_z(child)

func _spawn_player() -> void:
	player = preload("res://scenes/Player.tscn").instantiate()
	player.global_position = _find_walkable_start()
	player.add_to_group("player")
	last_safe = player.global_position
	add_child(player)

## 在画面中心附近螺旋找一个可走点作为出生位置。
func _find_walkable_start() -> Vector2:
	for r in range(0, 420, 8):
		for a in range(0, 360, 15):
			var p: Vector2 = Vector2(640, 500) + Vector2(r, 0).rotated(deg_to_rad(a))
			if _walkable(p):
				return p
	return Vector2(640, 500)

func _walkable(feet: Vector2) -> bool:
	var x := int(feet.x)
	var y := int(feet.y)
	if x < 0 or y < 0 or x >= walk_img.get_width() or y >= walk_img.get_height():
		return false
	return walk_img.get_pixelv(Vector2i(x, y)).a > 0.3

func _physics_process(_delta: float) -> void:
	if player == null:
		return
	# 玩家移动后做一次脚底采样:不可走则退回上一安全点(用手绘遮罩实现碰撞)
	var feet := player.global_position + FEET_OFFSET
	if _walkable(feet):
		last_safe = player.global_position
	else:
		player.global_position = last_safe
		player.velocity = Vector2.ZERO
