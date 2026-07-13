extends HUDPanel
class_name InventoryPanel

## 背包面板(全局 HUD 版)。
## 技术栈: Godot Control + 现有 HUDPanel / InventoryManager / ItemDB。
## 交互:左键选中,右侧按钮按数量转移;右键快捷转移 1 个;Shift+点击转移整组。

const COLS := 8
const SLOT := 62
const ITEM_ICON_INSET := 10
const SEED_ICON_INSET := 4
const DETAIL_ICON_INSET := 14
const DETAIL_SEED_ICON_INSET := 6
const VISIBLE_ROWS := 4
const LEFT_WIDTH := 710
const DETAIL_WIDTH := 300
const CREAM := Color(1.0, 0.94, 0.78, 0.98)
const CREAM_SOFT := Color(1.0, 0.90, 0.66, 0.55)
const PAPER := Color(1.0, 0.96, 0.84, 0.96)
const PAPER_DARK := Color(0.90, 0.78, 0.55, 0.42)
const BROWN := Color(0.48, 0.34, 0.21, 0.92)
const BROWN_SOFT := Color(0.66, 0.50, 0.32, 0.62)
const HONEY := Color(0.94, 0.58, 0.16, 1.0)
const HONEY_DARK := Color(0.66, 0.36, 0.10, 1.0)

const CATEGORIES := [
	{"key": "all", "label": "全部", "cats": []},
	{"key": "seed", "label": "种子", "cats": ["seed"]},
	{"key": "produce", "label": "食材", "cats": ["produce", "material"]},
	{"key": "tool", "label": "工具", "cats": ["tool"]},
	{"key": "dish", "label": "料理", "cats": ["dish"]},
	{"key": "decor", "label": "装饰", "cats": ["decor"]},
	{"key": "memory", "label": "记忆物品", "cats": ["memory"]},
]
const CATEGORY_LABELS := {
	"seed": "种子",
	"produce": "食材",
	"material": "材料",
	"tool": "工具",
	"dish": "料理",
	"decor": "装饰",
	"memory": "记忆物品",
	"gift": "礼物",
	"currency": "货币",
}

var _store_key := "backpack"
var _cat_key := "all"
var _selected_id := ""
var _selected_qty := 1
var _main_buttons: Array[Button] = []
var _cat_buttons: Array[Button] = []
var _grid: GridContainer
var _scroll: ScrollContainer
var _capacity_label: Label
var _coin_label: Label
var _sort_button: Button
var _detail_icon_holder: Panel
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_type: Label
var _detail_count: Label
var _detail_desc: Label
var _detail_props: VBoxContainer
var _qty_minus: Button
var _qty_plus: Button
var _qty_max: Button
var _qty_label: Label
var _transfer_button: Button
var _inv: Node

func _init() -> void:
	panel_title = "背包"
	card_size = Vector2(1120, 660)

func _build_content() -> void:
	_inv = get_node_or_null("/root/InventoryManager")
	_add_coin_badge()

	var main_tabs := HBoxContainer.new()
	main_tabs.add_theme_constant_override("separation", 0)
	content_root.add_child(main_tabs)
	_main_buttons.append(_make_main_tab(main_tabs, "🎒 我的背包", "backpack"))
	_main_buttons.append(_make_main_tab(main_tabs, "🏠 家庭共享仓库", "storehouse"))

	var tab_line := ColorRect.new()
	tab_line.color = Color(0.36, 0.12, 0.10, 0.95)
	tab_line.custom_minimum_size = Vector2(0, 2)
	content_root.add_child(tab_line)

	var cat_tabs := HBoxContainer.new()
	cat_tabs.add_theme_constant_override("separation", 8)
	content_root.add_child(cat_tabs)
	for c in CATEGORIES:
		_cat_buttons.append(_make_category_button(cat_tabs, String(c["key"]), String(c["label"])))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	content_root.add_child(body)
	body.add_child(_build_left_panel())
	body.add_child(_build_detail_panel())

	if _inv != null:
		_inv.backpack_changed.connect(_rebuild)
		_inv.storehouse_changed.connect(_rebuild)

	_refresh_tab_styles()
	_rebuild()

