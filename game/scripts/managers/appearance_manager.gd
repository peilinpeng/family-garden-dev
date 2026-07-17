extends Node

## 玩家捏脸配置的唯一入口。身体、发型、发色与服装共同决定一张完整动作图集；
## 所有场景只读取 MemoryManager.character_appearance，运行时不再使用遮罩或 Shader 换色。

const CATALOG_PATH := "res://assets/manifest/appearances.json"
const ROLE_BODY_TYPES := {
	"player": "feminine",
	"partner": "masculine",
	"father": "masculine",
	"mother": "feminine",
	"grandfather": "masculine",
	"grandmother": "feminine",
}
const ROLE_DEFAULT_HAIR := {
	"player": "braid_hat",
	"partner": "tousled",
	"father": "side_part",
	"mother": "soft_bob",
}
var _catalog: Dictionary = {}
var _avatar_cache: Dictionary = {}

func _ready() -> void:
	_load_catalog()

func _load_catalog() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	_catalog = parsed if parsed is Dictionary else {}
	if _catalog.is_empty():
		push_error("[AppearanceManager] appearances.json 解析失败")

func default_for_role(role_key: String) -> Dictionary:
	var canonical := CharacterDB.resolve(role_key) if CharacterDB != null else role_key
	var body_type := String(ROLE_BODY_TYPES.get(canonical, "feminine"))
	var body: Dictionary = body_definition(body_type)
	return {
		"version": 1,
		"enabled": supports_customization(role_key),
		"body_type": body_type,
		"hair_style": String(ROLE_DEFAULT_HAIR.get(canonical, body.get("default_hair_style", "tousled"))),
		"hair_color": "brown",
		"outfit": "original",
	}

func normalize(raw: Dictionary, fallback_role: String = "player") -> Dictionary:
	var fallback := default_for_role(fallback_role)
	var result := raw.duplicate(true) if raw is Dictionary else {}
	var canonical := CharacterDB.resolve(fallback_role) if CharacterDB != null else fallback_role
	# 家庭身份同时决定基础身体。爸爸妈妈沿用儿子/女儿的统一身体比例，
	# 但使用各自烘焙好的脸部和发型图集，避免旧 papa/mama 画风混入。
	var body_type := String(ROLE_BODY_TYPES.get(canonical, fallback.body_type))
	var body := body_definition(body_type)
	var styles: Dictionary = body.get("hair_styles", {})
	var hair_style := String(result.get("hair_style", body.get("default_hair_style", "")))
	var allowed_styles := available_hair_styles(fallback_role)
	if not allowed_styles.has(hair_style):
		hair_style = String(ROLE_DEFAULT_HAIR.get(canonical, body.get("default_hair_style", styles.keys()[0] if not styles.is_empty() else "")))
	var hair_color := String(result.get("hair_color", "brown"))
	if not hair_colors().has(hair_color):
		hair_color = "brown"
	var outfit := String(result.get("outfit", "original"))
	if not outfits().has(outfit):
		outfit = "original"
	return {
		"version": 1,
		"enabled": supports_customization(fallback_role) and bool(result.get("enabled", not result.is_empty())),
		"body_type": body_type,
		"hair_style": hair_style,
		"hair_color": hair_color,
		"outfit": outfit,
	}

func current(fallback_role: String = "player") -> Dictionary:
	if MemoryManager == null:
		return default_for_role(fallback_role)
	return normalize(MemoryManager.character_appearance, fallback_role)

func set_current(appearance: Dictionary, fallback_role: String = "player") -> void:
	if MemoryManager == null:
		return
	var enabled_appearance := appearance.duplicate(true)
	enabled_appearance["enabled"] = supports_customization(fallback_role) and bool(appearance.get("enabled", true))
	MemoryManager.character_appearance = normalize(enabled_appearance, fallback_role)
	_avatar_cache.clear()
	MemoryManager.save_game()

func ensure_current(fallback_role: String) -> void:
	if MemoryManager == null:
		return
	# 旧存档没有捏脸字段时继续使用 papa/mama/girl/boy 原角色，不擅自改变其形象。
	if MemoryManager.character_appearance.is_empty():
		return
	var normalized := normalize(MemoryManager.character_appearance, fallback_role)
	if MemoryManager.character_appearance != normalized:
		MemoryManager.character_appearance = normalized
		MemoryManager.save_game()

