extends CanvasLayer
class_name OpeningNarrativeLayer

## 启动剧情覆盖层(第一次进游戏播放,layer 30 盖住一切)。三幕:
##   幕1 家庭群消息(虚构"家庭消息"界面,逐条点击推进)
##   幕2 旁白(打字机,按空行分段,点击=本段显完/下一段)
##   幕3 旧木盒(5 个启动物占位卡)→「创建家庭花园」
## 右上角可跳过。结束发 finished(StoryManager 在那之后落 opening_seen)。
## 全程吃掉鼠标输入;若场上已有玩家(debug 重播)则锁移动,结束解锁。

signal finished

enum Act { CHAT, NARRATION, BOX }

## 幕1:家庭群消息(不模仿任何真实 App;自己的消息靠右)
const CHAT_MESSAGES := [
	{ "name": "妈妈", "text": "今天吃饭了吗？", "me": false },
	{ "name": "爸爸", "text": "那边天气怎么样？", "me": false },
	{ "name": "奶奶", "text": "别总熬夜。", "me": false },
	{ "name": "你", "text": "嗯嗯，我都挺好的。", "me": true },
]

## 幕2:旁白分段(用户提供文本,按空行拆段,原样不加戏)
const NARRATION_SEGMENTS := [
	"家常被说成是温馨的港湾。",
	"但很多时候，\n我们只是因为求学、工作和生活，\n慢慢住到了不同的地方。",
	"我们不是不关心彼此。\n只是聊天记录里，\n常常只剩下几句熟悉的问候：",
	"“吃饭了吗？”\n“最近怎么样？”\n“注意身体。”",
	"照片还在手机里。\n故事还在聊天记录里。\n那些没说完的话，\n也还留在某个角落。",
	"于是，我打开了这个家庭花园。",
	"这里可以种下一颗种子，\n做一顿饭，\n放进一张照片，\n留下一张明信片。",
	"也许家不一定总在同一个地方。\n有时候，\n它也可以是我们一起慢慢整理出来的地方。",
]

## 幕3:旧木盒美术(assets/begin_plot;整张图集临时按矩形裁切,后续换单图只需改 region)
const BOX_SHEET := "res://assets/begin_plot/box.png"        ## 横排 4 帧:关→微开→半开→全开,每帧 375×559
const OBJECTS_SHEET := "res://assets/begin_plot/objects.png"
const BOX_FRAME_SIZE := Vector2(375, 559)
const BOX_OPEN_FRAME_TIME := 0.16   ## 开盒动画每帧停留秒数

## 5 个启动物:region = 在 objects.png 里的包围盒(留 4px 边);对应玩法见 hint。
const BOX_ITEMS := [
	{ "id": "old_photo",      "name": "一张旧照片", "hint": "家庭树与相册的开始", "region": Rect2(91, 51, 227, 194) },
	{ "id": "seed_packet",    "name": "一包种子", "hint": "农场里种下第一颗", "region": Rect2(431, 60, 162, 192) },
	{ "id": "recipe_note",    "name": "手写菜谱", "hint": "厨房里那道家常菜", "region": Rect2(742, 51, 167, 196) },
	{ "id": "postcard_blank", "name": "空白明信片", "hint": "给家人留句话", "region": Rect2(246, 312, 244, 170) },
	{ "id": "garden_key",     "name": "写着 Garden 的小钥匙", "hint": "点它,打开家庭花园", "region": Rect2(593, 324, 145, 145) },
]

const TYPE_SPEED := 24.0   ## 打字机速度(字/秒)

var _act: int = Act.CHAT
var _root: Control
var _stage: Control            ## 当前幕的内容容器(切幕时整体替换)
var _chat_list: VBoxContainer
var _chat_index := 0
var _narration_label: Label
var _narration_index := 0
var _type_tween: Tween
var _fade: ColorRect

