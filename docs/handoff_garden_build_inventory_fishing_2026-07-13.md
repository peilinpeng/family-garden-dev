# 家庭花园功能交接说明（2026-07-13）

## 分支与远端

- 当前分支：`feature/garden-mvp-loop`
- 远端仓库：`https://github.com/peilinpeng/family-garden-dev.git`
- 本次工作基于 `git pull --rebase --autostash` 后的最新当前分支；当前分支当时已是最新。
- 同步参考了远端 `origin/feature/garden-tilemap` 中的花园瓦片资源和示例场景。

## 本次主要完成内容

### 1. 主花园背景与场景区域

- 主花园背景已替换为 `E:/000/family garden/new_garden_basic.png`。
- 仓库内目标文件：
  - `game/assets/backgrounds/shared_garden.png`
- `scene_manager.gd` 中已调整主花园：
  - 新背景下的玩家活动区。
  - 新背景下的碰撞区。
  - 新背景下的鱼塘、房间、农场入口位置。
  - 花园加载时初始化 DIY 建造系统。

### 2. 可游玩的 DIY 花园建造系统

新增核心脚本：

- `game/scripts/garden_builder/garden_build_manager.gd`

新增 autoload：

- `GardenBuildManager="*res://scripts/garden_builder/garden_build_manager.gd"`

入口方式：

- 主花园右侧有“建造”按钮。
- 键盘 `B` 可打开/关闭建造模式。

建造模式能力：

- 选择分类素材并在草坪网格中放置。
- 放置时有绿色/红色预览提示。
- 不允许放在不可编辑区域、阻挡区域或已有物件占用的格子上。
- 支持删除模式，点击已放置物件删除。
- 玩家进入建造模式时移动会锁定，退出后恢复。

### 3. 瓦片系统已接入建造模式

瓦片不再只是资源文件，已接入玩家可操作流程。

接入资源：

- `game/assets/garden/tileset/garden_ground_tileset.tres`
- `game/assets/garden/tileset/ground/Tileset_Ground.png`
- `game/assets/garden/tileset/ground/Tileset_Road.png`
- `game/scenes/GardenTiled.tscn`

建造栏新增分类：

- `地面`
- `小路`
- `瓦片`

当前可用瓦片工具：

- 浅草地
- 密草地
- 花草地
- 泥土地
- 石子路
- 浅石路
- 路边缘
- 擦除瓦片

实现方式：

- 建造系统会在主花园动态创建 `TileMapLayer`：
  - 节点名：`GardenBuildGroundTiles`
  - 使用 `garden_ground_tileset.tres`
  - `scale = Vector2(2, 2)`，适配 16px 源瓦片到 32px 建造网格。
- 玩家点击草坪格子会调用 `TileMapLayer.set_cell()` 铺设瓦片。
- 擦除工具调用 `TileMapLayer.erase_cell()`。

### 4. 切分素材接入建造系统

素材数据库：

- `game/assets/garden_builder/data/garden_assets.json`

当前素材总数：166

分类数量：

- 花坛：68
- 植物：6
- 花盆：39
- 家具：43
- 装饰：5
- 工具：5

素材文件位于：

- `game/assets/garden_builder/textures/`
- `game/assets/garden_builder/icons/`

辅助报告：

- `reports/garden_asset_manifest.csv`
- `reports/garden_asset_review.md`
- `reports/garden_asset_contact_sheet.png`

### 5. 建造存档格式

建造布局保存到：

- `user://garden_layout_v1.json`

当前保存版本：

- `version = 2`

保存内容：

- `objects`：玩家放置的素材物件。
- `tiles`：玩家铺设的地面/小路瓦片。

示例结构：

```json
{
  "version": 2,
  "objects": [
    {
      "instance_id": "gb_pot_03_001_123456",
      "asset_id": "gb_pot_03_001",
      "cell": [12, 14]
    }
  ],
  "tiles": [
    {
      "tile_id": "path_stone_01",
      "cell": [18, 12]
    }
  ]
}
```

### 6. 背包、物品、钓鱼相关改动

