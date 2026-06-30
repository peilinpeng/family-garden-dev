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

func _ready() -> void:
	backpack = Inventory.new(BACKPACK_SLOTS)
	storehouse = Inventory.new(STOREHOUSE_SLOTS)
	backpack.changed.connect(func(): backpack_changed.emit(); save())
	storehouse.changed.connect(func(): storehouse_changed.emit(); save())
	if not load_inv():
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

# ── 持久化 ────────────────────────────────────────────
func save() -> void:
	var data := {
		"backpack": backpack.to_array(),
		"storehouse": storehouse.to_array(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func load_inv() -> bool:
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
func _grant_starter_kit() -> void:
	var db := get_node_or_null("/root/ItemDB")
	if db != null:
		for sid in db.by_category("seed"):
			backpack.add(sid, 5)
	backpack.add("tool_wateringcan", 1)
	backpack.add("coin", 100)
	save()
