extends HUDPanel
class_name KitchenCookingPanel

## 沉浸式 AI 烹饪面板：从家庭共享仓拖食材入锅，等待期间可拖动木勺搅拌。
## 食材不会在拖入时扣除；AI 成功且提交前由 AIWorkflowManager 再次校验并原子扣除。

const COOKING_ATLAS := preload("res://assets/kitchen_cooking/cooking_atlas.png")
const POT_REGION := Rect2(270, 480, 700, 720)
const SPOON_REGION := Rect2(90, 40, 180, 480)
const FLAME_REGION := Rect2(900, 140, 250, 310)
const MIN_COOK_SECONDS := 2.8
const MAX_INGREDIENT_KINDS := 5

const COLOR_TEXT := Color(0.24, 0.18, 0.12, 1.0)
const COLOR_MUTED := Color(0.47, 0.37, 0.25, 0.90)
const COLOR_WARN := Color(0.72, 0.26, 0.18, 1.0)
const COLOR_GOOD := Color(0.25, 0.48, 0.27, 1.0)

class IngredientDragButton:
	extends Button
	var item_id := ""
	var item_texture: Texture2D

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if disabled or item_id == "":
			return null
		var preview := TextureRect.new()
		preview.texture = item_texture
		preview.custom_minimum_size = Vector2(48, 48)
		preview.size = Vector2(48, 48)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview.modulate = Color(1, 1, 1, 0.92)
		set_drag_preview(preview)
		return {"kind": "kitchen_ingredient", "item_id": item_id}

class IngredientDropZone:
	extends Control
	signal ingredient_dropped(item_id: String)
	var enabled := true
	var drag_hover := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		var valid := enabled and data is Dictionary and String((data as Dictionary).get("kind", "")) == "kitchen_ingredient"
		if drag_hover != valid:
			drag_hover = valid
			queue_redraw()
		return valid

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		drag_hover = false
		queue_redraw()
		if data is Dictionary:
			ingredient_dropped.emit(String((data as Dictionary).get("item_id", "")))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and drag_hover:
			drag_hover = false
			queue_redraw()

	func _draw() -> void:
		var color := Color(1.0, 0.77, 0.32, 0.96) if drag_hover else Color(1.0, 0.92, 0.66, 0.46)
		draw_arc(size * 0.5, minf(size.x, size.y) * 0.37, 0.0, TAU, 48, color, 3.0 if drag_hover else 1.5, true)

class StirSpoon:
	extends TextureRect
	signal stirred(amount: float)
	var enabled := true
	var orbit_center := Vector2.ZERO
	var orbit_radius := Vector2(58, 24)
	var dragging := false
	var last_angle := -0.9
	var auto_angle := -0.9

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_DRAG
		pivot_offset = size * 0.5
		_place(last_angle)

	func _process(delta: float) -> void:
		if not dragging:
			auto_angle = wrapf(auto_angle + delta * 0.42, -PI, PI)
			last_angle = auto_angle
			_place(auto_angle)

	func _gui_input(event: InputEvent) -> void:
		if not enabled:
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			mouse_default_cursor_shape = Control.CURSOR_DRAG if dragging else Control.CURSOR_POINTING_HAND
			if dragging:
				_update_from_pointer()
			accept_event()
		elif event is InputEventMouseMotion and dragging:
			_update_from_pointer()
			accept_event()
		elif event is InputEventScreenTouch:
			dragging = event.pressed
			if dragging:
				_update_from_screen(event.position)
			accept_event()
		elif event is InputEventScreenDrag and dragging:
			_update_from_screen(event.position)
			accept_event()

	func _update_from_pointer() -> void:
		var parent_control := get_parent() as Control
		if parent_control != null:
			_apply_pointer(parent_control.get_local_mouse_position())

	func _update_from_screen(screen_position: Vector2) -> void:
		var parent_control := get_parent() as Control
		if parent_control == null:
			return
		var local := parent_control.get_global_transform_with_canvas().affine_inverse() * screen_position
		_apply_pointer(local)

	func _apply_pointer(pointer: Vector2) -> void:
		var angle := (pointer - orbit_center).angle()
		var delta_angle := absf(wrapf(angle - last_angle, -PI, PI))
		last_angle = angle
		auto_angle = angle
		_place(angle)
		if delta_angle > 0.003:
			stirred.emit(delta_angle)

	func _place(angle: float) -> void:
		position = orbit_center + Vector2(cos(angle) * orbit_radius.x, sin(angle) * orbit_radius.y) - size * 0.5
		rotation = angle + PI * 0.5

