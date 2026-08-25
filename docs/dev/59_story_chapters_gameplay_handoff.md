# 59｜三章主线、角色、钓鱼与农场玩法交接

日期：2026-07-15

当前分支：`feature/garden-tilemap`

远端分支：`origin/feature/garden-tilemap`

交接基线提交：`222e011 feat(game): 完成三章主线并恢复核心玩法`

## 1. 当前状态

本轮已经把以下内容合并到远端分支：

- 三章主线任务与章节切换；
- 第三章完成第一次 AI 房间生成后进入开放成长；
- 爸爸、妈妈统一风格角色素材与角色创建入口；
- 池塘钓鱼玩法恢复；
- 农场靠近田块后的选种、浇水、施肥、生长、收获提示；
- 主线结束后的记忆花园等级 2、等级 3 目标；
- 对应 Godot 回归测试。

本轮没有修改 `main`，也没有强推远端。远端更新整合时保留了队友提交的：

- 完整钓鱼动画和脱钩概率；
- 鱼钩收线时的物品展示；
- 池塘人物比例修正；
- 旧版鱼塘记忆花迁移到主花园；
- DIY 物件尺寸和占格修正。

## 2. 最近关键提交

### `222e011 feat(game): 完成三章主线并恢复核心玩法`

- 加入三章主线状态机；
- 恢复并接入钓鱼主线；
- 农场接入小型种子选择栏和动作图标；
- 接入首次记忆房间描述输入；
- 新增爸爸、妈妈角色变体；
- 新增综合回归测试。

### `863a880 feat(game): 整合角色外观与近期体验更新`

- 汇总此前角色外观、开场、Logo、厨房和界面体验修改；
- 是 `222e011` 的直接前置提交。

### 远端已整合的队友提交

- `6796f10 docs: 补充花园瓦片分支最终交接`
- `963bdc1 fix: 修正DIY物件尺寸与摆放占格`
- `01f5b09 fix: 调整池塘人物显示比例`
- `afb4cd4 fix: 统一将记忆花生成到主花园`
- `7632e4b fix: 优化花园建造界面并恢复池塘钓鱼`

## 3. 三章主线实现

主线定义集中在：

- `game/scripts/managers/story_manager.gd`
- `game/scripts/ui/quest_panel.gd`

任务完成态继续保存在 `MemoryManager.chapter1_tasks`。字段名虽然仍叫 `chapter1_tasks`，现在承载三章状态。这是为了兼容旧存档，暂时不要直接改字段名。

### 3.1 第一章：重新打开花园

任务顺序：

1. `open_box`：开场旧木盒结束时完成；
2. `first_photo`：任务面板中确认收好旧照片；
3. `garden_edit`：花园布局保存时完成；
4. `first_seed`：种下 `corrato`，即番茄；
5. `harvest_tomato`：收获番茄；
6. `first_dish`：`KitchenManager.ai_dish_created` 发出后完成；
7. `dish_on_table`：`KitchenManager.meal_completed` 发出后完成。

章节结束文字：

> 花园还没有完全整理好，但这里已经重新有了生活的气息。

相关事件来源：

- `GardenBuildManager.layout_saved`
- `FarmManager.planted`
- `FarmManager.harvested`
- `KitchenManager.ai_dish_created`
- `KitchenManager.meal_completed`

### 3.2 第二章：河流带来的惊喜

任务顺序：

1. `first_fishing`：第一次成功钓起结果；
2. `first_bottle`：打开第一次钓到的漂流瓶；
3. `first_place`：保存第一个地图留点；
4. `first_postcard`：保存留点时生成并寄出明信片。

第一次有效拉竿在 `first_bottle` 尚未完成时会保底获得漂流瓶，防止主线被随机结果卡住。

漂流瓶固定留言：

> 今天的风很好，希望你那里也是。

章节结束文字：

> 河流把远方的心意送到了这里，而你也从这里寄出了一句话。

关键接入点：

- `SceneManager._pick_fishing_result()`
- `SceneManager._award_fishing_result()`
- `SceneManager._open_caught_bottle_content()`
- `SceneManager._save_new_place()`
- `StoryManager.record_fishing_result()`
- `StoryManager.record_place_and_postcard()`

### 3.3 第三章：自己长出的花

任务顺序：

1. `first_memory_flower`：前两章完成后自动生成第一朵记忆花记录；
2. `collect_memory_flower`：在任务面板点击“收录记忆花”；
3. `first_ai_room`：生成第一间记忆房间。