背包/物品：

- 新增右侧竖排物品栏/背包入口。
- 背包 UI 接入 `InventoryManager` / `ItemDB`。
- 钓到金鱼会进入背包。
- 树枝不会进入背包。
- 漂流瓶结果只提供“打开”选项。

钓鱼：

- 新增鱼竿、鱼漂、树枝、背包、金鱼图标素材接入。
- 调整钓鱼拉杆逻辑，失败/脱钩不会再产出鱼或漂流瓶。
- 增加力度条互动。
- 调整鱼竿、鱼线、鱼漂的视觉连接。

中文化：

- 主 UI、入口文案、钓鱼弹窗、背包 UI、建造 UI 优先统一为中文。
- 面板关闭按钮避免使用乱码字符，改为稳定的 `X` 或中文按钮。

## 关键文件清单

核心脚本：

- `game/scripts/garden_builder/garden_build_manager.gd`
- `game/scripts/managers/scene_manager.gd`
- `game/scripts/ui/inventory_ui.gd`
- `game/scripts/managers/item_db.gd`
- `game/scripts/managers/scene_portal.gd`
- `game/scripts/player.gd`

配置：

- `game/project.godot`
- `game/assets/manifest/portals_garden.json`
- `game/assets/manifest/items.json`
- `game/assets/manifest/characters.json`

主花园与瓦片资源：

- `game/assets/backgrounds/shared_garden.png`
- `game/assets/garden/tileset/`
- `game/scenes/GardenTiled.tscn`

建造素材：

- `game/assets/garden_builder/`

钓鱼/背包素材：

- `game/assets/pond/props/fishing_rod.png`
- `game/assets/pond/props/fishing_bobber.png`
- `game/assets/pond/props/tree_branch.png`
- `game/assets/items/fish_goldfish.png`
- `game/assets/ui/icons/icon_backpack.png`

## 已做验证

- 已执行 `git pull --rebase --autostash`，当前分支已是最新。
- 已执行 `git diff --check`，无空白/补丁格式错误。
- 已解析验证：
  - `game/assets/manifest/portals_garden.json`
  - `game/assets/garden_builder/data/garden_assets.json`
- 已确认建造素材数据库 166 条可读取。
- 已处理 `garden_build_manager.gd` 中 warning-as-error 的 Variant 类型推断问题：
  - 第 224 行已改为显式 `int`。
  - 文件内局部 `var :=` 推断写法已清理。

## 未完成或需后续验证

- 当前机器未找到 `godot` / `godot4` 命令，无法执行 headless 运行验证。
- 建议下一步在 Godot 编辑器中打开项目，重点验收：
  1. 进入主花园后新背景是否正确显示。
  2. 点击右侧“建造”按钮是否打开建造栏。
  3. 地面/小路瓦片是否可铺设和擦除。
  4. 花盆/花坛/家具等素材是否可放置和删除。
  5. 退出再进入花园后布局是否从 `user://garden_layout_v1.json` 恢复。
  6. 鱼塘钓鱼失败是否不会再给鱼/漂流瓶。
  7. 金鱼是否进入背包，树枝是否不进入背包。

## 操作说明

玩家操作：

- `WASD` / 方向键：移动。
- 点击右侧“建造”：进入/退出建造模式。
- `B`：进入/退出建造模式。
- 建造模式内左键：放置素材或铺设瓦片。
- 建造模式内右键：取消当前选择。
- 删除键：切换删除模式。
- 删除模式内左键：删除已放置物件。

开发注意：

- 地面瓦片和素材物件使用同一个保存文件，但保存字段分开：
  - `tiles`
  - `objects`
- 瓦片网格大小为 32px；源瓦片为 16px，因此 `TileMapLayer.scale = Vector2(2, 2)`。
- 主花园 DIY 可编辑区域目前在 `scene_manager.gd` 的 `_setup_garden_builder()` 中配置。
- 若 Godot 后续继续报 warning-as-error，优先检查 `Dictionary.get()`、`JSON.parse_string()`、`load()` 相关变量是否需要显式类型。
