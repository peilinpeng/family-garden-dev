extends HUDPanel
class_name PantryPanel

## 家庭食品储藏区：按分类浏览共享仓、查看单件详情，并完成 pantry 站加工配方。

const BROWSE_CATEGORIES := ["produce", "dish", "seed"]
const CATEGORY_TABS := [
	{"id": "all", "label": "全部"},
	{"id": "produce", "label": "食材"},
	{"id": "seed", "label": "种子"},
	{"id": "dish", "label": "料理"},
	{"id": "processed", "label": "加工品"},
]
const CATEGORY_LABELS := {
	"produce": "家庭共享 · 食材",
	"seed": "家庭共享 · 种子",
	"dish": "家庭共享 · 料理",
}

const COLOR_TEXT := Color(0.24, 0.18, 0.12, 1.0)
const COLOR_MUTED := Color(0.47, 0.37, 0.25, 0.90)
const COLOR_GOOD := Color(0.25, 0.48, 0.27, 1.0)
const COLOR_WARN := Color(0.72, 0.34, 0.18, 1.0)

var _active_category := "all"
var _selected_item_id := ""
var _refresh_queued := false

var _summary_label: Label
var _craftable_label: Label
var _browse_count_label: Label
var _item_grid: GridContainer
var _detail_box: VBoxContainer
var _recipe_box: VBoxContainer
var _tab_buttons: Dictionary = {}

func _init() -> void:
	panel_title = "储藏区 · 家庭食品"
	card_size = Vector2(920, 590)

func _build_content() -> void:
	content_root.add_theme_constant_override("separation", 9)
	content_root.add_child(_build_summary())
	content_root.add_child(_build_tabs())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_build_inventory_panel())
	body.add_child(_build_detail_panel())
	content_root.add_child(body)
	content_root.add_child(_build_recipe_panel())

	if not InventoryManager.storehouse_changed.is_connected(_on_storehouse_changed):
		InventoryManager.storehouse_changed.connect(_on_storehouse_changed)
	_refresh_all()

func _build_summary() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 48)
	panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.92, 0.74, 0.72), Color(0.78, 0.56, 0.32, 0.52), 1, 10))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_top = 7
	row.offset_right = -14
	row.offset_bottom = -7
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var title := _label("家庭共享仓库", 15, COLOR_TEXT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	_summary_label = _label("", 12, COLOR_MUTED)
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_summary_label)
	_craftable_label = _label("", 12, COLOR_GOOD)
	_craftable_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_craftable_label)
	return panel

func _build_tabs() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 36)
	row.add_theme_constant_override("separation", 7)
	var caption := _label("分类", 13, COLOR_MUTED)
	caption.custom_minimum_size = Vector2(44, 0)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)
	for raw in CATEGORY_TABS:
		var tab_id := String(raw.get("id", "all"))
		var button := Button.new()
		button.text = String(raw.get("label", "全部"))
		button.custom_minimum_size = Vector2(76, 34)
		button.focus_mode = Control.FOCUS_NONE
		HUDPanel._style_soft_button(button)
		button.pressed.connect(_select_category.bind(tab_id))
		_tab_buttons[tab_id] = button
		row.add_child(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var hint := _label("点击物品查看数量、来源与用途", 11, COLOR_MUTED)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hint)
	return row

func _build_inventory_panel() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.96, 0.84, 0.78), Color(0.72, 0.52, 0.30, 0.52), 1, 10))
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 11
	root.offset_top = 10
	root.offset_right = -11
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 7)
	panel.add_child(root)

	var header := HBoxContainer.new()
	header.add_child(_label("共享仓存货", 15, COLOR_TEXT))
	_browse_count_label = _label("", 11, COLOR_MUTED)
	_browse_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browse_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_browse_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_browse_count_label)
	root.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_item_grid = GridContainer.new()
	_item_grid.columns = 3
	_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_grid.add_theme_constant_override("h_separation", 7)
	_item_grid.add_theme_constant_override("v_separation", 7)
	scroll.add_child(_item_grid)
	return panel

