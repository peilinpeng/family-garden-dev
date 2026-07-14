# 花园视觉与建造系统合并交接（2026-07-14）

## 合并信息

- 源分支：`feature/garden-mvp-loop`
- 建议目标分支：`dev`
- Godot 工程：`game/project.godot`
- 逻辑画布：1280×720
- 建造网格：32×32 逻辑像素
- 本次提交包含当前功能分支尚未提交的完整工作区更新，不仅是单一瓦片修复。

## 一、花园地形与 DIY 建造

### 语义地形

- 玩家只选择 `泥土地面 / 浅色石板 / 水池 / 草地恢复`，不再直接选择图集坐标。
- 泥土、石板路和水面共用 47 格八邻域 blob 规则，支持外角、内凹角、窄颈、L 形和 U 形区域。
- 修改一个格子时会重算周围八格。
- 水面使用独立运行时 `TileMapLayer`。
- 支持点击、连续拖动、Shift 矩形、Ctrl+Z/Ctrl+Y 和草地恢复。
- 存档升级为语义 `terrain_cells`；仍保留旧 `tiles` 存档迁移逻辑。

核心文件：

- `game/scripts/garden_builder/garden_build_manager.gd`
- `game/scripts/garden_builder/terrain_autotile_resolver.gd`
- `game/assets/garden/tileset/ground/Tileset_Dirt.png`
- `game/scenes/garden_builder/test/garden_terrain_test.tscn`

### 摆放预览、碰撞与遮挡

- 物件、瓦片和删除预览固定在场景最高预览层，不会被已铺瓦片或已摆物件遮挡。
- 正式放置后，普通物件按 bottom-center 落点 Y 值排序，与玩家脚底排序保持一致。
- `ground_decor`、`wall_object`、`foreground` 使用各自固定层级。
- 不再用完整占格矩形作为碰撞箱；默认碰撞只覆盖物件底部实体脚印。
- 支持资产级 `collision_rect = [x, y, w, h]` 精确配置。
- `collision=false` 或 `walkable=true` 不创建运行时碰撞。
- 物件占格仍用于防止摆放重叠和在物件下方重新铺地。

### 素材与人物比例

角色实际显示高度约 77–100px，DIY 素材按以下比例校准：

| 分类 | 显示缩放 | 高度中位数（约） |
|---|---:|---:|
| 花坛 | 0.78 | 81px |
| 植物 | 0.68 | 62px |
| 花盆 | 0.50 | 49px |
| 家具 | 0.68 | 82px |
| 装饰 | 0.75 | 59px |
| 工具 | 0.58 | 38px |

- 原生 16px tileset 家具单独按 2x 显示。
- 预览、删除命中区域和碰撞脚印均读取调整后的显示尺寸。
- 旧存档无需迁移，重新载入后自动采用新比例。

### 已排除的错误花坛

以下素材包含完整 L 形主体和断裂的右上角大块残片，已从运行时 DIY 数据库与有效 CSV 中移除：

- `gb_flowerbed_02_020`
- `gb_flowerbed_02_022`
- `gb_flowerbed_02_039`
- `gb_flowerbed_02_041`
- `gb_flowerbed_02_049`

源 PNG 和图标暂时保留，便于以后重新裁切。有效 DIY 素材为 161 项，其中花坛 63 项。旧存档如引用这些 ID，载入时会忽略对应物件。

## 二、记忆花与记忆连接

### 记忆花

- 所有花园记忆花统一使用 `game/assets/garden/memory_flowers.png`。
- 图集中 12 朵花按 `slot_id` 稳定选择，同一记忆不会在重进场景后随机换花。
- 显示高度由 96px 调整为 64px。
- 点击热区保持 80×80px，视觉缩小后仍容易点击。
- 记忆花不创建行走碰撞。

### 记忆 Link

- 白天使用 8 帧蓝色蝴蝶：`link_butterfly_day.png`。
- 夜晚使用 8 帧发光蜜蜂：`link_bee_night.png`。
- Link 沿自然曲线路径移动，并根据关系强度调整表现。
- 正式序列帧加载失败时保留程序化绘制作为回退。
- 配置集中在 `game/assets/memory_links/memory_link_config.json`。

核心文件：

- `game/scripts/managers/node_factory.gd`
- `game/scripts/managers/memory_manager.gd`
- `game/scripts/memory_links/memory_link_visualizer.gd`
- `game/scripts/memory_links/memory_link_instance.gd`
- `game/scripts/memory_links/memory_link_path.gd`
- `game/scripts/managers/scene_manager.gd`