func _add_coin_badge() -> void:
	var badge := Panel.new()
	badge.position = Vector2(card_size.x - 206, 22)
	badge.size = Vector2(118, 40)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _box(Color(0.91, 0.80, 0.58, 0.38), Color(0.76, 0.58, 0.35, 0.20), 0, 18, 0))
	card.add_child(badge)

	_coin_label = Label.new()
	_coin_label.position = Vector2(12, 5)
	_coin_label.size = Vector2(96, 30)
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_label.add_theme_font_size_override("font_size", 19)
	_coin_label.add_theme_color_override("font_color", Color(0.24, 0.18, 0.12, 1.0))
	badge.add_child(_coin_label)

func _build_left_panel() -> Control:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(LEFT_WIDTH, 0)
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 10)

	var grid_panel := Panel.new()
	grid_panel.custom_minimum_size = Vector2(LEFT_WIDTH, VISIBLE_ROWS * SLOT + (VISIBLE_ROWS - 1) * 10 + 42)
	grid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	grid_panel.add_theme_stylebox_override("panel", _box(Color(0.94, 0.84, 0.63, 0.32), BROWN_SOFT, 1, 12, 4))
	wrap.add_child(grid_panel)

	var grid_margin := MarginContainer.new()
	grid_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		grid_margin.add_theme_constant_override("margin_" + side, 18)
	grid_panel.add_child(grid_margin)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_margin.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	wrap.add_child(bottom)

	_capacity_label = Label.new()
	_capacity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_capacity_label.add_theme_font_size_override("font_size", 19)
	_capacity_label.add_theme_color_override("font_color", Color(0.25, 0.18, 0.12, 0.95))
	bottom.add_child(_capacity_label)

	_sort_button = Button.new()
	_sort_button.text = "自动整理"
	_sort_button.custom_minimum_size = Vector2(160, 44)
	_sort_button.focus_mode = Control.FOCUS_ALL
	_style_secondary_button(_sort_button)
	_sort_button.pressed.connect(_sort_current_store)
	bottom.add_child(_sort_button)
	return wrap

func _build_detail_panel() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.98, 0.90, 0.88), BROWN_SOFT, 1, 14, 4))

	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_top = 18
	top.offset_right = -18
	top.offset_bottom = 114
	top.add_theme_constant_override("separation", 16)
	panel.add_child(top)

	_detail_icon_holder = Panel.new()
	_detail_icon_holder.custom_minimum_size = Vector2(96, 96)
	_detail_icon_holder.add_theme_stylebox_override("panel", _box(CREAM_SOFT, BROWN_SOFT, 1, 12, 2))
	top.add_child(_detail_icon_holder)

	_detail_icon = TextureRect.new()
	_detail_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_icon.offset_left = 14
	_detail_icon.offset_top = 14
	_detail_icon.offset_right = -14
	_detail_icon.offset_bottom = -14
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_icon_holder.add_child(_detail_icon)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 6)
	top.add_child(title_box)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 22)
	_detail_name.add_theme_color_override("font_color", Color(0.20, 0.14, 0.10, 1.0))
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(_detail_name)

	_detail_type = Label.new()
	_detail_type.add_theme_font_size_override("font_size", 16)
	_detail_type.add_theme_color_override("font_color", Color(0.50, 0.32, 0.18, 0.85))
	title_box.add_child(_detail_type)

	_detail_count = Label.new()
	_detail_count.add_theme_font_size_override("font_size", 14)
	_detail_count.add_theme_color_override("font_color", Color(0.42, 0.32, 0.22, 0.88))
	title_box.add_child(_detail_count)

	var desc_panel := Panel.new()
	desc_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	desc_panel.offset_left = 18
	desc_panel.offset_top = 132
	desc_panel.offset_right = -18
	desc_panel.offset_bottom = 238
	desc_panel.add_theme_stylebox_override("panel", _box(Color(0.90, 0.78, 0.55, 0.45), Color(0, 0, 0, 0), 0, 10, 0))
	panel.add_child(desc_panel)

	_detail_desc = Label.new()
	_detail_desc.position = Vector2(14, 12)
	_detail_desc.size = Vector2(DETAIL_WIDTH - 64, 82)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_font_size_override("font_size", 15)
	_detail_desc.add_theme_color_override("font_color", Color(0.24, 0.18, 0.12, 0.95))
	desc_panel.add_child(_detail_desc)

	var props_scroll := ScrollContainer.new()
	props_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	props_scroll.offset_left = 18
	props_scroll.offset_top = 252
	props_scroll.offset_right = -18
	props_scroll.offset_bottom = -136
	props_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(props_scroll)

	_detail_props = VBoxContainer.new()
	_detail_props.add_theme_constant_override("separation", 4)
	props_scroll.add_child(_detail_props)

	var action_box := VBoxContainer.new()
	action_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	action_box.offset_left = 18
	action_box.offset_top = -118
	action_box.offset_right = -18
	action_box.offset_bottom = -18
	action_box.add_theme_constant_override("separation", 10)
	panel.add_child(action_box)
	action_box.add_child(_build_quantity_selector())

	_transfer_button = Button.new()
	_transfer_button.custom_minimum_size = Vector2(0, 50)
	_transfer_button.focus_mode = Control.FOCUS_ALL
	_style_primary_button(_transfer_button)
	_transfer_button.pressed.connect(_transfer_selected)
	action_box.add_child(_transfer_button)
	return panel

