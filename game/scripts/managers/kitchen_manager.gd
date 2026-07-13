extends Node

## 厨房玩法逻辑(autoload KitchenManager)。制作 / 订单 / 餐桌,全部与 UI 解耦,面板只调这里。
## 库存一律走「家庭共享仓」InventoryManager.storehouse(has/take/give 的 storehouse 参数=true),
## 共享仓改动已自动本地持久化 + 推云(见 inventory_manager.gd),无需在这里再管持久化。
## 已完成订单记在 MemoryManager.kitchen_orders_done(家庭数据,随 save_game 落盘)。

const ORDERS_PATH := "res://assets/manifest/kitchen_orders.json"

signal meal_completed(meal_data: Dictionary)   ## 餐桌"完成晚餐"时发,携带摆放的料理数据(留作扩展 hook)
signal crafted(recipe_id: String, output_item_id: String)
signal ai_dish_created(dish_id: String)
signal order_submitted(order_id: String, reward_coin: int)

var _orders: Array = []   ## [{id, display_name, requires:[{id,qty}], reward_coin, description}, ...]
var _ai_dish_texture_cache: Dictionary = {}

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

func random_ai_ingredients(limit: int = 3) -> Array:
	var pool: Array = []
	for stack in InventoryManager.storehouse.stacks:
		var iid := String(stack.get("id", ""))
		var count := int(stack.get("count", 0))
		var item: ItemDef = ItemDB.get_def(iid)
		if item == null or item.category != "produce" or count <= 0:
			continue
		pool.append({"id": iid, "count": count})
	pool.shuffle()
	var selected: Array = []
	var target := mini(maxi(limit, 1), 5)
	for raw in pool.slice(0, target):
		var iid := String(raw.get("id", ""))
		selected.append({
			"id": iid,
			"name": ItemDB.display_name(iid),
			"qty": 1 if int(raw.get("count", 0)) <= 1 else randi_range(1, mini(2, int(raw.get("count", 0)))),
		})
	return selected

func can_make_random_ai_dish() -> bool:
	return random_ai_ingredients(2).size() >= 1

func craft_random_ai_dish(station_type: String = "stove") -> Dictionary:
	var ingredients := random_ai_ingredients(randi_range(2, 4))
	return await craft_ai_dish_with_ingredients(ingredients, station_type)

## 使用玩家在互动烹饪面板中选定的食材制作 AI 料理。
## 只做白名单、去重和库存校验；真正扣料仍由 commit_kitchen_dish_draft 在 AI 成功后原子执行。
func craft_ai_dish_with_ingredients(ingredients: Array, station_type: String = "stove") -> Dictionary:
	var validation := validate_ai_ingredients(ingredients)
	if not bool(validation.get("ok", false)):
		return validation
	var normalized: Array = validation.get("ingredients", [])
	var draft: Dictionary = await AIWorkflowManager.prepare_kitchen_dish_draft(normalized, station_type)
	if not bool(draft.get("ok", false)):
		return draft
	var result: Dictionary = await AIWorkflowManager.commit_kitchen_dish_draft(draft)
	if bool(result.get("ok", false)):
		var dish: Dictionary = result.get("dish", {})
		ai_dish_created.emit(String(dish.get("id", "")))
	return result