func _build_detail_panel() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.95, 0.79, 0.72), Color(0.72, 0.52, 0.30, 0.52), 1, 10))
	_detail_box = VBoxContainer.new()
	_detail_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_box.offset_left = 14
	_detail_box.offset_top = 10
	_detail_box.offset_right = -14
	_detail_box.offset_bottom = -10
	_detail_box.add_theme_constant_override("separation", 5)
	panel.add_child(_detail_box)
	return panel

func _build_recipe_panel() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 116)
	panel.add_theme_stylebox_override("panel", _box(Color(0.96, 0.88, 0.67, 0.62), Color(0.71, 0.50, 0.27, 0.58), 1, 10))
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 11
	root.offset_top = 8
	root.offset_right = -11
	root.offset_bottom = -8
	root.add_theme_constant_override("separation", 5)
	panel.add_child(root)
	root.add_child(_label("可制作料理 · 储藏加工", 14, COLOR_TEXT))
	_recipe_box = VBoxContainer.new()
	_recipe_box.add_theme_constant_override("separation", 5)
	root.add_child(_recipe_box)
	return panel

func _refresh_all() -> void:
	_refresh_summary()
	_refresh_tabs()
	_rebuild_items()
	_rebuild_recipes()

func _refresh_summary() -> void:
	var kinds: Dictionary = {}
	var total := 0
	for stack in InventoryManager.storehouse.stacks:
		var iid := String(stack.get("id", ""))
		var item: ItemDef = ItemDB.get_def(iid)
		if item == null or not (item.category in BROWSE_CATEGORIES):
			continue
		kinds[iid] = true
		total += int(stack.get("count", 0))
	_summary_label.text = "%d 种 · %d 件 · %d/%d 槽" % [kinds.size(), total, InventoryManager.storehouse.used_slots(), InventoryManager.storehouse.capacity]
	var craftable := 0
	for recipe in RecipeDB.by_station("pantry"):
		if bool(KitchenManager.can_craft(recipe.id).get("ok", false)):
			craftable += 1
	_craftable_label.text = "现在可制作 %d 项" % craftable
	_craftable_label.add_theme_color_override("font_color", COLOR_GOOD if craftable > 0 else COLOR_MUTED)

func _refresh_tabs() -> void:
	for key in _tab_buttons:
		HUDPanel._mark_active(_tab_buttons[key] as Button, String(key) == _active_category)

func _rebuild_items() -> void:
	_clear(_item_grid)
	var visible := _visible_items()
	var visible_ids: Array[String] = []
	for entry in visible:
		visible_ids.append(String(entry.get("id", "")))
	if not visible_ids.has(_selected_item_id):
		_selected_item_id = visible_ids[0] if not visible_ids.is_empty() else ""
	_browse_count_label.text = "当前分类 %d 种" % visible.size()

	if visible.is_empty():
		var empty := _label("这个分类里暂时没有物品。\n去花园收获或完成料理后再回来看看。", 12, COLOR_MUTED)
		empty.custom_minimum_size = Vector2(510, 76)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_item_grid.add_child(empty)
	else:
		for entry in visible:
			_item_grid.add_child(_item_card(String(entry.get("id", "")), int(entry.get("count", 0))))
	_rebuild_detail()

func _item_card(iid: String, count: int) -> Button:
	var item: ItemDef = ItemDB.get_def(iid)
	var button := Button.new()
	button.text = "%s\n×%d" % [ItemDB.display_name(iid), count]
	button.icon = ItemDB.icon_texture(iid)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 40)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(168, 65)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "%s · 点击查看详情" % _category_name(item.category if item != null else "")
	HUDPanel._style_soft_button(button)
	HUDPanel._mark_active(button, iid == _selected_item_id)
	button.pressed.connect(_select_item.bind(iid))
	return button

