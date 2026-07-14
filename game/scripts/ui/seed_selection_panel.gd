extends HUDPanel
class_name SeedSelectionPanel

signal seed_planted(plot_index: int, crop_id: String)

## 播种选种面板。列出玩家拥有的种子(家庭共享仓 + 背包合并),点一下在目标地块播种。
## 打开前由 farm.gd 设 target_plot。播种走 FarmManager.plant(消耗种子、进 farm_plots 持久化)。

var target_plot: int = -1
var _list: VBoxContainer

func _init() -> void:
	panel_title = "播种 · 选择种子"
	card_size = Vector2(460, 460)

func _build_content() -> void:
	var hint := Label.new()
	hint.text = "选择一种已有的种子"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.40, 0.33, 0.25, 1.0))
	content_root.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	_rebuild()

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var any := false
	for crop in CropDB.CROPS:
		var cid: String = str(crop.id)
		var sid: String = CropDB.seed_item_id(cid)
		var count: int = InventoryManager.storehouse.count(sid) + InventoryManager.backpack.count(sid)
		if count <= 0:
			continue
		any = true
		_list.add_child(_seed_row(cid, sid, count))
	if not any:
		var empty := Label.new()
		empty.text = "还没有种子。可以去农场小铺购买。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(400, 0)
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.5, 0.42, 0.3, 0.9))
		_list.add_child(empty)

func _seed_row(crop_id: String, seed_id: String, count: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	HUDPanel._style_soft_button(btn)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 10)
	btn.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.texture = ItemDB.icon_texture(seed_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var lbl := Label.new()
	lbl.text = "%s   ×%d" % [CropDB.display_name(crop_id), count]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 1.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	btn.pressed.connect(func() -> void:
		if FarmManager.plant(target_plot, crop_id):
			seed_planted.emit(target_plot, crop_id)
			SceneManager._show_toast("种下了 %s" % CropDB.display_name(crop_id))
			close_requested.emit()
		else:
			SceneManager._show_toast("种不了(没有种子或地已占用)"))
	return btn
