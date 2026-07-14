extends Node

## Family Garden 记忆/数据层（autoload 单例）。
## 拥有：家庭数据模型 + 本地存档 + 云数据落地 + 查询 + 邮箱告警状态。
## 不持有任何场景/UI 节点；UI 通过 mailbox_alert_changed 信号刷新邮箱徽标。
## 从 main.gd 拆出，逻辑保持不变（增量 2 / feature/c-foundation）。

signal mailbox_alert_changed(state: String)
signal farm_activity_changed

const SAVE_PATH := "user://family_garden_save_v2.json"
const TEST_SAVE_PATH := "user://family_garden_save_v2.test.json"
const FAMILY_ID := "Happy_birthday_David"

const MAILBOX_ALERT_NONE := "none"
const MAILBOX_ALERT_DOT := "dot"
const MAILBOX_ALERT_LETTER := "letter"

var plants: Array = []
var travel_places: Array = []
var postcards: Array = []
var garden_messages: Array = []
var kitchen_orders_done: Array = []   ## 已完成的厨房订单 id(家庭数据;v1 本地持久化,未来可接云)
var kitchen_ai_dishes: Array = []     ## AI 随机料理 [{id,name,ingredients,description,quantity,generation_meta...}]
var farm_activity_log: Array = []     ## 农场告示牌动态 [{id, actor_name, action, detail, created_at...}]
# ── 启动剧情 / Chapter 1(个人 onboarding 态,与 selected_role_key 同为本设备个人字段;
#    未来迁移点:per-member 云 profile) ──
var opening_seen: bool = false        ## 开场叙事是否已看过(跳过也算)
var onboarding_guide_seen: bool = false ## 开场后的屏幕高亮指引是否已完成或跳过
var chapter1_tasks: Dictionary = {}   ## task_id -> true(Chapter 1 任务完成态)
var memory_cards: Array = []          ## 已解锁记忆卡 [{id,title,desc,unlocked_at}](未来接家庭树/相册/云端)
var farm_plots: Array = []            ## 农场地块状态 FarmPlotState(家庭共享;由 FarmManager 读写)
var farm_livestock: Dictionary = {}   ## 畜牧状态 source_id -> last_collected_at(家庭共享)
var mailbox_has_unread := true # legacy compatibility; true means mailbox_alert_state != none
var mailbox_alert_state: String = MAILBOX_ALERT_DOT
var selected_role_key: String = ""
var player_display_name: String = ""
var character_appearance: Dictionary = {}   ## 本机玩家捏脸配置；由 AppearanceManager 校验和渲染。
var last_scene_id: String = ""
var last_spawn_key: String = "default"
var last_player_position: Dictionary = {}
var last_saved_at: String = ""

# 记忆/节点/回答数据（字段对齐 backend/supabase/memory_schema.sql）。
# 本地存档和 CloudManager 同步并行存在；UI 层只通过本管理器读写。
var memories: Array = []
var nodes: Array = []
var answers: Array = []
# AI 房间 / 房间物件（字段对齐 memory_schema.sql 的 rooms / room_objects）。
var rooms: Array = []
var room_objects: Array = []
var ai_sync_outbox: Array = []
# 跨成员互动计数（= 家庭关系温度计，对齐 families.cross_member_interaction_count）。
# 有效跨成员回答 +1：回答者≠上传者 且 同一 (memory, 回答者) 只计一次。进花园直接读它判季节。
var cross_member_interaction_count: int = 0
var cross_member_pairs: Array = []  # 去重键 "memory_id|answerer"
# 家庭画像（family-portrait）：新成员首次参与 或 记忆数翻倍(2→4→8→16) 时重算版本，挂到入口木牌。
# 当前用 version 表示画像摘要重算；未来接真实 AI 画像时继续用 version 触发重画/缓存失效。
var family_portrait: Dictionary = {"version": 0, "member_count": 0, "memory_count": 0, "last_threshold": 0, "members": []}

## 用 AI 记忆卡片创建一条 memory。返回该 memory dict。
func create_memory(ai_card: Dictionary, input_type: String = "photo", raw_text: String = "", image_url: String = "", generation_meta: Dictionary = {}, workflow_key: String = "", upload_id: String = "") -> Dictionary:
	if workflow_key != "":
		for existing in memories:
			if existing is Dictionary and String(existing.get("workflow_key", "")) == workflow_key:
				return existing
	var memory_id := "mem_" + workflow_key.sha256_text().left(24) if workflow_key != "" \
		else "mem_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	var mem := {
		"id": memory_id,
		"family_id": FAMILY_ID,
		"user_id": selected_role_key,
		"input_type": input_type,
		"raw_text": raw_text,
		"image_url": image_url,
		"upload_id": upload_id,
		"status": "ai_done" if not ai_card.is_empty() else "uploaded",
		"ai_card": ai_card,
		"generation_meta": generation_meta.duplicate(true),
		"link_status": "pending" if not ai_card.is_empty() and input_type not in ["room_photo", "bottle_answer"] else "not_applicable",
		"workflow_key": workflow_key,
		"created_at": Time.get_datetime_string_from_system()
	}
	memories.append(mem)
	save_game()
	_sync("memories", mem)
	return mem

## 为某条 memory 在场景里创建一个节点（slot_id 由游戏系统分配，AI 不输出坐标）。
func create_node(memory_id: String, scene_id: String, node_type: String, slot_id: String, asset_key: String = "", workflow_key: String = "") -> Dictionary:
	if workflow_key != "":
		for existing in nodes:
			if existing is Dictionary and String(existing.get("workflow_key", "")) == workflow_key:
				return existing
	var node := {
		"id": "node_" + workflow_key.sha256_text().left(24) if workflow_key != "" \
			else "node_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000),
		"family_id": FAMILY_ID,
		"memory_id": memory_id,
		"scene_id": scene_id,
		"node_type": node_type,
		"asset_key": asset_key,
		"slot_id": slot_id,
		"state": "new",
		"clickable": true,
		"workflow_key": workflow_key,
		"created_at": Time.get_datetime_string_from_system()
	}
	nodes.append(node)
	save_game()
	_sync("nodes", node)
	return node

