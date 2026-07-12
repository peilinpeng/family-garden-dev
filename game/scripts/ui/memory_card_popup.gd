extends HUDPanel
class_name MemoryCardPopup

## 记忆卡解锁弹窗(小卡)。卡面用暖色 Panel + emoji 占位,待美术后换插画。
## card_data 由 StoryManager.unlock_card 传入:{id,title,desc,emoji,unlocked_at}。
## 未来接入:家庭树 / 明信片 / 相册 / 云端同步。

var card_data: Dictionary = {}

func _init() -> void:
	panel_title = "✨ 解锁记忆卡"
	card_size = Vector2(380, 340)

func _build_content() -> void:
	# 卡面(占位:暖色圆角 + 大 emoji)
	var face := Panel.new()
	face.custom_minimum_size = Vector2(0, 130)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1.0, 0.98, 0.90, 1.0)
	box.border_color = Color(0.85, 0.68, 0.40, 0.9)
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	face.add_theme_stylebox_override("panel", box)
	content_root.add_child(face)

	var emoji := Label.new()
	emoji.text = str(card_data.get("emoji", "✨"))
	emoji.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji.add_theme_font_size_override("font_size", 56)
	face.add_child(emoji)

	var title := Label.new()
	title.text = "记忆卡:" + str(card_data.get("title", ""))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 1.0))
	content_root.add_child(title)

	var desc := Label.new()
	desc.text = str(card_data.get("desc", ""))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.42, 0.34, 0.25, 0.95))
	content_root.add_child(desc)

	var ok := Button.new()
	ok.text = "收下"
	ok.custom_minimum_size = Vector2(0, 40)
	HUDPanel._style_soft_button(ok)
	ok.pressed.connect(func() -> void: close_requested.emit())
	content_root.add_child(ok)