func _ready() -> void:
	layer = 30
	if SceneManager.player != null and is_instance_valid(SceneManager.player):
		SceneManager.set_player_input_locked(true)   # debug 重播时场上有玩家

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_click)
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.07, 1.0)   # 温暖的深色,不用纯黑
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage)

	var skip := Button.new()
	skip.text = "跳过 ›"
	skip.position = Vector2(1180, 18)
	skip.size = Vector2(84, 34)
	skip.mouse_filter = Control.MOUSE_FILTER_STOP
	skip.focus_mode = Control.FOCUS_NONE
	HUDPanel._style_soft_button(skip)
	skip.pressed.connect(_finish)
	_root.add_child(skip)

	var hint := Label.new()
	hint.text = "点击继续"
	hint.position = Vector2(0, 682)
	hint.size = Vector2(1280, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65, 0.45))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hint)

	# 整层淡入
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8)

	_enter_chat()

# ── 推进 ───────────────────────────────────────────────

func _on_click(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	match _act:
		Act.CHAT:
			_advance_chat()
		Act.NARRATION:
			_advance_narration()
		Act.BOX:
			pass   # 幕3 由"创建家庭花园"按钮收尾,点击空白不推进

# ── 幕1:家庭群消息 ─────────────────────────────────────

func _enter_chat() -> void:
	_act = Act.CHAT
	_clear_stage()
	var panel := Panel.new()
	panel.position = Vector2(400, 130)
	panel.size = Vector2(480, 430)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.98, 0.95, 0.88, 0.10)
	box.border_color = Color(0.85, 0.72, 0.52, 0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", box)
	_stage.add_child(panel)

	var title := Label.new()
	title.text = "🏠 家庭消息"
	title.position = Vector2(22, 16)
	title.size = Vector2(300, 26)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80, 0.9))
	panel.add_child(title)

	_chat_list = VBoxContainer.new()
	_chat_list.position = Vector2(22, 56)
	_chat_list.size = Vector2(436, 350)
	_chat_list.add_theme_constant_override("separation", 12)
	panel.add_child(_chat_list)

	_chat_index = 0
	_advance_chat()   # 先出第一条

func _advance_chat() -> void:
	if _chat_index < CHAT_MESSAGES.size():
		_chat_list.add_child(_make_bubble(CHAT_MESSAGES[_chat_index]))
		_chat_index += 1
	else:
		_enter_narration()

## 消息气泡(样式仿世界聊天:家人米色靠左、自己暖绿靠右)。加入时淡入。
func _make_bubble(msg: Dictionary) -> Control:
	var is_me := bool(msg.get("me", false))
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bubble := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.86, 0.93, 0.72, 0.92) if is_me else Color(1.0, 0.95, 0.82, 0.90)
	style.border_color = Color(0.58, 0.62, 0.36, 0.6) if is_me else Color(0.62, 0.48, 0.32, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	bubble.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	for m in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + m, 12)
	for m in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, 7)
	bubble.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	margin.add_child(vb)
	var who := Label.new()
	who.text = str(msg.get("name", ""))
	who.add_theme_font_size_override("font_size", 11)
	who.add_theme_color_override("font_color", Color(0.40, 0.33, 0.25, 0.85))
	vb.add_child(who)
	var body := Label.new()
	body.text = str(msg.get("text", ""))
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(0.20, 0.16, 0.12, 1.0))
	vb.add_child(body)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_me:
		row.add_child(sp)
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		row.add_child(sp)

	row.modulate.a = 0.0
	create_tween().tween_property(row, "modulate:a", 1.0, 0.35)
	return row

# ── 幕2:旁白(打字机) ──────────────────────────────────

func _enter_narration() -> void:
	_act = Act.NARRATION
	_clear_stage()
	_narration_label = Label.new()
	_narration_label.position = Vector2(240, 240)
	_narration_label.size = Vector2(800, 260)
	_narration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_narration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narration_label.add_theme_font_size_override("font_size", 21)
	_narration_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.83, 0.95))
	_narration_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_narration_label)
	_narration_index = 0
	_show_segment()

func _show_segment() -> void:
	var text: String = NARRATION_SEGMENTS[_narration_index]
	_narration_label.text = text
	_narration_label.visible_characters = 0
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_narration_label, "visible_characters", text.length(), text.length() / TYPE_SPEED)

