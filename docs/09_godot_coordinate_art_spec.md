# 09｜Godot 坐标系统与美术资产统一规范（C′ 方案）

> 版本：v1.1（2026-06-11）
> 状态：soft pixel art 风格部分以 48 小时试产（`docs/dev/33_px_trial_spec.md`）通过为生效条件；坐标与系统规则部分立即生效。
> 适用范围：Family Garden 比赛版本全部场景、美术资产、动态节点、AI 房间生成、三人协作。
> 上游文档：`03_art_asset_pipeline.md`、`04_ai_interfaces.md`、`05_backend_data_model.md`。
> 冲突处理：凡与本文档冲突的旧描述，以本文档为准；发现冲突在每日同步中提出，由 A 裁决后更新对应文档。

---

## 1. 文档目的

统一规定：Godot 逻辑画布与美术等效空间的换算关系；坐标、锚点、点击区、碰撞区规则；场景背景与物件的 soft pixel art 生产规格；Asset Manifest 字段；动态节点 slot 规范；AI 房间生成的 zone + footprint 协议；角色移动与场景入口；层级遮挡；三人分工与验收标准。

目标：美术产出的每一张图、AI 输出的每一段 JSON、游戏系统生成的每一个节点，使用同一套坐标语言。

---

## 2. 画布、缩放与风格方案（最终决策，不再讨论）

### 2.1 核心规则

**采用方案 C′：逻辑画布 1280×720 不变 + 资产层 soft pixel art + 2x 显示。**

1. **Godot 逻辑画布继续采用 1280×720**，`project.godot` 现有设置保持不动：
   - `window/size/viewport_width = 1280`，`viewport_height = 720`
   - `window/stretch/mode = "canvas_items"`，`aspect = "expand"`
2. **美术等效空间为 640×360**：美术按"1 个美术像素 = 2 个逻辑像素"作画。
   - 背景源图按 640×360 生产，导入后 2x 显示铺满画布；
   - 物件源图按第 5 节的美术像素档位生产，导入后由 NodeFactory 统一施加 `scale = Vector2(2, 2)`。
3. **不切换** 640×360 原生 viewport，**不启用**整数缩放（手机异形屏下整数缩放会产生黑边或 1x 事故）；最终整体缩放允许小数，软像素风格对此不敏感。
4. **纹理采样统一 Nearest**：`textures/canvas_textures/default_texture_filter = 0`（当前工程已是此值，保持不动）。
5. **所有策划/系统坐标一律使用 1280×720 逻辑坐标**：manifest、slot、zone、click_rect、collision_rect、default_x/y 全部记录逻辑坐标。美术像素与逻辑像素的换算只发生在"美术作画"这一层，其他人不接触 640 空间数字。

### 2.2 角色与交互策略（P0 / P1 / P2）

比赛版本**保留主控角色的基础行走**。角色行走服务于空间感、沉浸感和场景切换的自然过渡，但不允许挤占 AI 记忆卡片、漂流瓶、AI 房间生成、动态节点这四条主功能的进度。

**P0（必须）：**

1. 一个主控角色，基础行走动画：**复用现有 12 帧（3×4）sprite sheet 和 player.gd 的移动逻辑**，不重写角色系统；soft pixel art 转换只替换贴图，不改移动代码；
2. 入口触发式场景切换：角色走进入口区域即切换场景（走到鱼塘入口进鱼塘、走到房门进房间、走到农场小路进农场），由 ScenePortal（Area2D）管理，规范见第 14 节；
3. 入口同时支持直接点按触发（与走入触发调用同一切换函数）——这是手机端在 P1 移动方案落地前的 P0 兜底，也是桌面端的快捷方式；
4. 每个场景定义 spawn point，玩家进入后出现在合理位置（沿用 main.gd ROOM_DATA 的 spawn 字段思路，规范见第 14 节）。

**P1（强加分）：**

