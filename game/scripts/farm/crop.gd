class_name Crop
extends Sprite2D

## 一株作物。用 crops_daily 图集,按生长阶段切帧,计时器推进阶段。
## 脚底对齐种植点,z_index 按脚底 Y 排序,实现与玩家/其它作物的前后遮挡。

var panel: int
var row: int
var stage: int = 0
var elapsed: float = 0.0

func setup(p: int, r: int, plot_pos: Vector2) -> void:
	panel = p
	row = r
	texture = load(CropDB.SHEET)
	centered = false
	region_enabled = true
	_refresh()
	# 32x32 帧:水平居中、底边落在种植点上
	position = (plot_pos - Vector2(CropDB.CELL / 2.0, CropDB.CELL)).round()
	z_index = int(plot_pos.y)

func _process(delta: float) -> void:
	if stage >= CropDB.STAGES - 1:
		return
	elapsed += delta
	if elapsed >= CropDB.SECONDS_PER_STAGE:
		elapsed -= CropDB.SECONDS_PER_STAGE
		stage += 1
		_refresh()

func _refresh() -> void:
	region_rect = CropDB.region(panel, row, stage)

func is_mature() -> bool:
	return stage >= CropDB.STAGES - 1
