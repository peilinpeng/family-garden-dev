extends HUDPanel
class_name InventoryPanel

## 背包面板(全局 HUD 版)。原来是只挂在 Farm、按 I 开的 CanvasLayer 并列双栏,现改成:
##   主 tab:我的背包 / 家庭共享仓库(切换数据源 InventoryManager.backpack / .storehouse)
##   分类子 tab:全部 / 种子 / 食材 / 工具 / 料理 / 装饰 / 记忆物品(映射现有类别 + 空占位)
## 交互沿用现有"点一下转移"(背包→共享仓 / 共享仓→背包,Shift 整组),不做拖拽/拆分/交易。
## 由 GameHUD 承载,底部背包图标 + I 键均可开。

const COLS := 8
const SLOT := 48

# 分类 tab → 物品 category 映射。空数组表示"接受全部(除货币)";已知无数据的分类会显示占位。
const CATEGORIES := [
	{"key": "all", "label": "全部"},
	{"key": "seed", "label": "种子"},
	{"key": "produce", "label": "食材"},
	{"key": "tool", "label": "工具"},
	{"key": "dish", "label": "料理"},      # 暂无数据,占位
	{"key": "decor", "label": "装饰"},     # 暂无数据,占位
	{"key": "memory", "label": "记忆物品"}, # 暂无数据,占位
]

var _store_key := "backpack"
var _cat_key := "all"
var _main_buttons: Array = []
var _cat_buttons: Array = []
var _grid: GridContainer
var _scroll: ScrollContainer
var _empty_label: Label
var _currency_label: Label
var _inv: Node

func _init() -> void:
	panel_title = "物品 / Inventory"
	card_size = Vector2(720, 520)

func _build_content() -> void:
	_inv = get_node_or_null("/root/InventoryManager")

	# ---- 主 tab:我的背包 / 家庭共享仓库 ----
	var main_tabs := HBoxContainer.new()
	main_tabs.add_theme_constant_override("separation", 10)
	content_root.add_child(main_tabs)
	_main_buttons.append(_make_tab(main_tabs, "🎒 我的背包", func() -> void: _select_store("backpack")))
	_main_buttons.append(_make_tab(main_tabs, "🏠 家庭共享仓库", func() -> void: _select_store("storehouse")))

	# ---- 分类子 tab ----
	var cat_tabs := HBoxContainer.new()
	cat_tabs.add_theme_constant_override("separation", 6)
	content_root.add_child(cat_tabs)
	for c in CATEGORIES:
		var key: String = c["key"]
		_cat_buttons.append(_make_tab(cat_tabs, c["label"], func() -> void: _select_cat(key), 13))

	# ---- 货币行(金币单独展示,不塞进网格)----
	_currency_label = Label.new()
	_currency_label.add_theme_font_size_override("font_size", 14)
	_currency_label.add_theme_color_override("font_color", Color(0.55, 0.42, 0.15, 1.0))
	content_root.add_child(_currency_label)

	# ---- 物品网格(可滚动)+ 空状态 ----
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_root.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)

	_empty_label = Label.new()
	_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override("font_size", 15)
	_empty_label.add_theme_color_override("font_color", Color(0.52, 0.42, 0.30, 0.85))
	content_root.add_child(_empty_label)

	# ---- 底部提示 ----
	var hint := Label.new()
	hint.text = "左键移 1 · Shift+左键移整组 · 背包 ⇄ 共享仓 · 按 I 或 Esc 关闭"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.50, 0.40, 0.28, 0.7))
	content_root.add_child(hint)

	# 库存变化即时刷新(节点释放时自动断开)。
	if _inv != null:
		_inv.backpack_changed.connect(_rebuild)
		_inv.storehouse_changed.connect(_rebuild)

	_refresh_tab_styles()
	_rebuild()

func _select_store(key: String) -> void:
	_store_key = key
	_refresh_tab_styles()
	_rebuild()

func _select_cat(key: String) -> void:
	_cat_key = key
	_refresh_tab_styles()
	_rebuild()

func _make_tab(parent: Node, text: String, on_select: Callable, font_size: int = 15) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 34)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(on_select)
	parent.add_child(b)
	return b

func _refresh_tab_styles() -> void:
	if _main_buttons.size() >= 2:
		_style_tab(_main_buttons[0], _store_key == "backpack")
		_style_tab(_main_buttons[1], _store_key == "storehouse")
	for i in _cat_buttons.size():
		_style_tab(_cat_buttons[i], CATEGORIES[i]["key"] == _cat_key)

