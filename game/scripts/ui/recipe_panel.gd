extends HUDPanel
class_name RecipePanel

## 制作面板(炉灶 StoveArea / 备餐台 PrepTableArea 共用)。
## UI 分成三层:顶部 AI 主操作、AI 结果条、固定菜谱列表 + 详情。

const COLOR_TEXT := Color(0.24, 0.18, 0.12, 1.0)
const COLOR_MUTED := Color(0.47, 0.37, 0.25, 0.9)
const COLOR_WARN := Color(0.72, 0.26, 0.18, 1.0)
const COLOR_GOOD := Color(0.25, 0.48, 0.27, 1.0)

var station: String = "stove"
var _selected_id: String = ""
var _latest_ai_dish: Dictionary = {}
var _ai_state: String = "idle"
var _ai_message: String = ""
var _ai_error_code: String = ""

var _ai_result_root: VBoxContainer
var _list_box: VBoxContainer
var _detail_box: VBoxContainer

func _init() -> void:
	panel_title = "灶台 · 做饭"
	card_size = Vector2(820, 560)

func _build_content() -> void:
	content_root.add_child(_build_header())

	_ai_result_root = VBoxContainer.new()
	_ai_result_root.add_theme_constant_override("separation", 0)
	content_root.add_child(_ai_result_root)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_root.add_child(body)

	body.add_child(_build_recipe_list_panel())
	body.add_child(_build_detail_panel())

	var recipes := RecipeDB.by_station(station)
	if _selected_id == "" and recipes.size() > 0:
		_selected_id = recipes[0].id
	_rebuild()

func _build_header() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 58)
	panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.92, 0.74, 0.68), Color(0.78, 0.56, 0.32, 0.55), 1, 10))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_top = 10
	row.offset_right = -14
	row.offset_bottom = -10
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	copy.add_child(_label("家庭共享仓库", 15, COLOR_TEXT))
	copy.add_child(_label("选择固定菜谱，或让 AI 用现有食材随机做一道菜。", 12, COLOR_MUTED))

	var ai_btn := Button.new()
	ai_btn.text = "AI 随机做一道菜"
	ai_btn.custom_minimum_size = Vector2(154, 38)
	HUDPanel._style_soft_button(ai_btn)
	ai_btn.pressed.connect(_on_ai_random_dish_pressed.bind(ai_btn))
	row.add_child(ai_btn)

	var dev := Button.new()
	dev.text = "补测试食材"
	dev.custom_minimum_size = Vector2(104, 38)
	HUDPanel._style_soft_button(dev)
	dev.modulate = Color(1, 1, 1, 0.78)
	dev.pressed.connect(func() -> void:
		KitchenManager.grant_test_ingredients()
		_rebuild()
		SceneManager._show_toast("已补齐测试食材到家庭共享仓"))
	row.add_child(dev)
	return panel

func _build_recipe_list_panel() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(258, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.96, 0.84, 0.72), Color(0.72, 0.52, 0.30, 0.55), 1, 10))

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 12
	root.offset_right = -12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	root.add_child(_label("固定菜谱", 15, COLOR_TEXT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 7)
	scroll.add_child(_list_box)
	return panel

func _build_detail_panel() -> Control:
	var panel := Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.95, 0.79, 0.50), Color(0.72, 0.52, 0.30, 0.48), 1, 10))

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 14
	scroll.offset_top = 12
	scroll.offset_right = -14
	scroll.offset_bottom = -12
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 11)
	scroll.add_child(_detail_box)
	return panel

func _rebuild() -> void:
	_rebuild_ai_result()
	_rebuild_list()
	_rebuild_detail()

func _rebuild_ai_result() -> void:
	for c in _ai_result_root.get_children():
		c.queue_free()
	if _ai_state == "idle":
		_ai_result_root.visible = false
		return
	_ai_result_root.visible = true
	match _ai_state:
		"loading":
			_ai_result_root.add_child(_ai_status_card("AI 正在做菜", _ai_message, false, ""))
		"error":
			_ai_result_root.add_child(_ai_status_card("AI 做菜没有成功", _ai_message, true, _ai_error_code))
		_:
			if _latest_ai_dish.is_empty():
				_ai_result_root.add_child(_ai_status_card("AI 做菜没有成功", "没有拿到可显示的菜品结果。", true, ""))
			else:
				_ai_result_root.add_child(_ai_result_card(_latest_ai_dish))

func _rebuild_list() -> void:
	for c in _list_box.get_children():
		c.queue_free()
	var recipes := RecipeDB.by_station(station)
	if recipes.is_empty():
		var empty := _label("这个台子暂时没有可做的食谱。", 13, COLOR_MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list_box.add_child(empty)
		return
	for recipe in recipes:
		_list_box.add_child(_recipe_button(recipe))

func _recipe_button(recipe: RecipeDef) -> Button:
	var can_make := bool(KitchenManager.can_craft(recipe.id).ok)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 54)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = "%s\n%s" % [recipe.display_name, "材料齐全" if can_make else "缺少材料"]
	btn.icon = ItemDB.icon_texture(recipe.output_item_id)
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	HUDPanel._style_soft_button(btn)
	HUDPanel._mark_active(btn, recipe.id == _selected_id)
	if not can_make:
		btn.modulate = Color(1, 1, 1, 0.58)
	var rid := recipe.id
	btn.pressed.connect(func() -> void:
		_selected_id = rid
		_rebuild())
	return btn

