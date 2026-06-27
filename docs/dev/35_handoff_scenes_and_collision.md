# 35｜交接说明：场景切换框架 · 爸爸鱼塘 · Kitchen 厨房庭院场景

> 面向接手 C（游戏系统）的队友。覆盖最近两个提交的内容、怎么跑、怎么继续加场景、
> 以及 Kitchen 场景「全画布 PNG + Y-Sort + 碰撞自动生成」的完整做法与再生成方法。
> 分支：`feature/garden-mvp-loop`。涉及提交：
> - `6f253b1` ScenePortal 通用场景切换框架 + 爸爸鱼塘(WIP)
> - `b096640` Kitchen 厨房+庭院场景（全画布 PNG + Y-Sort + 引导图碰撞）

---

## 0. 一分钟跑起来

- 引擎：**Godot 4.7.x**（全队锁定，勿用别的版本）。
- 首次拉取后，资源导入缓存 `.godot/` 不在版本库，需先导入一次：
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
  ```
- 跑完整游戏：Godot 打开 `game/project.godot` → 运行（主场景 `scenes/Main.tscn`）。
- **单独跑 Kitchen 场景**（最快验收）：
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --path game res://scenes/Kitchen.tscn
  ```
  桌面操作：WASD/方向键移动。看碰撞：编辑器菜单 **Debug ▸ Visible Collision Shapes** 再运行。

---

## 1. 项目的一个关键前提：场景是「代码过程化建」的，不是 .tscn

现有游戏（花园/鱼塘/房间/旅行）**全部在 GDScript 里动态构建**，工程里只有 `scenes/Main.tscn`
一个场景，`main.gd._ready()` 注入 `SceneManager` 后由它搭建一切。

例外是本次新增的 **`Kitchen.tscn`**——它是一个**独立的编辑器 .tscn 场景**（因为美术按整图叠层
+ 编辑器 Y-Sort 的方式给的）。两套范式都在用，别混淆：

| | 过程化（花园/鱼塘/房间…） | 编辑器场景（Kitchen） |
|---|---|---|
| 在哪 | `scripts/managers/scene_manager.gd` | `scenes/Kitchen.tscn` |
| 怎么改 | 改 GDScript | 编辑器里改节点 / 跑脚本重生成 |
| Player | `SceneManager` 代码 new 出来 | 实例化 `scenes/Player.tscn` 进 WorldYSort |

---

## 2. ScenePortal —— 通用场景切换框架（提交 6f253b1）

为「花园 ⇄ 鱼塘 ⇄ …」做的可复用切换框架，**别再像旧 `_enter_house` 那样每个场景写死一套**。

### 2.1 组成
- 新 autoload **`ScenePortal`**（`scripts/managers/scene_portal.gd`），仿 `SlotManager` 风格：
  - `load_scene(scene)`：读 `assets/manifest/portals_{scene}.json`
  - `get_spawn(scene, key)`：取出生点逻辑坐标，找不到回退 `default` 并告警
  - `build_portals(scene, world, travel_cb)`：按 `trigger_rect` 生成入口 Area2D，
    **走入(body_entered，仅 `player` 组)** 和 **点按(tap)** 两种触发都走同一回调（docs/09 §14）
- `SceneManager.goto_scene(target, spawn_key)`：所有切场景的唯一入口（match 分发）
- `SceneManager._on_portal_travel()`：带 **0.4s 防抖锁**，防止刚进场就反复触发
- `_add_player()` 里玩家加入了 `"player"` 组，供 portal 的 body_entered 识别

### 2.2 加一个新场景 / 新入口怎么做
1. 写 `assets/manifest/portals_<场景>.json`（spawn_points + portals，字段见 docs/09 §14.2）。
2. 在 `SceneManager.goto_scene()` 的 `match` 里加一个分支，指向你的 `_build_<场景>()`。
3. `_build_<场景>()` 末尾调用 `ScenePortal.build_portals("<场景>", world, _on_portal_travel)`。
4. 出生点用 `ScenePortal.get_spawn("<场景>", spawn_key)`。

> portal 的 `spawn_point` 字段指的是**目标场景**里的出生点 key（例：花园去鱼塘的 portal
> 写 `spawn_point:"from_garden"` → 落在 `portals_fishpond.json` 的 `spawn_points.from_garden`）。

### 2.3 顺带改的 NodeFactory
`node_factory.gd` 现在**优先读 manifest `file_name` 的真实美术**
（`res://assets/<scene>/<file_name>`），缺图才回退占位 `flower.png`。
A 出正式美术后，丢进对应场景目录即自动生效，无需改代码。

---

## 3. 爸爸鱼塘 fishpond（WIP，mock-first）

`SceneManager._build_fishpond()`：占位水色背景 + 漂流瓶节点 + 返回入口 + 问题面板 + 回答生成岸边记忆。
- 数据是**写死的 mock**（`DEMO_BOTTLE_QUESTIONS`），离场重置、不落库——这是阶段1「先用 mock 跑通主线」
  的刻意做法，等 `ai_client.gd` 落地后真实数据统一灌入。