## 返回 {ok, ingredients} 或稳定错误；只允许共享仓中真实存在的 produce，最多 5 种。
func validate_ai_ingredients(ingredients: Array) -> Dictionary:
	if ingredients.is_empty():
		return {"ok": false, "error": {"code": "NO_INGREDIENTS", "message": "请先把食材放进锅里。"}}
	var merged: Dictionary = {}
	for raw in ingredients:
		if not raw is Dictionary:
			continue
		var iid := String((raw as Dictionary).get("id", ""))
		var qty := int((raw as Dictionary).get("qty", 0))
		var item: ItemDef = ItemDB.get_def(iid)
		if iid == "" or qty <= 0 or item == null or item.category != "produce":
			return {"ok": false, "error": {"code": "INVALID_INGREDIENT", "message": "锅里有不能用于料理的物品。"}}
		merged[iid] = int(merged.get(iid, 0)) + qty
	if merged.is_empty() or merged.size() > 5:
		return {"ok": false, "error": {"code": "INVALID_INGREDIENTS", "message": "每次请选择 1 到 5 种食材。"}}
	var normalized: Array = []
	for iid_value in merged:
		var iid := String(iid_value)
		var qty := int(merged[iid])
		if qty > InventoryManager.storehouse.count(iid):
			return {"ok": false, "error": {"code": "INGREDIENTS_CHANGED", "message": "%s 的库存已经不够了。" % ItemDB.display_name(iid)}}
		normalized.append({"id": iid, "name": ItemDB.display_name(iid), "qty": qty})
	return {"ok": true, "ingredients": normalized}

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
		if is_ai_dish(sid) and MemoryManager.consume_kitchen_ai_dish(sid, 1):
			placed.append(sid)
		elif sid != "" and _count_in_storehouse(sid) > 0:
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

func is_ai_dish(dish_id: String) -> bool:
	return not MemoryManager.get_kitchen_ai_dish(dish_id).is_empty()

func ai_dish_count(dish_id: String) -> int:
	var dish: Dictionary = MemoryManager.get_kitchen_ai_dish(dish_id)
	return int(dish.get("quantity", 0)) if not dish.is_empty() else 0

func available_ai_dishes() -> Array:
	return MemoryManager.kitchen_ai_dishes.filter(func(dish): return dish is Dictionary and int(dish.get("quantity", 0)) > 0)

func dish_display_name(dish_id: String) -> String:
	var dish: Dictionary = MemoryManager.get_kitchen_ai_dish(dish_id)
	if not dish.is_empty():
		return String(dish.get("name", dish_id))
	return ItemDB.display_name(dish_id)

func dish_description(dish_id: String) -> String:
	var dish: Dictionary = MemoryManager.get_kitchen_ai_dish(dish_id)
	if not dish.is_empty():
		return String(dish.get("description", ""))
	var item: ItemDef = ItemDB.get_def(dish_id)
	return String(item.get_field("description", "")) if item != null else ""

func dish_icon(dish_id: String) -> Texture2D:
	var dish: Dictionary = MemoryManager.get_kitchen_ai_dish(dish_id)
	if not dish.is_empty():
		var generated := _ai_dish_texture(dish)
		if generated != null:
			return generated
		return ItemDB.icon_texture("dish_garden_breakfast")
	return ItemDB.icon_texture(dish_id)

# ── 内部 ───────────────────────────────────────────────

func _ai_dish_texture(dish: Dictionary) -> Texture2D:
	var visual: Dictionary = dish.get("visual", {}) if dish.get("visual", {}) is Dictionary else {}
	if visual.is_empty():
		return null
	var key := String(dish.get("id", "")) + ":" + JSON.stringify(visual)
	if _ai_dish_texture_cache.has(key):
		return _ai_dish_texture_cache[key]
	var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var plate := _color_from_hex(String(visual.get("plate_color", "#F4E4C8")), Color(0.96, 0.88, 0.73, 1.0))
	var base := _color_from_hex(String(visual.get("base_color", "#F2C14E")), Color(0.90, 0.58, 0.25, 1.0))
	var garnish := _color_from_hex(String(visual.get("garnish_color", "#4E9D55")), Color(0.28, 0.62, 0.34, 1.0))
	var accents := _visual_accent_colors(visual)
	var shape := String(visual.get("shape", "plate"))
	var seed_hash: int = int(String(dish.get("id", "dish_ai")).hash())
	var seed: int = seed_hash if seed_hash >= 0 else -seed_hash
	match shape:
		"bowl":
			_draw_bowl_icon(img, plate, base, accents, garnish, seed)
		"jar":
			_draw_jar_icon(img, plate, base, accents, garnish, seed)
		"mug":
			_draw_mug_icon(img, plate, base, accents, garnish, seed)
		"breakfast_plate":
			_draw_breakfast_icon(img, plate, base, accents, garnish, seed)
		_:
			_draw_plate_icon(img, plate, base, accents, garnish, seed)
	var tex := ImageTexture.create_from_image(img)
	_ai_dish_texture_cache[key] = tex
	return tex