1. 手机端移动：虚拟摇杆或点击移动（直线移动 + 碰撞停止），**不做寻路系统**；
2. 靠近入口时的提示气泡（prompt_text 显示"进入爸爸鱼塘"等）；
3. 行走音效/脚步细节等轻量打磨。

**P2（比赛后）：**

1. 多角色完整行走动画（NPC 家庭成员比赛版用静态立绘或 1–2 帧 idle）；
2. 复杂动作：钓鱼、坐下、种植动作、多人实时移动——比赛版一律不做。

**点按交互仍是所有核心功能的主路径**：记忆花、漂流瓶、照片牌、UI 全部点按触发，不依赖角色走近（P1 的靠近提示只是增强，不是前置条件）。

### 2.3 生效条件与回退

- 第 4/5/11 节（风格与生产规格）在 48 小时试产通过后生效；
- 试产不通过：风格回退手绘水彩，本文档仅第 2.1 条第 4 款（采样改 Linear）、第 4/5/11 节回退；第 3、6–10、12–14 节（坐标与系统规则）**与风格无关，无条件生效**。

---

## 3. Godot 坐标系统

1. **坐标原点**：场景左上角 `(0, 0)`；X 向右，Y 向下（Godot 2D 默认）。
2. **画布范围**：`(0,0)`–`(1280,720)`。重要交互物件必须完整落在此范围内；`expand` 延伸出的两侧只允许纯装饰。
3. **背景放置**：
   - `Sprite2D`（`centered = true`）：`position = Vector2(640, 360)`，`scale = Vector2(2, 2)`；
   - `TextureRect`：`position = Vector2(0, 0)`，铺满 viewport；
   - 同一场景内统一用一种。
4. **物件 position 的含义**：物件的 `position` = 它的**落点**，即图片 bottom_center 在场景中的位置（站地上的是脚底中心，漂水上的是吃水线中心，挂墙上的是底边中心）。不是图片中心。
5. **bottom_center 实现**（C 在 NodeFactory 中统一封装，禁止各场景手写偏移）：
   - `Sprite2D` 设 `centered = false`，`offset = Vector2(-w/2, -h)`（w/h 为源图美术像素尺寸）；配合 `scale = (2,2)` 后落点即逻辑坐标。
6. **坐标取值规则**：所有物件落点取**偶数逻辑坐标**（保证 2x 后美术像素对齐，避免半像素错位）；slot 坐标必须对齐 16 逻辑像素网格。
7. **网格换算表**（记住这一行就够）：

   | 单位 | 逻辑 px | 美术 px |
   |---|---|---|
   | 基础网格 | 16 | 8 |
   | footprint 1 格 | 32 | 16 |
   | 整张画布 | 1280×720 | 640×360 |

---

## 4. 场景背景规范

1. **源图尺寸**：一律 **640×360** 美术像素，PNG，非透明；导入后 2x 显示。
2. **命名**：`scene_{场景}_bg_{编号}.png`，如 `scene_garden_bg_01.png`。
3. **生产路线**：AI 概念图 → Converter 像素化 → 手工修整（详见第 11 节），全程使用全局调色板。
4. **背景中禁止画死**（必须单独出图）：记忆花、漂流瓶、照片牌、明信片、记忆种子、全部入口木牌/门牌、任何会点击/发光/变状态/被数据驱动的物件、前景遮挡物、任何 UI。
5. **背景中允许包含**：地面、天空、水面底色、远景、固定花坛、小路等纯氛围元素。
6. **构图**：slot 预定区域（见第 7 节）保持留白、低对比，保证节点可读。
7. **体积**：像素背景 PNG 通常 < 100KB，若超过 300KB 说明密度或色板出了问题，退回检查。

---

## 5. 可交互物件规范

适用：记忆花、漂流瓶、照片牌、木牌/门牌、房间物件、旅行标记/明信片、记忆种子。

