# 13｜场景：AI 个人房间 AI Room

## 1. 场景定位

AI 个人房间用于把用户真实生活空间转化为游戏中的个人记忆空间。

这个功能不是复杂装修系统，也不是高精度 3D 房间重建。它的目标是：

> 让用户上传的房间照片，通过 AI 识别关键物件和氛围，生成一个“相似气质”的可互动游戏房间。

---

## 2. 体验目标

用户应该感到：

- 自己真实生活中的一些元素进入了游戏；
- 房间不是完全复制，但有熟悉的物件和氛围；
- 照片墙、书桌、台灯、植物等物件可以承载个人记忆；
- 这个房间是家庭花园中属于自己的小角落。

---

## 3. 核心玩法

玩家可以：

1. 上传房间照片；
2. AI 识别房间类型、风格和物件；
3. 游戏系统根据 AI 输出选择房间组件；
4. 生成个人房间；
5. 点击照片墙、书桌等物件查看记忆；
6. 返回家庭花园。

---

## 4. 空间布局

```text
┌────────────────────────────────────────────┐
│ 左侧：门 / 返回花园                         │
│                                            │
│ 中间：房间主体，书桌、床、地毯等             │
│                                            │
│ 右侧：照片墙 / 记忆物件区域                 │
│                                            │
│ 下方：房间识别结果 / 记忆卡片弹窗            │
└────────────────────────────────────────────┘
```

---

## 5. 资产清单

| asset_id | 资产名称 | 类型 | 功能 | 可点击 | 碰撞 | 前景遮挡 | 多状态 | 优先级 |
|---|---|---|---|---|---|---|---|---|
| scene_room_bg_01 | 房间背景 | background | 墙面和地板 | no | no | no | no | P0 |
| prop_room_door_01 | 房间门 | node/collision | 返回花园 | yes | yes | no | no | P0 |
| prop_room_window_01 | 窗户 | prop | 氛围 | optional | no | no | no | P0 |
| prop_room_desk_01 | 书桌 | prop/collision | 可承载记忆 | optional | yes | no | no | P0 |
| prop_room_lamp_01 | 台灯 | prop | AI 可识别物件 | optional | no | no | no | P0 |
| prop_room_plant_01 | 植物 | prop | AI 可识别物件 | optional | no | no | no | P0 |
| prop_room_photo_wall_01 | 照片墙 | node | 查看照片记忆 | yes | no | no | yes | P0 |
| prop_room_bed_01 | 床 | collision | 房间结构 | no | yes | no | no | P1 |
| prop_room_chair_01 | 椅子 | prop/collision | 房间物件 | optional | yes | no | no | P1 |
| node_room_memory_object_01 | 房间记忆物件 | node | AI 生成节点 | yes | optional | no | yes | P0 |
| ui_room_result_panel_01 | 房间结果面板 | ui | 展示 AI 识别结果 | no | no | no | no | P0 |

---

## 6. AI 房间生成逻辑

AI 输出示例：

```json
{
  "room_type": "bedroom",
  "style": "warm_cozy",
  "suggested_room_theme": "study_corner",
  "description": "这个房间看起来温暖安静，适合生成一个带书桌、台灯、植物和照片墙的个人空间。",
  "objects": [
    { "object_type": "desk", "zone": "back_left" },
    { "object_type": "lamp", "zone": "back_left" },
    { "object_type": "plant", "zone": "right_side" },
    { "object_type": "photo_wall", "zone": "back_wall" }
  ]
}
```

游戏系统处理：

1. 根据 `room_type` 选择背景；
2. 根据 `objects` 映射资产；
3. 使用预设槽位摆放物件；
4. 设置可点击和碰撞；
5. 生成房间结果 UI。

AI 不输出坐标，不直接生成完整地图。

---

## 7. 对象映射表

| AI object | asset_key | 默认功能 |
|---|---|---|
| desk | prop_room_desk_01 | 碰撞/房间物件 |
| lamp | prop_room_lamp_01 | 装饰/小记忆点 |
| plant | prop_room_plant_01 | 装饰 |
| photo_wall | prop_room_photo_wall_01 | 可点击记忆入口 |
| bed | prop_room_bed_01 | 碰撞/结构 |
| chair | prop_room_chair_01 | 碰撞/装饰 |
| window | prop_room_window_01 | 氛围 |

---

## 8. 验收标准

AI 房间完成标准：

1. 用户可以上传或选择一张房间图；
2. AI 或 mock 返回 room_type、style、objects；
3. 游戏根据 objects 生成至少 3 个房间物件；
4. 至少一个物件可点击；
5. 房间可返回花园；
6. 不追求精准复刻，只追求氛围相似；
7. 手机横屏下房间可读，UI 不遮挡关键区域。

---

## 9. 给 Claude / Cline 的开发提示词

```text
请读取 docs/04_ai_interfaces.md、docs/scenes/13_scene_ai_room.md 和 docs/ui/22_ui_upload_panel.md。
任务：实现 AI 个人房间的最小可运行版本。
要求：先用 mock room JSON，不接真实 AI；实现房间背景、根据 objects 生成物件、照片墙可点击、返回花园、房间识别结果面板。
不要做复杂装修系统，不要让 AI 输出坐标。
```