func _visual_accent_colors(visual: Dictionary) -> Array[Color]:
	var result: Array[Color] = []
	var raw: Array = visual.get("accent_colors", []) if visual.get("accent_colors", []) is Array else []
	for item in raw:
		result.append(_color_from_hex(String(item), Color(0.84, 0.24, 0.18, 1.0)))
	if result.is_empty():
		result.append(Color(0.84, 0.24, 0.18, 1.0))
	return result

func _draw_plate_icon(img: Image, plate: Color, base: Color, accents: Array[Color], garnish: Color, seed: int) -> void:
	_draw_ellipse(img, Vector2(48, 78), 32, 7, Color(0.20, 0.12, 0.06, 0.18))
	_draw_ellipse(img, Vector2(48, 48), 34, 30, plate.darkened(0.28))
	_draw_ellipse(img, Vector2(48, 46), 34, 30, plate)
	_draw_ellipse(img, Vector2(48, 46), 25, 22, plate.lightened(0.16))
	_draw_ellipse(img, Vector2(48, 46), 21, 18, base)
	_draw_food_bits(img, Vector2(48, 46), 19, 15, accents, garnish, seed, 16)

func _draw_bowl_icon(img: Image, plate: Color, base: Color, accents: Array[Color], garnish: Color, seed: int) -> void:
	_draw_ellipse(img, Vector2(48, 78), 29, 7, Color(0.20, 0.12, 0.06, 0.18))
	_draw_ellipse(img, Vector2(48, 43), 30, 16, plate.darkened(0.25))
	_draw_ellipse(img, Vector2(48, 41), 30, 15, plate)
	_draw_ellipse(img, Vector2(48, 41), 23, 10, base)
	_draw_rect(img, Rect2i(22, 43, 52, 24), plate.darkened(0.12))
	_draw_ellipse(img, Vector2(48, 64), 26, 12, plate.darkened(0.18))
	_draw_food_bits(img, Vector2(48, 41), 20, 8, accents, garnish, seed, 12)

func _draw_jar_icon(img: Image, plate: Color, base: Color, accents: Array[Color], garnish: Color, seed: int) -> void:
	_draw_ellipse(img, Vector2(48, 79), 23, 6, Color(0.20, 0.12, 0.06, 0.16))
	_draw_rect(img, Rect2i(30, 24, 36, 50), base.darkened(0.18))
	_draw_rect(img, Rect2i(33, 27, 30, 44), base)
	_draw_rect(img, Rect2i(28, 18, 40, 13), plate.darkened(0.1))
	_draw_rect(img, Rect2i(31, 16, 34, 11), plate.lightened(0.18))
	_draw_ellipse(img, Vector2(48, 72), 18, 5, base.darkened(0.1))
	_draw_food_bits(img, Vector2(48, 49), 13, 18, accents, garnish, seed, 18)

func _draw_mug_icon(img: Image, plate: Color, base: Color, accents: Array[Color], garnish: Color, seed: int) -> void:
	_draw_ellipse(img, Vector2(48, 79), 24, 6, Color(0.20, 0.12, 0.06, 0.16))
	_draw_rect(img, Rect2i(28, 31, 38, 42), base.darkened(0.12))
	_draw_rect(img, Rect2i(31, 29, 32, 40), base)
	_draw_ellipse(img, Vector2(47, 30), 18, 7, plate.lightened(0.16))
	_draw_ellipse(img, Vector2(47, 30), 13, 4, base.lightened(0.18))
	_draw_ring(img, Vector2(67, 50), 12, 16, 4, plate.darkened(0.1))
	_draw_food_bits(img, Vector2(47, 38), 13, 9, accents, garnish, seed, 8)
	_draw_steam(img)