func _rebuild_detail() -> void:
	for c in _detail_box.get_children():
		c.queue_free()
	var recipe: RecipeDef = RecipeDB.get_def(_selected_id)
	if recipe == null:
		_detail_box.add_child(_label("请选择一道菜谱。", 14, COLOR_MUTED))
		return

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	_detail_box.add_child(top)
	top.add_child(_icon_card(ItemDB.icon_texture(recipe.output_item_id), 64))
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 3)
	top.add_child(title_box)
	title_box.add_child(_label(recipe.display_name, 22, COLOR_TEXT))
	var desc := _label(recipe.description, 13, COLOR_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(desc)

	_detail_box.add_child(_label("需要的材料", 15, COLOR_TEXT))
	for ing in recipe.ingredients:
		_detail_box.add_child(_ingredient_row(ing))

	var chk: Dictionary = KitchenManager.can_craft(recipe.id)
	var action := Button.new()
	action.custom_minimum_size = Vector2(0, 42)
	HUDPanel._style_soft_button(action)
	if bool(chk.get("ok", false)):
		action.text = "制作 %s ×%d" % [ItemDB.display_name(recipe.output_item_id), recipe.output_quantity]
		action.pressed.connect(func() -> void:
			if KitchenManager.craft(recipe.id):
				SceneManager._show_toast("做好了：%s" % recipe.display_name)
				_rebuild())
	else:
		action.text = "材料不足，暂时不能制作"
		action.disabled = true
	_detail_box.add_child(action)

	if not bool(chk.get("ok", false)):
		var miss := _label("还缺：" + _missing_text(chk), 12, COLOR_WARN)
		miss.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_box.add_child(miss)

func _ingredient_row(ing: Dictionary) -> Control:
	var iid := String(ing.get("id", ""))
	var need := int(ing.get("qty", 1))
	var have := InventoryManager.storehouse.count(iid)
	var enough := have >= need

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 34)
	row.add_theme_constant_override("separation", 8)
	row.add_child(_icon_rect(ItemDB.icon_texture(iid), 28))

	var name := _label(ItemDB.display_name(iid), 13, COLOR_TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name)

	var count := _label("%d / %d" % [have, need], 13, COLOR_GOOD if enough else COLOR_WARN)
	count.custom_minimum_size = Vector2(54, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count)

	var source := _label(_source_hint(iid) if not enough else "够用", 12, COLOR_MUTED if enough else COLOR_WARN)
	source.custom_minimum_size = Vector2(112, 0)
	source.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(source)
	return row

