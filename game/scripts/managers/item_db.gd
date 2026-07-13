extends Node

## 物品注册表(autoload ItemDB)。加载 items.json,按 id / 类别查询,解析图标。

const CATALOG_PATH := "res://assets/manifest/items.json"

var _defs: Dictionary = {}          ## id -> ItemDef
var _by_category: Dictionary = {}   ## category -> Array[String](id)
var _icon_cache: Dictionary = {}    ## icon_spec -> Texture2D
var _load_order: Array[String] = [] ## items.json 中的稳定顺序,供背包整理使用

func _ready() -> void:
	_load()

func _load() -> void:
	if not FileAccess.file_exists(CATALOG_PATH):
		push_error("[ItemDB] 缺少目录: " + CATALOG_PATH)
		return
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		push_error("[ItemDB] items.json 解析失败")
		return
	for raw in parsed.get("items", []):
		if raw is Dictionary:
			var def := ItemDef.new(raw)
			_defs[def.id] = def
			_by_category.get_or_add(def.category, []).append(def.id)
			_load_order.append(def.id)

func has(id: String) -> bool:
	return _defs.has(id)

func get_def(id: String) -> ItemDef:
	return _defs.get(id, null)

func display_name(id: String) -> String:
	var d: ItemDef = _defs.get(id, null)
	return d.name if d != null else id

func max_stack(id: String) -> int:
	var d: ItemDef = _defs.get(id, null)
	return d.max_stack if d != null else 99

func all_ids() -> Array:
	return _load_order.duplicate()

func catalog_index(id: String) -> int:
	var idx := _load_order.find(id)
	return idx if idx >= 0 else 999999

func by_category(cat: String) -> Array:
	return _by_category.get(cat, [])

## 支持 res:// 独立贴图路径，或把 "sheet:col:row" 解析成 32×32 的 AtlasTexture。
func icon_texture(id: String) -> Texture2D:
	var d: ItemDef = _defs.get(id, null)
	if d == null or d.icon_spec == "":
		return null
	if _icon_cache.has(d.icon_spec):
		return _icon_cache[d.icon_spec]
	if d.icon_spec.begins_with("res://"):
		if not ResourceLoader.exists(d.icon_spec):
			return null
		var standalone := load(d.icon_spec) as Texture2D
		if standalone != null:
			_icon_cache[d.icon_spec] = standalone
		return standalone
	var parts := d.icon_spec.split(":")
	if parts.size() != 3:
		return null
	var tex_path := "res://assets/farm/%s.png" % parts[0]
	if not ResourceLoader.exists(tex_path):
		return null
	var at := AtlasTexture.new()
	at.atlas = load(tex_path)
	at.region = Rect2(int(parts[1]) * 32, int(parts[2]) * 32, 32, 32)
	_icon_cache[d.icon_spec] = at
	return at