- 交互形状和花园记忆花完全同构：`SlotManager.allocate` → `NodeFactory` 生成 → 点击弹面板 → 回答 → 生长动画。
- 鱼塘背景/漂流瓶是占位；A 出图后按 manifest 文件名丢进 `assets/fishpond/` 即可。

---

## 4. Kitchen 厨房+庭院场景（提交 b096640）—— 重点

独立场景 `scenes/Kitchen.tscn`，**没有改动任何现有过程化代码 / Player / 移动 / 切换 / 云端**。

### 4.1 素材前提（务必理解）
`assets/kitchen/` 里每张物件 PNG 都是 **1280×720 全画布透明图**：物件画在它在原场景中的真实世界
坐标上，四周透明区不能裁。多张图叠加后与 `background.png` 像素级对齐。
**禁止**对这些 PNG 裁切/缩放/改色/重导出。像素风：Texture Filter 一律 Nearest。

### 4.2 节点结构与图层（z 从下到上）
```
Kitchen
├── Background        z=-300   BackgroundSprite
├── GroundProps       z=-200   TableShadow / Pond / Bamboo      （永远在玩家下方）
├── FixedBackVisuals  z=-100   Fridge / CookingPot              （永远在玩家下方）
├── WorldYSort        y_sort_enabled=true                       （玩家 + 可遮挡物件）
│     DiningTable / 4×Chair / PatioChairTop/Bottom / PatioTeaTable
│     / GardenBench / StoneLantern / Player(实例)
├── Foreground        z=1000   PendantLight / Flowers / Willow  （永远在玩家上方）
├── WorldCollision    SceneCollision(多边形) / BoundaryCollision / ...
├── InteractionAreas  6 个 Area2D（带 interact_action 元数据，逻辑待接）
└── DevReference      CollisionAreaGuide（默认隐藏，编辑器对照用）
```

### 4.3 全画布物件怎么放（核心技巧）
全画布底层（Background/Ground/Fixed/Foreground）：`Sprite2D.centered=false, position=(0,0)`，直接叠。

进 WorldYSort 的动态物件，用「**根节点落地锚点 + Sprite2D 负偏移**」：
```
DiningTable(Node2D).position = (锚点x, 锚点y)   # 锚点 = 物件不透明像素的“底部中心”=接地点
DiningTable.z_index = int(锚点y)                # 见下方“为什么用 z_index”
DiningTable/Sprite2D.centered=false
DiningTable/Sprite2D.position = (-锚点x, -锚点y) # 把整图拉回世界(0,0) → 画面仍对齐背景
```
这样视觉对齐不变，但根节点的 Y 能驱动正确的前后遮挡。

> **为什么不是单纯靠 `y_sort_enabled`？**
> `player.gd` 自己每帧设 `z_index = int(global_position.y)`（全项目的手动 y-sort 惯例），
> 不能改。所以 WorldYSort 里每个物件根也设 `z_index = int(锚点y)` 与玩家同制式；
> `y_sort_enabled` 一起开着兜底。两者一致，遮挡才正确。
> 锚点（每张图不透明像素的底部中心）是用 PIL 算出来的，不是手填——见 4.5。

### 4.4 碰撞（最容易踩坑，重点看）
两类碰撞：

1. **场景固定碰撞** `WorldCollision/SceneCollision`：由美术的 **`Collision_area.png`** 自动生成的
   多边形（`CollisionPolygon2D`）。`Collision_area.png` 是一张「障碍=不透明、可走=透明」的引导图，
   生成时把不透明区转成简化多边形、**只取外轮廓填实内孔**（所以池塘被填实，玩家踩不上水面）。
   → **不要手画这些框**。要改碰撞，去改 `Collision_area.png`，再按 4.5 重新生成。
2. **物件落地碰撞**：餐桌/椅/藤椅/茶几/长椅/石灯笼各自挂 `StaticBody2D + CollisionShape2D`，
   覆盖**物件主体的落地占地**（实心矩形）。
   ⚠️ 经验教训：一开始只给底部一条窄边，玩家能走进桌肚下、被桌子正确遮住，看起来像「图层穿帮」。
   **根因是碰撞太小**，把它扩到覆盖主体后就正常了。加新家具记得碰撞要挡住主体，别只挡底边。
3. `BoundaryCollision`：四周边界，防止走出画布。
4. **碰撞层**：所有障碍 `collision_layer=1`（玩家 `mask=1` 能检测）；不要动 Player 的层/掩码。

### 4.5 ⭐ 美术更新后，怎么重新生成碰撞 + 锚点（必看）
当 A 更新了 `Collision_area.png` 或任何物件 PNG，用下面这段 Python（需 `pillow` + `shapely`）
重新生成并烘焙进 `Kitchen.tscn`。这是本场景碰撞/锚点的**唯一可信来源**，别手改坐标。

