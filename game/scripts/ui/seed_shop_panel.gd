extends HUDPanel
class_name SeedShopPanel

const PANTRY_STAPLES := ["sugar", "bread", "honey", "lemon"]
const FARM_SUPPLIES := ["fertilizer"]
const SHOP_CATEGORIES := [
	{"key": "seed", "label": "种子"},
	{"key": "staple", "label": "常备食材"},
	{"key": "supply", "label": "农场用品"},
	{"key": "all", "label": "全部"},
]

const LIST_WIDTH := 500
const DETAIL_WIDTH := 330
const ROW_HEIGHT := 66
const ICON_SIZE := 52
const CREAM := Color(1.0, 0.94, 0.78, 0.98)
const PAPER := Color(1.0, 0.96, 0.84, 0.96)
const BROWN := Color(0.48, 0.34, 0.21, 0.92)
const BROWN_SOFT := Color(0.66, 0.50, 0.32, 0.62)
const HONEY := Color(0.94, 0.58, 0.16, 1.0)
const HONEY_DARK := Color(0.66, 0.36, 0.10, 1.0)

var _cat_key := "seed"
var _selected_id := ""
var _selected_qty := 1
var _cat_buttons: Array[Button] = []
var _list_box: VBoxContainer
var _coin_label: Label
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_type: Label
var _detail_owned: Label
var _detail_price: Label
var _detail_source: Label
var _detail_desc: Label
var _qty_minus: Button
var _qty_plus: Button
var _qty_five: Button
var _qty_max: Button
var _qty_label: Label
var _buy_button: Button
var _feedback_label: Label
var _feedback_tween: Tween

func _init() -> void:
	panel_title = "农场小铺"
	card_size = Vector2(920, 620)

func _build_content() -> void:
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 12)
	content_root.add_child(header)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	_coin_label = Label.new()
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coin_label.custom_minimum_size = Vector2(130, 26)
	_coin_label.add_theme_font_size_override("font_size", 17)
	_coin_label.add_theme_color_override("font_color", Color(0.28, 0.20, 0.12, 1.0))
	header.add_child(_coin_label)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	content_root.add_child(tabs)
	for cat in SHOP_CATEGORIES:
		_cat_buttons.append(_make_category_button(tabs, String(cat["key"]), String(cat["label"])))

	var tab_line := ColorRect.new()
	tab_line.color = Color(0.36, 0.12, 0.10, 0.95)
	tab_line.custom_minimum_size = Vector2(0, 2)
	content_root.add_child(tab_line)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	content_root.add_child(body)
	body.add_child(_build_list_panel())
	body.add_child(_build_detail_panel())

	if InventoryManager != null:
		if not InventoryManager.backpack_changed.is_connected(_rebuild):
			InventoryManager.backpack_changed.connect(_rebuild)
		if not InventoryManager.storehouse_changed.is_connected(_rebuild):
			InventoryManager.storehouse_changed.connect(_rebuild)
	_rebuild()

func _make_category_button(parent: Node, key: String, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(104, 42)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(func() -> void:
		_cat_key = key
		_selected_id = ""
		_selected_qty = 1
		_rebuild())
	parent.add_child(button)
	return button

func _build_list_panel() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _box(Color(0.94, 0.84, 0.63, 0.32), BROWN_SOFT, 1, 12, 4))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_list_box)
	return panel