func _draw_breakfast_icon(img: Image, plate: Color, base: Color, accents: Array[Color], garnish: Color, seed: int) -> void:
	_draw_ellipse(img, Vector2(48, 78), 34, 7, Color(0.20, 0.12, 0.06, 0.18))
	_draw_ellipse(img, Vector2(48, 48), 35, 28, plate.darkened(0.25))
	_draw_ellipse(img, Vector2(48, 46), 35, 28, plate)
	_draw_ellipse(img, Vector2(57, 49), 12, 10, Color(1.0, 0.96, 0.84, 1.0))
	_draw_ellipse(img, Vector2(57, 49), 5, 5, base)
	_draw_rect(img, Rect2i(27, 34, 22, 12), accents[0].lightened(0.15))
	_draw_rect(img, Rect2i(30, 49, 22, 12), accents[0])
	_draw_food_bits(img, Vector2(38, 58), 15, 9, accents, garnish, seed, 10)

func _draw_food_bits(img: Image, center: Vector2, rx: int, ry: int, accents: Array[Color], garnish: Color, seed: int, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		var angle := rng.randf_range(0.0, TAU)
		var radius := sqrt(rng.randf()) * 0.92
		var p := center + Vector2(cos(angle) * rx * radius, sin(angle) * ry * radius)
		var color := accents[i % accents.size()]
		_draw_ellipse(img, p, rng.randi_range(2, 5), rng.randi_range(2, 4), color)
	for i in 6:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(0.15, 0.88)
		var p := center + Vector2(cos(angle) * rx * radius, sin(angle) * ry * radius)
		_draw_rect(img, Rect2i(int(p.x), int(p.y), 3, 3), garnish)

func _draw_ellipse(img: Image, center: Vector2, rx: int, ry: int, color: Color) -> void:
	for y in range(int(center.y) - ry, int(center.y) + ry + 1):
		for x in range(int(center.x) - rx, int(center.x) + rx + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var dx := (float(x) + 0.5 - center.x) / float(maxi(rx, 1))
			var dy := (float(y) + 0.5 - center.y) / float(maxi(ry, 1))
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, color)

func _draw_ring(img: Image, center: Vector2, rx: int, ry: int, thickness: int, color: Color) -> void:
	for y in range(int(center.y) - ry, int(center.y) + ry + 1):
		for x in range(int(center.x) - rx, int(center.x) + rx + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var dx := (float(x) + 0.5 - center.x) / float(maxi(rx, 1))
			var dy := (float(y) + 0.5 - center.y) / float(maxi(ry, 1))
			var outer := dx * dx + dy * dy
			var inner_rx := maxi(rx - thickness, 1)
			var inner_ry := maxi(ry - thickness, 1)
			var idx := (float(x) + 0.5 - center.x) / float(inner_rx)
			var idy := (float(y) + 0.5 - center.y) / float(inner_ry)
			var inner := idx * idx + idy * idy
			if outer <= 1.0 and inner >= 1.0:
				img.set_pixel(x, y, color)

func _draw_rect(img: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, color)

func _draw_steam(img: Image) -> void:
	var steam := Color(0.78, 0.70, 0.62, 0.52)
	for p in [Vector2(42, 17), Vector2(49, 13), Vector2(56, 17)]:
		_draw_rect(img, Rect2i(int(p.x), int(p.y), 3, 8), steam)
		_draw_rect(img, Rect2i(int(p.x) + 2, int(p.y) - 4, 3, 5), steam)

func _color_from_hex(value: String, fallback: Color) -> Color:
	if value.length() == 7 and value.begins_with("#") and value.substr(1).is_valid_hex_number(false):
		return Color.html(value)
	return fallback

func _count_in_storehouse(id: String) -> int:
	if id == "":
		return 0
	return InventoryManager.storehouse.count(id)