class CookingEffects:
	extends Control
	var cooking := false
	var success_burst := 0.0
	var stir_energy := 0.0
	var elapsed := 0.0
	var ingredient_count := 0
	var liquid_color := Color(0.78, 0.38, 0.16, 0.94)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		elapsed += delta
		stir_energy = maxf(0.0, stir_energy - delta * 0.65)
		success_burst = maxf(0.0, success_burst - delta)
		queue_redraw()

	func add_stir(amount: float) -> void:
		stir_energy = minf(1.0, stir_energy + amount * 1.8)

	func _draw() -> void:
		var center := Vector2(205, 142)
		var wobble := sin(elapsed * (5.0 + stir_energy * 9.0)) * (1.5 + stir_energy * 2.5)
		_draw_ellipse(center + Vector2(0, wobble), Vector2(118, 34), liquid_color.lightened(stir_energy * 0.10))
		var bubble_count := 8 if cooking else (4 if ingredient_count > 0 else 2)
		bubble_count += int(round(stir_energy * 7.0))
		for index in bubble_count:
			var phase := elapsed * (1.8 + float(index % 3) * 0.35) + float(index) * 1.73
			var px := center.x + sin(phase * 1.37) * (24.0 + float(index % 5) * 14.0)
			var py := center.y + cos(phase) * (8.0 + float(index % 4) * 4.0)
			var radius := 2.2 + float(index % 3) + stir_energy * 1.5
			draw_circle(Vector2(px, py), radius, Color(1.0, 0.86, 0.54, 0.74))
			draw_arc(Vector2(px, py), radius, PI, TAU, 8, Color(1, 1, 1, 0.60), 1.0, true)
		if cooking or ingredient_count > 0:
			for index in 3:
				var x := center.x - 46.0 + float(index) * 46.0 + sin(elapsed + index) * 5.0
				var rise := fmod(elapsed * (22.0 + index * 3.0) + index * 18.0, 54.0)
				var alpha := 0.18 + 0.26 * (1.0 - rise / 54.0)
				var points := PackedVector2Array([
					Vector2(x, 104 - rise),
					Vector2(x - 5, 92 - rise),
					Vector2(x + 4, 80 - rise),
				])
				draw_polyline(points, Color(1.0, 0.96, 0.84, alpha), 3.0, true)
		if success_burst > 0.0:
			for index in 10:
				var angle := float(index) / 10.0 * TAU + elapsed * 0.4
				var radius := (1.0 - success_burst) * 65.0 + 22.0
				draw_circle(center + Vector2.from_angle(angle) * radius, 3.0, Color(1.0, 0.78, 0.24, success_burst))

	func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
		var points := PackedVector2Array()
		for index in 48:
			var angle := float(index) / 48.0 * TAU
			points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
		draw_colored_polygon(points, color)

var station := "stove"
var _selected: Dictionary = {}
var _latest_dish: Dictionary = {}
var _cooking := false
var _state := "idle"
var _message := ""
var _cook_started_msec := 0
var _status_phase := -1

var _inventory_grid: GridContainer
var _selection_box: VBoxContainer
var _stage: Control
var _effects: CookingEffects
var _drop_zone: IngredientDropZone
var _spoon: StirSpoon
var _stage_hint: Label
var _pot_icons: Array[Control] = []

func _init() -> void:
	panel_title = "灶台 · 互动烹饪"
	card_size = Vector2(1000, 620)

func _build_content() -> void:
	content_root.add_child(_build_instruction())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_root.add_child(body)
	body.add_child(_build_inventory_panel())
	body.add_child(_build_cooking_stage())
	body.add_child(_build_selection_panel())
	InventoryManager.storehouse_changed.connect(_on_inventory_changed)
	_rebuild_inventory()
	_rebuild_selection()
	_update_pot_icons()
	set_process(true)