func get_memory(memory_id: String) -> Dictionary:
	for m in memories:
		if m is Dictionary and String(m.get("id", "")) == memory_id:
			return m
	return {}

func set_memory_link_status(memory_id: String, status: String) -> void:
	if status not in ["pending", "generating", "complete", "failed", "not_applicable"]:
		return
	var memory := get_memory(memory_id)
	if memory.is_empty():
		return
	memory["link_status"] = status
	memory["updated_at"] = Time.get_datetime_string_from_system()
	save_game()
	_sync("memories", memory)

func create_kitchen_ai_dish(dish_data: Dictionary, generation_meta: Dictionary = {}, workflow_key: String = "") -> Dictionary:
	var dish_id := String(dish_data.get("id", ""))
	if dish_id == "":
		dish_id = "dish_ai_" + (workflow_key.sha256_text().left(24) if workflow_key != "" else "%d_%03d" % [Time.get_ticks_msec(), randi() % 1000])
	for existing in kitchen_ai_dishes:
		if existing is Dictionary and String(existing.get("id", "")) == dish_id:
			return existing
	var raw_ingredients: Variant = dish_data.get("ingredients", [])
	var raw_visual: Variant = dish_data.get("visual", {})
	var dish := {
		"id": dish_id,
		"family_id": FAMILY_ID,
		"name": String(dish_data.get("name", dish_id)),
		"description": String(dish_data.get("description", "")),
		"serving_note": String(dish_data.get("serving_note", "")),
		"family_question": String(dish_data.get("family_question", "")),
		"safety_note": String(dish_data.get("safety_note", "")),
		"ingredients": raw_ingredients.duplicate(true) if raw_ingredients is Array else [],
		"visual": raw_visual.duplicate(true) if raw_visual is Dictionary else {},
		"station_type": String(dish_data.get("station_type", "stove")),
		"quantity": int(dish_data.get("quantity", 1)),
		"role": selected_role_key,
		"generation_meta": generation_meta.duplicate(true),
		"workflow_key": workflow_key,
		"created_at": Time.get_datetime_string_from_system(),
		"updated_at": Time.get_datetime_string_from_system(),
	}
	kitchen_ai_dishes.append(dish)
	save_game()
	_sync("kitchen_dishes", dish)
	return dish

func get_kitchen_ai_dish(dish_id: String) -> Dictionary:
	for dish in kitchen_ai_dishes:
		if dish is Dictionary and String(dish.get("id", "")) == dish_id:
			return dish
	return {}

