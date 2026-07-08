class_name Crop
extends Sprite2D

## 一株作物的视觉。用 crops_daily 图集按"给定生长阶段"切帧(阶段由 FarmManager 按时间戳算,
## 不再自己计时)。附带两个小指示:浇水(湿润蓝点)、施肥(肥沃棕点)。
## 脚底对齐种植点,z_index 按脚底 Y 排序。

var panel: int
var row: int
var _wet: Sprite2D
var _fert: Sprite2D

func setup(p: int, r: int, plot_pos: Vector2) -> void:
	panel = p
	row = r
	texture = load(CropDB.SHEET)
	centered = false
	region_enabled = true
	# 32x32 帧:水平居中、底边落在种植点上
	position = (plot_pos - Vector2(CropDB.CELL / 2.0, CropDB.CELL)).round()
	z_index = int(plot_pos.y)
	_build_indicators()
	set_stage(0)

## 渲染指定阶段(0=幼苗 … STAGES-1=成熟)。
func set_stage(stage: int) -> void:
	region_rect = CropDB.region(panel, row, stage)

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
