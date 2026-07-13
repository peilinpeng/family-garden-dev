extends HUDPanel
class_name SeedShopPanel

const SEED_ROW_HEIGHT := 76
const SEED_ICON_SIZE := 58

var _list: VBoxContainer
var _coin_label: Label

func _init() -> void:
	panel_title = "种子小铺"
	card_size = Vector2(560, 500)

func _build_content() -> void:
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 12)
	content_root.add_child(header)

	var hint := Label.new()
	hint.text = "老爷爷刚浇完水，今天的种子都在这里。"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.40, 0.33, 0.25, 1.0))
	header.add_child(hint)

	_coin_label = Label.new()
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coin_label.custom_minimum_size = Vector2(110, 24)
	_coin_label.add_theme_font_size_override("font_size", 16)
	_coin_label.add_theme_color_override("font_color", Color(0.28, 0.20, 0.12, 1.0))
	header.add_child(_coin_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 7)
	scroll.add_child(_list)

	if InventoryManager != null:
		if not InventoryManager.backpack_changed.is_connected(_rebuild):
			InventoryManager.backpack_changed.connect(_rebuild)
		if not InventoryManager.storehouse_changed.is_connected(_rebuild):
			InventoryManager.storehouse_changed.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	if _coin_label != null:
		_coin_label.text = "金币 × %d" % _coin_count()

	var seed_ids: Array = ItemDB.by_category("seed") if ItemDB != null else []
	for raw_id in seed_ids:
		var seed_id := String(raw_id)
		var item: ItemDef = ItemDB.get_def(seed_id)
		if item == null:
			continue
		_list.add_child(_seed_row(seed_id, item))

func _seed_row(seed_id: String, item: ItemDef) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, SEED_ROW_HEIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.94, 0.78, 0.72)
	style.border_color = Color(0.62, 0.47, 0.30, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(SEED_ICON_SIZE, SEED_ICON_SIZE)
	icon.texture = ItemDB.icon_texture(seed_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = item.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.24, 0.18, 0.12, 1.0))
	info.add_child(name_label)

	var meta := Label.new()
	var owned := InventoryManager.backpack.count(seed_id) if InventoryManager != null else 0
	var price := _price(item)
	meta.text = "持有 %d    单价 %d 金币" % [owned, price]
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", Color(0.46, 0.36, 0.24, 0.9))
	info.add_child(meta)

	var buy_one := Button.new()
	buy_one.text = "购买"
	buy_one.custom_minimum_size = Vector2(82, 38)
	buy_one.focus_mode = Control.FOCUS_NONE
	HUDPanel._style_soft_button(buy_one)
	buy_one.disabled = _coin_count() < price
	buy_one.pressed.connect(func() -> void: _buy_seed(seed_id, item, 1))
	row.add_child(buy_one)

	var buy_five := Button.new()
	buy_five.text = "×5"
	buy_five.custom_minimum_size = Vector2(58, 38)
	buy_five.focus_mode = Control.FOCUS_NONE
	HUDPanel._style_soft_button(buy_five)
	buy_five.disabled = _coin_count() < price * 5
	buy_five.pressed.connect(func() -> void: _buy_seed(seed_id, item, 5))
	row.add_child(buy_five)

	return panel

func _buy_seed(seed_id: String, item: ItemDef, amount: int) -> void:
	if InventoryManager == null:
		return
	var price := _price(item) * amount
	if _coin_count() < price:
		SceneManager._show_toast("金币不够。")
		return
	var leftover := InventoryManager.give(seed_id, amount)
	if leftover > 0:
		var added := amount - leftover
		if added > 0:
			InventoryManager.take(seed_id, added)
		SceneManager._show_toast("背包放不下。")
		_rebuild()
		return
	_take_coins(price)
	SceneManager._show_toast("买到了 %s ×%d。" % [item.name, amount])
	_rebuild()

func _price(item: ItemDef) -> int:
	return max(1, int(item.get_field("buy", 8)))

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
