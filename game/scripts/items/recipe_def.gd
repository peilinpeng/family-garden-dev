class_name RecipeDef
extends RefCounted

## 单个配方定义(从 recipes.json 的一条记录构造)。厨房制作逻辑用它,不把配方硬编码进场景。

var id: String
var display_name: String
var station_type: String          ## stove / prep_table / pantry(决定在哪个站点面板出现)
var ingredients: Array = []       ## [{ "id": String, "qty": int }, ...]
var output_item_id: String
var output_quantity: int = 1
var unlock_requirement: String = ""  ## 可选,v1 留空 = 默认解锁
var description: String = ""

func _init(raw: Dictionary) -> void:
	id = str(raw.get("id", ""))
	display_name = str(raw.get("display_name", id))
	station_type = str(raw.get("station_type", "stove"))
	output_item_id = str(raw.get("output_item_id", ""))
	output_quantity = int(raw.get("output_quantity", 1))
	unlock_requirement = str(raw.get("unlock_requirement", ""))
	description = str(raw.get("description", ""))
	ingredients = []
	for ing in raw.get("ingredients", []):
		if ing is Dictionary and ing.has("id"):
			ingredients.append({ "id": str(ing.get("id", "")), "qty": int(ing.get("qty", 1)) })