func _build_quantity_selector() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	_qty_minus = Button.new()
	_qty_minus.text = "−"
	_qty_minus.custom_minimum_size = Vector2(44, 38)
	_style_stepper_button(_qty_minus)
	_qty_minus.pressed.connect(func() -> void: _set_selected_qty(_selected_qty - 1))
	row.add_child(_qty_minus)

	_qty_label = Label.new()
	_qty_label.custom_minimum_size = Vector2(96, 38)
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_qty_label.add_theme_font_size_override("font_size", 18)
	_qty_label.add_theme_color_override("font_color", Color(0.22, 0.16, 0.12, 1.0))
	_qty_label.add_theme_stylebox_override("normal", _box(Color(0.92, 0.82, 0.62, 0.32), Color(0, 0, 0, 0), 0, 8, 0))
	row.add_child(_qty_label)

	_qty_plus = Button.new()
	_qty_plus.text = "+"
	_qty_plus.custom_minimum_size = Vector2(44, 38)
	_style_stepper_button(_qty_plus)
	_qty_plus.pressed.connect(func() -> void: _set_selected_qty(_selected_qty + 1))
	row.add_child(_qty_plus)

	_qty_max = Button.new()
	_qty_max.text = "最大"
	_qty_max.custom_minimum_size = Vector2(54, 38)
	_style_stepper_button(_qty_max)
	_qty_max.pressed.connect(func() -> void: _set_selected_qty(_selected_count()))
	row.add_child(_qty_max)
	return row

func _make_main_tab(parent: Node, text: String, key: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 48)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(func() -> void: _select_store(key))
	parent.add_child(button)
	return button

func _make_category_button(parent: Node, key: String, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(78, 42)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(func() -> void: _select_cat(key))
	parent.add_child(button)
	return button

func _select_store(key: String) -> void:
	_store_key = key
	_selected_id = ""
	_selected_qty = 1
	_refresh_tab_styles()
	_rebuild()

func _select_cat(key: String) -> void:
	_cat_key = key
	_selected_qty = 1
	_refresh_tab_styles()
	_rebuild()

func _refresh_tab_styles() -> void:
	if _main_buttons.size() >= 2:
		_style_main_tab(_main_buttons[0], _store_key == "backpack")
		_style_main_tab(_main_buttons[1], _store_key == "storehouse")
	for i in _cat_buttons.size():
		_style_category_tab(_cat_buttons[i], String(CATEGORIES[i]["key"]) == _cat_key)

func _rebuild() -> void:
	if _inv == null or _grid == null:
		return
	var db := _item_db()
	var store: Object = _current_store()
	for child in _grid.get_children():
		child.queue_free()

	if _selected_id != "" and (store.count(_selected_id) <= 0 or not _matches_current_category(_selected_id, db)):
		_selected_id = _next_visible_id(db)
		_selected_qty = 1

	var visible_stacks := _visible_stacks(db)
	for stack in visible_stacks:
		_grid.add_child(_make_item_slot(String(stack.get("id", "")), int(stack.get("count", 0)), db))

	var empty_slots: int = max(0, _store_capacity() - _store_used_slots())
	if _cat_key != "all":
		empty_slots = max(empty_slots, COLS * VISIBLE_ROWS - visible_stacks.size())
	for i in empty_slots:
		_grid.add_child(_make_empty_slot())

	_capacity_label.text = "%s容量 %d / %d" % [_store_display_name(), _store_used_slots(), _store_capacity()]
	_sort_button.disabled = _store_used_slots() <= 1
	_coin_label.text = "💰  %d" % _total_coins()
	_clamp_selected_qty()
	_refresh_detail(db)

func _visible_stacks(db: Node) -> Array:
	var result: Array = []
	for raw_stack in _current_store().stacks:
		var id := String(raw_stack.get("id", ""))
		if id == "coin":
			continue
		if _matches_current_category(id, db):
			result.append(raw_stack)
	return result

func _make_item_slot(id: String, count: int, db: Node) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(SLOT, SLOT)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_slot(button, id == _selected_id)

	var tex: Texture2D = db.icon_texture(id) if db != null else null
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var inset := SEED_ICON_INSET if _is_seed_item(id, db) else ITEM_ICON_INSET
		_apply_icon_inset(icon, inset)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)

	if count > 1:
		button.add_child(_make_count_badge(count))

	if db != null:
		button.tooltip_text = "%s\n数量 x %d" % [db.display_name(id), count]
	button.gui_input.connect(_on_slot_input.bind(id))
	return button