func _advance_narration() -> void:
	# 正在打字 → 本段立即显完;已显完 → 下一段 / 进幕3
	if _narration_label.visible_characters >= 0 and _narration_label.visible_characters < _narration_label.text.length():
		if _type_tween != null and _type_tween.is_valid():
			_type_tween.kill()
		_narration_label.visible_characters = -1
		return
	_narration_index += 1
	if _narration_index < NARRATION_SEGMENTS.size():
		_show_segment()
	else:
		_enter_box()

# ── 幕3:旧木盒(真实美术:点盒 → 4 帧开启动画 → 物件弹出 → 点钥匙/按钮进入) ──

var _box_rect: TextureRect
var _box_atlas: AtlasTexture
var _box_opened := false
var _box_title: Label

func _enter_box() -> void:
	_act = Act.BOX
	_clear_stage()

	_box_title = Label.new()
	_box_title.text = "角落里,一个落了灰的旧木盒。"
	_box_title.position = Vector2(0, 92)
	_box_title.size = Vector2(1280, 30)
	_box_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box_title.add_theme_font_size_override("font_size", 19)
	_box_title.add_theme_color_override("font_color", Color(0.96, 0.92, 0.83, 0.95))
	_box_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_box_title)

	# 木盒:整张图集按 4 等分裁帧(后续换单图只需改 atlas/region)
	_box_atlas = AtlasTexture.new()
	_box_atlas.atlas = load(BOX_SHEET)
	_box_atlas.region = Rect2(Vector2.ZERO, BOX_FRAME_SIZE)
	_box_rect = TextureRect.new()
	_box_rect.texture = _box_atlas
	_box_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_box_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_box_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_box_rect.size = Vector2(300, 447)   # 375×559 × 0.8
	_box_rect.position = Vector2(490, 180)
	_box_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_box_rect)
	_box_rect.modulate.a = 0.0
	create_tween().tween_property(_box_rect, "modulate:a", 1.0, 0.5)

	# 点击热区:盖住盒体下半段(帧 0 的盒子画在贴图下半部)
	var hit := Button.new()
	hit.name = "BoxHitButton"
	hit.flat = true
	hit.position = _box_rect.position + Vector2(20, 220)
	hit.size = Vector2(260, 210)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		hit.add_theme_stylebox_override(s, empty)
	hit.pressed.connect(_open_box)
	_stage.add_child(hit)

	var tip := Label.new()
	tip.name = "BoxTip"
	tip.text = "点击木盒,打开它"
	tip.position = Vector2(0, 610)
	tip.size = Vector2(1280, 24)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65, 0.7))
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(tip)

## 播放 4 帧开启动画,停在全开帧,然后物件弹出。
func _open_box() -> void:
	if _box_opened:
		return
	_box_opened = true
	var hit := _stage.get_node_or_null("BoxHitButton")
	if hit != null:
		hit.queue_free()
	var tip := _stage.get_node_or_null("BoxTip")
	if tip != null:
		tip.queue_free()
	AudioManager.play_sfx("开门", -8.0)   # 暂借开门音效当开盒声,有专用音效后替换
	var t := create_tween()
	for f in [1, 2, 3]:
		t.tween_interval(BOX_OPEN_FRAME_TIME)
		t.tween_callback(_set_box_frame.bind(f))
	t.tween_interval(0.30)
	t.tween_callback(_pop_items)

func _set_box_frame(f: int) -> void:
	_box_atlas.region = Rect2(Vector2(f * BOX_FRAME_SIZE.x, 0), BOX_FRAME_SIZE)

