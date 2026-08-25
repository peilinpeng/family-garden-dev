# Mock JSON 示例

> 正式文件位于 `backend/mocks/`，机器约束位于 `backend/ai/schemas/`。
> 本页只作快速阅读，不是独立契约真源。

## 1. memory_card_mock.json

```json
{
  "title": "一次家庭旅行",
  "description": "这是一段温暖的家庭旅行记忆。画面中有户外空间和轻松的氛围。",
  "memory_type": "travel",
  "suggested_scene": "garden",
  "question": "你还记得这次旅行中最开心的一件事吗？",
  "node_type": "memory_flower",
  "confidence": 1.0,
  "safety_note": "仅整理用户提供的信息，没有推断具体人物关系。"
}
```

## 2. bottle_question_mock.json

```json
{
  "question": "你们上一次一起出去玩是什么时候？",
  "target_memory_type": "shared_memory",
  "suggested_scene": "fishpond",
  "prompt_type": "shared_memory",
  "tone": "warm",
  "safety_note": "问题保持开放和低压力，不预设家庭经历。"
}
```

## 3. kitchen_dish_mock.json

```json
{
  "name": "花园晨光小炒",
  "description": "把随机挑出的新鲜食材做成一盘明亮的小炒，味道清爽，适合摆在家庭餐桌中央。",
  "serving_note": "趁热端上桌，香气会更明显。",
  "family_question": "这道菜让你想到家里哪一次轻松的晚餐？",
  "visual": {
    "style": "soft_pixel_food_icon",
    "shape": "plate",
    "plate_color": "#F4E4C8",
    "base_color": "#F2C14E",
    "accent_colors": ["#D94B35", "#F07A3A", "#FFE08A"],
    "garnish_color": "#4E9D55"
  },
  "safety_note": "仅基于提供的食材生成料理说明，没有编造家庭事实。"
}
```

## 4. room_analysis_mock.json

```json
{
  "room_type": "bedroom",
  "style": "warm_cozy",
  "suggested_room_theme": "study_corner",
  "description": "这个房间适合生成一个温暖的学习角落。",
  "objects": [
    { "object_type": "desk", "zone": "back_left" },
    { "object_type": "lamp", "zone": "back_left" },
    { "object_type": "plant", "zone": "right_side" },
    { "object_type": "photo_wall", "zone": "back_wall" }
  ],
  "safety_note": "仅描述可见空间与物件，没有推断居住者身份。"
}
```

## 5. cross_memory_link_mock.json

```json
{
  "links": [
    {
      "memory_id_a": "mem_new",
      "memory_id_b": "mem_007",
      "relation_type": "same_place",
      "confidence": 0.78,
      "question": "这两段记忆看起来都与水边有关，它们是在同一个地方吗？",
      "node_type": "memory_link"
    }
  ],
  "safety_note": "仅依据已提供内容的可见重叠，没有推断人物关系。"
}
```

HTTP 返回时，以上对象放入统一响应的 `data`；同时返回 `ok` 和 `meta`。完整格式见 `docs/04_ai_interfaces.md`。
