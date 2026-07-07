class_name CropDB
extends RefCounted

## 作物图集与目录。
## crops_daily.png: 448x256,32x32/帧,14列 x 8行。
## panel 0 = 左面板(列 0-6),panel 1 = 右面板(列 7-13)。每种作物 7 个生长阶段(stage 0-6)。

const SHEET := "res://assets/farm/crops_daily.png"
const CELL := 32
const STAGES := 7
const SECONDS_PER_STAGE := 600.0  ## 10 分钟一阶段(调试用,正式上线改这里即可)

## 16 种作物:row 0-7 两个面板。名字取自素材包 read me,可随意改。
const CROPS := [
	{"id": "corrato",   "panel": 0, "row": 0},
	{"id": "tomelone",  "panel": 0, "row": 1},
	{"id": "peanks",    "panel": 0, "row": 2},
	{"id": "cauliviol", "panel": 0, "row": 3},
	{"id": "bottarries","panel": 0, "row": 4},
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

## 给定作物的某个阶段,返回它在图集里的取帧矩形。
static func region(panel: int, row: int, stage: int) -> Rect2:
	var col := panel * 7 + clampi(stage, 0, STAGES - 1)
	return Rect2(col * CELL, row * CELL, CELL, CELL)