func _make_empty_slot() -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT, SLOT)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.add_theme_stylebox_override("panel", _box(Color(0.86, 0.74, 0.54, 0.30), Color(0.65, 0.48, 0.30, 0.34), 1, 10, 2))
	slot.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_selected_id = ""
			_selected_qty = 1
			_rebuild())
	return slot

func _make_count_badge(count: int) -> Control:
	var badge := Panel.new()
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -24
	badge.offset_top = -24
	badge.offset_right = -4
	badge.offset_bottom = -4
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _box(Color(0.22, 0.16, 0.12, 0.76), Color(0, 0, 0, 0), 0, 4, 0))
	var label := Label.new()
	label.text = str(count)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return badge

func _on_slot_input(event: InputEvent, id: String) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return
	get_viewport().set_input_as_handled()
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_select_item(id)
		_transfer_slot(id, 1)
		return
	if event.shift_pressed:
		_select_item(id)
		_transfer_slot(id, _selected_count())
		return
	_select_item(id)

func _select_item(id: String) -> void:
	_selected_id = id
	_selected_qty = 1
	_rebuild()

func _refresh_detail(db: Node) -> void:
	var has_selection := _selected_id != "" and _selected_count() > 0
	_detail_icon.visible = has_selection
	_detail_icon_holder.visible = true
	_qty_minus.disabled = not has_selection or _selected_qty <= 1
	_qty_plus.disabled = not has_selection or _selected_qty >= _selected_count()
	_qty_max.disabled = not has_selection or _selected_qty >= _selected_count()
	_transfer_button.disabled = not has_selection
	_transfer_button.text = "转入共享仓库" if _store_key == "backpack" else "取回背包"
	_qty_label.text = str(_selected_qty if has_selection else 0)

	for child in _detail_props.get_children():
		child.queue_free()

	if not has_selection:
		_detail_icon.texture = null
		_detail_name.text = "请选择一个物品"
		_detail_type.text = ""
		_detail_count.text = ""
		_detail_desc.text = "左侧点击物品后,这里会显示名称、数量、描述和转移操作。"
		return

	var item = db.get_def(_selected_id) if db != null else null
	var item_name: String = db.display_name(_selected_id) if db != null else _selected_id
	var category := str(item.category) if item != null else ""
	_apply_icon_inset(_detail_icon, DETAIL_SEED_ICON_INSET if category == "seed" else DETAIL_ICON_INSET)
	_detail_icon.texture = db.icon_texture(_selected_id) if db != null else null
	_detail_name.text = item_name
	_detail_type.text = _category_label(category)
	_detail_count.text = "持有数量: %d" % _selected_count()
	_detail_desc.text = _description_for(item, db)

	_add_prop_if_present("最大堆叠", str(item.max_stack) if item != null else "")
	if item != null:
		_add_prop_if_present("购买价", str(item.get_field("buy", "")))
		_add_prop_if_present("售价", str(item.get_field("sell", "")))
		_add_prop_if_present("作物 ID", str(item.get_field("crop_id", "")))
		_add_prop_if_present("归属", _ownership_label(str(item.get_field("ownership_type", ""))))

