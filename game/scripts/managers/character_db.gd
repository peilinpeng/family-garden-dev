extends Node

## 角色注册表(autoload CharacterDB)。加载 characters.json,按 id/别名查角色配置。
## 每个角色:sheet(贴图)+ hframes/vframes(走路表网格)+ scale(屏上尺寸归一)。
## 同一套数据供本地玩家 Player 与联机远端 RemotePlayer 复用。

const CATALOG_PATH := "res://assets/manifest/characters.json"

var _defs: Dictionary = {}      ## id -> Dictionary
var _aliases: Dictionary = {}   ## role_key -> 规范 id
var _order: Array = []

func _ready() -> void:
	_load()

func _load() -> void:
	if not FileAccess.file_exists(CATALOG_PATH):
		push_error("[CharacterDB] 缺少: " + CATALOG_PATH)
		return
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		push_error("[CharacterDB] characters.json 解析失败")
		return
	for c in parsed.get("characters", []):
		if c is Dictionary and c.has("id"):
			_defs[str(c.id)] = c
			_order.append(str(c.id))
	_aliases = parsed.get("aliases", {})

## 把任意 role_key(father/papa/girl/...)解析成规范角色 id;未知则回退第一个。
func resolve(role_key: String) -> String:
	if _defs.has(role_key):
		return role_key
	if _aliases.has(role_key):
		return str(_aliases[role_key])
	return _order[0] if _order.size() > 0 else ""

func has(id: String) -> bool:
	return _defs.has(id)

func get_def(id: String) -> Dictionary:
	return _defs.get(resolve(id), {})

func display_name(id: String) -> String:
	return str(get_def(id).get("name", id))

func texture(id: String) -> Texture2D:
	var d := get_def(id)
	if d.is_empty():
		return null
	var path := "res://assets/characters/%s.png" % str(d.get("sheet", ""))
	return load(path) if ResourceLoader.exists(path) else null

func all_ids() -> Array:
	return _order.duplicate()
