class_name CropDB
extends RefCounted

## 作物图集与目录。
## crops_daily.png: 448x256,32x32/帧,14列 x 8行。
## panel 0 = 左面板(列 0-6),panel 1 = 右面板(列 7-13)。每种作物 7 个生长阶段(stage 0-6)。

const SHEET := "res://assets/farm/crops_daily.png"
const CELL := 32
const STAGES := 7
const SECONDS_PER_STAGE := 600.0  ## 旧字段:保留兼容,新生长走 stage_duration(crop_id)

const DEFAULT_STAGE_DURATION := 120.0  ## 每作物可覆盖;满熟 = (STAGES-1) × 该值
const DEFAULT_YIELD := 2

## 16 种作物:row 0-7 两个面板。CropDefinition 字段:可选 display_name / stage_duration / base_yield
## (未标注的用上面的默认值)。seed_item_id = "seed_<id>",harvest_item_id = "produce_<id>"(约定派生)。
## 第一版重点作物:corrato=番茄、bottarries=草莓、cauliviol=紫花菜。
const CROPS := [
	{"id": "corrato",   "panel": 0, "row": 0, "display_name": "番茄",   "stage_duration": 90.0,  "base_yield": 2},
	{"id": "tomelone",  "panel": 0, "row": 1},
	{"id": "peanks",    "panel": 0, "row": 2},
	{"id": "cauliviol", "panel": 0, "row": 3, "display_name": "紫花菜", "stage_duration": 150.0, "base_yield": 3},
	{"id": "bottarries","panel": 0, "row": 4, "display_name": "草莓",   "stage_duration": 120.0, "base_yield": 2},
	{"id": "safruma",   "panel": 0, "row": 5},
	{"id": "mooam",     "panel": 0, "row": 6},
	{"id": "reoin",     "panel": 0, "row": 7},
	{"id": "rocue",     "panel": 1, "row": 0},
	{"id": "sproccili", "panel": 1, "row": 1},
	{"id": "cacorange", "panel": 1, "row": 2},
	{"id": "popacom",   "panel": 1, "row": 3},
	{"id": "chuf",      "panel": 1, "row": 4},
	{"id": "trevainne", "panel": 1, "row": 5},
	{"id": "cacerries", "panel": 1, "row": 6},
	{"id": "aubaba",    "panel": 1, "row": 7},
]

static func get_crop(index: int) -> Dictionary:
	return CROPS[index % CROPS.size()]

static func get_crop_by_id(crop_id: String) -> Dictionary:
	return find(crop_id)

## 按 crop_id 找配置(找不到返回空字典)。
static func find(crop_id: String) -> Dictionary:
	for c in CROPS:
		if str(c.id) == crop_id:
			return c
	return {}

static func display_name(crop_id: String) -> String:
	var c := find(crop_id)
	return str(c.get("display_name", crop_id)) if not c.is_empty() else crop_id

static func stage_duration(crop_id: String) -> float:
	var c := find(crop_id)
	return float(c.get("stage_duration", DEFAULT_STAGE_DURATION)) if not c.is_empty() else DEFAULT_STAGE_DURATION

static func base_yield(crop_id: String) -> int:
	var c := find(crop_id)
	return int(c.get("base_yield", DEFAULT_YIELD)) if not c.is_empty() else DEFAULT_YIELD

static func seed_item_id(crop_id: String) -> String:
	return "seed_" + crop_id

static func harvest_item_id(crop_id: String) -> String:
	return "produce_" + crop_id

## 给定作物的某个阶段,返回它在图集里的取帧矩形。
static func region(panel: int, row: int, stage: int) -> Rect2:
	var col := panel * 7 + clampi(stage, 0, STAGES - 1)
	return Rect2(col * CELL, row * CELL, CELL, CELL)