func body_types() -> Dictionary:
	return _catalog.get("body_types", {})

func body_definition(body_type: String) -> Dictionary:
	return body_types().get(body_type, {})

func hair_styles(body_type: String) -> Dictionary:
	return body_definition(body_type).get("hair_styles", {})

func available_hair_styles(role_key: String) -> Dictionary:
	var canonical := CharacterDB.resolve(role_key) if CharacterDB != null else role_key
	if not supports_customization(canonical):
		return {}
	var body_type := String(ROLE_BODY_TYPES.get(canonical, "feminine"))
	var styles := hair_styles(body_type)
	if canonical in ["father", "mother"]:
		var style_id := String(ROLE_DEFAULT_HAIR.get(canonical, ""))
		var filtered: Dictionary = {}
		if styles.has(style_id):
			filtered[style_id] = styles[style_id]
		return filtered
	return styles

func supports_customization(role_key: String) -> bool:
	if CharacterDB == null:
		return true
	var definition := CharacterDB.get_def(role_key)
	return bool(definition.get("customizable", true))

func hair_colors() -> Dictionary:
	return _catalog.get("hair_colors", {})

func outfits() -> Dictionary:
	return _catalog.get("outfits", {})

func _resolved_definition(appearance: Dictionary, fallback_role: String) -> Dictionary:
	var clean := normalize(appearance, fallback_role)
	var style: Dictionary = hair_styles(String(clean.body_type)).get(String(clean.hair_style), {})
	var variants: Dictionary = style.get("outfit_variants", {})
	var result: Dictionary
	if String(clean.outfit) != "original" and variants.has(String(clean.outfit)):
		result = (variants[String(clean.outfit)] as Dictionary).duplicate(true)
	elif style.has("character_id"):
		var base := CharacterDB.get_def(String(style.character_id)).duplicate(true)
		base["hair_sheets"] = (style.get("hair_sheets", {}) as Dictionary).duplicate(true)
		result = base
	else:
		result = style.duplicate(true)
	var hair_sheets: Dictionary = result.get("hair_sheets", {})
	# 发色功能暂时不对玩家展示：存档仍保留 hair_color 原值，但渲染统一读取
	# 自然棕成品图。未来恢复时只需重新启用这里的 clean.hair_color。
	var color_id := "brown"
	if hair_sheets.has(color_id):
		result["sheet"] = String(hair_sheets[color_id])
	var canonical := CharacterDB.resolve(fallback_role) if CharacterDB != null else fallback_role
	if canonical in ["father", "mother"]:
		var parent_sheet := "parents/%s_%s" % [canonical, String(clean.outfit)]
		var parent_path := "res://assets/characters/%s.png" % parent_sheet
		if ResourceLoader.exists(parent_path):
			result["sheet"] = parent_sheet
	return result

func variant_definition(appearance: Dictionary, fallback_role: String = "player") -> Dictionary:
	var result := _resolved_definition(appearance, fallback_role)
	result["hframes"] = 3
	result["vframes"] = 5
	return result

func texture(appearance: Dictionary, fallback_role: String = "player") -> Texture2D:
	var definition := _resolved_definition(appearance, fallback_role)
	var sheet := String(definition.get("sheet", ""))
	var path := "res://assets/characters/%s.png" % sheet
	return load(path) if ResourceLoader.exists(path) else CharacterDB.texture(fallback_role)

func frame_rects(appearance: Dictionary, fallback_role: String = "player") -> Array:
	return variant_definition(appearance, fallback_role).get("frame_rects", [])

func avatar_texture(appearance: Dictionary, fallback_role: String = "player") -> Texture2D:
	var clean := normalize(appearance, fallback_role)
	var cache_key := JSON.stringify(clean)
	if _avatar_cache.has(cache_key):
		return _avatar_cache[cache_key]
	var source := texture(clean, fallback_role)
	var rects := frame_rects(clean, fallback_role)
	if source == null or rects.size() < 2:
		return CharacterDB.avatar_texture(fallback_role)
	var raw: Array = rects[1]
	var rect := Rect2i(int(raw[0]), int(raw[1]), int(raw[2]), int(raw[3]))
	var image := source.get_image().get_region(rect)
	var result := ImageTexture.create_from_image(image)
	_avatar_cache[cache_key] = result
	return result
