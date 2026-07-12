extends HUDPanel
class_name MealTablePanel

## 餐桌(DiningTableArea)。3 个逻辑槽位(主食/菜品/饮品甜点),从家庭共享仓选成品料理放入,
## "完成晚餐"至少 1 份则扣除并 emit KitchenManager.meal_completed。回忆/照片/留言留作 hook。

const SLOT_LABELS := ["主食", "菜品", "饮品 / 甜点"]

var _slots: Array = ["", "", ""]   ## 每个槽位放的 dish id("" = 空)
var _slot_box: HBoxContainer
var _dish_box: VBoxContainer

func _init() -> void:
	panel_title = "餐桌 · 家庭晚餐"
	card_size = Vector2(680, 520)

func _build_content() -> void:
	var hint := Label.new()
	hint.text = "从家庭共享仓挑选做好的料理，摆上餐桌吧。"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.40, 0.33, 0.25, 1.0))
	content_root.add_child(hint)

	# 三个槽位
	_slot_box = HBoxContainer.new()
	_slot_box.add_theme_constant_override("separation", 12)
	_slot_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content_root.add_child(_slot_box)

	# 可选料理
	var dish_title := Label.new()
	dish_title.text = "🍽️ 共享仓里的料理（点一下摆到空槽）"
	dish_title.add_theme_font_size_override("font_size", 14)
	dish_title.add_theme_color_override("font_color", Color(0.30, 0.24, 0.17, 1.0))
	content_root.add_child(dish_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_root.add_child(scroll)
	_dish_box = VBoxContainer.new()
	_dish_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dish_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_dish_box)

	# 完成晚餐
	var done := Button.new()
	done.text = "🎉 完成晚餐"
	done.custom_minimum_size = Vector2(0, 44)
	HUDPanel._style_soft_button(done)
	done.pressed.connect(_on_complete)
	content_root.add_child(done)

	_refresh()

func _refresh() -> void:
	_rebuild_slots()
	_rebuild_dishes()

func _rebuild_slots() -> void:
	for c in _slot_box.get_children():
		c.queue_free()
	for i in 3:
		_slot_box.add_child(_slot_widget(i))

func _slot_widget(idx: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var slot := Button.new()
	slot.custom_minimum_size = Vector2(120, 96)
	HUDPanel._style_soft_button(slot)
	var did: String = _slots[idx]
	if did == "":
		slot.text = "＋"
		slot.add_theme_font_size_override("font_size", 28)
	else:
		slot.text = ItemDB.display_name(did)
		slot.icon = ItemDB.icon_texture(did)
		slot.expand_icon = true
		slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		slot.pressed.connect(func() -> void:   # 点已放的槽位=取回
			_slots[idx] = ""
			_refresh())
	box.add_child(slot)

	var lbl := Label.new()
	lbl.text = SLOT_LABELS[idx]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.42, 0.34, 0.25, 0.95))
	box.add_child(lbl)
	return box

func _rebuild_dishes() -> void:
	for c in _dish_box.get_children():
		c.queue_free()
	# 可用 = 共享仓里的 dish 数量 − 已摆放数量
	var placed_count: Dictionary = {}
	for did in _slots:
		if did != "":
			placed_count[did] = int(placed_count.get(did, 0)) + 1
	var shown := 0
	for s in InventoryManager.storehouse.stacks:
		var iid: String = str(s.get("id", ""))
		var def: ItemDef = ItemDB.get_def(iid)
		if def == null or def.category != "dish":
			continue
		var avail: int = int(s.get("count", 0)) - int(placed_count.get(iid, 0))
		if avail <= 0:
			continue
		_dish_box.add_child(_dish_row(iid, avail))
		shown += 1
	if shown == 0:
		var empty := Label.new()
		empty.text = "共享仓里还没有做好的料理，先去灶台做几道菜吧～"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(560, 0)
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.5, 0.42, 0.3, 0.85))
		_dish_box.add_child(empty)

func _dish_row(iid: String, avail: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.texture = ItemDB.icon_texture(iid)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var lbl := Label.new()
	lbl.text = "%s   ×%d" % [ItemDB.display_name(iid), avail]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.26, 0.21, 0.15, 1.0))
	row.add_child(lbl)
	var btn := Button.new()
	btn.text = "摆上"
	btn.custom_minimum_size = Vector2(72, 34)
	HUDPanel._style_soft_button(btn)
	btn.pressed.connect(func() -> void:
		var slot := _first_empty_slot()
		if slot >= 0:
			_slots[slot] = iid
			_refresh()
		else:
			SceneManager._show_toast("餐桌满了，先取下一道再摆"))
	row.add_child(btn)
	return row

func _first_empty_slot() -> int:
	for i in 3:
		if _slots[i] == "":
			return i
	return -1

func _on_complete() -> void:
	var dishes: Array = []
	for did in _slots:
		if did != "":
			dishes.append(did)
	if dishes.is_empty():
		SceneManager._show_toast("先摆上至少一道料理吧~")
		return
	if KitchenManager.complete_meal(dishes):
		SceneManager._show_toast("家庭晚餐已准备好 🍽️")
		close_requested.emit()