func consume_kitchen_ai_dish(dish_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	for index in range(kitchen_ai_dishes.size()):
		var dish: Variant = kitchen_ai_dishes[index]
		if not dish is Dictionary or String(dish.get("id", "")) != dish_id:
			continue
		var row := dish as Dictionary
		var count := int(row.get("quantity", 0))
		if count < amount:
			return false
		row["quantity"] = count - amount
		row["updated_at"] = Time.get_datetime_string_from_system()
		if int(row.get("quantity", 0)) <= 0:
			kitchen_ai_dishes.remove_at(index)
			queue_ai_delete("kitchen_dishes", dish_id)
		else:
			_sync("kitchen_dishes", row)
		save_game()
		return true
	return false

## 注：不能叫 get_node，会覆盖 Node 原生方法（Godot 4.7 视为错误）。
func get_node_by_id(node_id: String) -> Dictionary:
	for n in nodes:
		if n is Dictionary and String(n.get("id", "")) == node_id:
			return n
	return {}

func get_nodes_for_scene(scene_id: String) -> Array:
	return nodes.filter(func(n): return n is Dictionary and String(n.get("scene_id", "")) == scene_id)

## 记忆花统一陈列在主花园。兼容旧存档及云端曾写入鱼塘的花与关联藤蔓。
func migrate_fishpond_memories_to_garden() -> int:
	var migrated := 0
	var changed := false
	var migrated_memory_ids := {}
	for raw_node in nodes:
		if not (raw_node is Dictionary):
			continue
		var node: Dictionary = raw_node
		if String(node.get("scene_id", "")) != "fishpond":
			continue
		var node_type := String(node.get("node_type", ""))
		if node_type not in ["memory_flower", "memory_seed"]:
			continue
		node["scene_id"] = "garden"
		node["slot_id"] = "garden_archive_flowers"
		var memory_id := String(node.get("memory_id", ""))
		if memory_id != "":
			migrated_memory_ids[memory_id] = true
		_sync("nodes", node)
		migrated += 1
		changed = true
	# 同步修正所有已位于花园的花朵卡片，避免旧 AI 建议仍把界面指向鱼塘。
	for raw_node in nodes:
		if not (raw_node is Dictionary):
			continue
		var garden_node: Dictionary = raw_node
		if String(garden_node.get("scene_id", "")) == "garden" \
			and String(garden_node.get("node_type", "")) in ["memory_flower", "memory_seed"]:
			migrated_memory_ids[String(garden_node.get("memory_id", ""))] = true
	for raw_memory in memories:
		if not (raw_memory is Dictionary):
			continue
		var memory: Dictionary = raw_memory
		if not migrated_memory_ids.has(String(memory.get("id", ""))):
			continue
		var card: Dictionary = memory.get("ai_card", {})
		if String(card.get("suggested_scene", "garden")) == "garden":
			continue
		card["suggested_scene"] = "garden"
		memory["ai_card"] = card
		_sync("memories", memory)
		changed = true
	# 旧鱼塘记忆之间的藤蔓也随记忆迁入花园，避免成为不可见的孤立数据。
	for raw_link in nodes:
		if not (raw_link is Dictionary):
			continue
		var link: Dictionary = raw_link
		if String(link.get("scene_id", "")) == "fishpond" and String(link.get("node_type", "")) == "memory_link":
			link["scene_id"] = "garden"
			_sync("nodes", link)
			changed = true
	if changed:
		save_game()
	return migrated

## 创建一条记忆连线节点（连接两条记忆；relation_type/question 来自 cross-memory-link 或空存档演示种子）。
func create_memory_link(memory_id: String, linked_memory_id: String, scene_id: String, relation_type: String, question: String, confidence: float = 1.0, generation_meta: Dictionary = {}) -> Dictionary:
	if memory_id == "" or linked_memory_id == "" or memory_id == linked_memory_id:
		return {}
	var pair := [memory_id, linked_memory_id]
	pair.sort()
	var pair_key := String(pair[0]) + "|" + String(pair[1])
	for existing in nodes:
		if existing is Dictionary and String(existing.get("node_type", "")) == "memory_link" \
			and String(existing.get("pair_key", "")) == pair_key:
			return existing
	var node := {
		"id": "link_" + pair_key.sha256_text().left(24),
		"family_id": FAMILY_ID,
		"memory_id": memory_id,
		"linked_memory_id": linked_memory_id,
		"source_memory_id": memory_id,
		"target_memory_id": linked_memory_id,
		"scene_id": scene_id,
		"node_type": "memory_link",
		"relation_type": relation_type,
		"relation_strength": _relation_strength_for_type(relation_type),
		"active_time_mode": "both",
		"visual_style": _visual_style_for_type(relation_type),
		"visible_when": "always",
		"curve_points": [],
		"question": question,
		"confidence": confidence,
		"generation_meta": generation_meta.duplicate(true),
		"followup_answer": "",
		"followup_answered_by": "",
		"followup_answered_at": "",
		"followup_updated_at": "",
		"pair_key": pair_key,
		"slot_id": "",
		"state": "new",
		"clickable": true,
		"created_at": Time.get_datetime_string_from_system()
	}
	nodes.append(node)
	save_game()
	_sync("nodes", node)
	return node

func get_memory_links(scene_id: String) -> Array:
	return nodes.filter(func(n): return n is Dictionary \
		and String(n.get("node_type", "")) == "memory_link" \
		and String(n.get("scene_id", "")) == scene_id)

func _relation_strength_for_type(relation_type: String) -> float:
	var text := relation_type.to_lower()
	if text.contains("strong") or text.contains("family"):
		return 0.86
	if text.contains("weak"):
		return 0.30
	return 0.58

func _visual_style_for_type(relation_type: String) -> String:
	return "bee" if relation_type.to_lower().contains("bee") else "butterfly"

func get_memory_link_by_id(link_id: String) -> Dictionary:
	for node in nodes:
		if node is Dictionary and String(node.get("node_type", "")) == "memory_link" \
			and String(node.get("id", "")) == link_id:
			return node
	return {}

func is_memory_link_answered(link: Dictionary) -> bool:
	return String(link.get("followup_answer", "")).strip_edges() != ""

func answer_memory_link(link_id: String, answer_text: String) -> Dictionary:
	var link := get_memory_link_by_id(link_id)
	if link.is_empty():
		return {"ok": false, "error": {"code": "LINK_NOT_FOUND", "message": "这条记忆藤蔓已经不存在。"}}
	var text := answer_text.strip_edges()
	if text == "":
		return {"ok": false, "error": {"code": "EMPTY_ANSWER", "message": "先写一点补充，再保存。"}}
	if text.length() > 1200:
		return {"ok": false, "error": {"code": "ANSWER_TOO_LONG", "message": "补充内容不能超过 1200 个字。"}}
	var now := Time.get_datetime_string_from_system()
	var was_answered := is_memory_link_answered(link)
	link["followup_answer"] = text
	link["followup_answered_by"] = selected_role_key
	if not was_answered or String(link.get("followup_answered_at", "")) == "":
		link["followup_answered_at"] = now
	link["followup_updated_at"] = now
	link["state"] = "grown"
	save_game()
	_sync("nodes", link)
	return {"ok": true, "link": link, "updated": was_answered}

func clear_memory_link_answer(link_id: String) -> bool:
	var link := get_memory_link_by_id(link_id)
	if link.is_empty():
		return false
	link["followup_answer"] = ""
	link["followup_answered_by"] = ""
	link["followup_answered_at"] = ""
	link["followup_updated_at"] = Time.get_datetime_string_from_system()
	link["state"] = "new"
	save_game()
	_sync("nodes", link)
	return true

func get_memory_link_endpoints(link: Dictionary) -> Dictionary:
	var memory_a := get_memory(String(link.get("memory_id", "")))
	var memory_b := get_memory(String(link.get("linked_memory_id", "")))
	return {
		"memory_a": memory_a,
		"memory_b": memory_b,
		"ok": not memory_a.is_empty() and not memory_b.is_empty(),
	}

func count_memory_links_for_memory(memory_id: String, scene_id: String = "") -> int:
	var count := 0
	for node in nodes:
		if not (node is Dictionary):
			continue
		if String(node.get("node_type", "")) != "memory_link":
			continue
		if scene_id != "" and String(node.get("scene_id", "")) != scene_id:
			continue
		if String(node.get("memory_id", "")) == memory_id or String(node.get("linked_memory_id", "")) == memory_id:
			count += 1
	return count

func update_memory_card(memory_id: String, card: Dictionary) -> bool:
	var validation := AIContractValidator.validate_data("generate-memory-card", card)
	if not bool(validation.get("ok", false)):
		return false
	var memory := get_memory(memory_id)
	if memory.is_empty():
		return false
	memory["ai_card"] = card.duplicate(true)
	memory["updated_at"] = Time.get_datetime_string_from_system()
	save_game()
	_sync("memories", memory)
	return true

func delete_memory(memory_id: String) -> bool:
	var memory := get_memory(memory_id)
	if memory.is_empty():
		return false
	var upload_id := String(memory.get("upload_id", ""))
	var deleted_node_ids: Array = []
	for node in nodes:
		if node is Dictionary and (String(node.get("memory_id", "")) == memory_id \
			or String(node.get("linked_memory_id", "")) == memory_id):
			deleted_node_ids.append(String(node.get("id", "")))
	nodes = nodes.filter(func(node): return not (node is Dictionary and (String(node.get("memory_id", "")) == memory_id or String(node.get("linked_memory_id", "")) == memory_id)))
	var deleted_answer_ids: Array = []
	for answer in answers:
		if answer is Dictionary and String(answer.get("memory_id", "")) == memory_id:
			deleted_answer_ids.append(String(answer.get("id", "")))
	answers = answers.filter(func(answer): return not (answer is Dictionary and String(answer.get("memory_id", "")) == memory_id))
	memories = memories.filter(func(item): return not (item is Dictionary and String(item.get("id", "")) == memory_id))
	for node_id in deleted_node_ids:
		queue_ai_delete("nodes", node_id)
	for answer_id in deleted_answer_ids:
		queue_ai_delete("answers", answer_id)
	queue_ai_delete("memories", memory_id)
	if upload_id != "":
		queue_ai_image_delete(upload_id)
	save_game()
	_schedule_ai_outbox_flush()
	return true

func get_answer_for_memory(memory_id: String) -> String:
	var result := ""
	for a in answers:
		if a is Dictionary and String(a.get("memory_id", "")) == memory_id:
			result = String(a.get("answer_text", ""))
	return result

## 回答一条记忆：存 answer + 把该记忆的节点标记为 grown + 存档。
func answer_memory(memory_id: String, answer_text: String) -> void:
	var ans := {
		"id": "ans_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000),
		"family_id": FAMILY_ID,
		"memory_id": memory_id,
		"user_id": selected_role_key,
		"answer_text": answer_text,
		"created_at": Time.get_datetime_string_from_system()
	}
	answers.append(ans)
	var grown: Array = []
	for n in nodes:
		if n is Dictionary and String(n.get("memory_id", "")) == memory_id:
			n["state"] = "grown"
			grown.append(n)
	save_game()
	_sync("answers", ans)
	for n in grown:
		_sync("nodes", n)  # 节点状态变 grown，同步

## 用 AI 房间识别结果创建一个房间（room_analysis：room_type/style/suggested_room_theme/...）。
func create_room(analysis: Dictionary, source_memory_id: String = "", workflow_key: String = "", generation_meta: Dictionary = {}, scene_schema: Dictionary = {}) -> Dictionary:
	if workflow_key != "":
		for existing in rooms:
			if existing is Dictionary and String(existing.get("workflow_key", "")) == workflow_key:
				return existing
	var room := {
		"id": "room_" + workflow_key.sha256_text().left(24) if workflow_key != "" \
			else "room_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000),
		"family_id": FAMILY_ID,
		"user_id": selected_role_key,
		"room_name": String(analysis.get("suggested_room_theme", "")),
		"room_type": String(analysis.get("room_type", "unknown")),
		"style": String(analysis.get("style", "")),
			"background_asset": "",
			"scene_schema": scene_schema.duplicate(true),
			"source_memory_id": source_memory_id,
		"workflow_key": workflow_key,
		"generation_meta": generation_meta.duplicate(true),
		"created_at": Time.get_datetime_string_from_system()
	}
	rooms.append(room)
	save_game()
	_sync("rooms", room)
	return room

## 在房间里摆一件物件（slot_id 由 ZoneManager 分配，AI 只给 object_type / zone）。
func create_room_object(room_id: String, object_type: String, zone: String, slot_id: String, asset_key: String = "") -> Dictionary:
	for existing in room_objects:
		if existing is Dictionary and String(existing.get("room_id", "")) == room_id \
			and String(existing.get("slot_id", "")) == slot_id:
			return existing
	var obj := {
		"id": "obj_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000),
		"family_id": FAMILY_ID,
		"room_id": room_id,
		"object_type": object_type,
		"asset_key": asset_key,
		"slot_id": slot_id,
		"zone": zone,
		"clickable": true,
		"collision": false,
		"created_at": Time.get_datetime_string_from_system()
	}
	room_objects.append(obj)
	save_game()
	_sync("room_objects", obj)
	return obj

func get_room_for_user(user_id: String) -> Dictionary:
	var result := {}
	for r in rooms:
		if r is Dictionary and String(r.get("user_id", "")) == user_id:
			result = r  # 取最近一个
	return result

func get_room_objects(room_id: String) -> Array:
	return room_objects.filter(func(o): return o is Dictionary and String(o.get("room_id", "")) == room_id)

func delete_room(room_id: String) -> bool:
	var found := false
	for room in rooms:
		if room is Dictionary and String(room.get("id", "")) == room_id:
			found = true
			break
	if not found:
		return false
	var object_ids: Array = []
	for object in room_objects:
		if object is Dictionary and String(object.get("room_id", "")) == room_id:
			object_ids.append(String(object.get("id", "")))
	room_objects = room_objects.filter(func(object): return not (object is Dictionary and String(object.get("room_id", "")) == room_id))
	rooms = rooms.filter(func(room): return not (room is Dictionary and String(room.get("id", "")) == room_id))
	for object_id in object_ids:
		queue_ai_delete("room_objects", object_id)
	queue_ai_delete("rooms", room_id)
	save_game()
	_schedule_ai_outbox_flush()
	return true

func update_room_object(object_id: String, zone: String, slot_id: String) -> bool:
	for object in room_objects:
		if object is Dictionary and String(object.get("id", "")) == object_id:
			object["zone"] = zone
			object["slot_id"] = slot_id
			object["updated_at"] = Time.get_datetime_string_from_system()
			save_game()
			_sync("room_objects", object)
			return true
	return false

func delete_room_object(object_id: String) -> bool:
	var previous_size := room_objects.size()
	room_objects = room_objects.filter(func(object): return not (object is Dictionary and String(object.get("id", "")) == object_id))
	if room_objects.size() == previous_size:
		return false
	queue_ai_delete("room_objects", object_id)
	save_game()
	_schedule_ai_outbox_flush()
	return true

func create_bottle(question_card: Dictionary, slot_id: String, generation_meta: Dictionary = {}) -> Dictionary:
	var question := String(question_card.get("question", "")).strip_edges()
	if question == "":
		return {}
	var question_key := question.to_lower().sha256_text()
	for existing in nodes:
		if existing is Dictionary and String(existing.get("node_type", "")) == "bottle" \
			and String(existing.get("question_key", "")) == question_key:
			return existing
	var bottle := {
		"id": "bottle_" + question_key.left(24),
		"family_id": FAMILY_ID,
		"scene_id": "fishpond",
		"node_type": "bottle",
		"slot_id": slot_id,
		"question": question,
		"question_key": question_key,
		"question_card": question_card.duplicate(true),
		"generation_meta": generation_meta.duplicate(true),
		"state": "floating",
		"answer": "",
		"answer_memory_id": "",
		"clickable": true,
		"created_at": Time.get_datetime_string_from_system(),
	}
	nodes.append(bottle)
	save_game()
	_sync("nodes", bottle)
	return bottle

func get_bottles() -> Array:
	return nodes.filter(func(node): return node is Dictionary and String(node.get("node_type", "")) == "bottle" and String(node.get("scene_id", "")) == "fishpond")

func mark_bottle_answered(bottle_id: String, answer_text: String, memory_id: String) -> bool:
	for bottle in nodes:
		if bottle is Dictionary and String(bottle.get("id", "")) == bottle_id:
			if String(bottle.get("answer_memory_id", "")) != "":
				return false
			bottle["state"] = "opened"
			bottle["answer"] = answer_text
			bottle["answer_memory_id"] = memory_id
			save_game()
			_sync("nodes", bottle)
			return true
	return false

## 登记一次跨成员回答：回答者≠上传者 且 同一 (memory, 回答者) 未计过 → 计数 +1。
## 返回是否真正计数（用于触发分季背景刷新）。
func register_cross_member_answer(memory_id: String, answerer: String) -> bool:
	var mem := get_memory(memory_id)
	var uploader := String(mem.get("user_id", ""))
	if uploader == "" or answerer == "" or answerer == uploader:
		return false
	var pair := memory_id + "|" + answerer
	if pair in cross_member_pairs:
		return false
	cross_member_pairs.append(pair)
	cross_member_interaction_count += 1
	save_game()
	_sync("families", _family_row())
	return true

## 参与过的成员 key（上传记忆 或 回答过的人）。
func participants() -> Array:
	var seen: Array = []
	for m in memories:
		var u := String(m.get("user_id", ""))
		if u != "" and not (u in seen):
			seen.append(u)
	for a in answers:
		var u := String(a.get("user_id", ""))
		if u != "" and not (u in seen):
			seen.append(u)
	return seen

## ≤n 的最大 2 的幂（≥2）；不足 2 返回 0。用于"记忆数翻倍"阈值 2/4/8/16…。
func _largest_pow2_le(n: int) -> int:
	if n < 2:
		return 0
	var p := 2
	while p * 2 <= n:
		p *= 2
	return p

## 按需重算家庭画像：新成员首次参与 或 记忆数跨过新的翻倍阈值 → version +1。返回是否重算。
func maybe_recompute_family_portrait() -> bool:
	var parts := participants()
	var mem_count := memories.size()
	var known: Array = family_portrait.get("members", [])
	var new_member := false
	for p in parts:
		if not (p in known):
			new_member = true
			break
	var threshold := _largest_pow2_le(mem_count)
	var doubled := threshold > int(family_portrait.get("last_threshold", 0))
	if not new_member and not doubled:
		return false
	family_portrait = {
		"version": int(family_portrait.get("version", 0)) + 1,
		"member_count": parts.size(),
		"memory_count": mem_count,
		"last_threshold": threshold,
		"members": parts
	}
	save_game()
	_sync("families", _family_row())
	return true

## 花园季节（家庭关系温度计）：0→春 / 3-9→夏 / 10+→秋（docs/dev/34 §Part 1）。
func garden_season() -> String:
	if cross_member_interaction_count >= 10:
		return "autumn"
	if cross_member_interaction_count >= 3:
		return "summer"
	return "spring"

func apply_cloud_data(data: Dictionary, force: bool = false) -> void:
	var remote_places: Array = data.get("travel_places", [])
	var remote_postcards: Array = data.get("postcards", [])
	var remote_messages: Array = data.get("messages", [])
	var remote_events: Array = data.get("mailbox_events", [])

	var has_remote_content: bool = remote_places.size() > 0 or remote_postcards.size() > 0 or remote_messages.size() > 0

	if has_remote_content or force:
		travel_places = []
		for raw_place in remote_places:
			if raw_place is Dictionary:
				var row: Dictionary = raw_place
				var place_id: String = str(row.get("id", ""))
				travel_places.append({
					"id": place_id,
					"title": str(row.get("title", "Untitled Place")),
					"note": str(row.get("note", "")),
					"x": float(row.get("map_x", 0.0)),
					"y": float(row.get("map_y", 0.0)),
					"postcard_id": "",
					"created_by": "",
					"role": "",
					"photo_path": str(row.get("photo_path", ""))
				})

		postcards = []
		for raw_postcard in remote_postcards:
			if raw_postcard is Dictionary:
				var row: Dictionary = raw_postcard
				var postcard_id: String = str(row.get("id", ""))
				var place_id: String = str(row.get("place_id", ""))
				postcards.append({
					"id": postcard_id,
					"place_id": place_id,
					"title": str(row.get("title", "新明信片")),
					"message": str(row.get("message", "")),
					"is_new": bool(row.get("is_new", false)),
					"created_by": "",
					"role": "",
					"photo_path": str(row.get("photo_path", ""))
				})

		for place in travel_places:
			var local_place_id: String = str(place.get("id", ""))
			var linked_postcard: Dictionary = find_postcard_by_place(local_place_id)
			if not linked_postcard.is_empty():
				place["postcard_id"] = str(linked_postcard.get("id", ""))

		garden_messages = []
		for raw_message in remote_messages:
			if raw_message is Dictionary:
				var row: Dictionary = raw_message
				garden_messages.append({
					"id": str(row.get("id", "")),
					"author": str(row.get("author_name", "Family")),
					"text": str(row.get("body", "")),
					"created_at": str(row.get("created_at", "")),
					"role": ""
				})

	var has_unread_letter: bool = false
	var has_unread_dot: bool = false
	for raw_event in remote_events:
		if raw_event is Dictionary:
			var event_row: Dictionary = raw_event
			if not bool(event_row.get("is_read", true)):
				if str(event_row.get("type", "")) == "postcard":
					has_unread_letter = true
				else:
					has_unread_dot = true

	if has_unread_letter or count_unread_postcards() > 0:
		set_mailbox_alert(MAILBOX_ALERT_LETTER)
	elif has_unread_dot:
		set_mailbox_alert(MAILBOX_ALERT_DOT)
	else:
		clear_mailbox_alert()

func normalize_mailbox_alert(state: String) -> String:
	if state == MAILBOX_ALERT_LETTER or state == MAILBOX_ALERT_DOT or state == MAILBOX_ALERT_NONE:
		return state
	return MAILBOX_ALERT_NONE

func set_mailbox_alert(state: String) -> void:
	mailbox_alert_state = normalize_mailbox_alert(state)
	mailbox_has_unread = mailbox_alert_state != MAILBOX_ALERT_NONE
	mailbox_alert_changed.emit(mailbox_alert_state)

func notify_new_postcard() -> void:
	# Letter alerts have the highest priority because they mean a concrete postcard/mail item arrived.
	set_mailbox_alert(MAILBOX_ALERT_LETTER)

func notify_family_activity() -> void:
	# Ordinary family activity uses a subtle red dot, unless a stronger letter alert is already present.
	if mailbox_alert_state != MAILBOX_ALERT_LETTER:
		set_mailbox_alert(MAILBOX_ALERT_DOT)

func record_farm_activity(action: String, label: String, detail: String, item_id: String = "", qty: int = 0) -> Dictionary:
	var clean_detail := detail.strip_edges()
	if clean_detail == "":
		return {}
	var role := selected_role_key
	if GameIdentity != null and GameIdentity.is_ready() and GameIdentity.role != "":
		role = GameIdentity.role
	if role == "":
		role = "father"
	var actor_name := ""
	if GameIdentity != null and GameIdentity.is_ready():
		actor_name = GameIdentity.display_name.strip_edges()
	if actor_name == "":
		actor_name = player_display_name.strip_edges()
	if actor_name == "" and CharacterDB != null:
		actor_name = CharacterDB.display_name(role)
	var family_id := FAMILY_ID
	if CloudManager != null and CloudManager.has_method("family_code"):
		var cloud_family := str(CloudManager.family_code()).strip_edges()
		if cloud_family != "":
			family_id = cloud_family
	var now_unix := int(Time.get_unix_time_from_system())
	var row := {
		"id": "farm_log:%s:%d:%d" % [family_id, Time.get_ticks_msec(), randi() % 1000000],
		"family_id": family_id,
		"actor_member_id": GameIdentity.member_id if GameIdentity != null and GameIdentity.is_ready() else "",
		"actor_role": role,
		"actor_name": actor_name,
		"action": action,
		"label": label,
		"detail": clean_detail,
		"item_id": item_id,
		"qty": qty,
		"created_at_unix": now_unix,
		"created_at": Time.get_datetime_string_from_system()
	}
	farm_activity_log.append(row)
	_trim_farm_activity_log()
	save_game()
	_sync("farm_activity_log", row)
	notify_family_activity()
	farm_activity_changed.emit()
	return row

func recent_farm_activities(limit: int = 30) -> Array:
	var rows := farm_activity_log.duplicate(true)
	rows.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((a as Dictionary).get("created_at_unix", 0)) > int((b as Dictionary).get("created_at_unix", 0)) \
			if a is Dictionary and b is Dictionary else false)
	if limit > 0 and rows.size() > limit:
		rows = rows.slice(0, limit)
	return rows