func _add_prop_if_present(label: String, value: String) -> void:
	if value == "" or value == "null":
		return
	var row := Label.new()
	row.text = "%s: %s" % [label, value]
	row.add_theme_font_size_override("font_size", 13)
	row.add_theme_color_override("font_color", Color(0.42, 0.32, 0.22, 0.86))
	_detail_props.add_child(row)

func _description_for(item: ItemDef, db: Node) -> String:
	if item == null:
		return "暂无描述。"
	var desc := str(item.get_field("description", ""))
	if desc != "":
		return desc
	if item.category == "seed":
		var crop_id := item.crop_id()
		var produce_id := "produce_" + crop_id
		if db != null and db.has(produce_id):
			return "成熟后可以收获%s。" % db.display_name(produce_id)
	if item.category == "produce":
		return "可用于料理、订单或家庭共享。"
	if item.category == "tool":
		return "用于照料农场和家庭花园。"
	return "暂无描述。"

func _set_selected_qty(value: int) -> void:
	_selected_qty = clampi(value, 1, max(1, _selected_count()))
	_refresh_detail(_item_db())

func _transfer_selected() -> void:
	if _selected_id == "":
		return
	_transfer_slot(_selected_id, _selected_qty)

func _transfer_slot(id: String, amount: int) -> void:
	if _inv == null or id == "":
		return
	var src: Object = _current_store()
	var before: int = src.count(id)
	var safe_amount := clampi(amount, 1, before)
	if safe_amount <= 0:
		return
	AudioManager.play_sfx("按钮")
	var moved := 0
	if _store_key == "backpack":
		moved = int(_inv.deposit(id, safe_amount))
	else:
		moved = int(_inv.withdraw(id, safe_amount))
	if moved <= 0:
		SceneManager._show_toast("目标仓库已满。")
		return
	SceneManager._show_toast(("已存入共享仓 x %d" if _store_key == "backpack" else "已取回背包 x %d") % moved)
	if src.count(id) <= 0:
		_selected_id = _next_visible_id(_item_db())
		_selected_qty = 1
	else:
		_selected_qty = clampi(_selected_qty, 1, src.count(id))
	_rebuild()

func _sort_current_store() -> void:
	if _inv == null:
		return
	if _store_key == "backpack":
		_inv.sort_backpack()
	else:
		_inv.sort_storehouse()
	SceneManager._show_toast("已整理%s。" % _store_display_name())
	_rebuild()

func _current_store() -> Object:
	return _inv.backpack if _store_key == "backpack" else _inv.storehouse

func _store_capacity() -> int:
	return int(_current_store().capacity)

func _store_used_slots() -> int:
	return int(_current_store().used_slots())

func _selected_count() -> int:
	if _inv == null or _selected_id == "":
		return 0
	return int(_current_store().count(_selected_id))

func _clamp_selected_qty() -> void:
	if _selected_id == "":
		_selected_qty = 1
		return
	_selected_qty = clampi(_selected_qty, 1, max(1, _selected_count()))

func _next_visible_id(db: Node) -> String:
	for stack in _visible_stacks(db):
		return String(stack.get("id", ""))
	return ""

func _matches_current_category(id: String, db: Node) -> bool:
	if _cat_key == "all":
		return true
	if db == null:
		return false
	var item = db.get_def(id)
	if item == null:
		return false
	for c in CATEGORIES:
		if String(c["key"]) == _cat_key:
			return (c["cats"] as Array).has(str(item.category))
	return false

func _is_seed_item(id: String, db: Node) -> bool:
	if db == null:
		return false
	var item = db.get_def(id)
	return item != null and str(item.category) == "seed"

func _apply_icon_inset(icon: Control, inset: int) -> void:
	icon.offset_left = inset
	icon.offset_top = inset
	icon.offset_right = -inset
	icon.offset_bottom = -inset

func _category_label(category: String) -> String:
	return String(CATEGORY_LABELS.get(category, category if category != "" else "物品"))

