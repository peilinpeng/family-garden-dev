extends HUDPanel
class_name MapHubPanel

signal world_map_requested
signal travel_map_requested

func _init() -> void:
	panel_title = "地图 / Maps"
	card_size = Vector2(480, 300)

func _build_content() -> void:
	var hint := Label.new()
	hint.text = "你想去往家园中的其他场景，还是打开旅行记忆？"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.40, 0.32, 0.23, 0.88))
	content_root.add_child(hint)

	var world_btn := Button.new()
	world_btn.text = "🏡  世界导航\n花园 · 农场 · 小屋 · 鱼塘"
	world_btn.custom_minimum_size = Vector2(0, 64)
	HUDPanel._style_soft_button(world_btn)
	world_btn.pressed.connect(func() -> void: world_map_requested.emit())
	content_root.add_child(world_btn)

	var travel_btn := Button.new()
	travel_btn.text = "🗺  旅行足迹\n地点 · 照片 · 明信片"
	travel_btn.custom_minimum_size = Vector2(0, 64)
	HUDPanel._style_soft_button(travel_btn)
	travel_btn.pressed.connect(func() -> void: travel_map_requested.emit())
	content_root.add_child(travel_btn)
