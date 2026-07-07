# 47 本地 UI / 场景更新交接说明

> 分支: `feature/garden-mvp-loop`  
> 最新提交: `e9b54df feat(ui): update bottom nav chat input`  
> 相关提交: `716c546 feat(ui): add clock and scene return portals`

## 1. 本次更新范围

本次本地更新主要集中在三个方向:

1. 底部 UI 精简与世界聊天输入框预留。
2. 昼夜钟 UI 接入。
3. 场景通行与遮挡关系修复,包括农场返回花园传送点、池塘 Y Sort 整理。

当前本地内容已经推送到 GitHub:

- remote: `origin`
- branch: `feature/garden-mvp-loop`
- HEAD: `e9b54df`

## 2. 底部 UI 更新

落地文件:

- `game/scripts/managers/scene_manager.gd`

调整内容:

- 移除了底部导航中的 `Sign`、`Save`、`Role`、`Back Garden`。
- 保留底部入口:
  - `World`
  - `Tree`
  - `Map`
  - `Postcards`
- 在底部同一行新增世界聊天输入框:
  - 节点名: `WorldChatInput`
  - 类型: `LineEdit`
  - placeholder: `Send a family message...`
  - 样式复用现有按钮的 `button_normal` / `button_hover`
- 在输入框上方新增近期消息预览:
  - 节点名: `WorldChatFeed`
  - 类型: `Label`
  - 展示最近 3 条家庭消息

当前聊天框已经接入基础聊天流程:

- 回车发送消息。
- 消息写入 `MemoryManager.garden_messages`。
- 如果 `CloudManager` 可用,调用 `CloudManager.create_message(...)` 同步到云端。
- 本地兜底保存到存档。
- 发送后刷新底部近期消息预览和留言板数据。

后续建议:

- 增加真正的实时多人 presence / family message channel。
- 增加聊天气泡或完整聊天历史浮层。

## 3. 昼夜钟 UI

落地文件:

- `game/scripts/ui/day_night_clock_ui.gd`
- `game/scripts/ui/day_night_clock_ui.gd.uid`
- `game/assets/ui/clock/*.png`
- `game/assets/ui/clock/*.png.import`
- `game/scripts/managers/scene_manager.gd`

实现说明:

- 时钟挂在主 UI 层 `UIRoot` 下,节点名为 `DayNightClock`。
- 使用 `TextureRect`。
- 读取现有 `/root/GameClock`。
- 每个整点根据当前小时切换图片。
- 图片加载顺序是手写数组,没有按文件名排序。

时钟帧规则:

```gdscript
frame_index = (current_hour - 5 + 24) % 24
```

已按以下固定顺序加载:

```text
0.png, 1.png, 2.png, 2-1.png, 3.png, 4.png,
5.png, 6.png, 7.png, 7-1.png, 8.png, 9.png,
9-1.png, 10.png, 10-1.png, 11.png, 12.png,
13.png, 14.png, 15.png, 16.png, 17.png,
18.png, 18-1.png
```

注意:

- `0.png` 对应 5:00 AM。
- `4:00` 对应最后一张 `18-1.png`。
- `texture_filter` 设置为 nearest,保持像素风。

## 4. 池塘 Y Sort 遮挡修复

落地文件:

- `game/scenes/pond/pond_area.tscn`
- `game/scripts/pond/fish_path_swim_controller.gd`
- `game/scripts/pond/duck_route_controller.gd`
- `game/scripts/player.gd`
- `game/scripts/managers/scene_manager.gd`

目标:

让玩家、鱼、鸭、青蛙、漂流瓶、池塘物件在同一个 Y Sort 父节点下按接地点正确遮挡。

当前结构:

```text
PondArea
├── Background
├── Collision
├── PondSpawnPoint
├── GardenReturnArea
├── MessageBottle
├── FishingSpot
└── YSortObjects
    ├── WaterRipple01..04
    ├── WaterLoop
    ├── Fish05Path01 / Fish05_01
    ├── Fish05Path02 / Fish05_02
    ├── Fish05Path03 / Fish05_03
    ├── DuckRoute / DuckSprite
    ├── PondHutLeft
    ├── PondHutRight
    ├── FishingPlatform
    ├── BenchSeat
    ├── WoodenSign
    ├── LotusFlower01..03
    ├── StoneLantern
    ├── FlowerBed
    ├── FlowerPot
    ├── WaterBucket
    ├── MetalBucket
    ├── MetalCrate
    ├── RopeCoil
    ├── FrogIdle
    └── BottleFloat
```