第一朵记忆花内容：

> 河边的风吹过衣角。
>
> 明信片上的墨还没有干。
>
> 桌上放着刚做好的番茄料理。

进入第三章且尚未生成房间时，从“我的房间”入口打开的是一句话生成面板。面板会展示以下可用记忆：

- 花园照片；
- 第一顿料理；
- 河边木桥；
- 第一张明信片；
- 第一朵记忆花。

首次房间生成成功后，`RoomLayoutManager.room_generated` 会完成 `first_ai_room`。第三章随即结束，不再进入强制终章。

章节结束文字：

> 这间房没有收藏很多东西，但它已经保存了你来到花园后的第一段生活。

## 4. 主线结束后的开放成长

当 `StoryManager.current_chapter()` 返回 `0` 时，任务面板改为显示长期成长目标。

### 记忆花园等级 2

- 3 朵记忆花；
- 3 张明信片；
- 3 道 AI 料理；
- 显示奖励：解锁第二个房间。

### 记忆花园等级 3

- 探索 5 个地点；
- 显示奖励：解锁花园中央区域。

当前实现已经计算并展示进度；奖励文字已经进入 UI，但第二房间和中央区域的实际开锁动作尚未绑定到独立场景门禁。

## 5. 爸爸、妈妈角色

主要文件：

- `game/scripts/managers/appearance_manager.gd`
- `game/scripts/ui/character_creator_panel.gd`
- `game/tools/build_parent_character_variants.py`
- `game/assets/characters/parents/`

实现方式：

- 爸爸复用男孩的身体、动作和 5 套成品服装；
- 妈妈复用女孩的身体、动作和 5 套成品服装；
- 爸爸固定侧分发型，并增加轻微成熟脸部特征；
- 妈妈固定柔和短发，并增加眼镜特征；
- 每套角色图集保留 15 帧动作；
- 不再使用旧 `papa.png`、`mama.png` 作为新角色创建结果。

角色创建页现在直接显示四种身份：

- 女孩；
- 男孩；
- 爸爸；
- 妈妈。

爸爸、妈妈目前各只有一种固定发型，服装仍有 5 套可选。生成脚本可以重复运行，不应手工逐帧改图。

## 6. 钓鱼玩法

主要文件：

- `game/scripts/managers/scene_manager.gd`
- `game/scenes/pond/pond_area.tscn`
- `game/assets/pond/props/`
- `game/assets/pond/fish/`
- `game/assets/pond/bottle/`

入口节点：`FishingSpot`。

交互方式：

- 玩家靠近显示“按 E 开始钓鱼”；
- 可以按 E 或点击钓鱼点；
- 红色标记进入绿色区域时点击“拉竿”；
- 结果包含金鱼、漂流瓶、树枝；
- 金鱼进入背包；
- 漂流瓶进入第二章留言流程；
- 非主线阶段继续使用随机概率和脱钩机制。

不要删除 `_register_pond_fishing_spot()` 或把 `FishingSpot` 改名，否则场景会再次失去钓鱼入口。

## 7. 农场玩法

主要文件：

- `game/scripts/farm/farm.gd`
- `game/scripts/ui/seed_selection_panel.gd`
- `game/assets/farm/action_icons/`

当前交互：

1. 玩家靠近空田块；
2. 田块上方和屏幕底部显示播种图标；
3. 按 E 打开小型种子栏；
4. 只显示家庭仓库与背包中实际拥有的种子；
5. 播种后按当前状态显示浇水、施肥、生长或收获图标；
6. 浇水壶和肥料仍按现有库存规则消耗或校验。

动作图标：

- `seed.png`
- `water.png`
- `fertilize.png`
- `grow.png`
- `harvest.png`

图标为 imagegen 生成的柔和像素风素材，使用统一纯色键控背景生成后完成透明化和 64×64 切分。原始生成提示词要求五枚横向排列的播种、浇水、施肥、生长、收获图标，模式为 `stylized-concept`。

## 8. AI 房间接入说明

当前项目已有正式 AI 路由是 `analyze-room-photo`，没有独立的“文本 + 多段记忆生成房间”路由。

因此第三章首次房间目前采用：