1. **导出**：透明背景 PNG，物件孤立、轮廓干净（1 美术像素深色描边，非纯黑）、无溢出阴影。
2. **尺寸档位**（源图 = 美术像素；显示 = 逻辑像素 = 源图 × 2）：

   | 物件类型 | 源图（美术 px） | 显示（逻辑 px） | footprint |
   |---|---|---|---|
   | 小节点：记忆花、种子、涟漪 | 32–48 见方 | 64–96 | 2x2 |
   | 中节点：漂流瓶、明信片、门牌 | 40–64 | 80–128 | 3x2 |
   | 木牌 / 照片牌 / 入口牌 | 64–80 | 128–160 | 3x3 |
   | 小家具：台灯、植物、椅子 | 48–80 高 | 96–160 | 2x2 / 2x3 |
   | 大家具：书桌、床、柜子 | 80–120 高 | 160–240 | 4x2 / 6x3 |
   | 墙面物：照片墙、窗 | 80–112 高 | 160–224 | wall_object |

3. **密度纪律**：全项目统一"1 美术像素 = 2 逻辑像素"，禁止任何资产用更细密度作画。
4. **pivot**：一律 bottom_center；底部留白 ≤ 2 美术像素，水平居中。
5. **多状态物件**：同一物件全部状态画布尺寸相同、基础轮廓重合、落点一致；命名 `node_garden_memory_flower_01_new.png` 格式。
6. **命名**：沿用 `03_art_asset_pipeline.md` 第 5 节 `类型_场景_名称_编号_状态.png`。
7. 交付必须同步登记 manifest（第 6 节），缺行视为未交付。

---

## 6. Asset Manifest 字段规范

manifest 是三方唯一对账单。表格维护，由 C 导出为 `game/assets/manifest/asset_manifest.json` 供 NodeFactory / RoomLayoutManager 运行时读取。

| 字段 | 填写人 | 说明 | 示例 |
|---|---|---|---|
| `asset_id` | A | 资产唯一 ID（不含状态后缀） | `node_garden_memory_flower_01` |
| `file_name` | A | 文件名（多状态填基准状态） | `node_garden_memory_flower_01_new.png` |
| `scene` | A | 所属场景 | `garden` |
| `category` | A | `background / node / prop / collision / foreground / ui / effect` | `node` |
| `width` / `height` | A | 源 PNG 尺寸（**美术像素**，= native） | `48` / `48` |
| `native_width` / `native_height` | A | 同上，保留为工具字段 | `48` / `48` |
| `display_width` / `display_height` | C | 画布显示尺寸（**逻辑像素** = native × 2） | `96` / `96` |
| `pivot` | A | 固定 `bottom_center`（背景/UI 填 `top_left`） | `bottom_center` |
| `default_x` / `default_y` | C | 默认落点（**逻辑坐标**；动态节点填 `-1` 表示由 slot 决定） | `-1` / `-1` |
| `click_rect` | C | 点击区 `[x, y, w, h]`，相对 pivot，**逻辑坐标**；`null` = 不可点 | `[-48, -96, 96, 96]` |
| `collision_rect` | C | 碰撞区，同格式；`null` = 无碰撞 | `null` |
| `footprint` | C | 占格 `列x行`（**网格单位**，1 格 = 32 逻辑 px = 16 美术 px）；墙面物 `wall_object`；非放置物 `null` | `2x2` |
| `z_rule` | C | `bg / ground_decor / ysort / foreground / ui` | `ysort` |
| `states` | A | `none` 或如 `new/read/grown` | `new/read/grown` |
| `interactive` | A | `yes / no` | `yes` |
| `owner` | A | A / B / C | `A` |
| `priority` | A | P0 / P1 / P2 | `P0` |
| `status` | A+C | `todo / generating / converting / cleaning / ready / tested / imported / need_revision` | `ready` |
| `notes` | 任意 | 备注 | `点击后打开记忆卡片` |

规则：A 填资产物理属性（尺寸、状态、命名、pivot）；C 填引擎侧属性（display、坐标、rect、footprint、z_rule）并推进导入后的 status；`click_rect` 最小 **80×80 逻辑像素**（手机触控下限），允许大于贴图。本表替代 `templates/ASSET_MANIFEST_TEMPLATE.md` 旧字段表。

