extends Node

## 厨房玩法逻辑(autoload KitchenManager)。制作 / 订单 / 餐桌,全部与 UI 解耦,面板只调这里。
## 库存一律走「家庭共享仓」InventoryManager.storehouse(has/take/give 的 storehouse 参数=true),
## 共享仓改动已自动本地持久化 + 推云(见 inventory_manager.gd),无需在这里再管持久化。
## 已完成订单记在 MemoryManager.kitchen_orders_done(家庭数据,随 save_game 落盘)。

const ORDERS_PATH := "res://assets/manifest/kitchen_orders.json"

signal meal_completed(meal_data: Dictionary)   ## 餐桌"完成晚餐"时发,携带摆放的料理数据(留作扩展 hook)
signal crafted(recipe_id: String, output_item_id: String)
signal order_submitted(order_id: String, reward_coin: int)

var _orders: Array = []   ## [{id, display_name, requires:[{id,qty}], reward_coin, description}, ...]

func _ready() -> void:
	_load_orders()

func _load_orders() -> void:
	if not FileAccess.file_exists(ORDERS_PATH):
		push_warning("[KitchenManager] 缺少订单配置: " + ORDERS_PATH)
		return
	var f := FileAccess.open(ORDERS_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_orders = parsed.get("orders", [])

# ── 制作 ───────────────────────────────────────────────

## 检查配方能否用家庭共享仓的材料制作。返回 {ok:bool, missing:[{id,need,have}]}。
func can_craft(recipe_id: String) -> Dictionary:
	var recipe: RecipeDef = RecipeDB.get_def(recipe_id)
	if recipe == null:
		return { "ok": false, "missing": [] }
	var missing: Array = []
	for ing in recipe.ingredients:
		var need: int = int(ing.get("qty", 1))
		var have: int = _count_in_storehouse(str(ing.get("id", "")))
		if have < need:
			missing.append({ "id": str(ing.get("id", "")), "need": need, "have": have })
	return { "ok": missing.is_empty(), "missing": missing }

## 制作:从共享仓扣材料 → 把成品加进共享仓。材料不足则不制作、返回 false。
func craft(recipe_id: String) -> bool:
	var recipe: RecipeDef = RecipeDB.get_def(recipe_id)
	if recipe == null:
		return false
	if not can_craft(recipe_id).ok:
		return false
	for ing in recipe.ingredients:
		InventoryManager.take(str(ing.get("id", "")), int(ing.get("qty", 1)), true)
	InventoryManager.give(recipe.output_item_id, recipe.output_quantity, true)
	crafted.emit(recipe_id, recipe.output_item_id)
	return true

## 开发/测试用:一键把所有配方需要的材料补到家庭共享仓,方便验证厨房流程。
## 只发放材料到共享仓,不碰花园收获逻辑。
func grant_test_ingredients() -> void:
	var needed: Dictionary = {}   ## id -> 最大需求量(取各配方里的最大用量 ×3,够连做几次)
	for recipe in RecipeDB.all():
		for ing in recipe.ingredients:
			var iid: String = str(ing.get("id", ""))
			var qty: int = int(ing.get("qty", 1)) * 3
			needed[iid] = maxi(int(needed.get(iid, 0)), qty)
	for iid in needed:
		var have: int = _count_in_storehouse(iid)
		var deficit: int = int(needed[iid]) - have
		if deficit > 0:
			InventoryManager.give(iid, deficit, true)

# ── 订单 ───────────────────────────────────────────────

func get_orders() -> Array:
	return _orders

func get_order(order_id: String) -> Dictionary:
	for o in _orders:
		if o is Dictionary and str(o.get("id", "")) == order_id:
			return o
	return {}

func is_done(order_id: String) -> bool:
	return MemoryManager.kitchen_orders_done.has(order_id)

## 家庭共享仓是否满足该订单(且未完成过)。
func can_fulfill(order_id: String) -> bool:
	if is_done(order_id):
		return false
	var order := get_order(order_id)
	if order.is_empty():
		return false
	for req in order.get("requires", []):
		if _count_in_storehouse(str(req.get("id", ""))) < int(req.get("qty", 1)):
			return false
	return true

## 提交订单:扣成品 → 给金币奖励(进共享仓)→ 标记完成(持久化)。成功返回奖励金币数,失败返回 -1。
func submit_order(order_id: String) -> int:
	if not can_fulfill(order_id):
		return -1
	var order := get_order(order_id)
	for req in order.get("requires", []):
		InventoryManager.take(str(req.get("id", "")), int(req.get("qty", 1)), true)
	var reward: int = int(order.get("reward_coin", 0))
	if reward > 0:
		InventoryManager.give("coin", reward, true)
	MemoryManager.kitchen_orders_done.append(order_id)
	MemoryManager.save_game()
	order_submitted.emit(order_id, reward)
	return reward

# ── 餐桌 ───────────────────────────────────────────────

## 完成晚餐:扣除摆放到餐桌的料理,emit meal_completed。dish_ids 为已摆放的料理 id 列表。
## 至少一份才算完成,返回是否完成。回忆/照片/留言等留作 meal_data 的扩展 hook。
func complete_meal(dish_ids: Array) -> bool:
	var placed: Array = []
	for did in dish_ids:
		var sid := str(did)
		if sid != "" and _count_in_storehouse(sid) > 0:
			InventoryManager.take(sid, 1, true)
			placed.append(sid)
	if placed.is_empty():
		return false
	var meal_data := {
		"dishes": placed,
		"role": MemoryManager.selected_role_key,
		"created_at": Time.get_datetime_string_from_system(),
	}
	MemoryManager.notify_family_activity()
	meal_completed.emit(meal_data)
	return true

# ── 内部 ───────────────────────────────────────────────

func _count_in_storehouse(id: String) -> int:
	if id == "":
		return 0
	return InventoryManager.storehouse.count(id)
