# 04｜AI 接口与内容安全规范

## 1. 文档目的

本文档定义 Family Garden 中 AI 模块的角色、接口、输出格式和安全边界。AI 模块必须与游戏系统稳定对接，不能只返回一段自然语言。

AI 的核心任务是：

- 帮助整理记忆；
- 生成温和问题；
- 识别房间氛围和关键物件；
- 输出结构化 JSON；
- 为游戏系统提供可读取的字段。

---

## 2. AI 的产品定位

AI 是“记忆整理助手”，不是“故事编造者”。

AI 可以：

- 描述照片中可见的内容；
- 判断照片可能属于哪类记忆；
- 为家庭成员生成温和、开放的问题；
- 把用户提供的信息整理成记忆卡片；
- 判断推荐场景和节点类型；
- 识别房间照片中的关键物件。

AI 不可以：

- 编造家庭事实；
- 推断人物关系；
- 分析家庭矛盾；
- 判断谁爱谁；
- 生成心理诊断；
- 生成强煽情文本；
- 编造死亡、疾病、离婚、创伤等敏感情节；
- 输出地图坐标。

---

## 3. 总体数据流

```text
用户上传照片/文字/房间图
↓
创建 memory 记录
↓
调用 AI 中转接口
↓
AI 返回结构化 JSON
↓
后端保存 AI 结果
↓
游戏系统读取 suggested_scene 和 node_type
↓
SlotManager 分配位置
↓
NodeFactory 生成地图节点
```

AI 不直接决定游戏坐标。坐标由游戏系统根据场景槽位决定。

---

## 4. 接口一：生成记忆卡片

### 4.1 用途

用户上传家庭照片、旅行照片、明信片或文字后，生成一张可展示的记忆卡片，并为后续场景节点生成提供结构化字段。

### 4.2 接口名称

```text
POST /api/ai/generate-memory-card
```

### 4.3 输入示例

```json
{
  "memory_id": "mem_001",
  "family_id": "family_001",
  "user_id": "user_001",
  "input_type": "photo",
  "image_url": "https://example.com/photo.jpg",
  "raw_text": "这是我们几年前一起出去玩的照片。",
  "language": "zh-CN"
}
```

### 4.4 输出格式

```json
{
  "title": "一次温暖的家庭出游",
  "description": "这张照片看起来像是一段轻松的家庭旅行记忆。画面中有户外环境和多人合影，整体氛围比较愉快。",
  "memory_type": "travel",
  "suggested_scene": "garden",
  "question": "你还记得这次出游中最开心的一件事吗？",
  "node_type": "memory_flower",
  "confidence": 0.82,
  "safety_note": "AI 未推断具体家庭关系，仅根据画面和用户文字生成开放式问题。"
}
```

### 4.5 字段说明

| 字段 | 类型 | 说明 |
|---|---|---|
| title | string | 卡片标题，短而温暖 |
| description | string | 画面描述，不编造事实 |
| memory_type | string | travel / childhood / home / daily_life / family_event / personal_room / old_memory |
| suggested_scene | string | garden / fishpond / farm / old_street / room / travel_area |
| question | string | 给家庭成员的开放式问题 |
| node_type | string | memory_flower / photo_board / bottle / room_object / postcard |
| confidence | number | AI 判断置信度 |
| safety_note | string | 可选，用于说明边界 |

---

## 5. 接口二：生成漂流瓶问题

### 5.1 用途

为鱼塘、花园或其他场景生成温和的家庭回忆问题。

### 5.2 接口名称

```text
POST /api/ai/generate-bottle-question
```

### 5.3 输入示例

```json
{
  "family_id": "family_001",
  "scene": "fishpond",
  "target_memory_type": "childhood",
  "tone": "warm",
  "avoid_topics": ["conflict", "trauma", "health", "politics"]
}
```

### 5.4 输出示例

```json
{
  "question": "小时候有没有一次和家人一起出门玩，让你现在还记得？",
  "target_memory_type": "childhood",
  "suggested_scene": "fishpond",
  "prompt_type": "shared_memory",
  "tone": "warm"
}
```

### 5.5 好问题标准

好的问题：