---

## 7. Slot 坐标规范

1. 每个场景必须有 slot 表；动态节点（记忆花、漂流瓶、照片牌、明信片、种子、涟漪、门牌、旅行标记、房间物件）**只能**落在 slot 上；
2. **AI 永远不输出坐标**；slot 由 SlotManager / RoomLayoutManager 分配；
3. slot 坐标 = 节点落点（bottom_center），**1280×720 逻辑坐标**，对齐 16px 网格且为偶数；
4. 命名：`{scene}_slot_{区域}_{编号}`；
5. 防重叠：一个 slot 同时只被一个节点占用（对应 `nodes.slot_id` 唯一）；slot 间距 ≥ 占用它的最大 footprint 宽度；
6. slot 用满：备用 slot → `overflow` 组 → 入队并提示"花园已经很热闹了"。禁止自由坐标兜底；
7. 数据文件：`game/assets/manifest/slots_{scene}.json`，C 维护，背景定稿时 A+C 核对一次后冻结。

示例（家庭花园）：

```json
{
  "scene": "garden",
  "canvas": [1280, 720],
  "grid": 16,
  "slots": [
    { "slot_id": "garden_slot_flowerbed_01", "pos": [432, 448], "allow": ["memory_flower", "memory_seed"], "size_hint": "2x2" },
    { "slot_id": "garden_slot_flowerbed_02", "pos": [512, 480], "allow": ["memory_flower", "memory_seed"], "size_hint": "2x2" },
    { "slot_id": "garden_slot_flowerbed_03", "pos": [592, 448], "allow": ["memory_flower"], "size_hint": "2x2" },
    { "slot_id": "garden_slot_board_01",     "pos": [816, 416], "allow": ["photo_board", "postcard"],     "size_hint": "3x3" },
    { "slot_id": "garden_slot_water_01",     "pos": [688, 560], "allow": ["bottle"],                      "size_hint": "3x2" },
    { "slot_id": "garden_slot_overflow_01",  "pos": [352, 560], "allow": ["memory_flower", "photo_board"], "size_hint": "3x3" }
  ]
}
```

各场景 slot 配额建议：花园 6+3+1+2（花坛/照片牌/水边/溢出）；鱼塘 3+4+2（漂浮/涟漪/岸边）；房间由 zone 内 slot 提供（第 8 节）；农场 6+2；老街 4+2；旅行 6。

---

## 8. AI 房间生成布局规范

### 8.1 AI 输出边界

1. AI **不生成**完整房间图片，**不输出**任何坐标、尺寸、footprint；
2. AI 允许输出的布局相关字段仅四个：`suggested_scene`、`node_type`（记忆节点），`object_type`、`zone`（房间物件）；
3. 房间接口在 `04_ai_interfaces.md` 接口三基础上扩展，`objects` 元素从字符串升级为对象（**纯字符串数组必须继续兼容**）：

```json
{
  "room_type": "bedroom",
  "style": "warm_cozy",
  "suggested_room_theme": "study_corner",
  "description": "这个房间看起来温暖安静，适合生成一个带书桌、台灯、植物和照片墙的角落。",
  "objects": [
    { "object_type": "desk",       "zone": "back_left"  },
    { "object_type": "lamp",       "zone": "back_left"  },
    { "object_type": "photo_wall", "zone": "back_wall"  },
    { "object_type": "plant",      "zone": "right_side" },
    { "object_type": "bed" }
  ]
}
```

4. `zone` 为可选建议：缺省或非法时，用 manifest 中该物件的 `default_zone`；
5. **footprint 一律由 manifest 按 `object_type` 查表**，AI 输出中出现的任何坐标/尺寸/footprint 字段一律忽略。

### 8.2 房间 zone 定义（逻辑坐标，房间背景定稿后 A+C 校准一次并冻结）

