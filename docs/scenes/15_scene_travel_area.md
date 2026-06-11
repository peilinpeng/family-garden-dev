# 15｜场景：旅行区域 Travel Area

## 1. 场景定位

旅行区域用于承载家庭旅行、异地生活、城市打卡和明信片记忆。比赛阶段可先做成一个轻量区域或明信片面板，不一定开发完整地图。

它适合连接：

- 家庭旅行照片；
- 留学生/异地生活照片；
- AI 生成明信片；
- 地图标记。

---

## 2. 体验目标

旅行区域应该让用户感到：

- 每次家庭旅行都可以成为一张可保存的明信片；
- 异地生活不是单独存在，而可以被带回家庭花园；
- 旅行照片能引发家庭成员的共同回忆。

---

## 3. 核心玩法

玩家可以：

1. 上传旅行照片；
2. AI 生成旅行记忆卡片；
3. AI 生成温暖的明信片描述；
4. 地图上出现旅行标记或明信片节点；
5. 点击查看照片、描述和家庭成员回答。

---

## 4. 资产清单

| asset_id | 资产名称 | 类型 | 功能 | 可点击 | 碰撞 | 前景遮挡 | 多状态 | 优先级 |
|---|---|---|---|---|---|---|---|---|
| scene_travel_bg_01 | 旅行区域背景 | background | 旅行记忆场景 | no | no | no | no | P2 |
| node_travel_postcard_01 | 明信片节点 | node | 查看旅行记忆 | yes | no | no | yes | P1 |
| prop_travel_map_pin_01 | 地图标记 | node | 旅行地点 | yes | no | no | no | P2 |
| prop_travel_suitcase_01 | 行李箱 | prop/collision | 旅行氛围 | optional | yes | no | no | P2 |
| prop_travel_camera_01 | 相机 | prop/node | 上传照片入口 | optional | no | no | no | P2 |
| ui_postcard_panel_01 | 明信片面板 | ui | 展示旅行卡片 | no | no | no | no | P1 |

---

## 5. AI 数据映射

```json
{
  "memory_type": "travel",
  "suggested_scene": "travel_area",
  "node_type": "postcard",
  "question": "这次旅行中有没有一个瞬间让你现在还记得？"
}
```

比赛阶段也可以把 travel_area 的节点生成在家庭花园里，作为明信片牌。

---

## 6. 验收标准

旅行区域基础完成标准：

1. 上传旅行照片后能生成旅行卡片；
2. 有明信片节点；
3. 点击明信片能查看照片和问题；
4. 不做复杂地理地图；
5. 能表达家庭旅行和异地生活进入花园的感觉。

---

## 7. 给 Claude / Cline 的开发提示词

```text
请读取 docs/scenes/15_scene_travel_area.md。
任务：实现旅行明信片节点，不需要开发完整旅行地图。上传旅行照片后，生成 postcard 节点并可点击查看卡片。
```
