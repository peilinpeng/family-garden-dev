extends Node

## 农场玩法逻辑(autoload FarmManager)。作物种植/浇水/施肥/收获 + 畜牧产出,全部与场景解耦。
## 状态存 MemoryManager(家庭共享,随 save_game 本地+云持久化):
##   - farm_plots: Array[FarmPlotState]  每格 {plot, crop_id, planted_at, watered, watered_at, fertilized, fertilized_at}
##   - farm_livestock: Dictionary        source_id -> last_collected_at
## 生长按时间戳算(不落 stage,退出/离线也能推进):浇一次水即开始长,到成熟为止。
## 库存一律走家庭共享仓 InventoryManager.storehouse(种子消耗优先共享仓、否则背包)。

signal changed   ## 任何作物/畜牧状态变化后发,场景据此重绘

# 畜牧定义(LivestockDefinition):source_id -> 产出/冷却/交互文案/就绪视觉
const LIVESTOCK := {
	"chicken_coop": { "output_item_id": "egg",  "output_quantity": 1, "production_cooldown": 120.0, "interaction_label": "收集鸡蛋", "visual_ready": "egg" },
	"cow_shed":     { "output_item_id": "milk", "output_quantity": 1, "production_cooldown": 180.0, "interaction_label": "收集牛奶", "visual_ready": "milk" },
}

func _now() -> float:
	# 时间戳生长的时间基准;联机对齐可加 GameClock.server_offset(留作 hook)。
	return Time.get_unix_time_from_system()

# ── 作物 ───────────────────────────────────────────────

func plots() -> Array:
	return MemoryManager.farm_plots

func get_plot(plot: int) -> Dictionary:
	for p in MemoryManager.farm_plots:
		if p is Dictionary and int(p.get("plot", -1)) == plot:
			return p
	return {}

func is_planted(plot: int) -> bool:
	return not get_plot(plot).is_empty()

## 播种:空地才行;消耗一颗 seed_<crop>(优先共享仓,否则背包)。成功返回 true。
func plant(plot: int, crop_id: String) -> bool:
	if is_planted(plot):
		return false
	if CropDB.find(crop_id).is_empty():
		return false
	if not _consume_seed(crop_id):
		return false
	MemoryManager.farm_plots.append({
		"plot": plot,
		"crop_id": crop_id,
		"planted_at": _now(),
		"watered": false,
		"watered_at": 0.0,
		"fertilized": false,
		"fertilized_at": 0.0,
	})
	_save()
	return true

func water(plot: int) -> bool:
	var p := get_plot(plot)
	if p.is_empty():
		return false
	p["watered"] = true
	p["watered_at"] = _now()
	_save()
	return true

func is_watered(plot: int) -> bool:
	var p := get_plot(plot)
	return not p.is_empty() and bool(p.get("watered", false))

## 施肥:每格只能一次。收获时 +1 产量。
func fertilize(plot: int) -> bool:
	var p := get_plot(plot)
	if p.is_empty() or bool(p.get("fertilized", false)):
		return false
	p["fertilized"] = true
	p["fertilized_at"] = _now()
	_save()
	return true

func is_fertilized(plot: int) -> bool:
	var p := get_plot(plot)
	return not p.is_empty() and bool(p.get("fertilized", false))

## 当前生长阶段:未浇水卡在 0;浇水后按 (now - watered_at)/stage_duration 推进到成熟。
func stage_of(plot: int) -> int:
	var p := get_plot(plot)
	if p.is_empty():
		return -1
	if not bool(p.get("watered", false)):
		return 0
	var dur: float = CropDB.stage_duration(str(p.get("crop_id", "")))
	if dur <= 0.0:
		return CropDB.STAGES - 1
	var elapsed: float = _now() - float(p.get("watered_at", 0.0))
	return clampi(int(floor(elapsed / dur)), 0, CropDB.STAGES - 1)

func is_mature(plot: int) -> bool:
	return is_planted(plot) and stage_of(plot) >= CropDB.STAGES - 1

## 距下一阶段(秒);已成熟返回 0,未浇水返回 -1(需先浇水)。
func seconds_to_next_stage(plot: int) -> float:
	var p := get_plot(plot)
	if p.is_empty():
		return 0.0
	if not bool(p.get("watered", false)):
		return -1.0
	if is_mature(plot):
		return 0.0
	var dur: float = CropDB.stage_duration(str(p.get("crop_id", "")))
	var elapsed: float = _now() - float(p.get("watered_at", 0.0))
	return maxf(0.0, dur - fmod(elapsed, dur))

