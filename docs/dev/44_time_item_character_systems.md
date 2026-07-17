# 44 · 时间 / 物品 / 角色 三系统设计

> 关联:[05 数据模型](../05_backend_data_model.md)、[43 联机方案](43_cloudbase_multiplayer_handoff.md)、`MemoryManager`、`ZoneManager`、`NodeFactory`
> 状态:**昼夜 · 物品 · 角色 三系统均已落地**(联机/上云为后续)
> 已定决策:昼夜=**现实时间(动森式)**;库存=**个人背包 + 共享仓 都要**

---

## 0. 大原则(三系统共用,别另起范式)

照搬项目已有的三套模式即可:

1. **数据驱动定义 + registry 单例**(如 `ZoneManager` 读 `zones_{scene}.json`、crops)。物品/角色都做成"数据 def + 注册表 autoload"。
2. **持久化接缝**(`MemoryManager` / CloudBase)。所有可变状态经它存。
3. **时钟 / 时间戳算,不每帧 tick**(crops 的 `planted_at`、chick 的 `grow_seconds`、动物状态机、昼夜)。

**id 空间统一**:物品、作物、角色、AI 目录共用同一套 id,便于 AI 生成时直接引用。

---

## 1. 时间系统

### 1.1 季节 = 已有,且是情感机制(勿改)

`MemoryManager.garden_season()` 是**"家庭关系温度计"**:由 `cross_member_interaction_count` 驱动(0→春 / 3-9→夏 / 10+→秋),配 `SceneManager` 的 `SeasonOverlay` 染色。

> ⚠️ **不要加日历季节**。它不是时间产物,是核心立意。新系统只 **读** `garden_season()`。

### 1.2 昼夜 = 已落地(GameClock)✅

- `scripts/managers/game_clock.gd`(autoload `GameClock`):游戏点钟≈现实点钟。
- 关键属性 / 方法:
  - `hours()` 0–24、`phase()`(night/dawn/day/dusk)、`is_night()`
  - `overlay_color()` → 给 CanvasModulate 的整屏染色乘子(白=正午无染色)
  - 信号 `hour_changed(int)` / `phase_changed(String)`
  - `set_server_time(unix)`:**联机对齐**(全家锚服务器时间)
  - `garden_tz_offset_hours`(默认 +8):全家用同一"花园时区",跨时区也一致
- 表现:**全局染色**——`GameClock` 自己创建一个 `CanvasModulate`(挂在 autoload 下、不在任何 CanvasLayer 内),染默认画布 → **所有场景(含独立运行)自动生效,无需逐场景添加**;UI 在单独 CanvasLayer 不受影响。
- 联动:动物 `animal.gd` 夜里几乎一直 REST 并保持睡姿(读 `/root/GameClock`,无时钟则安全回退);白天状态切换也整体放慢。

**调试看夜晚**:把 `GameClock` 的 `debug_start_hour` 设成 22(从晚上起),或 `time_scale` 调大(600=一天≈2.4 分钟);正式运行设回 `debug_start_hour=-1` / `time_scale=1`。

**联机**:昼夜不持久化(从时钟算),只需登录时 `set_server_time(服务器unix)` 对齐;全家因现实时间天然一致。

---

## 2. 物品系统(个人背包 + 共享仓)· 已实现 ✅

落地文件:`assets/manifest/items.json`、`scripts/items/item_def.gd`、`scripts/items/inventory.gd`、`scripts/managers/item_db.gd`(autoload `ItemDB`)、`scripts/managers/inventory_manager.gd`(autoload `InventoryManager`)、`scripts/ui/inventory_ui.gd` + `scenes/InventoryUI.tscn`。
- 37 个物品(16 作物各 种子+产出,图标复用 crops_daily 图集;+ 工具/礼物/货币)。
- `Inventory`:堆叠(按 max_stack)+ 槽位容量 + 增删移转 + 序列化 + `changed` 信号。
- `InventoryManager`:`backpack`(私有)+ `storehouse`(共享),本地存档 `user://inventory_v1.json`(后续走 seam 接 CloudBase),`deposit/withdraw` 转移,首次发初始种子。
- 接入农场:种植**消耗种子**、收获**产出进背包**(+概率返还种子)。
- UI:按 **I** 开关,背包/共享仓双栏,左键移 1 / Shift 移整组。
- **联机 TODO**:共享仓改为走 A 面(云函数校验写 + 广播),背包仍按本人。

### 2.1 定义

