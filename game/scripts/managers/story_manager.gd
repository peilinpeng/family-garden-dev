extends Node

## 启动剧情 / 章节任务管理(autoload StoryManager)。
## - 开场叙事:play_opening() 播放 OpeningNarrativeLayer,结束(含跳过)设 opening_seen 并存档;
## - Chapter 1 任务:常量任务表 + 完成态存 MemoryManager.chapter1_tasks(个人 onboarding 态);
##   农场/厨房任务由信号驱动自动打勾(FarmManager.planted/harvested、KitchenManager.crafted/meal_completed);
## - 记忆卡:unlock_card 落 MemoryManager.memory_cards + 弹 MemoryCardPopup。
## 未来接入点:记忆卡 → FamilyTree/Postcards/相册/云端;opening_seen → per-member 云 profile。

signal task_completed(task_id: String)
signal memory_card_unlocked(card: Dictionary)

## Chapter 1 任务表(顺序即展示顺序)。tracked=false 的靠 UI 按钮完成。
const CHAPTER1 := [
	{ "id": "open_box",     "label": "打开旧木盒" },
	{ "id": "first_photo",  "label": "放入第一张照片" },
	{ "id": "first_seed",   "label": "种下第一颗种子" },
	{ "id": "harvest_tomato", "label": "收获番茄" },
	{ "id": "first_dish",   "label": "做第一道家常菜" },
	{ "id": "dish_on_table", "label": "把它放到餐桌上" },
]

const CARDS := {
	"first_photo": { "id": "first_photo", "title": "第一张照片", "desc": "这张照片被放进了家庭花园。", "emoji": "📷" },
	"first_dish":  { "id": "first_dish",  "title": "第一道家常菜", "desc": "每个家都有自己的番茄炒蛋。", "emoji": "🍳" },
}

func _ready() -> void:
	# 任务自动追踪钩子(信号驱动,无轮询)。已完成的任务重复触发无副作用。
	FarmManager.planted.connect(func(_crop_id: String) -> void:
		complete_task("first_seed"))
	FarmManager.harvested.connect(func(crop_id: String, _item_id: String, _qty: int) -> void:
		if crop_id == "corrato":   # 红番茄
			complete_task("harvest_tomato"))
	KitchenManager.crafted.connect(func(_recipe_id: String, _output_id: String) -> void:
		if complete_task("first_dish"):
			unlock_card("first_dish"))
	KitchenManager.meal_completed.connect(func(_meal: Dictionary) -> void:
		complete_task("dish_on_table"))

# ── 开场叙事 ───────────────────────────────────────────

## 播放开场(await 到结束/跳过)。host:挂载 overlay 的节点(main 根)。
## debug replay 时传 mark_seen=false 以外的场景都会落 opening_seen。
var _pending_quest_intro := false   ## 开场刚播完,等进入花园后自动弹一次任务面板

func play_opening(host: Node) -> void:
	var layer := OpeningNarrativeLayer.new()
	host.add_child(layer)
	await layer.finished
	MemoryManager.opening_seen = true
	complete_task("open_box", true)   # 开场里已打开旧木盒(静默,不弹 toast)
	MemoryManager.save_game()
	_pending_quest_intro = true

## 进花园后调一次:开场刚播过则返回 true(并清标记),用于启动屏幕高亮引导。
func consume_quest_intro() -> bool:
	var pending := _pending_quest_intro
	_pending_quest_intro = false
	return pending

## 开发用:重置并立即重播开场(SettingsPanel 的"重播开场(开发)"按钮调)。不清任务进度。
func debug_replay_opening(host: Node) -> void:
	MemoryManager.opening_seen = false
	await play_opening(host)
	consume_quest_intro()   # 重播场景里人已在花园,直接启动高亮引导
	if SceneManager.game_hud != null:
		SceneManager.game_hud.start_onboarding_guide(true)

# ── Chapter 1 任务 ─────────────────────────────────────

func tasks() -> Array:
	return CHAPTER1

func is_task_done(task_id: String) -> bool:
	return bool(MemoryManager.chapter1_tasks.get(task_id, false))

## 当前应做的任务 id(第一个未完成);全完成返回 ""。
func current_task() -> String:
	for t in CHAPTER1:
		if not is_task_done(str(t.id)):
			return str(t.id)
	return ""

## 标记任务完成。返回"这次是否真的从未完成→完成"(重复调用返回 false)。
func complete_task(task_id: String, silent: bool = false) -> bool:
	if is_task_done(task_id):
		return false
	MemoryManager.chapter1_tasks[task_id] = true
	MemoryManager.save_game()
	task_completed.emit(task_id)
	if not silent:
		for t in CHAPTER1:
			if str(t.id) == task_id:
				SceneManager._show_toast("✅ 任务完成:" + str(t.label))
				break
	return true

# ── 记忆卡 ─────────────────────────────────────────────

func has_card(card_id: String) -> bool:
	for c in MemoryManager.memory_cards:
		if c is Dictionary and str(c.get("id", "")) == card_id:
			return true
	return false

## 解锁记忆卡:落存档 + 弹卡面。重复解锁忽略。
func unlock_card(card_id: String) -> void:
	if has_card(card_id) or not CARDS.has(card_id):
		return
	var card: Dictionary = CARDS[card_id].duplicate()
	card["unlocked_at"] = Time.get_datetime_string_from_system()
	MemoryManager.memory_cards.append(card)
	MemoryManager.save_game()
	memory_card_unlocked.emit(card)
	if SceneManager.game_hud != null:
		var popup := MemoryCardPopup.new()
		popup.card_data = card
		SceneManager.game_hud.open_panel(popup)