func _process(_delta: float) -> void:
	if not _cooking:
		return
	var elapsed := float(Time.get_ticks_msec() - _cook_started_msec) / 1000.0
	var phase := int(elapsed / 2.2) % 4
	if phase == _status_phase:
		return
	_status_phase = phase
	var messages := ["锅里开始咕嘟冒泡了…", "香味慢慢飘出来了…", "可以拖住木勺绕着锅搅拌", "AI 正在尝味道并想菜名…"]
	_stage_hint.text = messages[phase]

func _build_instruction() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 48)
	panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.92, 0.74, 0.70), Color(0.78, 0.56, 0.32, 0.55), 1, 10))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_top = 7
	row.offset_right = -14
	row.offset_bottom = -7
	panel.add_child(row)
	var copy := _label("把家庭共享仓里的食材拖进锅里；手机上也可以点一下加入。最多选择 5 种。", 13, COLOR_TEXT)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(copy)
	var badge := _label("AI 成功后才扣食材", 12, COLOR_GOOD)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(badge)
	return panel

func _build_inventory_panel() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(252, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.96, 0.84, 0.76), Color(0.72, 0.52, 0.30, 0.52), 1, 10))
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10
	root.offset_top = 10
	root.offset_right = -10
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 7)
	panel.add_child(root)
	root.add_child(_label("可用食材", 15, COLOR_TEXT))
	var tip := _label("拖拽或点击食材放入锅中", 11, COLOR_MUTED)
	root.add_child(tip)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = 2
	_inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_grid.add_theme_constant_override("h_separation", 6)
	_inventory_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_inventory_grid)
	return panel

func _build_cooking_stage() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color(0.91, 0.78, 0.55, 0.32), Color(0.66, 0.43, 0.24, 0.50), 1, 12))
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_stage)
	var glow := ColorRect.new()
	glow.position = Vector2(74, 300)
	glow.size = Vector2(272, 96)
	glow.color = Color(1.0, 0.56, 0.16, 0.08)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(glow)
	var pot := TextureRect.new()
	pot.position = Vector2(30, 54)
	pot.size = Vector2(360, 370)
	pot.texture = _atlas_texture(POT_REGION)
	pot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(pot)
	_effects = CookingEffects.new()
	_effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_effects)
	var flame := TextureRect.new()
	flame.position = Vector2(180, 332)
	flame.size = Vector2(60, 72)
	flame.texture = _atlas_texture(FLAME_REGION)
	flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(flame)
	var tween := flame.create_tween().set_loops()
	tween.tween_property(flame, "modulate", Color(1.0, 0.76, 0.48, 0.86), 0.38)
	tween.tween_property(flame, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.42)
	_drop_zone = IngredientDropZone.new()
	_drop_zone.position = Vector2(76, 72)
	_drop_zone.size = Vector2(268, 164)
	_drop_zone.ingredient_dropped.connect(add_ingredient)
	_stage.add_child(_drop_zone)
	_spoon = StirSpoon.new()
	_spoon.position = Vector2(170, 80)
	_spoon.size = Vector2(48, 132)
	_spoon.texture = _atlas_texture(SPOON_REGION)
	_spoon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spoon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_spoon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spoon.orbit_center = Vector2(210, 150)
	_spoon.stirred.connect(_on_spoon_stirred)
	_stage.add_child(_spoon)
	_stage_hint = _label("先把喜欢的食材放进锅里", 13, COLOR_TEXT)
	_stage_hint.position = Vector2(40, 432)
	_stage_hint.size = Vector2(340, 28)
	_stage_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage.add_child(_stage_hint)
	return panel

func _build_selection_panel() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(238, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.95, 0.79, 0.70), Color(0.72, 0.52, 0.30, 0.52), 1, 10))
	_selection_box = VBoxContainer.new()
	_selection_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selection_box.offset_left = 11
	_selection_box.offset_top = 11
	_selection_box.offset_right = -11
	_selection_box.offset_bottom = -11
	_selection_box.add_theme_constant_override("separation", 7)
	panel.add_child(_selection_box)
	return panel

