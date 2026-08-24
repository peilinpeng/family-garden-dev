class_name CloudBaseBackend
extends Node

## CloudBase 持久化后端,注入 CloudService 的接缝(persist_record/load_table/delete_record)。
##
## Godot 原生用 HTTP(见 docs/43):本类通过 HTTPS 调一个 CloudBase 云函数 data_gateway
## (源码 backend/cloudbase/data_gateway/),由它对云数据库做 CRUD。
##
## 鉴权:每用户身份(见 docs/45 §5/§9)。两类配置分开存,原因不同:
## - endpoint / family_id:项目级、非密钥,存 res://config/cloudbase.json(**可提交进 git**)。
## - member_token:个人凭证,是密钥,**绝不进 git**——自助加入(join_family)时服务端生成,
##   存在 res://config/cloudbase.json(**永远不提交这个字段/永远留空占位**)之外的
##   user://cloud_identity.json 里,天然只存在于这台设备本地。
##
## 首次进入(没有本地 member_token):is_configured()==true 但 has_identity()==false,
## 此时不会自动 bootstrap;由玩家在选角色界面选完角色/起完昵称的那一刻,
## CloudService.ensure_cloud_identity() 调 join_family() 自助注册、拿到令牌、存本地,
## 然后才 bootstrap()。之后每次启动 has_identity()==true,直接照常同步,无需再选。
##
## 读路径约束:CloudService.load_table 是同步的(pull_remote 同步调),所以本类用
## 「本地镜像缓存」——load_table 同步返回缓存,bootstrap()/refresh() 异步把云端拉进缓存。
## 写路径:persist_record/delete_record 走 fire-and-forget HTTP,同时乐观更新缓存。

const CONFIG_PATH := "res://config/cloudbase.json"      ## 项目级,可提交:endpoint / family_id
const IDENTITY_PATH := "user://cloud_identity.json"      ## 设备级,不提交:member_token
const REQUEST_TIMEOUT_SECONDS := 30.0
## bootstrap 时要从云端预拉进缓存的表(供 MemoryManager.pull_remote 同步读)。
const SNAPSHOT_TABLES := [
	"memories", "nodes", "answers", "rooms", "room_objects", "families", "inventories",
	"travel_places", "postcards", "messages", "mailbox_events", "farm_plots", "farm_activity_log",
	"farm_livestock", "kitchen_dishes",
]

var _cfg: Dictionary = {}

var _cache: Dictionary = {}   ## table -> Array[Dictionary]

# ── 配置(静态) ───────────────────────────────────────
static func load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var p: Variant = JSON.parse_string(f.get_as_text())
	return p if p is Dictionary else {}

static func load_identity() -> Dictionary:
	if not FileAccess.file_exists(IDENTITY_PATH):
		return {}
	var f := FileAccess.open(IDENTITY_PATH, FileAccess.READ)
	var p: Variant = JSON.parse_string(f.get_as_text())
	return p if p is Dictionary else {}

## 只要求 endpoint 非空——member_token 缺失是正常的"还没自助加入"状态,不代表离线。
static func is_configured() -> bool:
	return str(load_config().get("endpoint", "")) != ""

func _init() -> void:
	_cfg = load_config()
	var identity := load_identity()
	if identity.has("member_token"):
		_cfg["member_token"] = identity["member_token"]

## 本设备是否已经自助加入过(有自己的令牌)。
func has_identity() -> bool:
	return str(_cfg.get("member_token", "")) != ""

func family_id() -> String:
	return str(_cfg.get("family_id", ""))

# ── 自助加入(首次选角色时调用一次) ───────────────────
## 无需已有令牌:传家庭 id + 选的角色 + 起的昵称,服务端随机生成一个新令牌并建档。
## 成功后把令牌存进 user://(此设备专属,永不提交),之后 has_identity() 变 true。
func join_family(fam_id: String, role: String, display_name: String) -> bool:
	var res: Dictionary = await _request({
		"action": "join_family",
		"family_id": fam_id,
		"role": role,
		"display_name": display_name,
	})
	if not bool(res.get("ok", false)):
		push_warning("[CloudBase] join_family 失败: " + str(res.get("error", "")))
		return false
	var token := str(res.get("member_token", ""))
	if token == "":
		return false
	_cfg["member_token"] = token
	_cfg["family_id"] = fam_id
	var f := FileAccess.open(IDENTITY_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"member_token": token}))
	return true

func list_family_members() -> Array:
	var res: Dictionary = await _request({"action": "list_family_members"})
	if not bool(res.get("ok", false)):
		return []
	var members: Variant = res.get("members", [])
	return members if members is Array else []

# ── 接缝实现(family_id 不再需要:服务端从 member_token 解析) ─
func persist_record(table: String, row: Dictionary) -> void:
	# 乐观更新缓存(按 id upsert),再异步推云
	_cache_upsert(table, row)
	_post({"action": "upsert", "table": table, "row": row})

func persist_record_confirmed(table: String, row: Dictionary) -> Dictionary:
	var res: Dictionary = await _request({"action": "upsert", "table": table, "row": row})
	if bool(res.get("ok", false)):
		var cached := row.duplicate(true)
		if str(res.get("id", "")) != "":
			cached["id"] = str(res.get("id", ""))
		_cache_upsert(table, cached)
	return res

func delete_record(table: String, row_id: String) -> void:
	if _cache.has(table):
		_cache[table] = (_cache[table] as Array).filter(func(r): return str(r.get("id", "")) != row_id)
	_post({"action": "delete", "table": table, "id": row_id})

func delete_record_confirmed(table: String, row_id: String) -> Dictionary:
	var res: Dictionary = await _request({"action": "delete", "table": table, "id": row_id})
	if String(res.get("error", "")) == "not found":
		res = {"ok": true, "already_deleted": true}
	if bool(res.get("ok", false)) and _cache.has(table):
		_cache[table] = (_cache[table] as Array).filter(func(r): return str(r.get("id", "")) != row_id)
	return res