func _build_detail_panel() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.98, 0.90, 0.88), BROWN_SOFT, 1, 14, 4))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	box.add_child(top)

	var icon_holder := Panel.new()
	icon_holder.custom_minimum_size = Vector2(88, 88)
	icon_holder.add_theme_stylebox_override("panel", _box(Color(1.0, 0.90, 0.66, 0.55), BROWN_SOFT, 1, 12, 2))
	top.add_child(icon_holder)

	_detail_icon = TextureRect.new()
	_detail_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_icon.offset_left = 7
	_detail_icon.offset_top = 7
	_detail_icon.offset_right = -7
	_detail_icon.offset_bottom = -7
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(_detail_icon)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_box.add_theme_constant_override("separation", 5)
	top.add_child(title_box)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 20)
	_detail_name.add_theme_color_override("font_color", Color(0.20, 0.14, 0.10, 1.0))
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(_detail_name)

	_detail_type = Label.new()
	_detail_type.add_theme_font_size_override("font_size", 16)
	_detail_type.add_theme_color_override("font_color", Color(0.50, 0.32, 0.18, 0.85))
	title_box.add_child(_detail_type)

	_detail_owned = Label.new()
	_detail_owned.add_theme_font_size_override("font_size", 14)
	_detail_owned.add_theme_color_override("font_color", Color(0.42, 0.32, 0.22, 0.88))
	title_box.add_child(_detail_owned)

	_detail_price = _make_detail_label(18, Color(0.24, 0.18, 0.12, 0.95))
	box.add_child(_detail_price)

	_detail_source = _make_detail_label(14, Color(0.48, 0.34, 0.20, 0.9))
	_detail_source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail_source)

	var desc_panel := Panel.new()
	desc_panel.custom_minimum_size = Vector2(0, 78)
	desc_panel.add_theme_stylebox_override("panel", _box(Color(0.90, 0.78, 0.55, 0.45), Color(0, 0, 0, 0), 0, 10, 0))
	box.add_child(desc_panel)

	_detail_desc = Label.new()
	_detail_desc.position = Vector2(14, 10)
	_detail_desc.size = Vector2(DETAIL_WIDTH - 56, 56)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_font_size_override("font_size", 15)
	_detail_desc.add_theme_color_override("font_color", Color(0.24, 0.18, 0.12, 0.95))
	desc_panel.add_child(_detail_desc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	_feedback_label = Label.new()
	_feedback_label.visible = false
	_feedback_label.custom_minimum_size = Vector2(0, 22)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_feedback_label.add_theme_font_size_override("font_size", 12)
	_feedback_label.add_theme_color_override("font_color", Color(0.32, 0.42, 0.22, 0.82))
	box.add_child(_feedback_label)

	box.add_child(_build_quantity_selector())

	_buy_button = Button.new()
	_buy_button.custom_minimum_size = Vector2(0, 44)
	_buy_button.focus_mode = Control.FOCUS_ALL
	_style_primary_button(_buy_button)
	_buy_button.pressed.connect(_buy_selected)
	box.add_child(_buy_button)
	return panel

func _make_detail_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _build_quantity_selector() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	_qty_minus = _make_stepper("−", Vector2(44, 38), func() -> void: _set_selected_qty(_selected_qty - 1))
	row.add_child(_qty_minus)

	_qty_label = Label.new()
	_qty_label.custom_minimum_size = Vector2(76, 38)
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_qty_label.add_theme_font_size_override("font_size", 18)
	_qty_label.add_theme_color_override("font_color", Color(0.22, 0.16, 0.12, 1.0))
	_qty_label.add_theme_stylebox_override("normal", _box(Color(0.92, 0.82, 0.62, 0.32), Color(0, 0, 0, 0), 0, 8, 0))
	row.add_child(_qty_label)

	_qty_plus = _make_stepper("+", Vector2(44, 38), func() -> void: _set_selected_qty(_selected_qty + 1))
	row.add_child(_qty_plus)

	_qty_five = _make_stepper("+5", Vector2(42, 38), func() -> void: _set_selected_qty(_selected_qty + 5))
	row.add_child(_qty_five)

	_qty_max = _make_stepper("最大", Vector2(52, 38), func() -> void: _set_selected_qty(_max_affordable_qty()))
	row.add_child(_qty_max)
	return row

func _make_stepper(text: String, min_size: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_ALL
	_style_stepper_button(button)
	button.pressed.connect(action)
	return button

func _rebuild() -> void:
	if _list_box == null:
		return
	if _coin_label != null:
		_coin_label.text = "金币 × %d" % _coin_count()
	_refresh_category_styles()

	var visible_ids := _visible_ids()
	if _selected_id == "" or not visible_ids.has(_selected_id):
		_selected_id = String(visible_ids[0]) if not visible_ids.is_empty() else ""
		_selected_qty = 1
	_clamp_selected_qty()
	_rebuild_list(visible_ids)
	_refresh_detail()

func _refresh_category_styles() -> void:
	for i in _cat_buttons.size():
		var key := String(SHOP_CATEGORIES[i]["key"])
		_style_category_tab(_cat_buttons[i], key == _cat_key)

func _rebuild_list(ids: Array) -> void:
	for child in _list_box.get_children():
		child.queue_free()
	if ids.is_empty():
		var empty := Label.new()
		empty.text = "这个分类暂时没有商品。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color(0.50, 0.40, 0.28, 0.85))
		_list_box.add_child(empty)
		return
	for item_id in ids:
		var item: ItemDef = ItemDB.get_def(String(item_id)) if ItemDB != null else null
		if item != null:
			_list_box.add_child(_product_button(String(item_id), item))

func _product_button(item_id: String, item: ItemDef) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	HUDPanel._style_soft_button(button)
	HUDPanel._mark_active(button, item_id == _selected_id)
	button.pressed.connect(func() -> void:
		_selected_id = item_id
		_selected_qty = 1
		_rebuild())

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 10)
	button.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.texture = ItemDB.icon_texture(item_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = item.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.24, 0.18, 0.12, 1.0))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_label)

	var meta := Label.new()
	meta.text = "拥有 %d · 单价 %d 金币 · %s" % [_owned_count(item_id), _price(item), _shop_label(item)]
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", Color(0.46, 0.36, 0.24, 0.9))
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(meta)
	return button

