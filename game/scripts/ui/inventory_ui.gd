extends CanvasLayer

const COLS := 6
const SLOT_SIZE := 58
const BACKPACK := "backpack"
const STOREHOUSE := "storehouse"
const BACKPACK_ICON := "res://assets/ui/icons/icon_backpack.png"

var _inv: Node = null
var _db: Node = null
var _overlay: Control = null
var _root: Panel = null
var _hotbar_grid: GridContainer = null
var _backpack_grid: GridContainer = null
var _storehouse_grid: GridContainer = null
var _detail_title: Label = null
var _detail_meta: Label = null
var _detail_body: Label = null
var _move_one_button: Button = null
var _move_stack_button: Button = null
var _selected_id := ""
var _selected_source := BACKPACK

func _ready() -> void:
	layer = 40
	_inv = get_node_or_null("/root/InventoryManager")
	_db = get_node_or_null("/root/ItemDB")
	_build()
	hide_inventory()
	if _inv != null:
		_inv.backpack_changed.connect(_refresh)
		_inv.storehouse_changed.connect(_refresh)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		toggle()
		get_viewport().set_input_as_handled()
	if is_open() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_inventory()
		get_viewport().set_input_as_handled()

func is_open() -> bool:
	return _overlay != null and _overlay.visible

func toggle() -> void:
	if is_open():
		hide_inventory()
	else:
		show_inventory()

func show_inventory() -> void:
	if _overlay == null:
		return
	_overlay.visible = true
	_refresh()

func hide_inventory() -> void:
	if _overlay != null:
		_overlay.visible = false

func _build() -> void:
	_build_side_bar()

	_overlay = Control.new()
	_overlay.name = "InventoryOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.06, 0.04, 0.18)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(shade)

	_root = Panel.new()
	_root.position = Vector2(170, 78)
	_root.size = Vector2(940, 560)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(_root)
	_overlay.add_child(_root)

	var title := Label.new()
	title.text = "背包"
	title.position = Vector2(34, 24)
	title.size = Vector2(360, 34)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.22, 0.18, 0.13, 1.0))
	_root.add_child(title)

	var hint := Label.new()
	hint.text = "按 I 打开或关闭。选中物品后可以转移。"
	hint.position = Vector2(36, 60)
	hint.size = Vector2(600, 24)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.42, 0.34, 0.26, 0.9))
	_root.add_child(hint)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.position = Vector2(884, 22)
	close_button.size = Vector2(34, 30)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(hide_inventory)
	_root.add_child(close_button)

	_backpack_grid = _make_inventory_column("背包", Vector2(34, 104), BACKPACK, 24)
	_storehouse_grid = _make_inventory_column("共享仓", Vector2(422, 104), STOREHOUSE, 24)
	_build_detail_panel()

func _build_side_bar() -> void:
	var bar := Panel.new()
	bar.position = Vector2(1214, 92)
	bar.size = Vector2(54, 580)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.16, 0.12, 0.08, 0.20)
	bar_style.border_color = Color(0.60, 0.43, 0.25, 0.45)
	bar_style.set_border_width_all(1)
	bar_style.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("panel", bar_style)
	add_child(bar)

	var quick_button := Button.new()
	quick_button.text = ""
	quick_button.icon = load(BACKPACK_ICON) as Texture2D
	quick_button.expand_icon = true
	quick_button.tooltip_text = "打开背包"
	quick_button.position = Vector2(1219, 100)
	quick_button.size = Vector2(44, 42)
	quick_button.focus_mode = Control.FOCUS_NONE
	quick_button.pressed.connect(toggle)
	add_child(quick_button)

	_hotbar_grid = GridContainer.new()
	_hotbar_grid.position = Vector2(1220, 154)
	_hotbar_grid.columns = 1
	_hotbar_grid.add_theme_constant_override("v_separation", 7)
	add_child(_hotbar_grid)

func _make_inventory_column(label_text: String, pos: Vector2, source: String, visible_slots: int) -> GridContainer:
	var label := Label.new()
	label.text = label_text
	label.position = pos
	label.size = Vector2(320, 28)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.25, 0.20, 0.15, 1.0))
	_root.add_child(label)

	var scroll := ScrollContainer.new()
	scroll.position = pos + Vector2(0, 34)
	scroll.size = Vector2(COLS * (SLOT_SIZE + 6), 252)
	_root.add_child(scroll)

	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)

	var count_label := Label.new()
	count_label.name = source + "_count"
	count_label.position = pos + Vector2(210, 2)
	count_label.size = Vector2(142, 24)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 13)
	count_label.add_theme_color_override("font_color", Color(0.45, 0.37, 0.28, 0.9))
	_root.add_child(count_label)
	return grid