```json
{
  "scene": "room",
  "zones": {
    "back_wall":    { "rect": [192, 168, 896, 64],  "kind": "wall",  "slots": 3 },
    "back_left":    { "rect": [160, 280, 288, 96],  "kind": "floor", "slots": 2 },
    "back_center":  { "rect": [496, 280, 288, 96],  "kind": "floor", "slots": 2 },
    "back_right":   { "rect": [832, 280, 288, 96],  "kind": "floor", "slots": 2 },
    "left_side":    { "rect": [128, 400, 224, 128], "kind": "floor", "slots": 2 },
    "right_side":   { "rect": [928, 400, 224, 128], "kind": "floor", "slots": 2 },
    "front_left":   { "rect": [224, 544, 256, 96],  "kind": "floor", "slots": 1 },
    "front_center": { "rect": [512, 544, 256, 96],  "kind": "floor", "slots": 1 },
    "front_right":  { "rect": [800, 544, 256, 96],  "kind": "floor", "slots": 1 },
    "floor_center": { "rect": [448, 416, 384, 112], "kind": "floor", "slots": 1 }
  }
}
```

`kind: wall` 的 zone 只接受 `footprint = wall_object` 的物件。

### 8.3 RoomLayoutManager 职责（C 实现）

```text
输入：AI room JSON（或 mock）+ asset_manifest + zones 定义
处理：
1. 逐个 object：object_type → manifest 查 asset_id / footprint / default_zone / click_rect / collision_rect；
2. 定 zone：AI 建议合法且有空位 → 采用；否则 default_zone；再满 → 跳过并记日志；
3. 在 zone 内取下一个空 slot，按 footprint 查重不与已放物件重叠；
4. 实例化：position = slot 落点（bottom_center，偶数逻辑坐标），scale = (2,2)，z 按第 10 节；
5. 全部失败：使用预设默认房间布局，保证演示不空房。
输出：room_objects 记录（含 slot_id），字段与 05_backend_data_model.md 3.8 节一致。
```

确定性要求：同一份输入 JSON 重复生成 100 次，布局结果完全一致（不引入随机）。

---

## 9. 点击区域与碰撞区域规范

1. **坐标系**：`click_rect` / `collision_rect` 均为相对 pivot（bottom_center）的局部矩形 `[x, y, w, h]`，**逻辑像素**；落点为原点，向上为负 y。示例：显示 96×96 的记忆花整图可点 → `click_rect = [-48, -96, 96, 96]`。
2. **click_rect**：`interactive = yes` 必填；最小 80×80 逻辑像素，小贴图按"外扩"原则放大；实现为 `Area2D + RectangleShape2D`，由 NodeFactory 按 manifest 自动创建。
3. **collision_rect**：保留行走后碰撞规则如下——场景边界、水面、大家具、房屋、栅栏保留碰撞（沿用 main.gd 现有 collision zone 思路）；**node 类物件（记忆花、漂流瓶、照片牌、明信片、门牌、涟漪）一律不设碰撞**，角色可走过，避免节点增多后把花园走廊堵死；碰撞矩形只罩物件底部约 1/3 高度的"脚印"。
4. 两矩形互相独立：只点（记忆花）、只碰（床）、都有（书桌）、都无（纯装饰）均合法。

---

## 10. 层级与遮挡规范

| 层 | z_rule | z_index | 内容 |
|---|---|---|---|
| 背景 | `bg` | -100 | 场景背景图 |
| 墙面物 | （footprint=wall_object） | -40 | 照片墙、窗，贴背景、被一切地面物遮挡 |
| 地面装饰 | `ground_decor` | -50 | 小路、地毯等不参与遮挡的贴地件 |
| Y-sort 带 | `ysort` | `int(落点 y)`，0–720 | 主控角色、全部可放置物件、动态节点、立绘 |
| 前景遮挡 | `foreground` | 5000 | 树冠、水草、门框 |
| UI | `ui` | CanvasLayer | 全部面板按钮，永远最上 |

规则：Y-sort 带统一 `z_index = int(global_position.y)`（与现有 player.gd / npc_wander.gd 写法一致）；不使用节点属性 `Y Sort Enabled`（与现有手动 z_index 体系冲突）；UI 必须走 CanvasLayer，禁止大 z_index 冒充。