func _refresh_detail() -> void:
	var item: ItemDef = ItemDB.get_def(_selected_id) if ItemDB != null and _selected_id != "" else null
	var has_item := item != null
	_detail_icon.visible = has_item
	_buy_button.disabled = not has_item or _selected_qty <= 0 or _coin_count() < _price(item) * _selected_qty
	_qty_minus.disabled = not has_item or _selected_qty <= 1
	_qty_plus.disabled = not has_item
	_qty_five.disabled = not has_item
	_qty_max.disabled = not has_item or _max_affordable_qty() <= _selected_qty
	_qty_label.text = str(_selected_qty if has_item else 0)

	if not has_item:
		_detail_icon.texture = null
		_detail_name.text = "请选择一个商品"
		_detail_type.text = ""
		_detail_owned.text = ""
		_detail_price.text = ""
		_detail_source.text = ""
		_detail_desc.text = "左侧选择商品后，这里会显示用途、来源、数量和购买按钮。"
		_buy_button.text = "请选择商品"
		return

	_detail_icon.texture = ItemDB.icon_texture(_selected_id)
	_detail_name.text = item.name
	_detail_type.text = _shop_label(item)
	_detail_owned.text = "拥有数量: %d" % _owned_count(_selected_id)
	_detail_price.text = "单价 %d 金币 · 本次 %d 金币" % [_price(item), _price(item) * _selected_qty]
	_detail_source.text = "来源: " + _source_hint(item)
	_detail_desc.text = _description_for(item)
	_buy_button.text = "购买"

func _visible_ids() -> Array:
	var ids: Array = []
	match _cat_key:
		"seed":
			ids = ItemDB.by_category("seed") if ItemDB != null else []
		"staple":
			ids = PANTRY_STAPLES.duplicate()
		"supply":
			ids = FARM_SUPPLIES.duplicate()
		"all":
			ids = []
			if ItemDB != null:
				ids.append_array(ItemDB.by_category("seed"))
			ids.append_array(PANTRY_STAPLES)
			ids.append_array(FARM_SUPPLIES)
	return ids.filter(func(raw_id: Variant) -> bool:
		return ItemDB != null and ItemDB.get_def(String(raw_id)) != null)

func _set_selected_qty(value: int) -> void:
	_selected_qty = clampi(value, 1, max(1, _max_affordable_qty()))
	_refresh_detail()

func _clamp_selected_qty() -> void:
	_selected_qty = clampi(_selected_qty, 1, max(1, _max_affordable_qty()))

func _max_affordable_qty() -> int:
	var item: ItemDef = ItemDB.get_def(_selected_id) if ItemDB != null and _selected_id != "" else null
	if item == null:
		return 1
	return clampi(int(floor(float(_coin_count()) / float(_price(item)))), 1, 99)

func _buy_selected() -> void:
	var item: ItemDef = ItemDB.get_def(_selected_id) if ItemDB != null and _selected_id != "" else null
	if item == null:
		return
	_buy_item(_selected_id, item, _selected_qty)

func _buy_item(item_id: String, item: ItemDef, amount: int) -> void:
	if InventoryManager == null:
		return
	var price := _price(item) * amount
	if _coin_count() < price:
		SceneManager._show_toast("金币不够。")
		return
	var to_storehouse := _goes_to_storehouse(item)
	var leftover := InventoryManager.give(item_id, amount, to_storehouse)
	if leftover > 0:
		var added := amount - leftover
		if added > 0:
			InventoryManager.take(item_id, added, to_storehouse)
		SceneManager._show_toast("暂时放不下。")
		_rebuild()
		return
	_take_coins(price)
	var target := "家庭共享仓" if to_storehouse else "背包"
	var message := "购买成功，%s 数量 %d 已加入%s。" % [item.name, amount, target]
	SceneManager._show_toast(message)
	_show_feedback(message)
	if MemoryManager != null and MemoryManager.has_method("record_farm_activity"):
		MemoryManager.record_farm_activity("buy", "购买", "买了%s ×%d" % [item.name, amount], item_id, amount)
	_rebuild()

func _show_feedback(message: String) -> void:
	if _feedback_label == null:
		return
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_label.text = message
	_feedback_label.visible = true
	_feedback_label.modulate = Color(1, 1, 1, 1)
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(2.0)
	_feedback_tween.tween_property(_feedback_label, "modulate:a", 0.0, 0.5)
	_feedback_tween.tween_callback(func() -> void:
		if _feedback_label != null:
			_feedback_label.visible = false)

