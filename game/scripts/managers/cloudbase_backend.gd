class_name CloudBaseBackend
extends Node

## CloudBase 持久化后端,注入 CloudService 的接缝(persist_record/load_table/delete_record)。
##
## Godot 原生用 HTTP(见 docs/43):本类通过 HTTPS 调一个 CloudBase 云函数 data_gateway
## (源码 backend/cloudbase/data_gateway/),由它对云数据库做 CRUD。
##
## 鉴权:每用户身份(见 docs/45 §5)。客户端发自己的 member_token,
## 服务端据此解析 {family_id, member_id, role},**body 里不再需要/不被信任 family_id**。
##
## 读路径约束:CloudService.load_table 是同步的(pull_remote 同步调),所以本类用
## 「本地镜像缓存」——load_table 同步返回缓存,bootstrap()/refresh() 异步把云端拉进缓存。
## 写路径:persist_record/delete_record 走 fire-and-forget HTTP,同时乐观更新缓存。
##
## 未配置(endpoint 或 member_token 缺一)→ 全部安全降级:写 no-op、读空 → 等同纯本地。

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
	# 需同时有 endpoint 和本人的 member_token;缺一则保持离线(不发无鉴权请求)
	var c := load_config()
	return str(c.get("endpoint", "")) != "" and str(c.get("member_token", "")) != ""

func _init() -> void:
	_cfg = load_config()

# ── 接缝实现(family_id 不再需要:服务端从 member_token 解析) ─
func persist_record(table: String, row: Dictionary) -> void:
	# 乐观更新缓存(按 id upsert),再异步推云
	_cache_upsert(table, row)
	_post({"action": "upsert", "table": table, "row": row})

func delete_record(table: String, row_id: String) -> void:
	if _cache.has(table):
		_cache[table] = (_cache[table] as Array).filter(func(r): return str(r.get("id", "")) != row_id)
	_post({"action": "delete", "table": table, "id": row_id})

func load_table(table: String, _query: String = "") -> Array:
	return (_cache.get(table, []) as Array).duplicate(true)

# ── 启动预拉(异步) ───────────────────────────────────
## 注入后调一次:whoami → 拉云端各表进缓存 → 触发各系统同步读取 → 最后才广播身份就绪。
##
## 关键顺序:GameIdentity.set_identity() 特意放在**最后一步**,而不是 whoami 一拿到结果
## 就立刻设置。这样任何代码只要看到 GameIdentity.is_ready()==true,就能保证背包/共享仓等
## 数据也已经是云端最新状态——不存在“身份先就绪、数据还在路上”的窗口期。
## (曾复现的真实竞态:若身份先就绪,玩家这时的操作可能被随后才落地的旧快照悄悄覆盖。)
func bootstrap() -> void:
	var who: Dictionary = await _request({"action": "whoami"})
	if not bool(who.get("ok", false)):
		push_warning("[CloudBase] whoami 失败,member_token 可能无效")
		return
	await refresh()
	var mem := get_node_or_null("/root/MemoryManager")
	if mem != null and mem.has_method("pull_remote"):
		mem.pull_remote()
	var inv := get_node_or_null("/root/InventoryManager")
	if inv != null and inv.has_method("sync_from_cloud"):
		inv.sync_from_cloud()
	var identity := get_node_or_null("/root/GameIdentity")
	if identity != null:
		identity.set_identity(
			str(who.get("member_id", "")),
			str(who.get("family_id", "")),
			str(who.get("role", "")),
			str(who.get("display_name", "")))

func refresh() -> void:
	var res: Dictionary = await _request({"action": "snapshot", "tables": SNAPSHOT_TABLES})
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
	# 本人的成员令牌:服务端据此解析身份(family_id/member_id/role),不信 body
	var token := str(_cfg.get("member_token", ""))
	if token != "":
		headers.append("Authorization: Bearer " + token)
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
