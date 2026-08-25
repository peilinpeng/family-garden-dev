extends Node

## Gate 6 实时在场通道。Godot 用 WebSocketPeer 连 CloudBase 云托管的 presence_relay。
## 这里只同步瞬时位置和在线状态，不落库；持久数据仍走 CloudManager/data_gateway。

signal status_changed(status: String)
signal peer_joined(peer: Dictionary)
signal peer_moved(peer: Dictionary)
signal peer_left(member_id: String)
signal peer_snapshot(peers: Array)
signal world_changed(event: Dictionary)

const CONFIG_PATH := "res://config/cloudbase.json"
const SEND_INTERVAL := 0.12
const MIN_MOVE_DISTANCE := 4.0
const PEER_TIMEOUT := 12.0

var _ws := WebSocketPeer.new()
var _status := "offline"
var _scene_id := ""
var _player: Node2D
var _send_timer := 0.0
var _reconnect_timer := 0.0
var _reconnect_delay := 1.0
var _sequence := 0
var _last_sent_position := Vector2(INF, INF)
var _last_sent_direction := "down"
var _last_sent_animation := "idle"
var _want_connected := false
var _hello_sent := false
var _peers: Dictionary = {}  ## member_id -> Dictionary
var _world_event_sequence := 0
var _recent_world_events: Dictionary = {}  ## event_id -> local msec

func _ready() -> void:
	set_process(true)

func is_configured() -> bool:
	return _presence_endpoint() != ""

func status() -> String:
	return _status

func peers() -> Array:
	return _peers.values()

func announce_world_changed(table: String, row_id: String, action: String = "upsert") -> void:
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN or _status != "online":
		return
	_world_event_sequence += 1
	var event_id := "%s:%d:%d" % [
		GameIdentity.member_id,
		Time.get_ticks_msec(),
		_world_event_sequence,
	]
	_send({
		"type": "world_changed",
		"table": table,
		"id": row_id,
		"action": action,
		"timestamp": Time.get_ticks_msec(),
		"event_id": event_id,
	})

func enter_scene(scene_id: String, player: Node2D) -> void:
	_scene_id = scene_id
	_player = player
	_want_connected = true
	_peers.clear()
	peer_snapshot.emit([])
	_try_connect()

func leave_scene(scene_id: String = "") -> void:
	if scene_id != "" and scene_id != _scene_id:
		return
	_want_connected = false
	_scene_id = ""
	_player = null
	_peers.clear()
	peer_snapshot.emit([])
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send({"type": "leave"})
	_ws.close()
	_set_status("offline")

func _process(delta: float) -> void:
	_ws.poll()
	_drain_messages()
	_expire_stale_peers()
	var state := _ws.get_ready_state()
	if _want_connected and is_configured() and GameIdentity.is_ready():
		if state == WebSocketPeer.STATE_CLOSED:
			_reconnect_timer -= delta
			if _reconnect_timer <= 0.0:
				_try_connect()
		elif state == WebSocketPeer.STATE_OPEN:
			if _status != "online":
				_send_hello()
			_send_timer -= delta
			if _send_timer <= 0.0:
				_send_timer = SEND_INTERVAL
				_maybe_send_move()
	elif state == WebSocketPeer.STATE_OPEN or state == WebSocketPeer.STATE_CONNECTING:
		_ws.close()

func _try_connect() -> void:
	if not _want_connected:
		return
	if not is_configured():
		_set_status("disabled")
		return
	if not GameIdentity.is_ready():
		_set_status("waiting_identity")
		if not GameIdentity.identity_ready.is_connected(_on_identity_ready):
			GameIdentity.identity_ready.connect(_on_identity_ready)
		return
	if _ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING or _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		return
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(_presence_endpoint())
	if err != OK:
		_schedule_reconnect()
		return
	_hello_sent = false
	_set_status("connecting")

func _on_identity_ready() -> void:
	if _want_connected:
		_try_connect()

func _send_hello() -> void:
	if _hello_sent:
		return
	var token := str(CloudBaseBackend.load_identity().get("member_token", ""))
	if token == "":
		_set_status("waiting_identity")
		return
	_send({
		"type": "hello",
		"token": token,
		"scene_id": _scene_id,
		"appearance": MemoryManager.character_appearance.duplicate(true) if MemoryManager != null else {},
	})
	_hello_sent = true

