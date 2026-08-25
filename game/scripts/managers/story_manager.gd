extends Node

## 三章主线进度管理。所有进度由真实玩法事件写入 MemoryManager.chapter1_tasks，
## 沿用旧字段以兼容现有存档；字段现在承载完整主线而不只第一章。

signal task_completed(task_id: String)
signal chapter_changed(chapter_id: int)
signal memory_card_unlocked(card: Dictionary)

const CHAPTERS := {
	1: {
		"title": "重新打开花园",
		"subtitle": "编辑花园 → 种植 → 收获 → AI 料理",
		"ending": "花园还没有完全整理好，但这里已经重新有了生活的气息。",
		"tasks": [
			{"id": "open_box", "label": "打开旧木盒"},
			{"id": "first_photo", "label": "收好过去的花园照片"},
			{"id": "garden_edit", "label": "移动入口处的长椅、花盆或桌子"},
			{"id": "first_seed", "label": "在农场种下番茄"},
			{"id": "harvest_tomato", "label": "收获番茄"},
			{"id": "first_dish", "label": "用收获制作第一道 AI 料理"},
			{"id": "dish_on_table", "label": "把料理摆到餐桌上"},
		],
	},
	2: {
		"title": "河流带来的惊喜",
		"subtitle": "钓鱼 → 漂流瓶 → 地图留点 → 寄明信片",
		"ending": "河流把远方的心意送到了这里，而你也从这里寄出了一句话。",
		"tasks": [
			{"id": "first_fishing", "label": "在河边完成第一次钓鱼"},
			{"id": "first_bottle", "label": "捞起并打开漂流瓶"},
			{"id": "first_place", "label": "在河边木桥创建第一个地图留点"},
			{"id": "first_postcard", "label": "拍照、写一句话并寄出明信片"},
		],
	},
	3: {
		"title": "自己长出的花",
		"subtitle": "生活行为 → 记忆花生长 → 第一次 AI 房间生成",
		"ending": "这间房没有收藏很多东西，但它已经保存了你来到花园后的第一段生活。",
		"tasks": [
			{"id": "first_memory_flower", "label": "观察生活中长出的第一朵记忆花"},
			{"id": "collect_memory_flower", "label": "把记忆花收录进图鉴"},
			{"id": "first_ai_room", "label": "输入描述并生成第一间 AI 房间"},
		],
	},
}

const CARDS := {
	"first_photo": {"id": "first_photo", "title": "第一张花园照片", "desc": "旧木盒里，花园曾经的样子还留在照片上。", "kind": "photo"},
	"first_dish": {"id": "first_dish", "title": "第一顿料理", "desc": "收获的番茄变成了桌上的第一道料理。", "kind": "dish"},
	"first_memory_flower": {
		"id": "first_memory_flower",
		"title": "来到花园后的第一段生活",
		"desc": "河边的风吹过衣角。\n明信片上的墨还没有干。\n桌上放着刚做好的番茄料理。",
		"kind": "memory_flower",
	},
}

var _pending_quest_intro := false

func _ready() -> void:
	FarmManager.planted.connect(func(crop_id: String) -> void:
		if crop_id == "corrato":
			complete_task("first_seed"))
	FarmManager.harvested.connect(func(crop_id: String, _item_id: String, _qty: int) -> void:
		if crop_id == "corrato":
			complete_task("harvest_tomato"))
	KitchenManager.ai_dish_created.connect(func(_dish_id: String) -> void:
		_record_first_dish())
	KitchenManager.meal_completed.connect(func(_meal: Dictionary) -> void:
		complete_task("dish_on_table"))
	if GardenBuildManager != null and not GardenBuildManager.layout_saved.is_connected(_on_garden_layout_saved):
		GardenBuildManager.layout_saved.connect(_on_garden_layout_saved)
	if RoomLayoutManager != null and not RoomLayoutManager.room_generated.is_connected(_on_room_generated):
		RoomLayoutManager.room_generated.connect(_on_room_generated)
	call_deferred("_reconcile_existing_progress")

func play_opening(host: Node) -> void:
	var layer := OpeningNarrativeLayer.new()
	host.add_child(layer)
	await layer.finished
	MemoryManager.opening_seen = true
	complete_task("open_box", true)
	MemoryManager.save_game()
	_pending_quest_intro = true

func consume_quest_intro() -> bool:
	var pending := _pending_quest_intro
	_pending_quest_intro = false
	return pending

func debug_replay_opening(host: Node) -> void:
	MemoryManager.opening_seen = false
	await play_opening(host)
	consume_quest_intro()
	if SceneManager.game_hud != null:
		SceneManager.game_hud.start_onboarding_guide(true)

func current_chapter() -> int:
	for chapter_id in [1, 2, 3]:
		if not _chapter_complete(chapter_id):
			return chapter_id
	return 0

func chapter_title(chapter_id: int = current_chapter()) -> String:
	if chapter_id == 0:
		return "开放成长"
	return str((CHAPTERS[chapter_id] as Dictionary).get("title", ""))