func _rebuild_detail() -> void:
	_clear(_detail_box)
	_detail_box.add_child(_label("物品详情", 14, COLOR_TEXT))
	if _selected_item_id == "":
		var empty := _label("选择左侧物品，查看它的数量和用途。", 12, COLOR_MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_box.add_child(empty)
		return
	var item: ItemDef = ItemDB.get_def(_selected_item_id)
	if item == null:
		return

	var icon := _icon_rect(ItemDB.icon_texture(_selected_item_id), 66)
	icon.custom_minimum_size = Vector2(0, 70)
	_detail_box.add_child(icon)
	var name := _label(item.name, 18, COLOR_TEXT)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_box.add_child(name)
	var category := _label(String(CATEGORY_LABELS.get(item.category, "家庭共享")), 11, COLOR_GOOD)
	category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_box.add_child(category)
	var count := _label("库存数量  ×%d" % InventoryManager.storehouse.count(_selected_item_id), 13, COLOR_TEXT)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_box.add_child(count)

	var description := _item_description(item)
	var desc := _label(description, 11, COLOR_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_box.add_child(desc)
	_add_context_action(item)

func _add_context_action(item: ItemDef) -> void:
	match item.category:
		"produce":
			var cook := Button.new()
			cook.text = "打开互动烹饪"
			cook.custom_minimum_size = Vector2(0, 34)
			HUDPanel._style_soft_button(cook)
			cook.pressed.connect(func() -> void:
				if SceneManager.game_hud != null:
					SceneManager.game_hud.open_panel(KitchenCookingPanel.new()))
			_detail_box.add_child(cook)
		"dish":
			var table := Button.new()
			table.text = "摆到餐桌"
			table.custom_minimum_size = Vector2(0, 34)
			HUDPanel._style_soft_button(table)
			var dish_id := item.id
			table.pressed.connect(func() -> void:
				if SceneManager.game_hud != null:
					var meal_panel := MealTablePanel.new()
					meal_panel.initial_dish_id = dish_id
					SceneManager.game_hud.open_panel(meal_panel))
			_detail_box.add_child(table)
		"seed":
			var hint := _label("在花园地块选择种子时即可播种。", 11, COLOR_MUTED)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_detail_box.add_child(hint)

func _rebuild_recipes() -> void:
	_clear(_recipe_box)
	var recipes := RecipeDB.by_station("pantry")
	if recipes.is_empty():
		_recipe_box.add_child(_label("暂无储藏加工配方。", 12, COLOR_MUTED))
		return
	for recipe in recipes:
		_recipe_box.add_child(_recipe_card(recipe))

func _recipe_card(recipe: RecipeDef) -> Control:
	var can_make := bool(KitchenManager.can_craft(recipe.id).get("ok", false))
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 67)
	panel.add_theme_stylebox_override("panel", _box(
		Color(1.0, 0.96, 0.84, 0.86),
		Color(0.42, 0.65, 0.37, 0.78) if can_make else Color(0.72, 0.52, 0.30, 0.48),
		2 if can_make else 1,
		9
	))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_top = 6
	row.offset_right = -10
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 9)
	panel.add_child(row)
	row.add_child(_icon_rect(ItemDB.icon_texture(recipe.output_item_id), 48))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	row.add_child(info)
	info.add_child(_label("%s  ×%d" % [recipe.display_name, recipe.output_quantity], 14, COLOR_TEXT))
	var requirement := _label(_ingredient_requirement_text(recipe), 11, COLOR_GOOD if can_make else COLOR_WARN)
	requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(requirement)

	var button := Button.new()
	button.text = "制作 1 份"
	button.custom_minimum_size = Vector2(116, 42)
	button.disabled = not can_make
	button.tooltip_text = "材料不足" if not can_make else "从共享仓扣除材料并放入成品"
	HUDPanel._style_soft_button(button)
	button.pressed.connect(_craft_recipe.bind(recipe.id))
	row.add_child(button)
	return panel

