# 37｜Fishpond 池塘素材接入记录

## 1. 接入范围

- 素材源目录：`E:\000\family garden\assets`
- 原始备份：`E:\000\family garden\assets_backup_before_rename`
- Godot 目标目录：`game/assets/fishpond/`
- 场景文件：`game/scenes/Fishpond.tscn`
- 加载入口：`SceneManager._build_fishpond()`

## 2. 当前结构

```text
game/assets/fishpond/
  background/pond_background.png
  fish/koi_fish_01..04/koi_fish_swim_<direction>_01.png
  frog/frog_unknown_01..04.png
  items/*.png
  water/water_ripple_01..04.png
  pond_asset_manifest.json
```

## 3. 场景层级

`Fishpond.tscn` 按 `docs/dev/36_scene_ownership_and_pipeline.md` 的新场景规范搭建：

```text
Fishpond
  Background
  GroundProps
  FixedBackVisuals
  WorldYSort
  WorldCollision
  InteractionAreas
```

背景是 1280x720 整图，直接 `centered=false` 贴到 `(0,0)`。
鱼、青蛙和道具是裁切小图，目前按可运行占位坐标摆放。

## 4. 碰撞与交互

- 已加四周边界碰撞。
- 已给钓鱼台、两座小屋、长椅、木牌添加落地占地碰撞。
- 已给钓鱼台和木牌添加 `InteractionAreas` 占位区，元数据为 `interact_action` / `prompt`。
- 记忆花、漂流瓶、返回入口仍由现有 `SceneManager` + `ScenePortal` + `NodeFactory` 生成。

## 5. 待美术/场景复核

- 道具当前不是全画布透明图，坐标为手工占位，需在 Godot 中按背景微调。
- 青蛙源文件无法从命名判断 idle/jump，暂命名为 `frog_unknown_##`。
- 如果后续有 `Collision_area.png`，应按 docs/dev/35 的方式生成更精确的碰撞。
- 打开 Godot 后建议开启 Debug -> Visible Collision Shapes 检查碰撞框。