## 5 个物件从盒口依次弹出,飞到上方一排;钥匙可点,同时出现"创建家庭花园"按钮。
func _pop_items() -> void:
	_box_title.text = "盒子里,装着一些被留下来的东西。"
	var box_mouth: Vector2 = _box_rect.position + Vector2(150, 260)   # 盒口(全开帧的开口处)
	var slot_x := [140.0, 368.0, 596.0, 824.0, 1052.0]   # 上方一排 5 个落点(每格宽 228)
	var slot_y := 150.0
	for i in BOX_ITEMS.size():
		var item: Dictionary = BOX_ITEMS[i]
		var region: Rect2 = item["region"]
		var atlas := AtlasTexture.new()
		atlas.atlas = load(OBJECTS_SHEET)
		atlas.region = region
		# 统一缩放到高约 120px,保持各物件比例
		var scale_f: float = 120.0 / region.size.y
		var display := region.size * scale_f

		var holder := Control.new()   # 物件 + 名字 + 说明 一组
		holder.position = box_mouth
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.modulate.a = 0.0
		holder.scale = Vector2(0.25, 0.25)
		_stage.add_child(holder)

		var img := TextureRect.new()
		img.texture = atlas
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		img.size = display
		img.position = Vector2(-display.x * 0.5, -display.y * 0.5)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(img)

		var name_lbl := Label.new()
		name_lbl.text = str(item["name"])
		name_lbl.position = Vector2(-110, display.y * 0.5 + 8)
		name_lbl.size = Vector2(220, 20)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.83, 0.95))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(name_lbl)

		var hint_lbl := Label.new()
		hint_lbl.text = str(item["hint"])
		hint_lbl.position = Vector2(-110, display.y * 0.5 + 28)
		hint_lbl.size = Vector2(220, 18)
		hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_lbl.add_theme_font_size_override("font_size", 12)
		hint_lbl.add_theme_color_override("font_color", Color(0.80, 0.72, 0.58, 0.8))
		hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(hint_lbl)

		# 钥匙可点:直接进入主流程
		if str(item["id"]) == "garden_key":
			var key_hit := Button.new()
			key_hit.flat = true
			key_hit.position = Vector2(-display.x * 0.5 - 10, -display.y * 0.5 - 10)
			key_hit.size = display + Vector2(20, 20)
			key_hit.mouse_filter = Control.MOUSE_FILTER_STOP
			key_hit.focus_mode = Control.FOCUS_NONE
			var empty2 := StyleBoxEmpty.new()
			for s in ["normal", "hover", "pressed", "focus"]:
				key_hit.add_theme_stylebox_override(s, empty2)
			key_hit.pressed.connect(_finish)
			key_hit.mouse_entered.connect(func() -> void:
				create_tween().tween_property(holder, "scale", Vector2(1.1, 1.1), 0.1))
			key_hit.mouse_exited.connect(func() -> void:
				create_tween().tween_property(holder, "scale", Vector2.ONE, 0.1))
			holder.add_child(key_hit)

		# 依次弹出:位置 + 缩放 + 淡入,带一点回弹
		var target := Vector2(slot_x[i] + 114.0, slot_y)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(holder, "position", target, 0.55).set_delay(i * 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(holder, "scale", Vector2.ONE, 0.55).set_delay(i * 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(holder, "modulate:a", 1.0, 0.35).set_delay(i * 0.14)

	# 物件出完后,给出双入口:点钥匙 或 底部按钮
	var t := create_tween()
	t.tween_interval(BOX_ITEMS.size() * 0.14 + 0.6)
	t.tween_callback(func() -> void:
		var create_btn := Button.new()
		create_btn.text = "🔑 创建家庭花园"
		create_btn.position = Vector2(520, 640)
		create_btn.size = Vector2(240, 46)
		create_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		create_btn.focus_mode = Control.FOCUS_NONE
		HUDPanel._style_soft_button(create_btn)
		create_btn.add_theme_font_size_override("font_size", 17)
		create_btn.pressed.connect(_finish)
		create_btn.modulate.a = 0.0
		_stage.add_child(create_btn)
		create_tween().tween_property(create_btn, "modulate:a", 1.0, 0.4))

# ── 收尾(创建花园 / 跳过共用) ─────────────────────────

var _finished := false

func _finish() -> void:
	# 防抖:跳过与创建按钮都走这里,快速双击/两个按钮先后点只收尾一次
	# (父级 mouse_filter=IGNORE 并不会屏蔽子按钮的点击,必须显式挡)。
	if _finished:
		return
	_finished = true
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.6)
	t.tween_callback(func() -> void:
		if SceneManager.player != null and is_instance_valid(SceneManager.player):
			SceneManager.set_player_input_locked(false)
		finished.emit()
		queue_free())

func _clear_stage() -> void:
	for c in _stage.get_children():
		c.queue_free()
