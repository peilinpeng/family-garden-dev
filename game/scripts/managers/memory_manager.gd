extends Node

## Family Garden 记忆/数据层（autoload 单例）。
## 拥有：家庭数据模型 + 本地存档 + 云数据落地 + 查询 + 邮箱告警状态。
## 不持有任何场景/UI 节点；UI 通过 mailbox_alert_changed 信号刷新邮箱徽标。
## 从 main.gd 拆出，逻辑保持不变（增量 2 / feature/c-foundation）。

signal mailbox_alert_changed(state: String)

const SAVE_PATH := "user://family_garden_save_v2.json"

const MAILBOX_ALERT_NONE := "none"
const MAILBOX_ALERT_DOT := "dot"
const MAILBOX_ALERT_LETTER := "letter"

var plants: Array = []
var travel_places: Array = []
var postcards: Array = []
var garden_messages: Array = []
var mailbox_has_unread := true # legacy compatibility; true means mailbox_alert_state != none
var mailbox_alert_state: String = MAILBOX_ALERT_DOT
var selected_role_key: String = ""
var player_display_name: String = ""

func apply_cloud_data(data: Dictionary) -> void:
	var remote_places: Array = data.get("travel_places", [])
	var remote_postcards: Array = data.get("postcards", [])
	var remote_messages: Array = data.get("messages", [])
	var remote_events: Array = data.get("mailbox_events", [])

	var has_remote_content: bool = remote_places.size() > 0 or remote_postcards.size() > 0 or remote_messages.size() > 0

	if has_remote_content:
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
					"title": str(row.get("title", "New postcard")),
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

func clear_mailbox_alert() -> void:
	set_mailbox_alert(MAILBOX_ALERT_NONE)

func save_game() -> void:
	var data := {
		"plants": plants,
		"travel_places": travel_places,
		"postcards": postcards,
		"garden_messages": garden_messages,
		"mailbox_has_unread": mailbox_has_unread,
		"mailbox_alert_state": mailbox_alert_state,
		"selected_role_key": selected_role_key,
		"player_display_name": player_display_name
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		plants = []
		travel_places = []
		postcards = []
		garden_messages = []
		mailbox_alert_state = MAILBOX_ALERT_DOT
		mailbox_has_unread = mailbox_alert_state != MAILBOX_ALERT_NONE
		selected_role_key = ""
		player_display_name = ""
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		plants = []
		travel_places = []
		postcards = []
		garden_messages = []
		mailbox_alert_state = MAILBOX_ALERT_DOT
		mailbox_has_unread = mailbox_alert_state != MAILBOX_ALERT_NONE
		selected_role_key = ""
		player_display_name = ""
		return
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		plants = parsed.get("plants", [])
		travel_places = parsed.get("travel_places", [])
		postcards = parsed.get("postcards", [])
		garden_messages = parsed.get("garden_messages", [])
		if parsed.has("mailbox_alert_state"):
			mailbox_alert_state = normalize_mailbox_alert(str(parsed.get("mailbox_alert_state", MAILBOX_ALERT_NONE)))
		else:
			var legacy_unread := bool(parsed.get("mailbox_has_unread", true))
			mailbox_alert_state = MAILBOX_ALERT_LETTER if legacy_unread and count_unread_postcards() > 0 else (MAILBOX_ALERT_DOT if legacy_unread else MAILBOX_ALERT_NONE)
		mailbox_has_unread = mailbox_alert_state != MAILBOX_ALERT_NONE
		selected_role_key = str(parsed.get("selected_role_key", ""))
		player_display_name = str(parsed.get("player_display_name", ""))
	else:
		plants = []
		travel_places = []
		postcards = []
		garden_messages = []
		mailbox_alert_state = MAILBOX_ALERT_DOT
		mailbox_has_unread = mailbox_alert_state != MAILBOX_ALERT_NONE
		selected_role_key = ""
		player_display_name = ""

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
		clear_mailbox_alert()
		if save_after_change:
			save_game()
