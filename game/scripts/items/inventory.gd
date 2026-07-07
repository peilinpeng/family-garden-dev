class_name Inventory
extends RefCounted

## 一个库存:堆叠存放,有槽位容量。背包 / 共享仓都用它。
## 槽位模型:stacks 是 Array[{id, count}];同一物品按 max_stack 拆多个堆。

signal changed

var capacity: int = 24            ## 最多多少个堆(槽位)
var stacks: Array = []            ## [{ "id": String, "count": int }]

func _init(slot_capacity: int = 24) -> void:
	capacity = slot_capacity

# ── 查询 ──────────────────────────────────────────────
func count(id: String) -> int:
	var n := 0
	for s in stacks:
		if s.id == id:
			n += s.count
	return n

func has(id: String, amount: int = 1) -> bool:
	return count(id) >= amount

func used_slots() -> int:
	return stacks.size()

func is_full() -> bool:
	return stacks.size() >= capacity

# ── 增 ────────────────────────────────────────────────
## 加入 count 个;返回未能放下的剩余(0 表示全放下)。
func add(id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var ms := _max_stack(id)
	var left := amount
	# 1) 先填已有未满的堆
	for s in stacks:
		if s.id == id and s.count < ms:
			var fit: int = min(ms - s.count, left)
			s.count += fit
			left -= fit
			if left <= 0:
				break
	# 2) 再开新堆(受容量限制)
	while left > 0 and stacks.size() < capacity:
		var put: int = min(ms, left)
		stacks.append({"id": id, "count": put})
		left -= put
	if left != amount:
		changed.emit()
	return left

# ── 删 ────────────────────────────────────────────────
## 移除 count 个;返回实际移除数。
func remove(id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var left := amount
	for i in range(stacks.size() - 1, -1, -1):
		var s: Dictionary = stacks[i]
		if s.id == id:
			var take: int = min(s.count, left)
			s.count -= take
			left -= take
			if s.count <= 0:
				stacks.remove_at(i)
			if left <= 0:
				break
	var removed := amount - left
	if removed > 0:
		changed.emit()
	return removed

# ── 转移 ──────────────────────────────────────────────
## 从本库存移 count 个到 other;数量受"自己有多少"和"对方放得下多少"限制。
## 返回实际转移数。原子:放不下的退回自己。
func move_to(other: Inventory, id: String, amount: int) -> int:
	var avail: int = min(amount, count(id))
	if avail <= 0:
		return 0
	var taken := remove(id, avail)
	var leftover := other.add(id, taken)
	if leftover > 0:
		add(id, leftover)   # 对方没放下的退回
	return taken - leftover

# ── 序列化 ────────────────────────────────────────────
func to_array() -> Array:
	return stacks.duplicate(true)

func from_array(arr: Array) -> void:
	stacks = []
	for s in arr:
		if s is Dictionary and s.has("id") and s.has("count"):
			stacks.append({"id": str(s.id), "count": int(s.count)})
	changed.emit()

func clear() -> void:
	stacks = []
	changed.emit()

func _max_stack(id: String) -> int:
	var loop := Engine.get_main_loop()
	if loop == null:
		return 99
	var db := (loop as SceneTree).root.get_node_or_null("ItemDB")
	return db.max_stack(id) if db != null else 99