func _maybe_send_move() -> void:
	if _player == null or _scene_id == "":
		return
	var pos := _player.global_position
	var direction := _player_direction()
	var animation_state := _player_animation_state()
	var changed := pos.distance_to(_last_sent_position) >= MIN_MOVE_DISTANCE \
		or direction != _last_sent_direction \
		or animation_state != _last_sent_animation
	if not changed:
		return
	_sequence += 1
	_last_sent_position = pos
	_last_sent_direction = direction
	_last_sent_animation = animation_state
	_send({
		"type": "move",
		"scene_id": _scene_id,
		"position": {"x": pos.x, "y": pos.y},
		"direction": direction,
		"animation_state": animation_state,
		"timestamp": Time.get_ticks_msec(),
		"sequence": _sequence,
	})

func _drain_messages() -> void:
	while _ws.get_available_packet_count() > 0:
		var parsed: Variant = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
		if parsed is Dictionary:
			_handle_message(parsed)
	var state := _ws.get_ready_state()
	if _want_connected and (state == WebSocketPeer.STATE_CLOSED or state == WebSocketPeer.STATE_CLOSING) and _status == "online":
		_schedule_reconnect()

func _handle_message(msg: Dictionary) -> void:
	var msg_type := str(msg.get("type", ""))
	match msg_type:
		"hello_ok":
			_set_status("online")
			_reconnect_delay = 1.0
			var peers: Array = msg.get("peers", [])
			_peers.clear()
			for peer in peers:
				if peer is Dictionary:
					_upsert_peer(peer, false)
			peer_snapshot.emit(_peers.values())
		"peer_joined":
			var peer: Dictionary = msg.get("peer", {})
			_upsert_peer(peer, true)
		"peer_moved":
			var peer: Dictionary = msg.get("peer", {})
			if _upsert_peer(peer, false):
				peer_moved.emit(_peers[str(peer.get("member_id", ""))])
		"peer_left":
			var member_id := str(msg.get("member_id", ""))
			if _peers.erase(member_id):
				peer_left.emit(member_id)
		"world_changed":
			var raw_event: Variant = msg.get("event", {})
			if raw_event is Dictionary:
				_handle_world_changed(raw_event)
		"world_changed_ack":
			pass
		"error":
			_schedule_reconnect()

func _handle_world_changed(event: Dictionary) -> void:
	if event.is_empty():
		return
	if str(event.get("member_id", "")) == GameIdentity.member_id:
		return
	var event_id := str(event.get("event_id", ""))
	if event_id != "":
		if _recent_world_events.has(event_id):
			return
		_recent_world_events[event_id] = Time.get_ticks_msec()
	_trim_recent_world_events()
	world_changed.emit(event)

func _trim_recent_world_events() -> void:
	if _recent_world_events.size() <= 80:
		return
	var cutoff := Time.get_ticks_msec() - 120000
	for event_id in _recent_world_events.keys():
		if int(_recent_world_events[event_id]) < cutoff:
			_recent_world_events.erase(event_id)

func _upsert_peer(peer: Dictionary, emit_join: bool) -> bool:
	var member_id := str(peer.get("member_id", ""))
	if member_id == "" or member_id == GameIdentity.member_id:
		return false
	var existing: Dictionary = _peers.get(member_id, {})
	var sequence := int(peer.get("sequence", 0))
	if existing.has("sequence") and sequence < int(existing.get("sequence", 0)):
		return false
	peer["last_seen_local_msec"] = Time.get_ticks_msec()
	_peers[member_id] = peer
	if emit_join:
		peer_joined.emit(peer)
	return true

func _expire_stale_peers() -> void:
	var now := Time.get_ticks_msec()
	var expired: Array[String] = []
	for member_id in _peers:
		var peer: Dictionary = _peers[member_id]
		if now - int(peer.get("last_seen_local_msec", now)) > int(PEER_TIMEOUT * 1000.0):
			expired.append(str(member_id))
	for member_id in expired:
		_peers.erase(member_id)
		peer_left.emit(member_id)

func _schedule_reconnect() -> void:
	_ws.close()
	_hello_sent = false
	_set_status("reconnecting")
	_reconnect_timer = _reconnect_delay
	_reconnect_delay = minf(_reconnect_delay * 1.8, 12.0)

func _send(data: Dictionary) -> void:
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_ws.send_text(JSON.stringify(data))

func _set_status(next: String) -> void:
	if _status == next:
		return
	_status = next
	status_changed.emit(_status)

func _presence_endpoint() -> String:
	if not FileAccess.file_exists(CONFIG_PATH):
		return ""
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return ""
	return str(parsed.get("presence_endpoint", "")).strip_edges()

func _player_direction() -> String:
	var row := int(_player.get("facing_row") if _player != null else 0)
	match row:
		1:
			return "left"
		2:
			return "right"
		3:
			return "up"
		_:
			return "down"

func _player_animation_state() -> String:
	if _player == null:
		return "idle"
	var velocity: Variant = _player.get("velocity")
	if velocity is Vector2 and velocity.length() > 6.0:
		return "walk"
	return "idle"