func _trim_farm_activity_log() -> void:
	farm_activity_log = recent_farm_activities(120)

func clear_mailbox_alert() -> void:
	set_mailbox_alert(MAILBOX_ALERT_NONE)

func _reset_all() -> void:
	plants = []
	travel_places = []
	postcards = []
	garden_messages = []
	kitchen_orders_done = []
	kitchen_ai_dishes = []
	farm_activity_log = []
	farm_plots = []
	farm_livestock = {}
	opening_seen = false
	onboarding_guide_seen = false
	chapter1_tasks = {}
	memory_cards = []
	memories = []
	nodes = []
	answers = []
	rooms = []
	room_objects = []
	ai_sync_outbox = []
	cross_member_interaction_count = 0
	cross_member_pairs = []
	family_portrait = {"version": 0, "member_count": 0, "memory_count": 0, "last_threshold": 0, "members": []}
	mailbox_alert_state = MAILBOX_ALERT_DOT
	mailbox_has_unread = mailbox_alert_state != MAILBOX_ALERT_NONE
	selected_role_key = ""
	player_display_name = ""
	character_appearance = {}
	last_scene_id = ""
	last_spawn_key = "default"
	last_player_position = {}
	last_saved_at = ""

func update_autosave(scene_id: String, position: Vector2, spawn_key: String = "default") -> void:
	if selected_role_key == "" or scene_id == "":
		return
	last_scene_id = scene_id
	last_spawn_key = spawn_key if spawn_key != "" else "default"
	last_player_position = {"x": position.x, "y": position.y}
	last_saved_at = Time.get_datetime_string_from_system()
	save_game()

