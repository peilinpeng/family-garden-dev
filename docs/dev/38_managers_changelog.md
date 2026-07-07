# 38｜公共 managers 变更日志（`game/scripts/managers/`）

> 改公共资产要在群里同步 + 在此记一行（见 `docs/dev/36` §1.3、`docs/dev/37` §3）。
> 格式：`日期  负责人  一句话说明`。新的记在最上面。

## 变更日志

- 2026-06-28  C  family-portrait 上木牌：`MemoryManager` 加 `family_portrait` 状态 +
  `maybe_recompute_family_portrait`（新成员首次参与 / 记忆数翻倍 2→4→8→16 时 +version）+
  `participants`；`SceneManager` 渲染入口木牌（占位，挂载点 (645,200) 待校准）。
- 2026-06-28  C  memory_link 连线渲染：`MemoryManager` 加 `create_memory_link` / `get_memory_links`；
  `SceneManager` 画拱形连线 + 可点关联问题（mock 来源，阶段2 换 cross-memory-link 真调用）。
- 2026-06-28  C  分季背景：`MemoryManager` 加 `cross_member_interaction_count`（跨成员回答计数，
  回答者≠上传者且去重）+ `garden_season`（0→春/3-9→夏/10+→秋）；`SceneManager` 加季节氛围
  叠加层（占位，待 A 分季层定稿替换）。
- 2026-06-28  C  房间生成 mock 管线：新增 autoload **`ZoneManager`**（读 zones_room.json 按 zone
  分落点）+ **`RoomLayoutManager`**（generate 落库 / render 重建家具）；`MemoryManager` 加
  rooms/room_objects 数据层；`NodeFactory` 加 `make_room_object`；`SceneManager` 加上传房间图
  入口 + 渲染。`zones_room.json` 仍为 draft，待房间背景定稿后 A+C 校准 zone 坐标。
- 2026-06-28  C  数据层接进花园/鱼塘：记忆花、漂流瓶回答经 `MemoryManager` 落库并持久化
  （关游戏重开仍在）——Gate 1 最小线达成。
- 2026-06-28  C  `NodeFactory` 缺图回退改程序化占位（不再用不存在的 flower.png，真美术到位
  自动生效）；`MemoryManager.get_node` 改名 `get_node_by_id`（避免覆盖 Node 原生方法，
  Godot 4.7 报错）；`SlotManager` 加 `occupy` / `get_slot`；存档 JSON 扩展新字段（向后兼容）。

## 受影响的对外约定（teammates 需知）

- **新增 2 个 autoload**（`project.godot` 已注册）：`ZoneManager` / `RoomLayoutManager`。
- **存档格式扩展**：`user://family_garden_save_v2.json` 加了 rooms / room_objects /
  cross_member_interaction_count / family_portrait / memory_link 节点等键；旧档可正常加载（缺键取默认）。
- **mock 来源**：房间 / 连线 / 分季 / 画像目前都是**内联 mock 常量**，阶段2 接 B 的真 AI
  （cross-memory-link、analyze-room-photo）时只改对应单点。