func _style_tab(b: Button, active: bool) -> void:
	b.add_theme_color_override("font_color", Color(0.24, 0.18, 0.12, 1.0) if active else Color(0.42, 0.34, 0.25, 0.95))
	b.add_theme_color_override("font_hover_color", Color(0.18, 0.13, 0.09, 1.0))
	var normal := _tab_box(active, false)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", _tab_box(active, true))
	b.add_theme_stylebox_override("pressed", _tab_box(true, false))
	b.add_theme_stylebox_override("focus", _tab_box(active, true))

func _tab_box(active: bool, hover: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	if active:
		box.bg_color = Color(0.98, 0.90, 0.66, 0.98)
		box.border_color = Color(0.80, 0.55, 0.25, 1.0)
		box.set_border_width_all(2)
	else:
		box.bg_color = Color(1.0, 0.96, 0.84, 0.85) if hover else Color(1.0, 0.95, 0.82, 0.55)
		box.border_color = Color(0.66, 0.50, 0.32, 0.6)
		box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 12
	box.content_margin_right = 12
	return box

func _rebuild() -> void:
	if _grid == null or _inv == null:
		return
	for c in _grid.get_children():
		c.queue_free()

	var store: Object = _inv.backpack if _store_key == "backpack" else _inv.storehouse
	var db := get_node_or_null("/root/ItemDB")

	# 合并同 id → 总数,保持出现顺序。
	var totals: Dictionary = {}
	var order: Array = []
	var coins := 0
	for s in store.stacks:
		var id: String = s.id
		var cat := _category_of(db, id)
		if cat == "currency":
			coins += int(s.count)
			continue
		if not _matches_cat(cat):
			continue
		if not totals.has(id):
			order.append(id)
		totals[id] = int(totals.get(id, 0)) + int(s.count)

	# 货币行(仅在"全部/无过滤"或本仓有货币时展示;分类过滤到非货币时也照常显示总额)。
	_currency_label.text = "💰 金币 x %d" % coins
	_currency_label.visible = coins > 0

	if order.is_empty():
		_scroll.visible = false
		_empty_label.visible = true
		_empty_label.text = _empty_text()
		return

	_scroll.visible = true
	_empty_label.visible = false
	for id in order:
		_grid.add_child(_make_slot(id, totals[id], db))

func _category_of(db: Object, id: String) -> String:
	if db == null:
		return ""
	var d = db.get_def(id)
	if d == null:
		return ""
	return str(d.category)

func _matches_cat(cat: String) -> bool:
	if _cat_key == "all":
		return true
	return cat == _cat_key

func _empty_text() -> String:
	var store_name := "背包" if _store_key == "backpack" else "共享仓库"
	if _cat_key == "all":
		return "这个%s还什么都没有～" % store_name
	var label := "该分类"
	for c in CATEGORIES:
		if c["key"] == _cat_key:
			label = c["label"]
			break
	return "%s里暂时没有「%s」" % [store_name, label]

func _make_slot(id: String, n: int, db: Object) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(SLOT, SLOT)
	btn.focus_mode = Control.FOCUS_ALL
	HUDPanel._style_soft_button(btn)
	if db != null:
		var tex: Texture2D = db.icon_texture(id)
		if tex != null:
			var ic := TextureRect.new()
			ic.texture = tex
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ic.offset_left = 4
			ic.offset_top = 4
			ic.offset_right = -4
			ic.offset_bottom = -4
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(ic)
		# tooltip:物品名 + 数量(+ 描述,若数据里有)。
		var tip: String = db.display_name(id) + "\n数量 x " + str(n)
		var d = db.get_def(id)
		if d != null:
			var desc := str(d.get_field("desc", ""))
			if desc != "":
				tip += "\n" + desc
		btn.tooltip_text = tip
	# 数量角标
	if n > 1:
		var cnt := Label.new()
		cnt.text = str(n)
		cnt.add_theme_font_size_override("font_size", 12)
		cnt.add_theme_color_override("font_color", Color(0.20, 0.15, 0.10, 1.0))
		cnt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		cnt.offset_left = -18
		cnt.offset_top = -18
		cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(cnt)
	btn.pressed.connect(_on_slot.bind(id))
	return btn

func _on_slot(id: String) -> void:
	if _inv == null:
		return
	AudioManager.play_sfx("按钮")
	var whole := Input.is_key_pressed(KEY_SHIFT)
	var src: Object = _inv.backpack if _store_key == "backpack" else _inv.storehouse
	var amount: int = src.count(id) if whole else 1
	if _store_key == "backpack":
		_inv.deposit(id, amount)   # 背包 → 共享仓
	else:
		_inv.withdraw(id, amount)  # 共享仓 → 背包
