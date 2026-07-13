extends Node

## 物品注册表(autoload ItemDB)。加载 items.json,按 id / 类别查询,解析图标。

const CATALOG_PATH := "res://assets/manifest/items.json"

var _defs: Dictionary = {}          ## id -> ItemDef
var _by_category: Dictionary = {}   ## category -> Array[String](id)
var _icon_cache: Dictionary = {}    ## icon_spec -> Texture2D

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
	return _defs.keys()

func by_category(cat: String) -> Array:
	return _by_category.get(cat, [])

## 把 "sheet:col:row" 解析成 32×32 的 AtlasTexture(复用现有图集,无需新图标资源)。
func icon_texture(id: String) -> Texture2D:
	var d: ItemDef = _defs.get(id, null)
	if d == null or d.icon_spec == "":
		return null
	if _icon_cache.has(d.icon_spec):
		return _icon_cache[d.icon_spec]
	if d.icon_spec.begins_with("res://"):
		if not ResourceLoader.exists(d.icon_spec):
			return null
		var direct_texture := load(d.icon_spec) as Texture2D
		_icon_cache[d.icon_spec] = direct_texture
		return direct_texture
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