func _price(item: ItemDef) -> int:
	return max(1, int(item.get_field("buy", 8))) if item != null else 1

func _owned_count(item_id: String) -> int:
	if InventoryManager == null:
		return 0
	return int(InventoryManager.backpack.count(item_id)) + int(InventoryManager.storehouse.count(item_id))

func _shop_label(item: ItemDef) -> String:
	match str(item.category):
		"seed":
			return "种子"
		"produce":
			return "常备食材"
		"material":
			return "农场用品"
		_:
			return "商品"

func _source_hint(item: ItemDef) -> String:
	var hint := str(item.get_field("source_hint", ""))
	if hint != "":
		return hint
	if item.category == "seed":
		return "种下后会长成作物"
	return "农场小铺购买"

func _description_for(item: ItemDef) -> String:
	var desc := str(item.get_field("description", ""))
	if desc != "":
		return desc
	if item.category == "seed":
		var crop_id := item.crop_id()
		var produce_id := "produce_" + crop_id
		if ItemDB != null and ItemDB.has(produce_id):
			return "种下、浇水，成熟后可以收获%s。" % ItemDB.display_name(produce_id)
		return "种下后可以收获作物。"
	if item.id == "fertilizer":
		return "给已经浇过水的作物施肥，成熟后会多收一点。"
	if item.category == "produce":
		return "厨房常备食材，买到后直接放入家庭共享仓，可以立刻做饭。"
	return "可用于家庭花园。"

func _goes_to_storehouse(item: ItemDef) -> bool:
	return str(item.ownership_type) == "household"

func _coin_count() -> int:
	if InventoryManager == null:
		return 0
	return int(InventoryManager.backpack.count("coin")) + int(InventoryManager.storehouse.count("coin"))

func _take_coins(amount: int) -> void:
	var left := amount
	var from_backpack: int = min(left, int(InventoryManager.backpack.count("coin")))
	if from_backpack > 0:
		InventoryManager.take("coin", from_backpack)
		left -= from_backpack
	if left > 0:
		InventoryManager.take("coin", left, true)

func _style_category_tab(button: Button, active: bool) -> void:
	button.add_theme_color_override("font_color", Color(0.20, 0.14, 0.10, 1.0) if active else Color(0.40, 0.30, 0.22, 0.88))
	button.add_theme_stylebox_override("normal", _box(Color(0.98, 0.72, 0.24, 0.95) if active else PAPER, HONEY_DARK if active else BROWN_SOFT, 2 if active else 1, 12, 0))
	button.add_theme_stylebox_override("hover", _box(Color(1.0, 0.86, 0.44, 0.96), HONEY, 2, 12, 0))
	button.add_theme_stylebox_override("pressed", _box(Color(0.90, 0.58, 0.18, 0.98), HONEY_DARK, 2, 12, 0))
	button.add_theme_stylebox_override("focus", _box(Color(1.0, 0.86, 0.44, 0.96), HONEY, 2, 12, 0))

func _style_primary_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.58, 0.48, 0.36, 0.66))
	button.add_theme_stylebox_override("normal", _box(Color(0.94, 0.52, 0.08, 1.0), HONEY_DARK, 2, 12, 2))
	button.add_theme_stylebox_override("hover", _box(Color(1.0, 0.62, 0.12, 1.0), HONEY_DARK, 2, 12, 2))
	button.add_theme_stylebox_override("pressed", _box(Color(0.82, 0.42, 0.06, 1.0), HONEY_DARK, 2, 12, 1))
	button.add_theme_stylebox_override("disabled", _box(Color(0.80, 0.68, 0.48, 0.45), Color(0.58, 0.46, 0.30, 0.35), 1, 12, 0))

func _style_stepper_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.20, 0.14, 0.10, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.38, 0.28, 0.55))
	button.add_theme_stylebox_override("normal", _box(Color(0.98, 0.72, 0.24, 0.95), HONEY_DARK, 2, 10, 1))
	button.add_theme_stylebox_override("hover", _box(Color(1.0, 0.82, 0.38, 0.98), HONEY_DARK, 2, 10, 1))
	button.add_theme_stylebox_override("pressed", _box(Color(0.86, 0.58, 0.18, 0.98), HONEY_DARK, 2, 10, 1))
	button.add_theme_stylebox_override("disabled", _box(Color(0.80, 0.68, 0.48, 0.45), Color(0.58, 0.46, 0.30, 0.35), 1, 10, 0))

func _box(bg: Color, border: Color, border_width: int, radius: int, shadow: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.20, 0.12, 0.06, 0.18)
	style.shadow_size = shadow
	style.shadow_offset = Vector2(0, 2)
	return style