> 生成脚本未长期入库（一次性工具）。需要的话让我（或按下述逻辑）重建：
> - 锚点 = 每张物件 PNG `alpha>15` 的不透明包围盒「底部中心」(cx=(L+R)/2, y=B)。
> - 场景碰撞 = `Collision_area.png` `alpha>128` 掩码 → 12px 网格量化 →
>   `shapely.unary_union(格子)` → `buffer(0).simplify(9)` → **取 exterior（填洞）** → `CollisionPolygon2D`。
> - 物件落地框 = 该 PNG 不透明包围盒「整宽 × 底部 fraction 高度」的实心矩形
>   （桌 0.70 / 椅 0.55 / 茶几 0.50 / 石灯笼 0.40，可按需调）。
> - z_index 与根节点 position 都用上面的锚点。
> - 校验：headless 跑一遍场景，**不能有** `Convex decomposing failed!`（自交多边形要剔除/修复）。

### 4.6 交互区
`InteractionAreas` 下 6 个 Area2D：DiningTable/Fridge/Pond/Bamboo/StoneLantern/GardenBench，
各带 `metadata/interact_action` 与 `metadata/prompt`。**目前只是占位 Area2D，逻辑未接**。
项目里已有点击式交互系统（`scene_manager.gd._add_interactable_sprite`，基于 Area2D.input_event），
接逻辑时复用它，别另起一套。

### 4.7 Player.tscn
新增可复用 `scenes/Player.tscn` = `CharacterBody2D(player.gd)` + Sprite2D(papa 表 3×4,
scale≈0.4613) + 脚底碰撞框 28×22@(0,18)，`layer=1/mask=1`。复用现有 `player.gd`，未改其逻辑。

---

## 5. 已知限制 / 待办

- **柳树、竹水器目前静态**，节点已独立留位（柳树在 Foreground、竹在 GroundProps），
  后续做「树枝轻摆 / 水流水波」时再单独拆图加动画，**不要**给整张图做平移缩放动画。
- **前景遮挡是「整张图永远在上」**：在花园里走动时，flowers/willow 会盖住玩家
  （即使该花丛在玩家身后）。当前可接受；正式做法是把 `flowers.png` 拆成 `flowers_back/front`
  两层（A 出图后）。
- **背景里烘焙的物件无法遮挡玩家**：门口那棵橘子盆栽、台面下橱柜等是画进 `background.png` 的，
  玩家永远在它们前面。要让它们正确遮挡，需要 A 单独切成 PNG 再放进 WorldYSort。
- 场景级碰撞精度取决于 `Collision_area.png`；要更准就把那张图画准再重生成。
- Kitchen 还**没接进 ScenePortal 导航**（目前是独立场景）。要让它进主流程，按第 2.2 节
  加 `goto_scene` 分支 + portals json。

---

## 6. 协作红线（沿用 docs/dev/31、32）
- 不重写/回退现有 Player、移动、输入、场景切换、云端上传。
- 不修改/裁切/缩放/改色/重导出任何 PNG。
- 改契约/表结构/manifest 要同步三处并记变更日志（见 34 工作计划 0.2 / 0.7）。
- B(AI) 产物只在 `backend/`，C(游戏) 产物只在 `game/`，唯一对接面是 docs/04 的 JSON 契约。

---

## 7. 场景架构演进约定（增量迁移，已拍板）

背景：现有花园/鱼塘/房间是「代码过程化建场」（非 Godot 主流）；`.tscn` 编辑器场景才是
Godot 与商业引擎的主流方式。结论是**增量迁移、不一次性重构**（`scene_manager.gd` 2696 行
深度耦合了云端/明信片/对话/上传，全量重构高风险且赶不上截止）。约定如下：

1. **新场景一律 `.tscn`**（Kitchen 已示范）。不要再往 `scene_manager.gd` 里手搭新场景。
2. **动态物件用预制体实例化**，不要逐行 `new` 节点：
   - 预制体：`scenes/prefabs/DynamicNode.tscn`（记忆花/漂流瓶等运行时节点的可视化结构）。
   - `NodeFactory.make_memory_node()` 现在**实例化该预制体**再按 manifest 配置贴图/点击区/坐标
     （预制体缺失时回退代码构建 `_new_root()`，行为不变）。
   - 节点名约定（NodeFactory 依赖）：`Sprite` / `ClickArea` / `ClickArea/Shape`。
     要改记忆花/漂流瓶的基础外观，直接编辑 `DynamicNode.tscn` 即可，不用动代码。
3. **重耦合旧场景（花园 / 旅行地图 / 明信片）→ 比赛后再迁**。它们牵动 NPC/动物/植物/
   云端明信片/信箱，现在动 = 拿稳定性和工期冒险。
4. **房间 `_enter_house` → 计划做成 `.tscn` 样板**（最简单、最适合当模板），尚未做；
   做时把房间的静态背景+碰撞+边界搬进 `Room.tscn`，背景按 ROOM_DATA 运行时设置，
   动态部分（提示面板等）仍由代码挂。

> 一句话：**固定授权场景上 `.tscn`，动态物件做预制体在运行时实例化，Manager 只管「放哪/何时放」。**