func _build_detail_panel() -> void:
	var panel := Panel.new()
	panel.position = Vector2(34, 432)
	panel.size = Vector2(872, 92)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.89, 0.72, 0.55)
	style.border_color = Color(0.58, 0.44, 0.28, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	_detail_title = Label.new()
	_detail_title.position = Vector2(54, 446)
	_detail_title.size = Vector2(260, 28)
	_detail_title.add_theme_font_size_override("font_size", 19)
	_detail_title.add_theme_color_override("font_color", Color(0.20, 0.17, 0.12, 1.0))
	_root.add_child(_detail_title)

	_detail_meta = Label.new()
	_detail_meta.position = Vector2(54, 476)
	_detail_meta.size = Vector2(260, 24)
	_detail_meta.add_theme_font_size_override("font_size", 13)
	_detail_meta.add_theme_color_override("font_color", Color(0.45, 0.36, 0.25, 0.95))
	_root.add_child(_detail_meta)

	_detail_body = Label.new()
	_detail_body.position = Vector2(330, 446)
	_detail_body.size = Vector2(310, 58)
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_detail_body.add_theme_font_size_override("font_size", 14)
	_detail_body.add_theme_color_override("font_color", Color(0.28, 0.24, 0.18, 1.0))
	_root.add_child(_detail_body)

	_move_one_button = Button.new()
	_move_one_button.text = "转移 1 个"
	_move_one_button.position = Vector2(668, 446)
	_move_one_button.size = Vector2(96, 38)
	_move_one_button.pressed.connect(_move_selected.bind(false))
	_root.add_child(_move_one_button)

	_move_stack_button = Button.new()
	_move_stack_button.text = "转移整组"
	_move_stack_button.position = Vector2(776, 446)
	_move_stack_button.size = Vector2(104, 38)
	_move_stack_button.pressed.connect(_move_selected.bind(true))
	_root.add_child(_move_stack_button)

func _refresh() -> void:
	if _inv == null:
		return
	_fill_grid(_backpack_grid, _inv.backpack, BACKPACK, 24)
	_fill_grid(_storehouse_grid, _inv.storehouse, STOREHOUSE, 24)
	_fill_hotbar()
	_update_count_label(BACKPACK, _inv.backpack)
	_update_count_label(STOREHOUSE, _inv.storehouse)
	if _selected_id != "" and _source_inventory(_selected_source).count(_selected_id) <= 0:
		_selected_id = ""
	_update_detail()

func _fill_grid(grid: GridContainer, inventory: Object, source: String, visible_slots: int) -> void:
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()
	var totals := _totals_for(inventory)
	var order: Array = totals.keys()
	order.sort()
	for id in order:
		grid.add_child(_make_slot(str(id), int(totals[id]), source))
	var empties: int = max(0, visible_slots - order.size())
	for i in range(empties):
		grid.add_child(_make_empty_slot())

func _make_slot(id: String, count: int, source: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = _item_name(id)
	button.pressed.connect(_select_item.bind(id, source))
	if id == _selected_id and source == _selected_source:
		button.modulate = Color(1.0, 0.92, 0.62, 1.0)

	var icon := TextureRect.new()
	icon.position = Vector2(7, 6)
	icon.size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _db != null:
		icon.texture = _db.icon_texture(id)
	button.add_child(icon)

	if icon.texture == null:
		var fallback := Label.new()
		fallback.text = _fallback_icon_text(id)
		fallback.position = Vector2(4, 12)
		fallback.size = Vector2(50, 24)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 15)
		fallback.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16, 1.0))
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(fallback)

	var count_label := Label.new()
	count_label.text = str(count)
	count_label.position = Vector2(4, 39)
	count_label.size = Vector2(48, 16)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color(0.12, 0.10, 0.08, 1.0))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(count_label)
	return button

func _make_empty_slot() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	button.disabled = true
	return button