func mutate_storehouse(consumes: Array, grants: Array, operation_id: String) -> Dictionary:
	var res: Dictionary = await _request({
		"action": "mutate_storehouse",
		"operation_id": operation_id,
		"consumes": consumes,
		"grants": grants,
	})
	if res.has("stacks"):
		_cache_inventory_result("storehouse", res)
	return res

func perform_farm_action(action: String, payload: Dictionary, operation_id: String) -> Dictionary:
	var body := payload.duplicate(true)
	body["action"] = "farm_action"
	body["farm_action"] = action
	body["operation_id"] = operation_id
	var res: Dictionary = await _request(body)
	if not bool(res.get("ok", false)):
		return res
	if res.get("storehouse", null) is Dictionary:
		_cache_upsert("inventories", res["storehouse"])
	if res.get("backpack", null) is Dictionary:
		_cache_upsert("inventories", res["backpack"])
	if res.get("plot", null) is Dictionary and not (res["plot"] as Dictionary).is_empty():
		_cache_upsert("farm_plots", res["plot"])
	var deleted_plot_id := str(res.get("deleted_plot_id", ""))
	if deleted_plot_id != "" and _cache.has("farm_plots"):
		_cache["farm_plots"] = (_cache["farm_plots"] as Array).filter(
			func(row): return str(row.get("id", row.get("_id", ""))) != deleted_plot_id
		)
	if res.get("livestock", null) is Dictionary:
		_cache_upsert("farm_livestock", res["livestock"])
	return res

## 私有图片通道：原始字节只发给 data_gateway；返回的 upload_id 可持久化，
## 临时 image_url 只用于本次展示或 AI 调用，不应当作永久地址写入业务数据。
func upload_image(bytes: PackedByteArray, content_type: String, purpose: String = "ai") -> Dictionary:
	if bytes.is_empty():
		return {"ok": false, "error": "empty image"}
	return await _request({
		"action": "upload_image",
		"content_type": content_type,
		"base64_data": Marshalls.raw_to_base64(bytes),
		"purpose": purpose,
	})

func resolve_image(upload_id: String) -> Dictionary:
	return await _request({"action": "resolve_image", "upload_id": upload_id})

func delete_image(upload_id: String) -> bool:
	var result: Dictionary = await _request({"action": "delete_image", "upload_id": upload_id})
	return bool(result.get("ok", false)) or int(result.get("code", 0)) == 404

func delete_place_bundle(place_id: String) -> Dictionary:
	var result: Dictionary = await _request({
		"action": "delete_place_bundle",
		"place_id": place_id,
	})
	if not bool(result.get("ok", false)):
		return result
	if _cache.has("travel_places"):
		_cache["travel_places"] = (_cache["travel_places"] as Array).filter(
			func(row): return str(row.get("id", row.get("_id", ""))) != place_id
		)
	var postcard_ids: Array = result.get("postcard_ids", [])
	if _cache.has("postcards"):
		_cache["postcards"] = (_cache["postcards"] as Array).filter(
			func(row): return str(row.get("id", row.get("_id", ""))) not in postcard_ids
		)
	var event_ids: Array = result.get("event_ids", [])
	if _cache.has("mailbox_events"):
		_cache["mailbox_events"] = (_cache["mailbox_events"] as Array).filter(
			func(row): return str(row.get("id", row.get("_id", ""))) not in event_ids
		)
	return result

func load_table(table: String, _query: String = "") -> Array:
	return (_cache.get(table, []) as Array).duplicate(true)

# ── 启动预拉(异步) ───────────────────────────────────
## 只在 has_identity()==true 时调用(见 CloudService._ready / ensure_cloud_identity)。
## whoami → 拉云端各表进缓存 → 触发各系统同步读取 → 最后才广播身份就绪。
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

func cleanup_orphan_images() -> int:
	var result: Dictionary = await _request({"action": "cleanup_orphan_images"})
	return int(result.get("deleted", 0)) if bool(result.get("ok", false)) else 0

# ── HTTP ─────────────────────────────────────────────
func _post(body: Dictionary) -> void:
	# fire-and-forget:不关心返回
	_request(body)

func _request(body: Dictionary) -> Dictionary:
	var endpoint := str(_cfg.get("endpoint", ""))
	if endpoint == "":
		return {}
	var req := HTTPRequest.new()
	req.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(req)
	var headers := ["Content-Type: application/json"]
	# 本人的成员令牌:服务端据此解析身份(family_id/member_id/role),不信 body。
	# join_family 这个动作本身没有令牌(还没申请到),不带这个 header 也能调。
	var token := str(_cfg.get("member_token", ""))
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var err := req.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		req.queue_free()
		return {}
	var result: Array = await req.request_completed
	req.queue_free()
	var result_code: int = int(result[0])
	var code: int = result[1]
	var bytes: PackedByteArray = result[3]
	if result_code == HTTPRequest.RESULT_TIMEOUT:
		return {"ok": false, "error": "request timeout", "code": 504}
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "network request failed", "code": 503}
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if code < 200 or code >= 300:
		push_warning("[CloudBase] %s 失败 code=%d" % [body.get("action", "?"), code])
		return parsed if parsed is Dictionary else {"ok": false, "error": "http error", "code": code}
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

func _cache_inventory_result(kind: String, result: Dictionary) -> void:
	var row := {
		"id": str(result.get("id", kind)),
		"kind": kind,
		"stacks": (result.get("stacks", []) as Array).duplicate(true),
		"version": int(result.get("version", 0)),
	}
	_cache_upsert("inventories", row)
