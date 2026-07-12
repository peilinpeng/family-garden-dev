extends Node

## 配方注册表(autoload RecipeDB)。加载 recipes.json,按 id / station 查询。仿 ItemDB 结构。

const CATALOG_PATH := "res://assets/manifest/recipes.json"

var _defs: Dictionary = {}         ## id -> RecipeDef
var _by_station: Dictionary = {}   ## station_type -> Array[String](id)
var _order: Array = []             ## 保持 json 里的顺序

func _ready() -> void:
	_load()

func _load() -> void:
	if not FileAccess.file_exists(CATALOG_PATH):
		push_error("[RecipeDB] 缺少目录: " + CATALOG_PATH)
		return
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		push_error("[RecipeDB] recipes.json 解析失败")
		return
	for raw in parsed.get("recipes", []):
		if raw is Dictionary:
			var def := RecipeDef.new(raw)
			_defs[def.id] = def
			_order.append(def.id)
			_by_station.get_or_add(def.station_type, []).append(def.id)

func has(id: String) -> bool:
	return _defs.has(id)

func get_def(id: String) -> RecipeDef:
	return _defs.get(id, null)

## 全部配方(RecipeDef 数组,按 json 顺序)。
func all() -> Array:
	var out: Array = []
	for id in _order:
		out.append(_defs[id])
	return out

## 某站点的配方(RecipeDef 数组)。station_type = stove / prep_table / pantry。
func by_station(station: String) -> Array:
	var out: Array = []
	for id in _by_station.get(station, []):
		out.append(_defs[id])
	return out
