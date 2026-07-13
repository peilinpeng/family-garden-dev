extends HUDPanel
class_name RecipePanel

## 制作面板(炉灶 StoveArea / 备餐台 PrepTableArea 共用,按 station 过滤配方)。
## 左=配方列表(可做正常/材料不足灰化),右=选中配方详情(图标/名/描述/材料 have-need/制作按钮)。
## 库存一律走家庭共享仓;含"获取测试食材"开发按钮。逻辑全在 KitchenManager,这里只做 UI。

var station: String = "stove"   ## 打开前由厨房交互设置;决定显示哪个台子的配方
var _selected_id: String = ""
var _list_box: VBoxContainer
var _detail_box: VBoxContainer

func _init() -> void:
	panel_title = "灶台 · 做饭"
	card_size = Vector2(760, 520)

func _build_content() -> void:
	# 顶部:共享仓标注 + 测试发料
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content_root.add_child(header)
	var src := Label.new()
	src.text = "🏠 使用：家庭共享仓库"
	src.add_theme_font_size_override("font_size", 14)
	src.add_theme_color_override("font_color", Color(0.40, 0.33, 0.25, 1.0))
	src.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	src.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(src)
	var dev := Button.new()
	dev.text = "🧪 获取测试食材"
	dev.custom_minimum_size = Vector2(150, 34)
	HUDPanel._style_soft_button(dev)
	dev.pressed.connect(func() -> void:
		KitchenManager.grant_test_ingredients()
		_rebuild()
		SceneManager._show_toast("已补齐测试食材到家庭共享仓 🧺"))
	header.add_child(dev)

	# 主体:左列表 + 右详情
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_root.add_child(body)

	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(250, 0)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(left_scroll)
	_list_box = VBoxContainer.new()
	_list_box.custom_minimum_size = Vector2(250, 0)
	_list_box.add_theme_constant_override("separation", 6)
	left_scroll.add_child(_list_box)

	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 10)
	body.add_child(_detail_box)

	var recipes := RecipeDB.by_station(station)
	if _selected_id == "" and recipes.size() > 0:
		_selected_id = recipes[0].id
	_rebuild()

func _rebuild() -> void:
	_rebuild_list()
	_rebuild_detail()

func _rebuild_list() -> void:
	for c in _list_box.get_children():
		c.queue_free()
	var recipes := RecipeDB.by_station(station)
	if recipes.is_empty():
		var empty := Label.new()
		empty.text = "这个台子暂时没有可做的食谱"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.5, 0.42, 0.3, 0.85))
		_list_box.add_child(empty)
		return
	for r in recipes:
		var can_make: bool = KitchenManager.can_craft(r.id).ok
		var btn := Button.new()
		btn.text = ("✓ " if can_make else "· ") + r.display_name
		btn.custom_minimum_size = Vector2(0, 40)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		HUDPanel._style_soft_button(btn)
		HUDPanel._mark_active(btn, r.id == _selected_id)
		if not can_make:
			btn.modulate = Color(1, 1, 1, 0.5)   # 材料不足灰化
		var rid: String = r.id
		btn.pressed.connect(func() -> void:
			_selected_id = rid
			_rebuild())
		_list_box.add_child(btn)

func _rebuild_detail() -> void:
	for c in _detail_box.get_children():
		c.queue_free()
	var recipe: RecipeDef = RecipeDB.get_def(_selected_id)
	if recipe == null:
		return

	var titlerow := HBoxContainer.new()
	titlerow.add_theme_constant_override("separation", 10)
	_detail_box.add_child(titlerow)
	titlerow.add_child(_icon_rect(ItemDB.icon_texture(recipe.output_item_id), 48))
	var nm := Label.new()
	nm.text = recipe.display_name
	nm.add_theme_font_size_override("font_size", 20)
	nm.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 1.0))
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titlerow.add_child(nm)

	var desc := Label.new()
	desc.text = recipe.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(420, 0)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.40, 0.33, 0.25, 1.0))
	_detail_box.add_child(desc)

	var mat_title := Label.new()
	mat_title.text = "材料（家庭共享仓）"
	mat_title.add_theme_font_size_override("font_size", 15)
	mat_title.add_theme_color_override("font_color", Color(0.30, 0.24, 0.17, 1.0))
	_detail_box.add_child(mat_title)
	for ing in recipe.ingredients:
		var iid: String = str(ing.get("id", ""))
		var need: int = int(ing.get("qty", 1))
		var have: int = InventoryManager.storehouse.count(iid)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_icon_rect(ItemDB.icon_texture(iid), 28))
		var ml := Label.new()
		ml.text = "%s    %d / %d" % [ItemDB.display_name(iid), have, need]
		if have < need:
			ml.text += " · " + _source_hint(iid)
		ml.add_theme_font_size_override("font_size", 14)
		ml.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 1.0) if have >= need else Color(0.72, 0.28, 0.20, 1.0))
		ml.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ml)
		_detail_box.add_child(row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_detail_box.add_child(spacer)

	var chk: Dictionary = KitchenManager.can_craft(recipe.id)
	var craft_btn := Button.new()
	craft_btn.custom_minimum_size = Vector2(0, 44)
	HUDPanel._style_soft_button(craft_btn)
	if chk.ok:
		craft_btn.text = "制作 → %s ×%d" % [ItemDB.display_name(recipe.output_item_id), recipe.output_quantity]
		craft_btn.pressed.connect(func() -> void:
			if KitchenManager.craft(recipe.id):
				SceneManager._show_toast("做好了：%s ✨" % recipe.display_name)
				_rebuild())
	else:
		craft_btn.text = "材料不足"
		craft_btn.disabled = true
	_detail_box.add_child(craft_btn)
	if not chk.ok:
		var miss_names: Array = []
		for m in chk.missing:
			var missing_id := str(m.id)
			miss_names.append("%s×%d（%s）" % [
				ItemDB.display_name(missing_id),
				int(m.need) - int(m.have),
				_source_hint(missing_id)
			])
		var miss := Label.new()
		miss.text = "还缺：" + "、".join(miss_names)
		miss.add_theme_font_size_override("font_size", 13)
		miss.add_theme_color_override("font_color", Color(0.72, 0.28, 0.20, 0.95))
		_detail_box.add_child(miss)

func _icon_rect(tex: Texture2D, sz: int) -> TextureRect:
	var r := TextureRect.new()
	r.custom_minimum_size = Vector2(sz, sz)
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r

func _source_hint(item_id: String) -> String:
	var item: ItemDef = ItemDB.get_def(item_id) if ItemDB != null else null
	if item != null:
		var hint := str(item.get_field("source_hint", ""))
		if hint != "":
			return hint
		if item.category == "produce" and item.crop_id() != "":
			return "农场种植收获"
	match item_id:
		"egg":
			return "鸡舍收集"
		"milk":
			return "牛棚收集"
		_:
			return "旅行/地图奖励或后续活动"