---

## 11. 美术生产流水线与提示词规则

### 11.1 流水线（替代 03 文档第 10 节流程）

```text
AI 生成概念图（沿用 08 提示词库的水彩概念提示词，不必为像素改写）
↓
Converter 像素化：Box 降采样到目标美术像素尺寸 + 关闭抖动 + remap 到全局调色板
↓
Aseprite / Piskel 手工修整：描边、去噪、落点裁齐、状态对齐
↓
登记 Asset Manifest（status: cleaning → ready）
↓
交 C 导入 Godot：2x、Nearest、真机验证（status: tested → imported）
```

### 11.2 硬性规则

1. **全局调色板**：`family_garden_palette_v1.png`（Zughy 32 基底 + ≤8 个项目自定义色，总数 ≤40），所有资产强制 remap，禁止私加颜色；调色板由 A 维护，改版需通知全员重 remap 检查；
2. **统一密度**：1 美术像素 = 2 逻辑像素，无例外；
3. **软像素质感**：1 px 同色系深色描边（非纯黑）、平色块为主、抖动仅限背景大渐变、低饱和暖色；
4. **概念图提示词追加段**（加在 08 各物件提示词末尾）：

```text
Framing requirements for pixelation:
- single isolated object, centered, occupying at least 80% of the canvas;
- simple flat shapes with clear silhouette, minimal texture noise;
- the object stands on an invisible ground line at the bottom-center;
- transparent or plain background, no text, no logo, no cast shadow.
```

5. 每批资产先出 1 张试导入（交 C），通过再批量出同类与状态变体。

---

## 12. 三人协作规则

| 角色 | 职责 |
|---|---|
| A（产品+美术） | 维护调色板与密度纪律；按第 4/5/11 节生产资产；填 manifest 的 A 列字段；与 C 核对 slot 落点和 zone rect |
| B（AI+内容安全） | 保证 AI 输出符合第 8.1 节（含字符串数组兼容）；zone 枚举校验进 prompt；mock 与正式输出同构；不输出坐标/尺寸/footprint |
| C（游戏系统） | 实现 SlotManager / NodeFactory / RoomLayoutManager / ScenePortal；统一封装 bottom_center 与 2x scale；维护 slots/zones/portals JSON；填 manifest 的 C 列字段；导入测试推进 status |

配合规则：场景文档（10–15 号）管"有什么、什么体验"，本规范管"怎么摆、怎么标、怎么导"，各场景文档补一节 slot/portal 表；字段不互相代填；交接节奏沿用 `31_handoff_rules.md`（当天导入测试、反馈走 manifest 不走口头）；规范冲突当日提出、A 裁决、文档更新。

---

## 13. 验收标准

### 13.1 单个资产合格

1. 命名、透明度、美术像素尺寸符合第 5 节档位；
2. 100% 使用全局调色板、符合统一密度；
3. bottom_center 落点干净（底部留白 ≤ 2 美术像素）；
4. 多状态图画布与落点完全一致，切换不跳动；
5. manifest 全字段登记，status ≥ `tested`；
6. 手机横屏真机上可读、可点（click_rect ≥ 80×80 逻辑像素）。

### 13.2 单个场景合格

1. 背景源图 640×360、2x 显示，无画死的交互物件；
2. slot JSON 已建且数量 ≥ P0 需求；
3. 用 mock JSON 生成 ≥ 3 个节点：无重叠、遮挡正确、落点全部偶数逻辑坐标；
4. 进入/返回正常；竖屏显示旋转提示；
5. 同一 mock 输入重复进入，节点位置完全一致；
6. 主控角色可行走，12 帧动画播放正常，被前景/物件正确遮挡；
7. 每个 ScenePortal 走入与点按两种方式都能触发切换，进入新场景后出现在 spawn_point。

### 13.3 一次 AI 房间生成合格

