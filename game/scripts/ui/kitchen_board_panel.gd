extends HUDPanel
class_name KitchenBoardPanel

## 冰箱看板(FridgeArea)。家庭共享库存摘要 + 订单板(检查/提交/奖励/已完成)+ 家人留言入口。
## 订单与库存逻辑走 KitchenManager;留言复用现有世界聊天面板。

func _init() -> void:
	panel_title = "冰箱看板 · 家庭"
	card_size = Vector2(640, 540)

func _build_content() -> void:
	# 家庭共享库存摘要
	var inv_title := Label.new()
	inv_title.text = "🏠 家庭共享库存摘要"
	inv_title.add_theme_font_size_override("font_size", 15)
	inv_title.add_theme_color_override("font_color", Color(0.30, 0.24, 0.17, 1.0))
	content_root.add_child(inv_title)

	var summary := Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size = Vector2(560, 0)
	summary.add_theme_font_size_override("font_size", 14)
	summary.add_theme_color_override("font_color", Color(0.26, 0.21, 0.15, 1.0))
	summary.text = _summary_text()
	content_root.add_child(summary)

	var sep := HSeparator.new()
	content_root.add_child(sep)

	# 订单板
	var order_title := Label.new()
	order_title.text = "📋 订单板"
	order_title.add_theme_font_size_override("font_size", 15)
	order_title.add_theme_color_override("font_color", Color(0.30, 0.24, 0.17, 1.0))
	content_root.add_child(order_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_root.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for order in KitchenManager.get_orders():
		if order is Dictionary:
			list.add_child(_order_row(order))

	# 家人留言入口(复用世界聊天)
	var msg_btn := Button.new()
	msg_btn.text = "💬 家人留言"
	msg_btn.custom_minimum_size = Vector2(0, 40)
	HUDPanel._style_soft_button(msg_btn)
	msg_btn.pressed.connect(func() -> void:
		close_requested.emit()
		SceneManager._open_world_chat_history_panel())
	content_root.add_child(msg_btn)

func _summary_text() -> String:
	var parts: Array = []
	var n := 0
	for s in InventoryManager.storehouse.stacks:
		var iid: String = str(s.get("id", ""))
		parts.append("%s×%d" % [ItemDB.display_name(iid), int(s.get("count", 0))])
		n += 1
		if n >= 12:
			break
	if parts.is_empty():
		return "共享仓暂时空空如也。"
	return "、".join(parts)

func _order_row(order: Dictionary) -> Control:
	var oid: String = str(order.get("id", ""))
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1.0, 0.97, 0.88, 0.7)
	box.border_color = Color(0.64, 0.50, 0.32, 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", box)

	var margin := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, 10)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = str(order.get("display_name", oid))
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.24, 0.19, 0.14, 1.0))
	info.add_child(name_lbl)

	var req_parts: Array = []
	for req in order.get("requires", []):
		req_parts.append("%s×%d" % [ItemDB.display_name(str(req.get("id", ""))), int(req.get("qty", 1))])
	var req_lbl := Label.new()
	req_lbl.text = "需要：" + "、".join(req_parts) + "    奖励：金币×%d" % int(order.get("reward_coin", 0))
	req_lbl.add_theme_font_size_override("font_size", 13)
	req_lbl.add_theme_color_override("font_color", Color(0.42, 0.34, 0.25, 0.95))
	info.add_child(req_lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(96, 40)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	HUDPanel._style_soft_button(btn)
	if KitchenManager.is_done(oid):
		btn.text = "已完成"
		btn.disabled = true
	elif KitchenManager.can_fulfill(oid):
		btn.text = "提交"
		btn.pressed.connect(func() -> void:
			var reward: int = await KitchenManager.submit_order(oid)
			if reward >= 0:
				SceneManager._show_toast("订单完成！获得金币×%d 💰" % reward)
				_reopen())
	else:
		btn.text = "材料不足"
		btn.disabled = true
	row.add_child(btn)
	return card

func _reopen() -> void:
	for c in content_root.get_children():
		c.queue_free()
	_build_content()