func _rebuild_inventory() -> void:
	if _inventory_grid == null:
		return
	for child in _inventory_grid.get_children():
		child.queue_free()
	var counts: Dictionary = {}
	for stack in InventoryManager.storehouse.stacks:
		var iid := String(stack.get("id", ""))
		var item: ItemDef = ItemDB.get_def(iid)
		if item != null and item.category == "produce":
			counts[iid] = int(counts.get(iid, 0)) + int(stack.get("count", 0))
	var ids := counts.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return ItemDB.display_name(String(a)) < ItemDB.display_name(String(b)))
	if ids.is_empty():
		var empty := _label("共享仓里还没有食材。\n可以先收获农作物，或使用测试食材。", 12, COLOR_MUTED)
		empty.custom_minimum_size = Vector2(214, 70)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_inventory_grid.add_child(empty)
		return
	for iid_value in ids:
		var iid := String(iid_value)
		var button := IngredientDragButton.new()
		button.item_id = iid
		button.item_texture = ItemDB.icon_texture(iid)
		button.text = "%s  ×%d" % [ItemDB.display_name(iid), int(counts[iid])]
		button.icon = button.item_texture
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(108, 54)
		button.disabled = _cooking
		button.tooltip_text = "拖进锅里，或点击加入 1 份"
		HUDPanel._style_soft_button(button)
		button.pressed.connect(add_ingredient.bind(iid))
		_inventory_grid.add_child(button)

