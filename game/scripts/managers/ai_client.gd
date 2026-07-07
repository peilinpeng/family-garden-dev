extends Node

## Family Garden AI 客户端层（autoload 单例）。
## 所有 AI 能力的统一入口。接口对齐 docs/04（generate-memory-card / generate-bottle-question /
## analyze-room-photo / cross-memory-link）。
##
## 迭代2：默认走内联 mock（镜像 backend/mocks/*.json，单一真源）。
## set_backend 注入真后端后，异步 AI 方法走真调用（HTTP 云函数接混元），失败/无效自动回退 mock。
## 真后端契约：实现 `request(endpoint: String, payload: Dictionary) -> Variant`（异步，返回结构化 JSON）。
## 迭代2.5 落地真后端，本层与调用点签名不变。

# 真后端（HTTP 云函数）；null = 仅 mock。
var _backend: Object = null

# ── 内联 mock（单一真源；阶段2 真调用到位后作为 fallback）──────────────────
const MOCK_MEMORY_CARD := {
	"title": "一次家庭旅行",
	"description": "这是一段温暖的家庭旅行记忆。画面中有户外空间和轻松的氛围。",
	"memory_type": "travel",
	"suggested_scene": "garden",
	"question": "你还记得这次旅行中最开心的一件事吗？",
	"node_type": "memory_flower",
	"confidence": 1.0,
	"guess": "可能是 1990 年代的旅行"
}

const MOCK_ROOM_ANALYSIS := {
	"room_type": "bedroom",
	"style": "warm_cozy",
	"suggested_room_theme": "study_corner",
	"description": "这个房间适合生成一个温暖的学习角落。",
	"objects": [
		{"object_type": "desk", "zone": "back_left"},
		{"object_type": "lamp", "zone": "back_left"},
		{"object_type": "plant", "zone": "right_side"},
		{"object_type": "photo_wall", "zone": "back_wall"}
	]
}

const MOCK_BOTTLE_QUESTIONS := [
	"爸爸最常带你们去哪里钓鱼或散步？",
	"有没有一个和爸爸在水边度过的周末，你一直记得？",
]

const MOCK_LINK := {
	"relation_type": "same_place",
	"question": "这两段记忆好像在同一个地方？和家人聊聊那里的故事吧"
}

func set_backend(backend: Object) -> void:
	_backend = backend

# ── 同步 mock 取值：建场景期的 demo 种子数据（不触发真调用）─────────────────
func mock_memory_card() -> Dictionary:
	return MOCK_MEMORY_CARD.duplicate(true)

func mock_room_analysis() -> Dictionary:
	return MOCK_ROOM_ANALYSIS.duplicate(true)

func mock_bottle_questions() -> Array:
	return MOCK_BOTTLE_QUESTIONS.duplicate(true)

func mock_link() -> Dictionary:
	return MOCK_LINK.duplicate(true)

# ── 异步 AI 接口（真后端优先 + 失败/无效回退 mock）。接口名对齐 docs/04 ──────────
func generate_memory_card(image_url: String, text: String = "") -> Dictionary:
	return await _call("/api/ai/generate-memory-card", {"image_url": image_url, "text": text}, MOCK_MEMORY_CARD)

func analyze_room_photo(image_url: String) -> Dictionary:
	return await _call("/api/ai/analyze-room-photo", {"image_url": image_url}, MOCK_ROOM_ANALYSIS)

func generate_bottle_question(context: Dictionary = {}) -> Array:
	return await _call("/api/ai/generate-bottle-question", context, MOCK_BOTTLE_QUESTIONS)

func cross_memory_link(memory_id: String, candidates: Array = []) -> Dictionary:
	return await _call("/api/ai/cross-memory-link", {"memory_id": memory_id, "candidates": candidates}, MOCK_LINK)

# 统一调用 + 回退：真后端优先；缺省/失败/无效 → 回退 mock。
func _call(endpoint: String, payload: Dictionary, fallback: Variant) -> Variant:
	if _backend != null and _backend.has_method("request"):
		var result: Variant = await _backend.request(endpoint, payload)
		if _is_valid(result):
			return result
		push_warning("[AIClient] %s 返回无效，回退 mock" % endpoint)
	return _dup(fallback)

func _is_valid(result: Variant) -> bool:
	return (result is Dictionary and not (result as Dictionary).is_empty()) \
		or (result is Array and not (result as Array).is_empty())

func _dup(v: Variant) -> Variant:
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v