func has_resume_position() -> bool:
	return last_scene_id != "" \
		and last_player_position is Dictionary \
		and last_player_position.has("x") \
		and last_player_position.has("y")

func resume_position() -> Vector2:
	if not has_resume_position():
		return Vector2.ZERO
	return Vector2(float(last_player_position.get("x", 0.0)), float(last_player_position.get("y", 0.0)))

func reset_to_new_game() -> void:
	_reset_all()
	save_game()
	mailbox_alert_changed.emit(mailbox_alert_state)

# ── 远端同步接缝（迭代1a）────────────────────────────────────────────────
# 写操作把单条记录推给 CloudManager 的持久化后端；无后端时 no-op，本地 save_game 兜底。
# 迭代1b 注入 CloudBase 后端后即生效，本方法及调用点签名不变。
func _sync(table: String, row: Dictionary) -> void:
	CloudManager.persist_record(table, row)

func queue_ai_sync(table: String, row: Dictionary) -> void:
	var key := table + "|" + String(row.get("id", ""))
	for index in ai_sync_outbox.size():
		if String(ai_sync_outbox[index].get("key", "")) == key:
			ai_sync_outbox[index] = {"key": key, "operation": "upsert", "table": table, "row": row.duplicate(true)}
			save_game()
			return
	ai_sync_outbox.append({"key": key, "operation": "upsert", "table": table, "row": row.duplicate(true)})
	save_game()

