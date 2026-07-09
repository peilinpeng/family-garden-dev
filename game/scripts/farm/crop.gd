class_name Crop
extends Sprite2D

## 一株作物。用 crops_daily 图集,按生长阶段切帧,计时器推进阶段。
## 脚底对齐种植点,z_index 按脚底 Y 排序,实现与玩家/其它作物的前后遮挡。

var panel: int
var row: int
var crop_id: String = ""
var planted_at_unix: int = 0
var stage: int = 0
var elapsed: float = 0.0

func setup(p: int, r: int, plot_pos: Vector2, p_crop_id: String = "", p_planted_at_unix: int = 0) -> void:
	panel = p
	row = r
	crop_id = p_crop_id
	planted_at_unix = p_planted_at_unix if p_planted_at_unix > 0 else int(Time.get_unix_time_from_system())
	texture = load(CropDB.SHEET)
	centered = false
	region_enabled = true
	_update_stage_from_clock()
	_refresh()
	# 32x32 帧:水平居中、底边落在种植点上
	position = (plot_pos - Vector2(CropDB.CELL / 2.0, CropDB.CELL)).round()
	z_index = int(plot_pos.y)

func _process(delta: float) -> void:
	if stage >= CropDB.STAGES - 1:
		return
	elapsed += delta
	if elapsed >= 1.0:
		elapsed = 0.0
		var old_stage := stage
		_update_stage_from_clock()
		if stage != old_stage:
			_refresh()

func _update_stage_from_clock() -> void:
	if planted_at_unix <= 0:
		stage = 0
		return
	var age: float = max(0.0, float(Time.get_unix_time_from_system()) - float(planted_at_unix))
	stage = clampi(int(floor(age / CropDB.SECONDS_PER_STAGE)), 0, CropDB.STAGES - 1)

func seconds_until_mature() -> int:
	if is_mature():
		return 0
	var mature_at := float(planted_at_unix) + CropDB.SECONDS_PER_STAGE * float(CropDB.STAGES - 1)
	return max(0, int(ceil(mature_at - Time.get_unix_time_from_system())))

func _refresh() -> void:
	region_rect = CropDB.region(panel, row, stage)

func is_mature() -> bool:
	return stage >= CropDB.STAGES - 1
