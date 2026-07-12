extends HUDPanel
class_name FarmDebugPanel

## 农场开发/验收调试面板(F9 打开,非常驻 HUD 入口)。
## 仅用于验证种植→浇水→施肥→生长→收获→畜牧闭环,不影响正式玩家流程。

func _init() -> void:
	panel_title = "🐞 农场调试 (DEBUG)"
	card_size = Vector2(440, 420)

func _build_content() -> void:
	var note := Label.new()
	note.text = "仅供开发验收使用"
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.55, 0.45, 0.32, 0.9))
	content_root.add_child(note)

	content_root.add_child(_btn("🌱 获取测试种子 / 肥料 / 浇水壶", func() -> void:
		FarmManager.grant_test_kit()
		SceneManager._show_toast("已发放测试种子 + 肥料 + 浇水壶到共享仓")))

	content_root.add_child(_btn("⏩ 所有作物推进一个生长阶段", func() -> void:
		for p in FarmManager.plots().duplicate():
			FarmManager.advance_stage(int(p.get("plot", -1)))
		SceneManager._show_toast("所有作物 +1 阶段")))

	content_root.add_child(_btn("🌾 所有作物立即成熟", func() -> void:
		for p in FarmManager.plots().duplicate():
			FarmManager.mature_now(int(p.get("plot", -1)))
		SceneManager._show_toast("所有作物已成熟")))

	content_root.add_child(_btn("🥚 鸡舍立即可收集", func() -> void:
		FarmManager.make_livestock_ready("chicken_coop")
		SceneManager._show_toast("鸡舍已就绪")))

	content_root.add_child(_btn("🥛 牛舍立即可收集", func() -> void:
		FarmManager.make_livestock_ready("cow_shed")
		SceneManager._show_toast("牛舍已就绪")))

func _btn(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	HUDPanel._style_soft_button(b)
	b.pressed.connect(on_press)
	return b