func queue_ai_delete(table: String, row_id: String) -> void:
	if row_id == "":
		return
	var key := table + "|" + row_id
	var item := {"key": key, "operation": "delete", "table": table, "row_id": row_id}
	for index in ai_sync_outbox.size():
		if String(ai_sync_outbox[index].get("key", "")) == key:
			ai_sync_outbox[index] = item
			save_game()
			return
	ai_sync_outbox.append(item)
	save_game()

func queue_ai_image_delete(upload_id: String) -> void:
	if upload_id == "":
		return
	var key := "uploads|" + upload_id
	var item := {"key": key, "operation": "delete_image", "table": "uploads", "row_id": upload_id}
	for index in ai_sync_outbox.size():
		if String(ai_sync_outbox[index].get("key", "")) == key:
			ai_sync_outbox[index] = item
			save_game()
			return
	ai_sync_outbox.append(item)
	save_game()

func remove_ai_sync(table: String, row_id: String) -> void:
	var key := table + "|" + row_id
	ai_sync_outbox = ai_sync_outbox.filter(func(item): return String(item.get("key", "")) != key)
	save_game()

func _schedule_ai_outbox_flush() -> void:
	var workflow := get_node_or_null("/root/AIWorkflowManager")
	if workflow != null and workflow.has_method("flush_ai_sync_outbox"):
		workflow.call_deferred("flush_ai_sync_outbox")

