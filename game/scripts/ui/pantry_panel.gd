extends HUDPanel
class_name PantryPanel

## 储藏区面板(PantryArea)。v1:浏览家庭共享仓的食材/种子/保存食品 + 展示 pantry 站配方(果酱)可制作。
## 为将来果酱/腌菜/干香草等 recipe station 预留(station_type=pantry)。逻辑走 KitchenManager。

const BROWSE_CATEGORIES := ["produce", "dish", "seed"]   ## 家庭食品浏览:食材/料理/种子

func _init() -> void:
	panel_title = "储藏区 · 家庭食品"
	card_size = Vector2(700, 520)

func _build_content() -> void:
	var src := Label.new()
	src.text = "🏠 家庭共享仓库 · 食材与保存食品"
	src.add_theme_font_size_override("font_size", 14)
	src.add_theme_color_override("font_color", Color(0.40, 0.33, 0.25, 1.0))
	content_root.add_child(src)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_root.add_child(body)

	# 左:pantry 配方(可直接做)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	var recipe_title := Label.new()
	recipe_title.text = "🫙 可制作（储藏加工）"
	recipe_title.add_theme_font_size_override("font_size", 15)
	recipe_title.add_theme_color_override("font_color", Color(0.30, 0.24, 0.17, 1.0))
	left.add_child(recipe_title)
	var recipes := RecipeDB.by_station("pantry")
	if recipes.is_empty():
		var none := Label.new()
		none.text = "暂无储藏加工配方"
		none.add_theme_font_size_override("font_size", 13)
		none.add_theme_color_override("font_color", Color(0.5, 0.42, 0.3, 0.85))
		left.add_child(none)
	for r in recipes:
		left.add_child(_recipe_row(r))

	# 右:浏览共享仓食品
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	right_scroll.add_child(right)
	var browse_title := Label.new()
	browse_title.text = "📦 共享仓存货"
	browse_title.add_theme_font_size_override("font_size", 15)
	browse_title.add_theme_color_override("font_color", Color(0.30, 0.24, 0.17, 1.0))
	right.add_child(browse_title)

	var shown := 0
	for s in InventoryManager.storehouse.stacks:
		var iid: String = str(s.get("id", ""))
		var def: ItemDef = ItemDB.get_def(iid)
		if def == null or not (def.category in BROWSE_CATEGORIES):
			continue
		right.add_child(_browse_row(iid, int(s.get("count", 0))))
		shown += 1
	if shown == 0:
		var empty := Label.new()
		empty.text = "共享仓里还没有食材，去花园收获或用测试食材试试～"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(320, 0)
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.5, 0.42, 0.3, 0.85))
		right.add_child(empty)

func _recipe_row(r: RecipeDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_icon_rect(ItemDB.icon_texture(r.output_item_id), 32))
	var name_lbl := Label.new()
	name_lbl.text = r.display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 1.0))
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_lbl)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(72, 34)
	HUDPanel._style_soft_button(btn)
	var can_make: bool = KitchenManager.can_craft(r.id).ok
	btn.text = "做"
	btn.disabled = not can_make
	var rid: String = r.id
	var rname: String = r.display_name
	btn.pressed.connect(func() -> void:
		if KitchenManager.craft(rid):
			SceneManager._show_toast("做好了：%s ✨" % rname)
			_reopen())
	row.add_child(btn)
	return row

func _browse_row(iid: String, count: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_icon_rect(ItemDB.icon_texture(iid), 28))
	var lbl := Label.new()
	lbl.text = "%s   ×%d" % [ItemDB.display_name(iid), count]
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.26, 0.21, 0.15, 1.0))
	row.add_child(lbl)
	return row

## 制作后刷新:最省事的做法是重建内容(pantry 面板不大)。
func _reopen() -> void:
	for c in content_root.get_children():
		c.queue_free()
	_build_content()

func _icon_rect(tex: Texture2D, sz: int) -> TextureRect:
	var r := TextureRect.new()
	r.custom_minimum_size = Vector2(sz, sz)
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r