1. 玩家输入一句房间描述；
2. 使用 `AIClient.mock_room_analysis()` 取得合法房间契约基础；
3. 把玩家描述、主线记忆来源和初始家具写入草稿；
4. 交给 `RoomLayoutManager.generate()` 和 `RoomSceneGenerator` 落库、生成房间；
5. `generation_meta.source` 标记为 `mock`，不会伪装成真实线上 AI。

替换真实接口时，优先修改：

- `SceneManager._generate_first_room_from_brief()`；
- `AIClient` 新增文本房间路由调用；
- `AIWorkflowManager` 新增对应 draft/commit 流程；
- 后端增加 request/response schema、mock、prompt、validator 和测试。

真实接口输出仍应复用现有 `analyze-room-photo` 的房间数据结构，至少包含：

```json
{
  "room_type": "kitchen_corner",
  "style": "warm_cozy",
  "suggested_room_theme": "memory_corner",
  "description": "一个有河边晚风感觉的小厨房。",
  "objects": [
    {"object_type": "desk", "zone": "back_left"},
    {"object_type": "lamp", "zone": "back_right"},
    {"object_type": "photo_wall", "zone": "back_wall"},
    {"object_type": "plant", "zone": "right_side"},
    {"object_type": "chair", "zone": "front_left"}
  ]
}
```

AI 仍不得输出具体坐标，坐标由 `RoomLayoutManager`、`ZoneManager` 和 `RoomSceneGenerator` 决定。

## 9. 测试与验收

新增综合测试：

- `game/tests/story_gameplay_restore_test.gd`
- `game/tests/story_gameplay_restore_test.tscn`

覆盖内容：

- 爸爸、妈妈 5 套服装和 15 帧动作；
- 父母角色不回退到旧素材；
- `FishingSpot` 和钓鱼方法存在；
- 农场 5 枚动作图标存在；
- 种子选择面板能回传播种结果；
- 三章任务数量与第一朵记忆花文案；
- 主线结束后的两个成长目标。

本轮已经通过：

- Godot 4.7 主工程无界面启动；
- `Farm.tscn` 独立启动；
- `story_gameplay_restore_test.tscn`；
- `appearance_system_test.tscn`；
- `onboarding_guide_test.tscn`；
- `ai_gate4_test.tscn`；
- `gate7_room_scene_test.tscn`；
- 其他本地测试场景。

建议手工验收顺序：

1. 新存档播放旧木盒开场并创建角色；
2. 打开任务面板，确认第一章任务；
3. 在花园编辑模式移动一个入口物件；
4. 去农场靠近空田，按 E 选择番茄；
5. 浇水、等待成熟、收获；
6. 去厨房生成 AI 料理并摆上餐桌；
7. 去池塘完成首次钓鱼并打开指定漂流瓶；
8. 打开地图创建留点并生成明信片；
9. 查看并收录第一朵记忆花；
10. 进入自己的房间，输入描述并生成第一间房；
11. 再打开任务面板，确认进入开放成长状态。

## 10. 已知差异与后续事项

以下内容不会阻塞当前三章主线，但后续可继续精修：

1. 第一章的花园编辑任务目前在任意一次布局保存后完成，没有强制分别移动长椅、花盆和桌子。
2. 第二章第一个地图留点目前没有用坐标强制限定在木桥，只通过剧情引导玩家在木桥创建。
3. 第一朵记忆花已经进入记忆卡与图鉴数据，但第三章专属实体花的场景生长动画仍可进一步加强。
4. 第一次文本房间使用受控 mock/fallback 契约，真实文本房间 AI 路由仍需按第 8 节接入。
5. 等级 2、等级 3 已展示进度和奖励，但第二房间、花园中央区域的实际门禁解锁仍需实现。
6. 爸爸、妈妈当前各只有一种固定发型；如果补发型，继续使用完整成品图集，不要重新引入颜色遮罩。

## 11. 下一位开发者建议

优先级建议：

1. 接入真实“文本 + 记忆素材生成房间”接口；
2. 给第一朵记忆花增加主花园实体节点和生长动画；
3. 给木桥留点增加推荐坐标或区域标记；
4. 把等级 2、等级 3 的奖励接到真实门禁；
5. 最后再增加父母发型和服装数量。

继续开发前先执行：

```bash
git switch feature/garden-tilemap
git pull --ff-only origin feature/garden-tilemap
```

不要从旧提交恢复整份 `scene_manager.gd`，否则容易再次覆盖钓鱼、记忆花迁移和本轮章节钩子。
