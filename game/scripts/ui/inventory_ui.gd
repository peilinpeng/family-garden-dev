extends CanvasLayer

## 背包 / 共享仓界面。按 I 开关;左键移 1,Shift+左键移整组。
## 在 CanvasLayer 上 → 不受昼夜染色影响。UI 完全由脚本构建,数据驱动刷新。

const COLS := 6
const SLOT := 46

var _root: PanelContainer
var _bp_grid: GridContainer
var _st_grid: GridContainer
var _inv: Node

func _ready() -> void:
	layer = 10
	_inv = get_node_or_null("/root/InventoryManager")
	_build()
	visible = false
	if _inv != null:
		_inv.backpack_changed.connect(_refresh)
		_inv.storehouse_changed.connect(_refresh)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_I:
		visible = not visible
		if visible:
			_refresh()
		get_viewport().set_input_as_handled()

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_root = PanelContainer.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # 吃掉面板内的点击,不漏给农场
	center.add_child(_root)

	var pad := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + m, 16)
	_root.add_child(pad)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pad.add_child(vb)

	var title := Label.new()
	title.text = "物品"
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	vb.add_child(cols)
	_bp_grid = _make_column(cols, "背包")
	_st_grid = _make_column(cols, "共享仓")

	var hint := Label.new()
	hint.text = "按 I 开关 · 左键移 1 · Shift+左键移整组 · 背包→共享仓(反之亦然)"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.6)
	vb.add_child(hint)

func _make_column(parent: Node, name: String) -> GridContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)
	var lbl := Label.new()
	lbl.text = name
	lbl.add_theme_font_size_override("font_size", 16)
	col.add_child(lbl)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)
	return grid

func _refresh() -> void:
	if _inv == null:
		return
	_fill(_bp_grid, _inv.backpack, true)
	_fill(_st_grid, _inv.storehouse, false)

func _fill(grid: GridContainer, inventory: Object, is_backpack: bool) -> void:
	for c in grid.get_children():
		c.queue_free()
	var db := get_node_or_null("/root/ItemDB")
	# 合并同 id 显示(每个 id 一格,显示总数)
	var totals: Dictionary = {}
	var order: Array = []
	for s in inventory.stacks:
		if not totals.has(s.id):
			order.append(s.id)
		totals[s.id] = int(totals.get(s.id, 0)) + int(s.count)
	for id in order:
		grid.add_child(_make_slot(id, totals[id], db, is_backpack))
	# 补空槽到容量,视觉整齐
	var empties: int = max(0, min(inventory.capacity, COLS * 4) - order.size())
	for i in range(empties):
		grid.add_child(_make_slot("", 0, null, is_backpack))

func _make_slot(id: String, n: int, db: Object, is_backpack: bool) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(SLOT, SLOT)
	btn.focus_mode = Control.FOCUS_NONE
	if id == "":
		btn.disabled = true
		return btn
	if db != null:
		var tex: Texture2D = db.icon_texture(id)
		if tex != null:
			var ic := TextureRect.new()
			ic.texture = tex
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(ic)
		btn.tooltip_text = db.display_name(id)
	var cnt := Label.new()
	cnt.text = str(n)
	cnt.add_theme_font_size_override("font_size", 12)
	cnt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	cnt.offset_left = -18
	cnt.offset_top = -16
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(cnt)
	btn.pressed.connect(_on_slot.bind(id, is_backpack))
	return btn

func _on_slot(id: String, is_backpack: bool) -> void:
	if _inv == null:
		return
	AudioManager.play_sfx("按钮")
	var whole := Input.is_key_pressed(KEY_SHIFT)
	var src: Object = _inv.backpack if is_backpack else _inv.storehouse
	var amount: int = src.count(id) if whole else 1
	if is_backpack:
		_inv.deposit(id, amount)
	else:
		_inv.withdraw(id, amount)
