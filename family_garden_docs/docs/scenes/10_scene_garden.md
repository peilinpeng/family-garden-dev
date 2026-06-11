# 10｜场景：家庭花园 Garden Hub

## 1. 场景定位

家庭花园是 Family Garden 的主场景，也是用户进入游戏后最先看到的空间。它承担三个作用：

1. 展示家庭记忆正在生长；
2. 承载上传后生成的核心记忆节点；
3. 作为进入鱼塘、农场、个人房间、老街等场景的中心入口。

家庭花园不是普通装饰背景，而是家庭记忆的主容器。用户应该能在这里直观看到：这个家庭因为上传、回答和互动，正在慢慢长出新的花、照片牌和故事入口。

---

## 2. 体验目标

用户进入家庭花园后应感到：

- 这是一个温暖、低压力的家庭空间；
- 这里不是任务列表，而是一个会变化的小世界；
- 每朵花、每个牌子、每个漂流瓶都可能对应一段家庭故事；
- 家庭成员的互动会让花园变得更丰富。

---

## 3. 核心玩法

家庭花园中玩家可以：

1. 点击记忆花，查看 AI 生成的记忆卡片；
2. 点击照片牌，查看用户上传的照片；
3. 点击漂流瓶入口，进入家庭问题；
4. 点击入口木牌，进入爸爸鱼塘、AI 房间、爷爷农场等场景；
5. 上传新的照片或文字；
6. 回答 AI 提出的问题；
7. 看到新记忆节点在花园中出现或成长。

---

## 4. 空间布局

推荐 1280×720 横屏布局：

```text
┌────────────────────────────────────────────┐
│  农场入口 / 老街入口 / 旅行入口             │
│                                            │
│      记忆树 / 记忆花区域 / 照片牌           │
│                                            │
│ 房间入口        主路径          鱼塘入口     │
│                                            │
│       底部：记忆卡片弹窗 / 上传入口         │
└────────────────────────────────────────────┘
```

画面中心保留开放空间，避免背景细节过密。交互物件要清楚可见。

---

## 5. 资产清单

| asset_id | 资产名称 | 类型 | 功能 | 可点击 | 碰撞 | 前景遮挡 | 多状态 | 优先级 |
|---|---|---|---|---|---|---|---|---|
| scene_garden_bg_01 | 家庭花园背景 | background | 主场景底图 | no | no | no | no | P0 |
| path_garden_main_01 | 花园小路 | background | 引导玩家视线 | no | no | no | no | P0 |
| node_garden_memory_flower_01_new | 新记忆花 | node | 打开记忆卡片 | yes | no | no | yes | P0 |
| node_garden_memory_flower_01_read | 已读记忆花 | node | 查看已读记忆 | yes | no | no | yes | P0 |
| node_garden_memory_flower_01_grown | 成长记忆花 | node | 已补充回答的记忆 | yes | no | no | yes | P0 |
| prop_garden_photo_board_01_empty | 空照片牌 | node | 等待照片 | yes | no | no | yes | P0 |
| prop_garden_photo_board_01_filled | 已填照片牌 | node | 展示照片 | yes | no | no | yes | P0 |
| prop_garden_bottle_entrance_01 | 漂流瓶入口 | node | 进入漂流瓶问题 | yes | no | no | yes | P0 |
| prop_garden_sign_fishpond_01 | 鱼塘入口牌 | node | 跳转鱼塘 | yes | no | no | no | P0 |
| prop_garden_sign_room_01 | 房间入口牌 | node | 跳转个人房间 | yes | no | no | no | P0 |
| prop_garden_sign_farm_01 | 农场入口牌 | node | 跳转爷爷农场 | yes | no | no | no | P1 |
| prop_garden_sign_oldstreet_01 | 老街入口牌 | node | 跳转老街 | yes | no | no | no | P1 |
| prop_garden_tree_foreground_01 | 前景树冠 | foreground | 增强层次 | no | optional | yes | no | P1 |
| prop_garden_fence_01 | 花园栅栏 | collision | 边界 | no | yes | no | no | P1 |
| effect_garden_memory_glow_01 | 记忆光点 | effect | 新节点出现反馈 | no | no | no | optional | P1 |

---

## 6. 资产拆分要求

不要把以下内容画死在背景里：

- 记忆花；
- 漂流瓶入口；
- 照片牌；
- 鱼塘/房间/农场入口木牌；
- 前景树冠；
- 任何会点击、发光、变化状态的物件。

背景只保留地面、小路、远景、基础花坛和氛围。

---

## 7. AI 数据映射

AI 记忆卡片可能返回：

```json
{
  "memory_type": "travel",
  "suggested_scene": "garden",
  "node_type": "memory_flower",
  "title": "一次家庭旅行",
  "question": "你还记得这次旅行中最开心的一件事吗？"
}
```

游戏系统处理逻辑：

1. 如果 `suggested_scene = garden`，在家庭花园中创建节点；
2. 如果 `node_type = memory_flower`，使用 `node_garden_memory_flower_01_new`；
3. 位置由 GardenSlotManager 分配，不由 AI 决定；
4. 用户点击后打开记忆卡片；
5. 用户回答后节点状态变为 `grown`。

---

## 8. 节点状态

| 状态 | 表现 | 说明 |
|---|---|---|
| new | 轻微发光的新记忆花 | AI 刚生成，用户未查看 |
| read | 光弱一些的记忆花 | 用户已查看卡片 |
| answered | 花朵更饱满 | 用户回答了问题 |
| grown | 成长后的花或小树 | 多人补充后形成完整记忆 |

---

## 9. 验收标准

家庭花园完成标准：

1. 场景能正常加载；
2. 画面为 1280×720 横屏；
3. 至少有一个可点击记忆花；
4. 点击记忆花能打开记忆卡片；
5. 至少有两个场景入口；
6. 可以进入鱼塘和个人房间；
7. 手机横屏下按钮和节点可点击；
8. 竖屏不进入完整场景，而显示旋转提示；
9. 使用 mock 数据也能生成节点；
10. 不影响上传和 AI 主流程。

---

## 10. 给 Claude / Cline 的开发提示词

```text
请读取 docs/00_project_overview.md、docs/03_art_asset_pipeline.md 和 docs/scenes/10_scene_garden.md。

任务：实现家庭花园 Garden Hub 的最小可运行版本。

要求：
1. 不要重构全局架构；
2. 不要删除已有功能；
3. 先使用 mock memory_card JSON；
4. 实现背景加载、记忆花节点、点击弹出记忆卡片、鱼塘入口、房间入口；
5. 节点位置由预设槽位决定，不允许 AI 输出坐标；
6. 输出修改文件列表和验收步骤。
```