# families 行（家庭级状态：跨成员计数 + 家庭画像）。
func _family_row() -> Dictionary:
	return {
		"id": FAMILY_ID,
		"cross_member_interaction_count": cross_member_interaction_count,
		"family_portrait": family_portrait
	}

# 从远端拉取并覆盖本地缓存（迭代1b 启动时调用）。无后端时各表返回空 → 保留本地存档。
func pull_remote() -> void:
	var pulled := false
	var cloud_ready := CloudManager != null \
		and CloudManager.has_method("has_cloud_records") \
		and CloudManager.has_cloud_records()
	var t_mem := CloudManager.load_table("memories")
	if cloud_ready or not t_mem.is_empty():
		memories = t_mem
		pulled = true
	var t_node := CloudManager.load_table("nodes")
	if cloud_ready or not t_node.is_empty():
		nodes = t_node
		pulled = true
	var t_ans := CloudManager.load_table("answers")
	if cloud_ready or not t_ans.is_empty():
		answers = t_ans
		pulled = true
	var t_room := CloudManager.load_table("rooms")
	if cloud_ready or not t_room.is_empty():
		rooms = t_room
		pulled = true
	var t_obj := CloudManager.load_table("room_objects")
	if cloud_ready or not t_obj.is_empty():
		room_objects = t_obj
		pulled = true
	var t_fam := CloudManager.load_table("families")
	if not t_fam.is_empty() and t_fam[0] is Dictionary:
		var row: Dictionary = t_fam[0]
		cross_member_interaction_count = int(row.get("cross_member_interaction_count", cross_member_interaction_count))
		var fp: Variant = row.get("family_portrait", null)
		if fp is Dictionary:
			family_portrait = fp
		pulled = true
	var t_places := CloudManager.load_table("travel_places")
	var t_postcards := CloudManager.load_table("postcards")
	var t_messages := CloudManager.load_table("messages")
	var t_mailbox := CloudManager.load_table("mailbox_events")
	var t_farm_activity := CloudManager.load_table("farm_activity_log")
	var t_kitchen_dishes := CloudManager.load_table("kitchen_dishes")
	if cloud_ready or not t_places.is_empty() or not t_postcards.is_empty() or not t_messages.is_empty() or not t_mailbox.is_empty():
		apply_cloud_data({
			"travel_places": t_places,
			"postcards": t_postcards,
			"messages": t_messages,
			"mailbox_events": t_mailbox,
		}, cloud_ready)
		pulled = true
	if cloud_ready or not t_farm_activity.is_empty():
		farm_activity_log = t_farm_activity
		_trim_farm_activity_log()
		farm_activity_changed.emit()
		pulled = true
	if cloud_ready or not t_kitchen_dishes.is_empty():
		kitchen_ai_dishes = t_kitchen_dishes
		pulled = true
	if pulled:
		save_game()