func _visible_items() -> Array:
	var totals: Dictionary = {}
	for stack in InventoryManager.storehouse.stacks:
		var iid := String(stack.get("id", ""))
		var item: ItemDef = ItemDB.get_def(iid)
		if item == null or not (item.category in BROWSE_CATEGORIES) or not _matches_category(iid, item):
			continue
		totals[iid] = int(totals.get(iid, 0)) + int(stack.get("count", 0))
	var ids := totals.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var left := String(a)
		var right := String(b)
		var left_item: ItemDef = ItemDB.get_def(left)
		var right_item: ItemDef = ItemDB.get_def(right)
		var rank := {"produce": 0, "seed": 1, "dish": 2}
		var left_rank := int(rank.get(left_item.category if left_item != null else "", 9))
		var right_rank := int(rank.get(right_item.category if right_item != null else "", 9))
		if left_rank != right_rank:
			return left_rank < right_rank
		return ItemDB.catalog_index(left) < ItemDB.catalog_index(right))
	var result: Array = []
	for iid_value in ids:
		var iid := String(iid_value)
		result.append({"id": iid, "count": int(totals[iid])})
	return result

func _matches_category(iid: String, item: ItemDef) -> bool:
	match _active_category:
		"all": return true
		"processed": return _pantry_output_ids().has(iid)
		_: return item.category == _active_category

func _pantry_output_ids() -> Array[String]:
	var ids: Array[String] = []
	for recipe in RecipeDB.by_station("pantry"):
		ids.append(recipe.output_item_id)
	return ids

func _select_category(category_id: String) -> void:
	_active_category = category_id
	_refresh_tabs()
	_rebuild_items()

func _select_item(item_id: String) -> void:
	_selected_item_id = item_id
	_rebuild_items()

func _craft_recipe(recipe_id: String) -> void:
	var recipe: RecipeDef = RecipeDB.get_def(recipe_id)
	if recipe == null:
		return
	if await KitchenManager.craft(recipe_id):
		SceneManager._show_toast("做好了：%s ✨" % recipe.display_name)
	else:
		SceneManager._show_toast("材料还不够，暂时无法制作。")
	_queue_refresh()

func _ingredient_requirement_text(recipe: RecipeDef) -> String:
	var parts := PackedStringArray()
	for raw in recipe.ingredients:
		var iid := String(raw.get("id", ""))
		var need := int(raw.get("qty", 1))
		var have := InventoryManager.storehouse.count(iid)
		parts.append("%s %d/%d" % [ItemDB.display_name(iid), have, need])
	return "需要：" + " · ".join(parts)

func _item_description(item: ItemDef) -> String:
	var description := String(item.get_field("description", ""))
	var source := String(item.get_field("source_hint", ""))
	if description != "":
		return description
	if source != "":
		return "来源：%s\n\n%s" % [source, _category_usage(item.category)]
	return _category_usage(item.category)

func _category_usage(category: String) -> String:
	match category:
		"produce": return "可用于互动烹饪、固定配方或家庭料理。"
		"seed": return "带到花园播种，成熟后收获家庭食材。"
		"dish": return "已经完成的料理，可以摆到家庭餐桌。"
		_: return "存放在家庭共享仓库中。"

func _category_name(category: String) -> String:
	match category:
		"produce": return "食材"
		"seed": return "种子"
		"dish": return "料理"
		_: return "物品"

func _on_storehouse_changed() -> void:
	_queue_refresh()

func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_run_queued_refresh")

func _run_queued_refresh() -> void:
	_refresh_queued = false
	if is_inside_tree():
		_refresh_all()

func _clear(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()

func _icon_rect(texture: Texture2D, size_px: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(size_px, size_px)
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect

func _label(text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	return label

func _box(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	return box
