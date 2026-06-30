# 44 当前工程交接

日期: 2026-06-30
分支: `feature/garden-mvp-loop`
远端: `origin/feature/garden-mvp-loop`

## 当前状态

本分支最近集中处理了池塘场景:

- 使用实际池塘场景 `res://scenes/pond/pond_area.tscn`。
- 漂流瓶从静态图改为 6 帧 `AnimatedSprite2D` 循环动画。
- 三个漂流瓶保持交互逻辑，视觉缩小到原来的 1/2。
- 入口/返回点已调整到右侧区域。
- 鸭子已加入池塘场景，素材内部白色填充已修正。
- 鸭子水/陆判断使用现有水域碰撞多边形。
- 鸭子行为改为长时间行走/游动，间歇休息，降低固定循环感。
- 池塘周边、右侧房屋/栅栏、池塘上部已补空气墙。
- 池塘内鱼、鸭、漂流瓶和拆分物件已统一遮挡排序。

## 最近关键提交

- `876d9ba fix(game): unify pond depth sorting`
  - 统一鱼、鸭、漂流瓶、拆分物件的遮挡层。
  - 鱼/鸭运行时按全局 Y 写入绝对 `z_index`。
  - 动态生成的漂流瓶改成绝对 Y 排序。

- `3f5653e fix(game): tune pond duck and collision walls`
  - 鸭子缩小。
  - 水中动画只保留一帧普通游动。
  - 拉长鸭子移动和休息时长。
  - 补池塘空气墙和右侧房屋遮挡。

- `7d70818 fix(game): refine pond duck movement`
  - 修复鸭子透明抠图。
  - 用水域碰撞多边形判断水/陆。
  - 改成随机移动/休息状态。

- `34c9d37 feat(game): add pond scene animated bottles and duck`
  - 加入池塘漂流瓶动态帧、鸭子和基础池塘动态物件。

## 主要文件

### 场景

- `game/scenes/pond/pond_area.tscn`
  - 当前使用中的池塘场景。
  - 包含背景、水波、鱼、鸭、莲花、青蛙、右侧房屋、钓鱼平台、漂流瓶、空气墙和返回区域。

- `game/scenes/Fishpond.tscn`
  - 旧/备用鱼塘场景文件，当前主流程使用 `pond_area.tscn`。

### 池塘脚本

- `game/scripts/pond/fish_path_swim_controller.gd`
  - 控制鱼沿 Path2D 游动。
  - 根据运动方向切换游动动画。
  - 每帧用全局 Y 设置鱼的绝对 `z_index`。

- `game/scripts/pond/duck_route_controller.gd`
  - 控制鸭子沿 Path2D 移动。
  - 使用 `Collision/WaterCollision/WaterCollisionPolygon` 判断是否在水中。
  - 在水中播放 `water_swim`，陆地播放 `land_walk`，休息时暂停在随机休息帧。
  - 每帧用全局 Y 设置鸭子的绝对 `z_index`。

- `game/scripts/managers/node_factory.gd`
  - 负责运行时生成记忆节点/漂流瓶。
  - 动态漂流瓶使用 `assets/pond/bottle/bottle_float_sprite_frames.tres`。
  - 动态节点已设置 `z_as_relative = false`，用落点 Y 排序。

### 素材

- `game/assets/pond/bottle/`
  - Godot 使用中的漂流瓶 6 帧动画。
  - `bottle_float_01.png` 到 `bottle_float_06.png`。
  - `bottle_float_sprite_frames.tres` 动画名为 `float_loop`。

- `game/assets/pond/duck/`
  - Godot 使用中的鸭子素材。
  - 陆地走路帧: `duck_land_walk_01.png` 等。
  - 水中帧: `duck_water_01.png` 等。
  - 当前 `water_swim` 只使用 `duck_water_01.png`。
  - `duck_sprite_frames.tres` 包含 `land_walk`、`water_swim`、`land_idle`。

- `game/assets/pond/fish/fish_05/`
  - 当前池塘中使用的鱼动画资源。