## 收获:成熟才行。产出 produce_<crop> ×(base_yield + 施肥?1:0)进共享仓,清空地块。
func harvest(plot: int) -> int:
	var p := get_plot(plot)
	if p.is_empty() or not is_mature(plot):
		return 0
	var crop_id: String = str(p.get("crop_id", ""))
	var amount: int = CropDB.base_yield(crop_id) + (1 if bool(p.get("fertilized", false)) else 0)
	InventoryManager.give(CropDB.harvest_item_id(crop_id), amount, true)
	MemoryManager.farm_plots.erase(p)
	_save()
	return amount

func _consume_seed(crop_id: String) -> bool:
	var sid := CropDB.seed_item_id(crop_id)
	if InventoryManager.has(sid, 1, true):
		InventoryManager.take(sid, 1, true)
		return true
	if InventoryManager.has(sid, 1, false):
		InventoryManager.take(sid, 1, false)
		return true
	return false

# ── 畜牧 ───────────────────────────────────────────────

func livestock_ids() -> Array:
	return LIVESTOCK.keys()

func livestock_def(id: String) -> Dictionary:
	return LIVESTOCK.get(id, {})

func livestock_ready(id: String) -> bool:
	if not LIVESTOCK.has(id):
		return false
	if not MemoryManager.farm_livestock.has(id):
		return true   # 从没收集过 = 首次就绪
	var cd: float = float(LIVESTOCK[id].get("production_cooldown", 120.0))
	return _now() - float(MemoryManager.farm_livestock[id]) >= cd

func cooldown_left(id: String) -> float:
	if not LIVESTOCK.has(id) or not MemoryManager.farm_livestock.has(id):
		return 0.0
	var cd: float = float(LIVESTOCK[id].get("production_cooldown", 120.0))
	return maxf(0.0, cd - (_now() - float(MemoryManager.farm_livestock[id])))

## 收集畜牧产出:就绪才行。产出进共享仓 + 进冷却。返回收集数量(0=没就绪)。
func collect(id: String) -> int:
	if not livestock_ready(id):
		return 0
	var d: Dictionary = LIVESTOCK[id]
	var qty: int = int(d.get("output_quantity", 1))
	InventoryManager.give(str(d.get("output_item_id", "")), qty, true)
	MemoryManager.farm_livestock[id] = _now()
	_save()
	return qty

# ── 持久化 ─────────────────────────────────────────────

func _save() -> void:
	MemoryManager.save_game()
	changed.emit()

# ── Debug(仅开发/验收用) ──────────────────────────────

## 发一套测试用种子/肥料/浇水壶到家庭共享仓(不碰花园收获逻辑)。
func grant_test_kit() -> void:
	for cid in ["corrato", "bottarries", "cauliviol"]:
		InventoryManager.give(CropDB.seed_item_id(cid), 5, true)
	InventoryManager.give("fertilizer", 5, true)
	InventoryManager.give("tool_wateringcan", 1, true)

## 把某格生长往前推进一个阶段(把 watered_at 往回挪一个 stage_duration)。
func advance_stage(plot: int) -> void:
	var p := get_plot(plot)
	if p.is_empty():
		return
	if not bool(p.get("watered", false)):
		p["watered"] = true
		p["watered_at"] = _now()
	var dur: float = CropDB.stage_duration(str(p.get("crop_id", "")))
	p["watered_at"] = float(p.get("watered_at", _now())) - dur
	_save()

## 立即成熟:确保已浇水且 watered_at 足够早。
func mature_now(plot: int) -> void:
	var p := get_plot(plot)
	if p.is_empty():
		return
	var dur: float = CropDB.stage_duration(str(p.get("crop_id", "")))
	p["watered"] = true
	p["watered_at"] = _now() - dur * float(CropDB.STAGES) - 1.0
	_save()

func make_livestock_ready(id: String) -> void:
	if not LIVESTOCK.has(id):
		return
	var cd: float = float(LIVESTOCK[id].get("production_cooldown", 120.0))
	MemoryManager.farm_livestock[id] = _now() - cd - 1.0
	_save()