- `ItemDef`(数据,Resource 或 JSON):`id / name / icon / category(seed|produce|tool|gift|decor) / stackable / max_stack / use 行为`。
- `ItemDB`(autoload 注册表):加载所有 def、按 id 查。
- 与 crops / AI 目录**同一 id 空间**。

### 2.2 两个库存(都按决策要)

| | 归属 | 联机 | 存哪 |
|---|---|---|---|
| **个人背包** | 按 `user_id`,私有 | 只同步给本人 | 个人记录 |
| **共享仓** | 家庭一份 | **走联机 A 面**:云函数校验写 + 广播同步 | 家庭记录 |

- 数据结构都是 `{item_id: count}` 堆叠表,经 `MemoryManager` 持久化。
- **抢最后一个**(共享仓并发)→ 云函数事务裁决,和"种地那格"同理(见 43 §5)。

### 2.3 挂进现有循环

- 收作物 → 进个人背包;可存入共享仓。
- 种子 / 工具 → 从库存取用。
- 装饰类物品 → 摆放**复用 `NodeFactory` + `ZoneManager`**(已有摆放管线)。

---

## 3. 角色系统(成员即角色,和联机绑定)· 已实现 ✅

落地文件:`assets/manifest/characters.json`、`scripts/managers/character_db.gd`(autoload `CharacterDB`)、`scripts/player.gd`(加 `apply_character`)、`scripts/farm/remote_player.gd` + `scenes/RemotePlayer.tscn`。
- `CharacterDB`:6 个家庭身份(`father/mother/grandfather/grandmother/partner/player`),每个配 sheet/hframes/vframes/scale；`resolve(role_key)` 解析别名(papa→father、grandpa→grandfather、girl→player…)。女儿、儿子继续使用可定制外观，父母与祖辈使用固定完整 15 帧形象。
- `Player.apply_character(role)`:数据驱动换贴图/帧网格/缩放;本地玩家按存档 `selected_role_key`(独立运行回退 father)。
- `RemotePlayer`:渲染任意角色 + 名字标签 + `set_target()` 接收位置 + 插值 + 走路动画;z=脚底。**联机时由 presence 喂位置**;现在用 `placeholder_wander` 当占位家庭成员在花园里溜达。
- Farm:本地玩家 + 其余 3 个家庭成员可见。
- **联机 TODO**:把占位 wander 换成 presence 驱动(`set_target`),接 `members` 表真实成员-角色映射。

### 3.x 原设计(供参考)

- 已有:角色选择 `selected_role_key` + papa/mama/boy/girl 立绘 + `Player.tscn`。
- `CharacterDef`(数据):`role → {name, sprite_sheet, 默认外观}`。
- 一个成员 = `{user_id, character, 外观, 位置(联机), 个人背包引用}`。
- 本地玩家渲染登录成员;**远端成员**通过联机 presence 的 `RemotePlayer` 用**各自外观**渲染(看得出走来的是爸爸还是娃)。
- 接 `members` 表 + 联机 presence(见 43)+ 个人背包。主要是**身份 / 外观**层,渲染已有。

---

## 4. 建议实现顺序

1. ✅ **GameClock(昼夜)** —— 已落地。地基,动物/灯光/商店都读它。
2. **物品系统** —— 玩法循环主干(收→存→用/送/卖);共享仓后续接联机 A 面;装饰复用 NodeFactory。
3. **角色系统** —— 与联机 presence 一起做最自然。

---

## 5. 家庭树成长系统 · 已实现 ✅

- 新玩家首次进入花园会收到唯一一株家庭树幼苗，可自行选择种植位置。
- 家庭树使用固定 id `family_tree_unique`；移除后可以重新种植，但不会重复领取或生成多棵。
- 家庭树阶段由既有 `cross_member_interaction_count` 驱动，阈值为 `0 / 1 / 3 / 6 / 10`，分别显示 5 张透明像素素材。
- 有效互动仍沿用既有口径：回答者与上传者不同，且同一 `(memory_id, answerer)` 只计一次。
- 种植位置与赠礼状态进入 `MemoryManager` 本地存档；成长阶段由家庭互动量即时推导，不额外保存重复状态。
- 树根使用统一底部锚点，换阶段时只向上生长，不缩放游戏画面，也不改变 1280×720 可见范围。

---

## 6. 待拍板 / 下一步

- `ItemDef` / `CharacterDef` 用 Godot `Resource(.tres)` 还是 JSON(建议跟 `zones_*.json` 一致用 JSON,AI 也好生成)。
- 共享仓的并发裁决放云函数的哪个接口。
- 角色外观是否支持自定义(换装),还是固定 4 个角色。
- 昼夜是否驱动更多玩法(商店营业时间、夜间专属事件)。
