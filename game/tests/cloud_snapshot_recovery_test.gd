extends Node

class FakeBackend:
	extends CloudBaseBackend
	var response: Dictionary = {}

	func _init() -> void:
		_cfg = {"member_token": "isolated-test-token"}

	func _request(body: Dictionary) -> Dictionary:
		if body.get("action") == "whoami":
			return {"ok": true, "member_id": "test-member", "family_id": "test-family", "role": "player", "display_name": "测试"}
		return response.duplicate(true)

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _snapshot() -> Dictionary:
	var tables := {}
	var statuses := {}
	for table in CloudBaseBackend.SNAPSHOT_TABLES:
		tables[table] = []
		statuses[table] = {"ok": true}
	return {"ok": true, "tables": tables, "table_status": statuses}

func _run() -> void:
	await get_tree().process_frame
	var backend := FakeBackend.new()
	add_child(backend)
	CloudManager.set_persistence_backend(backend)
	GameIdentity.member_id = ""
	MemoryManager.memories = [{"id": "local-memory", "title": "本机记录"}]
	backend.response = {"ok": false, "code": 503}
	_assert(not await backend.bootstrap(), "首次快照失败不能宣告启动成功")
	_assert(not GameIdentity.is_ready(), "首次读取失败不得广播身份就绪")
	MemoryManager.pull_remote()
	_assert(MemoryManager.memories.size() == 1, "空缓存不能清空尚未同步的本机记录")

	backend.response = _snapshot()
	backend.response.tables.memories = [{"id": "cloud-memory", "title": "已同步记录"}]
	_assert(await backend.bootstrap(), "完整快照应完成启动")
	_assert(GameIdentity.is_ready(), "有效快照后身份才就绪")
	_assert(MemoryManager.memories[0].id == "cloud-memory", "有效快照应进入本地数据")

	var invalid_snapshots: Array = [
		{"ok": false, "tables": {"memories": []}},
		{"ok": true, "tables": {"memories": []}},
		{"ok": true, "tables": []},
	]
	var wrong_type := _snapshot()
	wrong_type.tables.answers = {}
	invalid_snapshots.append(wrong_type)
	var wrong_row := _snapshot()
	wrong_row.tables.memories = ["invalid"]
	invalid_snapshots.append(wrong_row)
	var failed_status := _snapshot()
	failed_status.table_status.memories = {"ok": false}
	invalid_snapshots.append(failed_status)
	for candidate in invalid_snapshots:
		backend.response = candidate
		_assert(not await backend.refresh(), "失败或不完整的快照必须整体拒绝")
		MemoryManager.pull_remote()
		_assert(MemoryManager.memories.size() == 1 and MemoryManager.memories[0].id == "cloud-memory", "拒绝快照后保持最后可信记忆")

	# 成功且确实为空必须生效，不能以保护失败为由让删除永不传播。
	backend.response = _snapshot()
	_assert(await backend.refresh(), "成功空快照应可应用")
	MemoryManager.pull_remote()
	_assert(MemoryManager.memories.is_empty(), "确认成功的空表可以清空本地镜像")
	CloudManager.set_persistence_backend(null)
	backend.queue_free()
	if failures.is_empty():
		print("PASS cloud_snapshot_recovery_test")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