1. JSON 通过校验（非法 zone 被纠正而非崩溃；字符串数组与对象数组都能处理）；
2. ≥ 3 个物件成功入 zone，互不重叠；≥ 1 个可点击并弹出对应 UI；
3. footprint 全部来自 manifest，AI 输出中的坐标/尺寸字段被忽略；
4. AI 失败时预设默认房间正常显示；
5. 同一 JSON 重复生成布局完全一致。

---

## 14. 角色移动与场景入口（ScenePortal）规范

### 14.1 角色移动

1. 主控角色复用现有 player.gd：12 帧（hframes=3, vframes=4）sheet、move_and_slide()、`z_index = int(global_position.y)`（属于第 10 节的 ysort 带）；
2. 像素化后的角色 sheet 规格：每帧 32×40 美术像素（显示 64×80 逻辑像素，接近现有 82px 显示高度），整张 sheet 96×160 美术像素；帧格必须严格对齐，禁止逐帧尺寸漂移；
3. 移动输入：桌面 = 键盘（现有 WASD/方向键逻辑不动）；手机 P0 = 无移动（靠点按入口），P1 = 虚拟摇杆或点击移动二选一（实现简单者优先），不做 NavigationAgent/A* 寻路；
4. 角色碰撞沿用现有"脚底小矩形"模式（碰撞箱只罩脚部，保证可走到物件背后被遮挡）。

### 14.2 ScenePortal 字段规范

每个入口是一个 Area2D，数据驱动，字段如下：

| 字段 | 类型 | 说明 |
|---|---|---|
| `portal_id` | string | 唯一 ID，如 `garden_portal_fishpond` |
| `target_scene` | string | 目标场景：garden / fishpond / farm / room / old_street / travel_area |
| `spawn_point` | string | 目标场景中的出生点 ID，如 `from_garden` |
| `trigger_rect` | rect | 触发区 `[x, y, w, h]`，1280×720 逻辑坐标 |
| `prompt_text` | string | 靠近提示文案（P1 使用），如 "进入爸爸鱼塘" |
| `tap_enabled` | bool | 是否支持直接点按触发（P0 默认 true） |

触发规则：body_entered（仅主控角色）→ 短暂淡出 → 切场景 → 在 spawn_point 淡入；点按触发走同一函数。切换期间锁输入约 0.3–0.5 秒，防止重复触发。

### 14.3 Spawn Point 规范

1. 每个场景维护 `spawn_points` 表：`{ "from_garden": [640, 560], "default": [640, 480] }`；
2. 坐标为逻辑坐标、偶数、对齐 16px 网格，且必须落在可行走区域内（不与 collision 重叠）；
3. 出生点应朝向场景内容、离对应返回入口 ≥ 64 逻辑像素（防止刚进场就触发返回）；
4. 找不到指定 spawn_point 时回退到 `default`，并打印警告。

### 14.4 Portal / Spawn JSON 示例

```json
{
  "scene": "garden",
  "spawn_points": {
    "default":       [640, 480],
    "from_fishpond": [1056, 448],
    "from_room":     [224, 448],
    "from_farm":     [640, 224]
  },
  "portals": [
    { "portal_id": "garden_portal_fishpond", "target_scene": "fishpond", "spawn_point": "from_garden",
      "trigger_rect": [1120, 384, 96, 128], "prompt_text": "进入爸爸鱼塘", "tap_enabled": true },
    { "portal_id": "garden_portal_room", "target_scene": "room", "spawn_point": "from_garden",
      "trigger_rect": [128, 384, 96, 128], "prompt_text": "回到我的房间", "tap_enabled": true },
    { "portal_id": "garden_portal_farm", "target_scene": "farm", "spawn_point": "from_garden",
      "trigger_rect": [576, 128, 128, 80], "prompt_text": "去爷爷农场", "tap_enabled": true }
  ]
}
```

数据文件：`game/assets/manifest/portals_{scene}.json`，C 维护；入口木牌美术资产照常登记 manifest（category=node，interactive=yes），木牌的 click_rect 与 portal 的 tap 触发绑定。