func _fill_hotbar() -> void:
	if _hotbar_grid == null or _inv == null:
		return
	for child in _hotbar_grid.get_children():
		child.queue_free()
	var totals := _totals_for(_inv.backpack)
	var order: Array = totals.keys()
	order.sort()
	for i in range(9):
		if i < order.size():
			_hotbar_grid.add_child(_make_hotbar_slot(str(order[i]), int(totals[order[i]])))
		else:
			_hotbar_grid.add_child(_make_hotbar_empty_slot())

func _make_hotbar_slot(id: String, count: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(42, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = _item_name(id)
	button.pressed.connect(_select_item.bind(id, BACKPACK))

	var icon := TextureRect.new()
	icon.position = Vector2(6, 5)
	icon.size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _db != null:
		icon.texture = _db.icon_texture(id)
	button.add_child(icon)

	if icon.texture == null:
		var fallback := Label.new()
		fallback.text = _fallback_icon_text(id)
		fallback.position = Vector2(2, 10)
		fallback.size = Vector2(38, 18)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 12)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(fallback)

	var count_label := Label.new()
	count_label.text = str(count)
	count_label.position = Vector2(2, 27)
	count_label.size = Vector2(36, 13)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(count_label)
	return button

func _make_hotbar_empty_slot() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(42, 42)
	button.disabled = true
	return button

func _select_item(id: String, source: String) -> void:
	_selected_id = id
	_selected_source = source
	_refresh()

func _move_selected(whole_stack: bool) -> void:
	if _inv == null or _selected_id == "":
		return
	var source_inv: Object = _source_inventory(_selected_source)
	var amount: int = source_inv.count(_selected_id) if whole_stack else 1
	if amount <= 0:
		return
	if _selected_source == BACKPACK:
		_inv.deposit(_selected_id, amount)
	else:
		_inv.withdraw(_selected_id, amount)

func _update_detail() -> void:
	var has_selection := _selected_id != ""
	_move_one_button.disabled = not has_selection
	_move_stack_button.disabled = not has_selection
	if not has_selection:
		_detail_title.text = "选择一个物品"
		_detail_meta.text = "背包会自动保存。"
		_detail_body.text = "农场收获会进入背包；这里可以把物品转入家庭共享仓。"
		return
	var inv: Object = _source_inventory(_selected_source)
	var source_label := "背包" if _selected_source == BACKPACK else "共享仓"
	_detail_title.text = _item_name(_selected_id)
	_detail_meta.text = "%s - 数量 %d - %s" % [source_label, inv.count(_selected_id), _item_category(_selected_id)]
	_detail_body.text = _item_description(_selected_id)

func _update_count_label(source: String, inventory: Object) -> void:
	var label := _root.get_node_or_null(source + "_count") as Label
	if label != null:
		label.text = "%d / %d 格" % [inventory.used_slots(), inventory.capacity]

func _source_inventory(source: String) -> Object:
	return _inv.backpack if source == BACKPACK else _inv.storehouse

func _totals_for(inventory: Object) -> Dictionary:
	var totals := {}
	for stack in inventory.stacks:
		var id := str(stack.get("id", ""))
		if id == "":
			continue
		totals[id] = int(totals.get(id, 0)) + int(stack.get("count", 0))
	return totals

func _item_name(id: String) -> String:
	return _db.display_name(id) if _db != null else id

func _item_category(id: String) -> String:
	if _db == null or not _db.has(id):
		return "物品"
	var def: ItemDef = _db.get_def(id)
	match def.category:
		"seed":
			return "种子"
		"produce":
			return "作物"
		"tool":
			return "工具"
		"gift":
			return "礼物"
		"currency":
			return "货币"
		_:
			return def.category

func _item_description(id: String) -> String:
	if _db == null or not _db.has(id):
		return "可收纳的物品。"
	var def: ItemDef = _db.get_def(id)
	match def.category:
		"seed":
			return "可以在农场种下，成熟后收获作物。"
		"produce":
			return "农场收获物，可出售或作为礼物。"
		"tool":
			return "家庭农场工具。"
		"gift":
			return "可以送给家人的礼物。"
		"currency":
			return "家庭花园里的通用货币。"
		_:
			return "可收纳的物品。"

func _fallback_icon_text(id: String) -> String:
	if id.begins_with("seed_"):
		return "种"
	if id.begins_with("produce_"):
		return "果"
	if id.begins_with("tool_"):
		return "具"
	if id == "coin":
		return "$"
	return "物"

func _apply_panel_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.95, 0.82, 0.97)
	style.border_color = Color(0.58, 0.42, 0.25, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.18, 0.10, 0.04, 0.22)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