func chapter_subtitle(chapter_id: int = current_chapter()) -> String:
	if chapter_id == 0:
		return "继续积累地点、料理、明信片、记忆花与房间素材"
	return str((CHAPTERS[chapter_id] as Dictionary).get("subtitle", ""))

func tasks(chapter_id: int = current_chapter()) -> Array:
	if chapter_id == 0:
		return []
	return (CHAPTERS[chapter_id] as Dictionary).get("tasks", [])

func is_task_done(task_id: String) -> bool:
	return bool(MemoryManager.chapter1_tasks.get(task_id, false))

func current_task() -> String:
	for task in tasks():
		if not is_task_done(str(task.id)):
			return str(task.id)
	return ""

func complete_task(task_id: String, silent: bool = false) -> bool:
	if is_task_done(task_id):
		return false
	var old_chapter := current_chapter()
	MemoryManager.chapter1_tasks[task_id] = true
	MemoryManager.save_game()
	task_completed.emit(task_id)
	if not silent:
		SceneManager._show_toast("任务完成：" + _task_label(task_id))
	_after_progress_changed(old_chapter)
	return true

func record_fishing_result(result_id: String) -> void:
	complete_task("first_fishing")
	if result_id == "bottle_opened":
		complete_task("first_bottle")

func record_place_and_postcard(place: Dictionary, postcard: Dictionary) -> void:
	if not place.is_empty():
		complete_task("first_place")
	if not postcard.is_empty():
		complete_task("first_postcard")

func collect_first_memory_flower() -> void:
	if is_task_done("first_memory_flower"):
		complete_task("collect_memory_flower")

func milestone_status() -> Array:
	var flower_count := MemoryManager.memory_cards.filter(func(card): return card is Dictionary and str(card.get("kind", "")) == "memory_flower").size()
	var postcard_count := MemoryManager.postcards.size()
	var dish_count := MemoryManager.kitchen_ai_dishes.size()
	var place_count := MemoryManager.travel_places.size()
	return [
		{"title": "记忆花园等级 2", "progress": "记忆花 %d/3 · 明信片 %d/3 · 料理 %d/3" % [flower_count, postcard_count, dish_count], "done": flower_count >= 3 and postcard_count >= 3 and dish_count >= 3, "reward": "解锁第二个房间"},
		{"title": "记忆花园等级 3", "progress": "探索地点 %d/5" % place_count, "done": place_count >= 5, "reward": "解锁花园中央区域"},
	]

func has_card(card_id: String) -> bool:
	return MemoryManager.memory_cards.any(func(card): return card is Dictionary and str(card.get("id", "")) == card_id)

func unlock_card(card_id: String) -> void:
	if has_card(card_id) or not CARDS.has(card_id):
		return
	var card: Dictionary = (CARDS[card_id] as Dictionary).duplicate(true)
	card["unlocked_at"] = Time.get_datetime_string_from_system()
	MemoryManager.memory_cards.append(card)
	MemoryManager.save_game()
	memory_card_unlocked.emit(card)
	if SceneManager.game_hud != null:
		var popup := MemoryCardPopup.new()
		popup.card_data = card
		SceneManager.game_hud.open_panel(popup)

func _record_first_dish() -> void:
	if complete_task("first_dish"):
		unlock_card("first_dish")

func _on_garden_layout_saved(_object_count: int) -> void:
	complete_task("garden_edit")

func _on_room_generated(_room: Dictionary) -> void:
	complete_task("first_ai_room")

func _reconcile_existing_progress() -> void:
	if not MemoryManager.travel_places.is_empty():
		complete_task("first_place", true)
	if not MemoryManager.postcards.is_empty():
		complete_task("first_postcard", true)
	if not MemoryManager.kitchen_ai_dishes.is_empty():
		complete_task("first_dish", true)
	if not MemoryManager.rooms.is_empty():
		complete_task("first_ai_room", true)
	_after_progress_changed(current_chapter())

func _after_progress_changed(old_chapter: int) -> void:
	var new_chapter := current_chapter()
	if old_chapter in [1, 2, 3] and _chapter_complete(old_chapter):
		var end_key := "chapter_%d_ending_seen" % old_chapter
		if not is_task_done(end_key):
			MemoryManager.chapter1_tasks[end_key] = true
			MemoryManager.save_game()
			SceneManager._show_toast(str((CHAPTERS[old_chapter] as Dictionary).ending))
	if new_chapter == 3 and not is_task_done("first_memory_flower"):
		unlock_card("first_memory_flower")
		MemoryManager.chapter1_tasks["first_memory_flower"] = true
		MemoryManager.save_game()
		task_completed.emit("first_memory_flower")
	if new_chapter != old_chapter:
		chapter_changed.emit(new_chapter)

func _chapter_complete(chapter_id: int) -> bool:
	for task in tasks(chapter_id):
		if not is_task_done(str(task.id)):
			return false
	return true

func _task_label(task_id: String) -> String:
	for chapter_id in [1, 2, 3]:
		for task in tasks(chapter_id):
			if str(task.id) == task_id:
				return str(task.label)
	return task_id