func _rebuild_selection() -> void:
	if _selection_box == null:
		return
	for child in _selection_box.get_children():
		child.queue_free()
	if _state == "success" and not _latest_dish.is_empty():
		_build_success_content()
		return
	_selection_box.add_child(_label("锅中食材  %d/%d" % [_selected.size(), MAX_INGREDIENT_KINDS], 15, COLOR_TEXT))
	var ingredient_area := VBoxContainer.new()
	ingredient_area.add_theme_constant_override("separation", 5)
	ingredient_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_selection_box.add_child(ingredient_area)
	if _selected.is_empty():
		var empty := _label("还没有食材。\n从左侧拖进锅里吧。", 12, COLOR_MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ingredient_area.add_child(empty)
	else:
		for iid_value in _selected:
			ingredient_area.add_child(_selected_row(String(iid_value)))
	if _message != "":
		var message_label := _label(_message, 11, COLOR_WARN if _state == "error" else COLOR_MUTED)
		message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_selection_box.add_child(message_label)
	var clear := Button.new()
	clear.text = "清空锅子"
	clear.custom_minimum_size = Vector2(0, 32)
	clear.disabled = _selected.is_empty() or _cooking
	HUDPanel._style_soft_button(clear)
	clear.modulate = Color(1, 1, 1, 0.76)
	clear.pressed.connect(_clear_selected)
	_selection_box.add_child(clear)
	var start := Button.new()
	start.text = "正在烹饪…" if _cooking else ("重新烹饪" if _state == "error" else "开始烹饪")
	start.custom_minimum_size = Vector2(0, 42)
	start.disabled = _selected.is_empty() or _cooking
	HUDPanel._style_soft_button(start)
	start.pressed.connect(_start_cooking)
	_selection_box.add_child(start)

func _selected_row(iid: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 39)
	row.add_theme_constant_override("separation", 4)
	row.add_child(_icon_rect(ItemDB.icon_texture(iid), 30))
	var name := _label(ItemDB.display_name(iid), 11, COLOR_TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(28, 28)
	minus.disabled = _cooking
	HUDPanel._style_soft_button(minus)
	minus.pressed.connect(_change_quantity.bind(iid, -1))
	row.add_child(minus)
	var count := _label(str(int(_selected[iid])), 12, COLOR_TEXT)
	count.custom_minimum_size = Vector2(18, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(28, 28)
	plus.disabled = _cooking or int(_selected[iid]) >= InventoryManager.storehouse.count(iid)
	HUDPanel._style_soft_button(plus)
	plus.pressed.connect(_change_quantity.bind(iid, 1))
	row.add_child(plus)
	return row

func _build_success_content() -> void:
	_selection_box.add_child(_label("料理完成！", 16, COLOR_GOOD))
	var icon := _icon_rect(KitchenManager.dish_icon(String(_latest_dish.get("id", ""))), 88)
	icon.custom_minimum_size = Vector2(0, 104)
	_selection_box.add_child(icon)
	var name := _label(String(_latest_dish.get("name", "随机料理")), 18, COLOR_TEXT)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_box.add_child(name)
	var desc := _label(String(_latest_dish.get("description", "")), 11, COLOR_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_selection_box.add_child(desc)
	var table := Button.new()
	table.text = "摆到餐桌"
	table.custom_minimum_size = Vector2(0, 38)
	HUDPanel._style_soft_button(table)
	var dish_id := String(_latest_dish.get("id", ""))
	table.pressed.connect(func() -> void:
		var meal_panel := MealTablePanel.new()
		meal_panel.initial_dish_id = dish_id
		if SceneManager.game_hud != null:
			SceneManager.game_hud.open_panel(meal_panel))
	_selection_box.add_child(table)
	var again := Button.new()
	again.text = "再做一道"
	again.custom_minimum_size = Vector2(0, 34)
	HUDPanel._style_soft_button(again)
	again.modulate = Color(1, 1, 1, 0.78)
	again.pressed.connect(_reset_after_success)
	_selection_box.add_child(again)

## 公开给 UI 测试和触屏点击使用；重复加入同类食材会增加数量。
func add_ingredient(item_id: String) -> bool:
	if _cooking:
		return false
	var item: ItemDef = ItemDB.get_def(item_id)
	var available := InventoryManager.storehouse.count(item_id)
	if item == null or item.category != "produce" or available <= 0:
		_show_error("这个物品现在不能放进锅里。")
		return false
	if not _selected.has(item_id) and _selected.size() >= MAX_INGREDIENT_KINDS:
		_show_error("锅里最多放 5 种食材。")
		return false
	var next := int(_selected.get(item_id, 0)) + 1
	if next > available:
		_show_error("%s 已经全部放进锅里了。" % ItemDB.display_name(item_id))
		return false
	_selected[item_id] = next
	_state = "idle"
	_message = ""
	_stage_hint.text = "食材已入锅，还可以继续搭配"
	_effects.ingredient_count = _selected.size()
	_rebuild_selection()
	_update_pot_icons()
	AudioManager.play_sfx("按钮", -10.0)
	return true

func selected_ingredients() -> Array:
	var result: Array = []
	for iid_value in _selected:
		var iid := String(iid_value)
		result.append({"id": iid, "name": ItemDB.display_name(iid), "qty": int(_selected[iid])})
	return result

func _change_quantity(item_id: String, delta: int) -> void:
	if _cooking or not _selected.has(item_id):
		return
	var next := int(_selected[item_id]) + delta
	if next <= 0:
		_selected.erase(item_id)
	else:
		_selected[item_id] = mini(next, InventoryManager.storehouse.count(item_id))
	_state = "idle"
	_message = ""
	_effects.ingredient_count = _selected.size()
	_rebuild_selection()
	_update_pot_icons()

func _clear_selected() -> void:
	if _cooking:
		return
	_selected.clear()
	_state = "idle"
	_message = ""
	_effects.ingredient_count = 0
	_stage_hint.text = "先把喜欢的食材放进锅里"
	_rebuild_selection()
	_update_pot_icons()

func _start_cooking() -> void:
	if _cooking:
		return
	var validation := KitchenManager.validate_ai_ingredients(selected_ingredients())
	if not bool(validation.get("ok", false)):
		var error: Dictionary = validation.get("error", {})
		_show_error(String(error.get("message", "请检查锅里的食材。")))
		return
	_cooking = true
	_state = "loading"
	_message = "AI 正在根据你的搭配生成一道新菜。等待时可以拖动木勺搅拌。"
	_cook_started_msec = Time.get_ticks_msec()
	_status_phase = -1
	_effects.cooking = true
	_drop_zone.enabled = false
	_spoon.enabled = true
	_set_close_locked(true)
	_rebuild_inventory()
	_rebuild_selection()
	var ingredients: Array = validation.get("ingredients", [])
	var result: Dictionary = await KitchenManager.craft_ai_dish_with_ingredients(ingredients, station)
	var elapsed := float(Time.get_ticks_msec() - _cook_started_msec) / 1000.0
	if elapsed < MIN_COOK_SECONDS:
		await get_tree().create_timer(MIN_COOK_SECONDS - elapsed).timeout
	if not is_inside_tree():
		return
	_cooking = false
	_effects.cooking = false
	_drop_zone.enabled = true
	_set_close_locked(false)
	if bool(result.get("ok", false)):
		_latest_dish = result.get("dish", {}) if result.get("dish", {}) is Dictionary else {}
		_state = "success"
		_message = ""
		_effects.success_burst = 1.0
		_stage_hint.text = "做好了！快看看这道新料理"
		AudioManager.play_sfx("收银机", -8.0)
		_rebuild_inventory()
		_rebuild_selection()
		SceneManager._show_toast("料理完成：%s" % String(_latest_dish.get("name", "随机料理")))
		return
	var error: Dictionary = result.get("error", {}) if result.get("error", {}) is Dictionary else {}
	_state = "error"
	_message = String(error.get("message", "AI 烹饪暂时没有成功，食材没有扣除。"))
	if _clamp_selected_to_inventory():
		_message += " 共享仓库存已变化，锅中数量已同步。"
	_stage_hint.text = "这次没有成功，食材还在锅里"
	_rebuild_inventory()
	_rebuild_selection()
	SceneManager._show_toast(_message)

func _reset_after_success() -> void:
	_latest_dish = {}
	_selected.clear()
	_state = "idle"
	_message = ""
	_effects.ingredient_count = 0
	_stage_hint.text = "先把喜欢的食材放进锅里"
	_rebuild_inventory()
	_rebuild_selection()
	_update_pot_icons()

func _update_pot_icons() -> void:
	for icon in _pot_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	_pot_icons.clear()
	if _stage == null:
		return
	var index := 0
	for iid_value in _selected:
		var iid := String(iid_value)
		var icon := _icon_rect(ItemDB.icon_texture(iid), 34)
		var angle := -PI * 0.85 + float(index) * (PI * 1.7 / maxf(1.0, float(_selected.size())))
		icon.position = Vector2(188, 124) + Vector2(cos(angle) * 62.0, sin(angle) * 17.0)
		icon.rotation = sin(float(index) * 1.7) * 0.12
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(icon)
		_stage.move_child(icon, _spoon.get_index())
		_pot_icons.append(icon)
		index += 1

func _on_spoon_stirred(amount: float) -> void:
	_effects.add_stir(amount)
	if _cooking:
		_stage_hint.text = "搅拌得正好，锅里越来越香了…"
	elif not _selected.is_empty():
		_stage_hint.text = "搭配好了就可以开始烹饪"

func _on_inventory_changed() -> void:
	if _cooking:
		return
	var changed := _clamp_selected_to_inventory()
	if changed:
		_message = "共享仓库存已变化，锅中数量已同步。"
	_rebuild_inventory()
	_rebuild_selection()
	_update_pot_icons()

func _clamp_selected_to_inventory() -> bool:
	var changed := false
	for iid_value in _selected.keys():
		var iid := String(iid_value)
		var available := InventoryManager.storehouse.count(iid)
		if available <= 0:
			_selected.erase(iid)
			changed = true
		elif int(_selected[iid]) > available:
			_selected[iid] = available
			changed = true
	return changed

func _set_close_locked(locked: bool) -> void:
	if card == null:
		return
	for child in card.get_children():
		if child is Button and (child as Button).text == "×":
			(child as Button).disabled = locked
			(child as Button).tooltip_text = "料理完成前请稍等" if locked else "关闭"

func _on_shade_input(event: InputEvent) -> void:
	if _cooking:
		if event is InputEventMouseButton and event.pressed:
			SceneManager._show_toast("料理还在锅里，请等它完成。")
		return
	super(event)

func _show_error(text: String) -> void:
	_state = "error"
	_message = text
	_rebuild_selection()
	SceneManager._show_toast(text)

func _atlas_texture(region: Rect2) -> Texture2D:
	var texture := AtlasTexture.new()
	texture.atlas = COOKING_ATLAS
	texture.region = region
	return texture

func _icon_rect(texture: Texture2D, size_px: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(size_px, size_px)
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect

func _label(text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	return label

func _box(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	return box