- `game/assets/fishpond/`
  - 鱼塘素材整理目录，包含背景、漂流瓶原始图层名版本、鱼、青蛙、水等素材和 `.import`。
  - 注意: 这个目录更像归档/中转素材，当前主场景多数引用 `assets/pond/...`。

- `game/assets/pond/unsorted/`
  - 尚未完全归类的池塘素材。

## 遮挡规则

池塘场景现在按以下原则处理遮挡:

1. 背景和水波保持固定负层级。
2. 鱼、鸭、玩家、动态漂流瓶按全局 Y 排序。
3. 拆分物件按视觉落地点设置绝对 `z_index`，并设置 `z_as_relative = false`。
4. 右侧房屋使用固定较高层级，保证角色在房屋后方时被遮住。
5. 场景瓶 `Props/MessageBottle` 保持交互节点不变，仅设置绝对排序。

如果之后新增池塘物件，建议:

- 可移动物体: 脚底/水面锚点 = `global_position.y`。
- 静态物体: 手动把 `z_index` 设成视觉落地点 Y，并设置 `z_as_relative = false`。
- 不要再给父节点设置一整个负层级来压低子物件，否则会破坏鱼/鸭/瓶之间的互相遮挡。

## 碰撞规则

池塘场景当前碰撞包括:

- `Collision/WaterCollision/WaterCollisionPolygon`
  - 给鸭子判断水域/陆地使用。
  - 不建议随意删除或改名。

- `Collision/PondAirWalls`
  - 画面四周边界。
  - 池塘上部水岸/树线。
  - 右侧栅栏内部。
  - 右侧房屋下沿和侧边。

- `Props/FishingPlatform/StaticBody2D`
  - 钓鱼平台碰撞。

- `Decorations/PondHutRight/StaticBody2D`
  - 右侧房屋碰撞。

## 交互逻辑

- 场景漂流瓶节点: `Props/MessageBottle`
  - 仍是 `Area2D`。
  - `metadata/interact_action = "pond_message_bottle"`。
  - `metadata/prompt = "Check the drifting bottle"`。
  - 点击逻辑由 `scripts/managers/scene_manager.gd` 注册。

- 运行时漂流瓶:
  - 由 `NodeFactory.make_memory_node()` 创建。
  - 仍通过 `ClickArea` 触发原有回调。

- 钓鱼点:
  - `Props/FishingSpot`，保留原 metadata 和碰撞。

## 当前待验证

本机命令行未找到 `godot`、`godot4`、`godot_console`，所以这些改动尚未通过命令行启动 Godot 验证。建议下一位接手者打开 Godot 编辑器检查:

1. 池塘场景能正常打开，无资源缺失报错。
2. 鸭子在水里只显示普通游动帧，陆地走路/休息节奏自然。
3. 玩家无法穿过池塘上部、右侧房屋/栅栏和四周边界。
4. 玩家、鱼、鸭、漂流瓶、莲花、钓鱼平台、房屋之间遮挡合理。
5. 三个漂流瓶都能点击并触发原交互。
6. 从主花园进入池塘、从池塘返回花园的传送逻辑正常。

## 已知注意事项

- `project.godot` 当前有本地改动: `config/features` 从 `"4.7"` 变为 `"4.6"`。本次按“现有内容”一并提交，后续如需锁定 Godot 版本请统一确认。
- `assets/characters/girl.png` 当前有较大本地改动，也按“现有内容”一并提交。
- `game/assets/fishpond/` 和 `game/assets/pond/` 中存在重复/中转素材，后续可以再做一次资产目录清理。
- `game/scripts/managers/node_factory.gd` 中历史中文注释存在乱码，但本次未重写该文件结构，仅补排序属性。

## 建议下一步

1. 用 Godot 编辑器打开项目，先跑 `res://scenes/Main.tscn`。
2. 进入池塘场景，检查碰撞和遮挡。
3. 如果遮挡有个别物件不顺眼，优先调整该物件的视觉落地点 `z_index`，不要改父节点整体层级。
4. 统一确认 Godot 版本后，再决定 `project.godot` 的 `config/features` 是否保持 `"4.6"`。
5. 清理或归档 `assets/fishpond/` 中与 `assets/pond/` 重复的素材。
