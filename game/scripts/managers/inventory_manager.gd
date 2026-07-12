extends Node

## 库存管理(autoload InventoryManager)。
## - backpack:个人背包(按本人,私有)
## - storehouse:共享仓(家庭一份;联机时走 A 面校验+同步,见 docs/43)
## 本地持久化用独立存档(user://inventory_v1.json),后续可经 seam 接 CloudBase。

signal backpack_changed
signal storehouse_changed

const SAVE_PATH := "user://inventory_v1.json"
const BACKPACK_SLOTS := 24
const STOREHOUSE_SLOTS := 120

var backpack: Inventory
var storehouse: Inventory
## 加载/同步期间(本地文件读入、云端快照覆盖)为 true,此时 Inventory 的 changed
## 信号不触发上云推送——避免把“刚加载/尚未从云端同步”的数据推回云端,
## 覆盖掉家庭共享仓里其他成员的真实数据。见 docs/45 §7(bootstrap 竞态修复)。
var _loading := false

func _ready() -> void:
	backpack = Inventory.new(BACKPACK_SLOTS)
	storehouse = Inventory.new(STOREHOUSE_SLOTS)
	backpack.changed.connect(func():
		backpack_changed.emit()
		_save_local()
		if not _loading:
			_push_backpack())
	storehouse.changed.connect(func():
		storehouse_changed.emit()
		_save_local()
		if not _loading:
			_push_storehouse())
	_loading = true
	var had_local := load_inv()
	_loading = false
	if not had_local:
		_grant_starter_kit()

# ── 便捷 API ──────────────────────────────────────────
## 给玩家物品(默认进背包)。返回未放下的剩余。
func give(id: String, amount: int = 1, to_storehouse: bool = false) -> int:
	return (storehouse if to_storehouse else backpack).add(id, amount)

func take(id: String, amount: int = 1, from_storehouse: bool = false) -> int:
	return (storehouse if from_storehouse else backpack).remove(id, amount)

func has(id: String, amount: int = 1, in_storehouse: bool = false) -> bool:
	return (storehouse if in_storehouse else backpack).has(id, amount)

## 背包 → 共享仓
func deposit(id: String, amount: int) -> int:
	return backpack.move_to(storehouse, id, amount)

## 共享仓 → 背包
func withdraw(id: String, amount: int) -> int:
	return storehouse.move_to(backpack, id, amount)

# ── 持久化(本地优先 + 上云) ──────────────────────────
## 本地整体快照,纯本设备缓存,两者一起写没有风险(不影响其他设备/成员)。
func _save_local() -> void:
	if OS.has_environment("FAMILY_GARDEN_TEST"):
		return
	var data := {
		"backpack": backpack.to_array(),
		"storehouse": storehouse.to_array(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

## 上云必须按「谁改了推谁」分开推送:backpack 是本人独占数据,随时推送安全;
## storehouse 是家庭共享数据,只有在本地已从云端同步过(sync_from_cloud 完成)之后
## 才应该再把它推回去——否则会用本地尚未同步的旧/空数据覆盖别的成员刚存的东西
## (曾复现的真实 bug:_grant_starter_kit 时 storehouse 还是空的,若一起推送
## 会把家庭共享仓覆盖成空)。用 _loading 门槛 + 按来源分开推送彻底避免。
func _push_backpack() -> void:
	var cloud := get_node_or_null("/root/CloudManager")
	if cloud != null and cloud.has_method("persist_record"):
		cloud.persist_record("inventories", {"id": "backpack", "kind": "backpack", "stacks": backpack.to_array()})

func _push_storehouse() -> void:
	var cloud := get_node_or_null("/root/CloudManager")
	if cloud != null and cloud.has_method("persist_record"):
		cloud.persist_record("inventories", {"id": "storehouse", "kind": "storehouse", "stacks": storehouse.to_array()})

## 从云覆盖(bootstrap 后由 CloudBaseBackend 调)。云端有则以云为准。
## _loading 保护:覆盖过程本身不应触发再次推送。
func sync_from_cloud() -> void:
	var cloud := get_node_or_null("/root/CloudManager")
	if cloud == null or not cloud.has_method("load_table"):
		return
	var rows: Array = cloud.load_table("inventories")
	_loading = true
	for r in rows:
		if not (r is Dictionary):
			continue
		var stacks: Array = r.get("stacks", [])
		match str(r.get("kind", "")):
			"backpack": backpack.from_array(stacks)
			"storehouse": storehouse.from_array(stacks)
	_loading = false
	_save_local()

func load_inv() -> bool:
	if OS.has_environment("FAMILY_GARDEN_TEST"):
		return false
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return false
	backpack.from_array(parsed.get("backpack", []))
	storehouse.from_array(parsed.get("storehouse", []))
	return true

## 首次进入:发一批种子,让"种→收→存"循环跑得起来。
## 只影响 backpack(本人独占),_loading 保护避免逐条重复推送;结束后统一推送一次。
## 刻意不碰 storehouse——它是家庭共享数据,这台设备此刻还没从云端同步过。
func _grant_starter_kit() -> void:
	_loading = true
	var db := get_node_or_null("/root/ItemDB")
	if db != null:
		for sid in db.by_category("seed"):
			backpack.add(sid, 5)
	backpack.add("tool_wateringcan", 1)
	backpack.add("coin", 100)
	_loading = false
	_save_local()
	_push_backpack()