func _ai_result_card(dish: Dictionary) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 132)
	panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.89, 0.60, 0.88), Color(0.84, 0.55, 0.24, 0.92), 1, 10))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_top = 10
	row.offset_right = -12
	row.offset_bottom = -10
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var dish_id := String(dish.get("id", ""))
	row.add_child(_icon_card(KitchenManager.dish_icon(dish_id), 86))

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	row.add_child(mid)
	mid.add_child(_label("刚做好的 AI 随机料理", 12, Color(0.50, 0.34, 0.17, 0.95)))
	mid.add_child(_label(String(dish.get("name", "随机料理")), 19, COLOR_TEXT))
	var desc := _label(String(dish.get("description", "")), 12, COLOR_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(desc)
	var ing := _label("食材：" + _ai_ingredient_text(dish), 12, COLOR_MUTED)
	ing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(ing)

	var actions := VBoxContainer.new()
	actions.custom_minimum_size = Vector2(112, 0)
	actions.add_theme_constant_override("separation", 8)
	row.add_child(actions)
	var table_btn := Button.new()
	table_btn.text = "摆到餐桌"
	table_btn.custom_minimum_size = Vector2(112, 36)
	HUDPanel._style_soft_button(table_btn)
	table_btn.pressed.connect(func() -> void:
		var meal_panel := MealTablePanel.new()
		meal_panel.initial_dish_id = dish_id
		if SceneManager.game_hud != null:
			SceneManager.game_hud.open_panel(meal_panel))
	actions.add_child(table_btn)
	var hide_btn := Button.new()
	hide_btn.text = "收起"
	hide_btn.custom_minimum_size = Vector2(112, 32)
	HUDPanel._style_soft_button(hide_btn)
	hide_btn.modulate = Color(1, 1, 1, 0.72)
	hide_btn.pressed.connect(func() -> void:
		_latest_ai_dish = {}
		_ai_state = "idle"
		_ai_message = ""
		_ai_error_code = ""
		_rebuild_ai_result())
	actions.add_child(hide_btn)
	return panel

func _ai_status_card(title_text: String, body_text: String, show_retry: bool, error_code: String) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 94)
	var bg := Color(1.0, 0.90, 0.68, 0.88) if not show_retry else Color(1.0, 0.88, 0.74, 0.90)
	var border := Color(0.84, 0.55, 0.24, 0.92) if not show_retry else Color(0.82, 0.38, 0.22, 0.90)
	panel.add_theme_stylebox_override("panel", _box(bg, border, 1, 10))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_top = 10
	row.offset_right = -14
	row.offset_bottom = -10
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	row.add_child(text_box)
	text_box.add_child(_label(title_text, 16, COLOR_TEXT))
	var body := _label(body_text, 12, COLOR_WARN if show_retry else COLOR_MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(body)
	if error_code != "":
		text_box.add_child(_label("错误码：" + error_code, 11, COLOR_MUTED))

	if show_retry:
		var actions := VBoxContainer.new()
		actions.custom_minimum_size = Vector2(108, 0)
		actions.add_theme_constant_override("separation", 6)
		row.add_child(actions)
		var retry_btn := Button.new()
		retry_btn.text = "再试一次"
		retry_btn.custom_minimum_size = Vector2(108, 32)
		HUDPanel._style_soft_button(retry_btn)
		retry_btn.pressed.connect(_on_ai_random_dish_pressed.bind(retry_btn))
		actions.add_child(retry_btn)
		var test_btn := Button.new()
		test_btn.text = "补测试食材"
		test_btn.custom_minimum_size = Vector2(108, 30)
		HUDPanel._style_soft_button(test_btn)
		test_btn.modulate = Color(1, 1, 1, 0.76)
		test_btn.pressed.connect(func() -> void:
			KitchenManager.grant_test_ingredients()
			_ai_state = "idle"
			_ai_message = ""
			_ai_error_code = ""
			_rebuild())
		actions.add_child(test_btn)
	return panel

func _icon_card(tex: Texture2D, size_px: int) -> Control:
	var holder := Panel.new()
	holder.custom_minimum_size = Vector2(size_px, size_px)
	holder.add_theme_stylebox_override("panel", _box(Color(1.0, 0.96, 0.82, 0.72), Color(0.75, 0.55, 0.32, 0.45), 1, 8))
	var icon := _icon_rect(tex, size_px - 18)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 9
	icon.offset_top = 9
	icon.offset_right = -9
	icon.offset_bottom = -9
	holder.add_child(icon)
	return holder

func _icon_rect(tex: Texture2D, sz: int) -> TextureRect:
	var r := TextureRect.new()
	r.custom_minimum_size = Vector2(sz, sz)
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _box(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	return box

func _missing_text(chk: Dictionary) -> String:
	var miss_names: Array = []
	var missing: Array = chk.get("missing", []) if chk.get("missing", []) is Array else []
	for m in missing:
		if not m is Dictionary:
			continue
		var missing_id := String((m as Dictionary).get("id", ""))
		miss_names.append("%s×%d（%s）" % [
			ItemDB.display_name(missing_id),
			int((m as Dictionary).get("need", 0)) - int((m as Dictionary).get("have", 0)),
			_source_hint(missing_id)
		])
	return "、".join(miss_names)

func _ai_ingredient_text(dish: Dictionary) -> String:
	var parts: Array = []
	var ingredients: Array = dish.get("ingredients", []) if dish.get("ingredients", []) is Array else []
	for raw in ingredients:
		if raw is Dictionary:
			var item := raw as Dictionary
			var item_id := String(item.get("id", ""))
			parts.append("%s×%d" % [String(item.get("name", ItemDB.display_name(item_id))), int(item.get("qty", 1))])
	return "、".join(parts) if not parts.is_empty() else "家庭共享仓食材"

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

func _on_ai_random_dish_pressed(button: Button) -> void:
	button.disabled = true
	button.text = "AI 做菜中..."
	_latest_ai_dish = {}
	_ai_state = "loading"
	_ai_message = "正在从家庭共享仓挑选食材，并生成菜名、说明和菜品图。"
	_ai_error_code = ""
	_rebuild_ai_result()
	await get_tree().process_frame
	var result: Dictionary = await KitchenManager.craft_random_ai_dish(station)
	if bool(result.get("ok", false)):
		_latest_ai_dish = result.get("dish", {}) if result.get("dish", {}) is Dictionary else {}
		_ai_state = "success"
		_ai_message = ""
		_ai_error_code = ""
		button.disabled = false
		button.text = "AI 随机做一道菜"
		_rebuild()
		SceneManager._show_toast("AI 随机料理已做好")
		return
	var error: Dictionary = result.get("error", {}) if result.get("error", {}) is Dictionary else {}
	var code := String(error.get("code", "AI_FAILED"))
	var message := String(error.get("message", "AI 随机料理暂时没有成功。"))
	_ai_state = "error"
	_ai_message = message
	_ai_error_code = code
	_rebuild_ai_result()
	SceneManager._show_toast(message)
	button.disabled = false
	button.text = "AI 随机做一道菜"