func _ownership_label(value: String) -> String:
	match value:
		"personal":
			return "个人"
		"household":
			return "家庭共享"
		"both":
			return "个人 / 家庭"
		_:
			return ""

func _store_display_name() -> String:
	return "背包" if _store_key == "backpack" else "共享仓库"

func _item_db() -> Node:
	return get_node_or_null("/root/ItemDB")

func _total_coins() -> int:
	if _inv == null:
		return 0
	return int(_inv.backpack.count("coin")) + int(_inv.storehouse.count("coin"))

func _style_main_tab(button: Button, active: bool) -> void:
	button.add_theme_color_override("font_color", Color(0.20, 0.14, 0.10, 1.0) if active else Color(0.48, 0.34, 0.22, 0.82))
	button.add_theme_stylebox_override("normal", _box(CREAM if active else Color(0.82, 0.66, 0.45, 0.55), BROWN if active else BROWN_SOFT, 2 if active else 1, 12, 0))
	button.add_theme_stylebox_override("hover", _box(Color(1.0, 0.96, 0.82, 0.98), HONEY, 2, 12, 0))
	button.add_theme_stylebox_override("pressed", _box(Color(0.94, 0.82, 0.58, 0.98), HONEY_DARK, 2, 12, 0))
	button.add_theme_stylebox_override("focus", _box(Color(1.0, 0.96, 0.82, 0.98), HONEY, 2, 12, 0))

func _style_category_tab(button: Button, active: bool) -> void:
	button.add_theme_color_override("font_color", Color(0.20, 0.14, 0.10, 1.0) if active else Color(0.40, 0.30, 0.22, 0.88))
	button.add_theme_stylebox_override("normal", _box(Color(0.98, 0.72, 0.24, 0.95) if active else PAPER, HONEY_DARK if active else BROWN_SOFT, 2 if active else 1, 12, 0))
	button.add_theme_stylebox_override("hover", _box(Color(1.0, 0.86, 0.44, 0.96), HONEY, 2, 12, 0))
	button.add_theme_stylebox_override("pressed", _box(Color(0.90, 0.58, 0.18, 0.98), HONEY_DARK, 2, 12, 0))
	button.add_theme_stylebox_override("focus", _box(Color(1.0, 0.86, 0.44, 0.96), HONEY, 2, 12, 0))

func _style_slot(button: Button, selected: bool) -> void:
	button.add_theme_stylebox_override("normal", _box(Color(1.0, 0.90, 0.66, 0.78), HONEY if selected else BROWN_SOFT, 3 if selected else 1, 10, 2))
	button.add_theme_stylebox_override("hover", _box(Color(1.0, 0.94, 0.76, 0.94), HONEY, 2, 10, 2))
	button.add_theme_stylebox_override("pressed", _box(Color(0.94, 0.80, 0.54, 0.94), HONEY_DARK, 2, 10, 1))
	button.add_theme_stylebox_override("focus", _box(Color(1.0, 0.94, 0.76, 0.94), HONEY, 2, 10, 2))

func _style_primary_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.58, 0.48, 0.36, 0.66))
	button.add_theme_stylebox_override("normal", _box(Color(0.94, 0.52, 0.08, 1.0), HONEY_DARK, 2, 12, 2))
	button.add_theme_stylebox_override("hover", _box(Color(1.0, 0.62, 0.12, 1.0), HONEY_DARK, 2, 12, 2))
	button.add_theme_stylebox_override("pressed", _box(Color(0.82, 0.42, 0.06, 1.0), HONEY_DARK, 2, 12, 1))
	button.add_theme_stylebox_override("disabled", _box(Color(0.80, 0.68, 0.48, 0.45), Color(0.58, 0.46, 0.30, 0.35), 1, 12, 0))

func _style_secondary_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.58, 0.48, 0.36, 0.66))
	button.add_theme_stylebox_override("normal", _box(Color(0.88, 0.53, 0.12, 0.95), HONEY_DARK, 2, 12, 2))
	button.add_theme_stylebox_override("hover", _box(Color(0.96, 0.62, 0.18, 0.98), HONEY_DARK, 2, 12, 2))
	button.add_theme_stylebox_override("pressed", _box(Color(0.76, 0.44, 0.08, 0.98), HONEY_DARK, 2, 12, 1))
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
