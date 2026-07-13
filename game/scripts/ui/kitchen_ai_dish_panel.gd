extends HUDPanel
class_name KitchenAIDishPanel

## AI 随机料理结果卡。只展示已保存的动态菜肴；消费仍由餐桌面板统一处理。

var dish_data: Dictionary = {}

func _init() -> void:
	panel_title = "AI 随机料理"
	card_size = Vector2(640, 500)

func _build_content() -> void:
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	content_root.add_child(title_row)
	var dish_id := String(dish_data.get("id", ""))
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.texture = KitchenManager.dish_icon(dish_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title_row.add_child(icon)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_box)
	var name := Label.new()
	name.text = String(dish_data.get("name", "随机料理"))
	name.add_theme_font_size_override("font_size", 22)
	name.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 1.0))
	title_box.add_child(name)
	var source := Label.new()
	source.text = "已加入餐桌可选菜品 · 数量 ×%d" % int(dish_data.get("quantity", 1))
	source.add_theme_font_size_override("font_size", 13)
	source.add_theme_color_override("font_color", Color(0.45, 0.36, 0.25, 0.9))
	title_box.add_child(source)

	var desc := Label.new()
	desc.text = String(dish_data.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(560, 0)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.32, 0.25, 0.18, 1.0))
	content_root.add_child(desc)

	var ing := Label.new()
	ing.text = "随机食材：" + _ingredient_text()
	ing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ing.add_theme_font_size_override("font_size", 14)
	ing.add_theme_color_override("font_color", Color(0.40, 0.32, 0.23, 0.96))
	content_root.add_child(ing)

	var note := Label.new()
	note.text = "上桌提示：" + String(dish_data.get("serving_note", ""))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color(0.40, 0.32, 0.23, 0.96))
	content_root.add_child(note)

	var question := Label.new()
	question.text = "餐桌话题：" + String(dish_data.get("family_question", ""))
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.add_theme_font_size_override("font_size", 15)
	question.add_theme_color_override("font_color", Color(0.30, 0.24, 0.17, 1.0))
	content_root.add_child(question)

	var trace := Label.new()
	var meta: Dictionary = dish_data.get("generation_meta", {}) if dish_data.get("generation_meta", {}) is Dictionary else {}
	trace.text = "AI 来源：%s · 模型：%s" % [String(meta.get("source", "local")), String(meta.get("model", "mock"))]
	trace.add_theme_font_size_override("font_size", 12)
	trace.add_theme_color_override("font_color", Color(0.45, 0.38, 0.29, 0.72))
	content_root.add_child(trace)

	var table_btn := Button.new()
	table_btn.text = "摆到餐桌"
	table_btn.custom_minimum_size = Vector2(0, 42)
	HUDPanel._style_soft_button(table_btn)
	table_btn.pressed.connect(func() -> void:
		var panel := MealTablePanel.new()
		panel.initial_dish_id = dish_id
		if SceneManager.game_hud != null:
			SceneManager.game_hud.open_panel(panel))
	content_root.add_child(table_btn)

func _ingredient_text() -> String:
	var parts: Array = []
	var ingredients: Array = dish_data.get("ingredients", []) if dish_data.get("ingredients", []) is Array else []
	for raw in ingredients:
		if raw is Dictionary:
			var item := raw as Dictionary
			var item_id := String(item.get("id", ""))
			parts.append("%s×%d" % [String(item.get("name", ItemDB.display_name(item_id))), int(item.get("qty", 1))])
	return "、".join(parts) if not parts.is_empty() else "家庭共享仓食材"