## 三、同批交付的既有功能分支更新

以下内容已经存在于本次提交前的未提交工作区，本次随完整功能分支一起交付：

- 家庭成员角色比例与 NPC 动画帧配置修正。
- 花园夜间房屋窗光表现。
- 钓鱼流程、失败结果和背包物品处理修正。
- 背包快捷栏收起/展开和按钮布局优化。
- 家庭树查看界面及相关按钮字体适配。
- 建造与设置入口图标资源。

相关文件主要包括：

- `game/assets/manifest/characters.json`
- `game/scripts/managers/scene_manager.gd`
- `game/scripts/npc_wander.gd`
- `game/scripts/ui/inventory_ui.gd`
- `game/assets/ui/icons/icon_build.png`
- `game/assets/ui/icons/icon_settings.png`

## 四、数据与兼容性

- 花园布局仍保存到 `user://garden_layout_v1.json`。
- 当前保存结构版本为 3，包含 `terrain_cells` 和 `placed_objects`。
- 旧版 `tiles`、`objects` 字段仍可读取。
- 删除的 5 个错误花坛不会导致存档解析失败，只会跳过已失效的资产 ID。
- 新的显示缩放不修改存档坐标。

## 五、已完成验证

- `git diff --check` 通过。
- 47 个 terrain mask 唯一性检查通过。
- 47 个图集坐标唯一性与范围检查通过。
- 166 项原始素材纹理路径检查通过。
- 有效 DIY 数据库：161 项；有效 CSV：161 行。
- 剩余 63 个花坛的大块透明连通区域检查通过，同类断裂残片为 0。
- 记忆花 manifest：64px 显示高度、80×80px 点击热区检查通过。
- 当前环境未找到 Godot 可执行程序，因此未完成编辑器运行和画面级回归。

详细报告：

- `reports/garden_terrain_test_report.md`
- `reports/terrain_tileset_validation.md`
- `reports/terrain_mask_manifest.csv`
- `reports/garden_asset_review.md`
- `docs/memory_link_visualizer.md`

## 六、合并前人工验收清单

1. 打开主花园，分别绘制泥土、石板和水面的单格、直线、L 形、U 形及多内凹区域。
2. 确认水面和泥土边缘连续，没有矩形填充块或错误内角。
3. 快速拖动、Shift 矩形、撤销、重做、草地恢复均正常。
4. 摆放物件时预览始终位于场景最上层；放下后恢复正常前后遮挡。
5. 开启“可见碰撞形状”，确认角色只被花盆、花坛、家具底部实体阻挡。
6. 角色走到物件后方时被遮挡，走到前方时覆盖物件。
7. 确认记忆花低于人物身高，花盆约在膝盖至腰部，家具比例协调。
8. 确认 5 个错误花坛不再出现在 DIY 选择栏。
9. 白天 Link 显示蝴蝶，夜晚 Link 显示发光蜜蜂。
10. 退出并重新进入花园，确认地形、摆放物、记忆花变体和 Link 均稳定恢复。
11. 回归钓鱼、背包快捷栏、家庭树和夜间窗光。

## 七、已知风险与回滚

- 47 格图集映射已通过静态检查，但最终方向和像素边缘仍需编辑器画面确认。
- 少数高花架约为 1.2–1.5 个角色身高，属于保留的高物件；如观感仍偏大，可为单项增加 `display_scale` 覆盖。
- 通用碰撞脚印按分类估算；个别异形家具应补 `collision_rect` 精调。
- 如需恢复被排除花坛，只需把对应资产条目重新加入 `garden_assets.json` 和有效 CSV；源 PNG 未删除。
- 如地形映射需要回滚，可恢复 `garden_build_manager.gd` 的旧瓦片保存/绘制逻辑并移除 `terrain_autotile_resolver.gd`，但必须同时处理版本 3 存档兼容。

## 八、建议合并方式

1. 将本功能分支合并到最新 `dev`。
2. 冲突时优先保留本分支的 `garden_build_manager.gd` 语义地形、碰撞和预览逻辑。
3. `scene_manager.gd` 变更面较大，建议按“记忆 Link / 夜间窗光 / 钓鱼 / 家庭树 / UI”分区检查冲突，不要整文件覆盖。
4. 合并后在 Godot 编辑器完成第六节人工验收，再进入发布分支。
