class_name CloudBaseBackend
extends Node

## CloudBase 持久化后端,注入 CloudService 的接缝(persist_record/load_table/delete_record)。
##
## Godot 原生用 HTTP(见 docs/43):本类通过 HTTPS 调一个 CloudBase 云函数 data_gateway
## (源码 backend/cloudbase/data_gateway/),由它对云数据库做 CRUD。
##
## 读路径约束:CloudService.load_table 是同步的(pull_remote 同步调),所以本类用
## 「本地镜像缓存」——load_table 同步返回缓存,bootstrap()/refresh() 异步把云端拉进缓存。
## 写路径:persist_record/delete_record 走 fire-and-forget HTTP,同时乐观更新缓存。
##
## 未配置(endpoint 空)→ 全部安全降级:写 no-op、读空 → 等同当前纯本地。

const CONFIG_PATH := "res://config/cloudbase.json"
## bootstrap 时要从云端预拉进缓存的表(供 MemoryManager.pull_remote 同步读)。
const SNAPSHOT_TABLES := ["memories", "nodes", "answers", "rooms", "room_objects", "families", "inventories"]

var _cfg: Dictionary = {}
var _cache: Dictionary = {}   ## table -> Array[Dictionary]

# ── 配置(静态) ───────────────────────────────────────
static func load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var p: Variant = JSON.parse_string(f.get_as_text())
	return p if p is Dictionary else {}

static func is_configured() -> bool:
	# 需同时有 endpoint 和家庭访问密钥;缺一则保持离线(不发无鉴权请求)
	var c := load_config()
	return str(c.get("endpoint", "")) != "" and str(c.get("access_key", "")) != ""

func _init() -> void:
	_cfg = load_config()

func family_id() -> String:
	return str(_cfg.get("family_id", ""))

# ── 接缝实现 ─────────────────────────────────────────
func persist_record(table: String, row: Dictionary) -> void:
	# 乐观更新缓存(按 id upsert),再异步推云
	_cache_upsert(table, row)
	_post({"action": "upsert", "table": table, "row": row, "family_id": family_id()})

func delete_record(table: String, row_id: String) -> void:
	if _cache.has(table):
		_cache[table] = (_cache[table] as Array).filter(func(r): return str(r.get("id", "")) != row_id)
	_post({"action": "delete", "table": table, "id": row_id, "family_id": family_id()})

func load_table(table: String, _query: String = "") -> Array:
	return (_cache.get(table, []) as Array).duplicate(true)

# ── 启动预拉(异步) ───────────────────────────────────
## 注入后调一次:把云端各表拉进缓存,再让 MemoryManager 同步读取。
func bootstrap() -> void:
	await refresh()
	var mem := get_node_or_null("/root/MemoryManager")
	if mem != null and mem.has_method("pull_remote"):
		mem.pull_remote()
	var inv := get_node_or_null("/root/InventoryManager")
	if inv != null and inv.has_method("sync_from_cloud"):
		inv.sync_from_cloud()

func refresh() -> void:
	var res: Dictionary = await _request({"action": "snapshot", "tables": SNAPSHOT_TABLES, "family_id": family_id()})
	var tables: Variant = res.get("tables", {})
	if tables is Dictionary:
		for t in tables:
			if tables[t] is Array:
				_cache[t] = tables[t]

# ── HTTP ─────────────────────────────────────────────
func _post(body: Dictionary) -> void:
	# fire-and-forget:不关心返回
	_request(body)

func _request(body: Dictionary) -> Dictionary:
	var endpoint := str(_cfg.get("endpoint", ""))
	if endpoint == "":
		return {}
	var req := HTTPRequest.new()
	add_child(req)
	var headers := ["Content-Type: application/json"]
	# 家庭访问密钥:服务端用它解析 family_id(绝不信 body 里的 family_id)
	var key := str(_cfg.get("access_key", ""))
	if key != "":
		headers.append("Authorization: Bearer " + key)
	var err := req.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		req.queue_free()
		return {}
	var result: Array = await req.request_completed
	req.queue_free()
	var code: int = result[1]
	var bytes: PackedByteArray = result[3]
	if code < 200 or code >= 300:
		push_warning("[CloudBase] %s 失败 code=%d" % [body.get("action", "?"), code])
		return {}
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}

func _cache_upsert(table: String, row: Dictionary) -> void:
	var arr: Array = _cache.get(table, [])
	var rid := str(row.get("id", ""))
	if rid != "":
		for i in arr.size():
			if str(arr[i].get("id", "")) == rid:
				arr[i] = row
				_cache[table] = arr
				return
	arr.append(row)
	_cache[table] = arr
