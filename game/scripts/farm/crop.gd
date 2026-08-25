class_name Crop
extends Sprite2D

## 一株作物的视觉。用 crops_daily 图集按"给定生长阶段"切帧(阶段由 FarmManager 按时间戳算,
## 不再自己计时)。附带两个小指示:浇水(湿润蓝点)、施肥(肥沃棕点)。
## 脚底对齐种植点,z_index 按脚底 Y 排序。

var panel: int
var row: int
var crop_id: String = ""
var planted_at_unix: int = 0
var stage: int = 0
var elapsed: float = 0.0
var _wet: Sprite2D
var _fert: Sprite2D

func setup(p: int, r: int, plot_pos: Vector2, p_crop_id: String = "", p_planted_at_unix: int = 0) -> void:
	panel = p
	row = r
	crop_id = p_crop_id
	planted_at_unix = p_planted_at_unix if p_planted_at_unix > 0 else int(Time.get_unix_time_from_system())
	texture = load(CropDB.SHEET)
	centered = false
	region_enabled = true
	# 32x32 帧:水平居中、底边落在种植点上
	position = (plot_pos - Vector2(CropDB.CELL / 2.0, CropDB.CELL)).round()
	z_index = int(plot_pos.y)
	_build_indicators()
	_update_stage_from_clock()
	_refresh()

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
	set_stage(stage)

## 渲染指定阶段(0=幼苗 … STAGES-1=成熟)。
func set_stage(next_stage: int) -> void:
	stage = clampi(next_stage, 0, CropDB.STAGES - 1)
	region_rect = CropDB.region(panel, row, stage)

func is_mature() -> bool:
	return stage >= CropDB.STAGES - 1

func set_watered(on: bool) -> void:
	if _wet != null:
		_wet.visible = on

func set_fertilized(on: bool) -> void:
	if _fert != null:
		_fert.visible = on

func _build_indicators() -> void:
	# 湿润:作物底部一小抹半透明蓝(像浇过水的湿土)
	_wet = Sprite2D.new()
	_wet.texture = _solid(20, 5, Color(0.35, 0.62, 0.95, 0.55))
	_wet.centered = false
	_wet.position = Vector2(CropDB.CELL * 0.5 - 10, CropDB.CELL - 4)
	_wet.z_index = -1
	_wet.visible = false
	add_child(_wet)
	# 肥沃:右上角一个小棕点
	_fert = Sprite2D.new()
	_fert.texture = _solid(5, 5, Color(0.45, 0.30, 0.14, 0.9))
	_fert.centered = false
	_fert.position = Vector2(CropDB.CELL - 8, 4)
	_fert.visible = false
	add_child(_fert)

func _solid(w: int, h: int, c: Color) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)