- 温和；
- 开放；
- 不评判；
- 不逼迫；
- 不带预设答案；
- 能引发具体回忆。

示例：

- “你还记得上一次全家一起出去玩是什么时候吗？”
- “家里有没有一顿饭让你一直记得？”
- “小时候最让你安心的地方是哪里？”

不好的问题：

- “你是不是觉得父母不理解你？”
- “这次旅行有没有改善你们的关系？”
- “你最讨厌家里的谁？”
- “父母是否让你受伤？”

---

## 6. 接口三：分析房间照片

### 6.1 用途

用户上传房间照片后，AI 识别房间类型、氛围和关键物件。游戏系统根据结果生成一个氛围相似的个人房间。

### 6.2 接口名称

```text
POST /api/ai/analyze-room-photo
```

### 6.3 输入示例

```json
{
  "memory_id": "mem_room_001",
  "image_url": "https://example.com/room.jpg",
  "language": "zh-CN"
}
```

### 6.4 输出示例

```json
{
  "room_type": "bedroom",
  "style": "warm_cozy",
  "objects": ["desk", "lamp", "plant", "photo_wall"],
  "suggested_room_theme": "study_corner",
  "description": "这个房间看起来温暖、安静，适合生成一个带书桌、台灯、植物和照片墙的个人记忆空间。"
}
```

### 6.5 字段说明

| 字段 | 说明 |
|---|---|
| room_type | bedroom / study / living_room / kitchen_corner / unknown |
| style | warm_cozy / simple / nostalgic / bright / quiet |
| objects | 从资产库中可匹配的物件列表 |
| suggested_room_theme | 房间主题 |
| description | 给用户看的温和描述 |

### 6.6 房间物件映射示例

| AI object | 游戏资产 |
|---|---|
| desk | prop_room_desk_01 |
| lamp | prop_room_lamp_01 |
| plant | prop_room_plant_01 |
| photo_wall | prop_room_photo_wall_01 |
| bed | prop_room_bed_01 |
| chair | prop_room_chair_01 |

---

## 7. Mock / Fallback 数据

每个 AI 接口都必须有 mock 数据。如果真实 AI 失败，游戏仍然能继续演示。

### 7.1 记忆卡片 mock

```json
{
  "title": "一次家庭旅行",
  "description": "这是一段温暖的家庭旅行记忆。",
  "memory_type": "travel",
  "suggested_scene": "garden",
  "question": "你还记得这次旅行中最开心的一件事吗？",
  "node_type": "memory_flower",
  "confidence": 1.0
}
```

### 7.2 漂流瓶 mock

```json
{
  "question": "你们上一次一起出去玩是什么时候？",
  "target_memory_type": "shared_memory",
  "suggested_scene": "fishpond",
  "prompt_type": "shared_memory",
  "tone": "warm"
}
```

### 7.3 房间识别 mock

```json
{
  "room_type": "bedroom",
  "style": "warm_cozy",
  "objects": ["desk", "lamp", "plant", "photo_wall"],
  "suggested_room_theme": "study_corner",
  "description": "这个房间适合生成一个温暖的学习角落。"
}
```

---

## 8. Prompt 规则

AI 系统提示词必须包含：

```text
你是 Family Garden 的记忆整理助手。你的任务是帮助家庭成员整理他们已经提供的照片、文字和回忆，并提出温和、开放、低压力的问题，引导他们继续补充故事。

你不能编造家庭事实，不能推断人物关系，不能分析家庭矛盾，不能判断亲密关系，不能生成心理诊断，不能输出攻击性或过度煽情内容。

对于不确定的信息，必须使用“可能”“看起来像”“可以理解为”等表达。请输出结构化 JSON，不要输出多余解释。
```

---

## 9. AI 输出验收标准

AI 输出必须满足：

1. 是合法 JSON；
2. 字段完整；
3. 不包含地图坐标；
4. 不编造家庭事实；
5. 问题温和开放；
6. suggested_scene 能被游戏识别；
7. node_type 能被 NodeFactory 映射；
8. 失败时有 mock 替代；
9. 输出长度适合 UI 展示；
10. 中文表达自然，不像生硬问卷。