关键处理:

- `YSortObjects.y_sort_enabled = true`。
- `Background` 保持在 Y Sort 外,底层显示。
- `Collision` 保持在 Y Sort 外,只负责碰撞。
- `MessageBottle`、`FishingSpot` 是交互区域,不参与 Y Sort。
- 可见的 `BottleFloat` 单独放入 `YSortObjects`。
- 鱼和鸭子的可见 sprite 变为 `YSortObjects` 直接子节点。
- 鱼、鸭控制脚本改为同步可见 sprite 的 `global_position`。
- 参与 Y Sort 的对象清理了手写 `z_index / z_as_relative`。
- 多个静态 Sprite 通过 `offset` 调整图片位置,让节点原点更接近接地点。
- 玩家进入池塘时挂到 `PondArea/YSortObjects` 下。
- 玩家在 Y Sort 父节点下不再动态写全局 `z_index`。

注意:

- 如果未来仍有遮挡不正确,优先检查物体是否还是画在背景大图里。
- 画在背景里的物体不能靠 Y Sort 遮挡玩家,必须切成独立透明 PNG 后放入 `YSortObjects`。
- 如果新增池塘物件,不要放进 `Props` / `Decorations` 这种整体容器里排序,应直接作为 `YSortObjects` 子节点。

## 5. 农场返回花园传送点

落地文件:

- `game/assets/manifest/portals_farm.json`
- `game/scripts/farm/farm.gd`
- `game/scripts/managers/scene_manager.gd`

新增 manifest:

```json
{
  "scene": "farm",
  "spawn_points": {
    "default": [640, 650],
    "from_garden": [640, 650]
  },
  "portals": [
    {
      "portal_id": "FarmGardenReturnArea",
      "target_scene": "res://scenes/Main.tscn",
      "spawn_point": "from_farm",
      "trigger_rect": [560, 620, 160, 96],
      "prompt_text": "Return to garden",
      "tap_enabled": true
    }
  ]
}
```

实现说明:

- 进入 farm 后,`SceneManager` 会调用:

```gdscript
ScenePortal.build_portals("farm", world, _on_portal_travel)
```

- `Farm.tscn` 自带玩家,因此 `farm.gd` 中给玩家补了:

```gdscript
player.add_to_group("player")
```

这样 `ScenePortal` 的 `body_entered` 才能识别玩家并触发返回。

## 6. 已知未完成项

1. 世界聊天框目前只是 UI 预留。
2. 聊天内容没有持久化,也没有接 CloudBase。
3. 本地环境没有可用 `godot` 命令,未能做自动运行时截图验收。
4. 池塘 Y Sort 已做静态结构检查,但仍建议在 Godot 编辑器里走位验证:
   - 玩家走到物体下方时,玩家在前。
   - 玩家走到物体上方时,物体在前。
   - 鱼、鸭、瓶子没有跳层或闪烁。

## 7. 验收建议

建议在 Godot 中依次验证:

1. 花园底部 UI:
   - 只显示 `World / Tree / Map / Postcards / WorldChatFeed / WorldChatInput`。
   - 不再显示 `Sign / Save / Role / Back Garden`。

2. 昼夜钟:
   - 右上角显示时钟。
   - 修改 `GameClock.debug_start_hour` 后图片能按小时变化。

3. 农场:
   - 从世界地图进入农场。
   - 走到画面底部中间区域,能返回花园。
   - 点击底部传送区也能返回花园。

4. 池塘:
   - 玩家和静态物件有正确前后遮挡。
   - 鸭子仍能区分水面/陆地动画。
   - 鱼仍能沿路径游动并切换方向。
   - 漂流瓶仍可点击交互。

## 8. 最近相关提交

```text
e9b54df feat(ui): update bottom nav chat input
716c546 feat(ui): add clock and scene return portals
aa76304 docs(dev): 46 CloudBase 存储现状交接(干净摘要,给后端同学)
```
