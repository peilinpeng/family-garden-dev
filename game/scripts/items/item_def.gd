class_name ItemDef
extends RefCounted

## 单个物品定义(从 items.json 的一条记录构造)。

var id: String
var name: String
var category: String      ## seed / produce / tool / gift / currency / decor
var max_stack: int = 99
var icon_spec: String = ""  ## "sheet:col:row",由 ItemDB.icon_texture 解析成 AtlasTexture
var ownership_type: String = "both"  ## personal / household / both:决定物品默认归个人背包还是家庭共享仓
var data: Dictionary = {}   ## 类别专属字段(crop_id / sell / buy / giftable / object_type ...)

func _init(raw: Dictionary) -> void:
	id = str(raw.get("id", ""))
	name = str(raw.get("name", id))
	category = str(raw.get("category", "misc"))
	max_stack = int(raw.get("max_stack", 99))
	icon_spec = str(raw.get("icon", ""))
	ownership_type = str(raw.get("ownership_type", "both"))
	data = raw.duplicate(true)

func get_field(key: String, default: Variant = null) -> Variant:
	return data.get(key, default)

func is_stackable() -> bool:
	return max_stack > 1

func crop_id() -> String:
	return str(data.get("crop_id", ""))