func save_game() -> void:
	var data := {
		"plants": plants,
		"travel_places": travel_places,
		"postcards": postcards,
		"garden_messages": garden_messages,
		"kitchen_orders_done": kitchen_orders_done,
		"kitchen_ai_dishes": kitchen_ai_dishes,
		"farm_activity_log": farm_activity_log,
		"farm_plots": farm_plots,
		"farm_livestock": farm_livestock,
		"opening_seen": opening_seen,
		"onboarding_guide_seen": onboarding_guide_seen,
		"chapter1_tasks": chapter1_tasks,
		"memory_cards": memory_cards,
		"memories": memories,
		"nodes": nodes,
		"answers": answers,
		"rooms": rooms,
		"room_objects": room_objects,
		"ai_sync_outbox": ai_sync_outbox,
		"cross_member_interaction_count": cross_member_interaction_count,
		"cross_member_pairs": cross_member_pairs,
		"family_portrait": family_portrait,
		"mailbox_has_unread": mailbox_has_unread,
		"mailbox_alert_state": mailbox_alert_state,
		"selected_role_key": selected_role_key,
		"player_display_name": player_display_name,
		"character_appearance": character_appearance,
		"last_scene_id": last_scene_id,
		"last_spawn_key": last_spawn_key,
		"last_player_position": last_player_position,
		"last_saved_at": last_saved_at
	}
	var file := FileAccess.open(_save_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_save() -> void:
	if not FileAccess.file_exists(_save_path()):
		_reset_all()
		return
	var file := FileAccess.open(_save_path(), FileAccess.READ)
	if not file:
		_reset_all()
		return
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		plants = parsed.get("plants", [])
		travel_places = parsed.get("travel_places", [])
		postcards = parsed.get("postcards", [])
		garden_messages = parsed.get("garden_messages", [])
		kitchen_orders_done = parsed.get("kitchen_orders_done", [])
		kitchen_ai_dishes = parsed.get("kitchen_ai_dishes", [])
		farm_activity_log = parsed.get("farm_activity_log", [])
		farm_plots = parsed.get("farm_plots", [])
		farm_livestock = parsed.get("farm_livestock", {})
		opening_seen = bool(parsed.get("opening_seen", false))
		onboarding_guide_seen = bool(parsed.get("onboarding_guide_seen", false))
		chapter1_tasks = parsed.get("chapter1_tasks", {})
		memory_cards = parsed.get("memory_cards", [])
		memories = parsed.get("memories", [])
		nodes = parsed.get("nodes", [])
		answers = parsed.get("answers", [])
		rooms = parsed.get("rooms", [])
		room_objects = parsed.get("room_objects", [])
		ai_sync_outbox = parsed.get("ai_sync_outbox", [])
		cross_member_interaction_count = int(parsed.get("cross_member_interaction_count", 0))
		cross_member_pairs = parsed.get("cross_member_pairs", [])
		family_portrait = parsed.get("family_portrait", {"version": 0, "member_count": 0, "memory_count": 0, "last_threshold": 0, "members": []})
		if parsed.has("mailbox_alert_state"):
			mailbox_alert_state = normalize_mailbox_alert(str(parsed.get("mailbox_alert_state", MAILBOX_ALERT_NONE)))
		else:
			var legacy_unread := bool(parsed.get("mailbox_has_unread", true))
			mailbox_alert_state = MAILBOX_ALERT_LETTER if legacy_unread and count_unread_postcards() > 0 else (MAILBOX_ALERT_DOT if legacy_unread else MAILBOX_ALERT_NONE)
		mailbox_has_unread = mailbox_alert_state != MAILBOX_ALERT_NONE
		selected_role_key = str(parsed.get("selected_role_key", ""))
		player_display_name = str(parsed.get("player_display_name", ""))
		var parsed_appearance: Variant = parsed.get("character_appearance", {})
		character_appearance = parsed_appearance if parsed_appearance is Dictionary else {}
		last_scene_id = str(parsed.get("last_scene_id", ""))
		last_spawn_key = str(parsed.get("last_spawn_key", "default"))
		var parsed_pos: Variant = parsed.get("last_player_position", {})
		last_player_position = parsed_pos if parsed_pos is Dictionary else {}
		last_saved_at = str(parsed.get("last_saved_at", ""))
	else:
		_reset_all()

func _save_path() -> String:
	return TEST_SAVE_PATH if OS.has_environment("FAMILY_GARDEN_TEST") else SAVE_PATH

func find_place(place_id: String) -> Dictionary:
	for place in travel_places:
		if str(place.get("id", "")) == place_id:
			return place
	return {}

func find_postcard(postcard_id: String) -> Dictionary:
	for postcard in postcards:
		if postcard is Dictionary and str(postcard.get("id", "")) == postcard_id:
			return postcard
	return {}

func find_postcard_by_place(place_id: String) -> Dictionary:
	for postcard in postcards:
		if str(postcard.get("place_id", "")) == place_id:
			return postcard
	return {}

func count_unread_postcards() -> int:
	var count := 0
	for postcard in postcards:
		if bool(postcard.get("is_new", false)):
			count += 1
	return count

func mark_postcards_read(save_after_change: bool = true) -> void:
	var changed := false
	for postcard in postcards:
		if bool(postcard.get("is_new", false)):
			postcard["is_new"] = false
			changed = true
	if changed:
		for postcard in postcards:
			_sync("postcards", postcard)
		clear_mailbox_alert()
		if save_after_change:
			save_game()
