# game/assets/manifest — 资产/槽位/入口对账单

本目录是**三方唯一对账单**，由 NodeFactory / SlotManager / RoomLayoutManager / ScenePortal
在运行时读取。字段与坐标规范以 `docs/09_godot_coordinate_art_spec.md` 为准（§6 manifest、
§7 slot、§8 房间 zone、§14 portal/spawn）。

> ⚠️ 本目录当前为**阶段 0 骨架（draft）**：坐标多为占位值，需在对应**场景背景定稿后由
> A+C 核对一次并冻结**（docs/09 §7.7、§8.2）。每个 JSON 顶部的 `_status` 标明是否已冻结。

## 文件清单

| 文件 | 维护人 | 说明 |
|---|---|---|
| `asset_manifest.json` | A 填物理属性 / C 填引擎属性 | 全部资产的统一对账单（§6） |
| `slots_{scene}.json` | C（背景定稿时 A+C 核对） | 各场景动态节点的槽位坐标（§7） |
| `portals_{scene}.json` | C | 各场景的入口 Area2D + 出生点（§14） |
| `zones_room.json` | A+C 校准冻结 | AI 房间生成的 zone 矩形（§8.2） |

## 关键约束（务必遵守）

- **AI 不输出坐标**：`slot_id` / `pos` / zone 矩形由游戏系统决定；AI 只产出
  `suggested_scene` / `node_type` / `object_type` / `zone`（建议值）。
- 槽位坐标 = 节点落点（bottom_center），1280×720 逻辑坐标，**偶数且对齐 16px**。
- `click_rect` 最小 80×80 逻辑像素（手机触控下限）。
- 一个 slot 同时只被一个节点占用（对应 `nodes.slot_id` 唯一）；满了走 `overflow` 组入队。
- `footprint` 一律由 manifest 按 `object_type` 查表，AI 输出里的坐标/尺寸/footprint 一律忽略。

## 当前覆盖范围（P0 三场景）

- 花园 garden：`slots_garden.json` + `portals_garden.json`
- 鱼塘 fishpond：`slots_fishpond.json` + `portals_fishpond.json`
- AI 房间 room：`zones_room.json`（房间用 zone 内 slot，见 §8）

农场 / 老街 / 旅行区域为 P1，待 P0 跑通后补 `slots_*` / `portals_*`。

## 待 docs/09 同步的小扩展

- `asset_manifest.json` 中房间物件条目使用了 `default_zone` 字段（RoomLayoutManager 在
  AI 未给/给非法 zone 时的兜底，见 §8.1 第 4 点）。该字段 §6 表暂未列出，已在此使用，
  待 docs/09 §6 补登（按 Part 0.2 流程同步）。
