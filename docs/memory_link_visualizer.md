# 记忆连接可视化系统交接说明

## 工程路径

- Godot 工程：`C:/Users/l/Documents/游戏素材/family-garden-dev/game/project.godot`
- 花园场景控制：`game/scripts/managers/scene_manager.gd`
- 记忆数据管理：`game/scripts/managers/memory_manager.gd`

## 现有记忆节点结构

- `MemoryManager.memories` 保存记忆本体，字段里有 `id`、`ai_card`、`user_id` 等。
- `MemoryManager.nodes` 保存场景节点。普通记忆花使用 `node_type = "memory_flower"`，并通过 `slot_id` 落到花园槽位。
- 花园进入时，`SceneManager._spawn_demo_memory_nodes()` 调用 `_render_scene_nodes("garden", ...)`，再由 `NodeFactory.make_memory_node()` 创建可点击的花朵节点。
- 旧的关系数据也存在 `MemoryManager.nodes` 里，`node_type = "memory_link"`，旧字段为 `memory_id` 和 `linked_memory_id`。

## 新增脚本与配置

- `game/scripts/memory_links/memory_link_visualizer.gd`
  - 关系可视化根节点。
  - 管理 `MemoryLinkRoot/LinkInstances/LinkParticles/DebugLayer`。
  - 接收记忆节点映射和 link 数据，负责重建所有连接实例。
- `game/scripts/memory_links/memory_link_instance.gd`
  - 单条连接的表现。
  - 生成自然曲线、淡点线和昼夜序列帧动态载体。
- `game/assets/memory_links/link_butterfly_day.png`
  - 白天使用的 8 帧蝴蝶透明序列图。
- `game/assets/memory_links/link_bee_night.png`
  - 夜晚使用的 8 帧发光蜜蜂透明序列图。
- `game/scripts/memory_links/memory_link_path.gd`
  - 曲线路径生成和采样工具。
- `game/assets/memory_links/memory_link_config.json`
  - 默认日间样式、夜间样式、强度配置、调试快捷键说明。

## Link 数据结构

新 link 兼容旧字段，并补充以下字段：

```gdscript
{
	"source_memory_id": "mem_a",
	"target_memory_id": "mem_b",
	"relation_strength": 0.58,
	"active_time_mode": "both",
	"visual_style": "butterfly",
	"visible_when": "always",
	"curve_points": []
}
```

旧存档只有 `memory_id / linked_memory_id` 时，`MemoryLinkVisualizer` 会自动转换为 `source_memory_id / target_memory_id`。

## 昼夜切换

- 系统会读取 `/root/GameClock.phase()`。
- `phase() == "night"` 时，连接载体自动切换为发光蜜蜂。
- 非夜晚时统一使用蝴蝶。
- 如果未来没有 `GameClock`，可以直接调用：

```gdscript
memory_link_visualizer.call("set_time_mode", "day")
memory_link_visualizer.call("set_time_mode", "night")
```

## 交互逻辑

- 默认不再显示大号 `Link` 文本。
- 默认不再显示粗实线，只显示轻量动态载体。
- 点击记忆花时，`SceneManager._on_memory_clicked()` 会调用：

```gdscript
memory_link_visualizer.call("set_selected_memory", memory_id)
```

- 被选中记忆相关的连接会增强淡点线，并轻微高亮两端花朵。
- 关闭面板时会清空选中状态。

## Debug 模式

- `F10`：切换 debug 模式。
- `F9`：切换关系查看模式。
- Debug 模式会显示路径、source/target、样式和强度。
- 正式模式不显示调试文字。

## 新增一条记忆连接

推荐继续走 `MemoryManager.create_memory_link()`：

```gdscript
MemoryManager.create_memory_link(
	source_memory_id,
	target_memory_id,
	"garden",
	"same_place",
	"这两段记忆都和池塘边的下午有关吗？"
)
```

连接强度和显示规则仍可在返回的字典或存档数据中覆盖：

```gdscript
link["relation_strength"] = 0.86
link["active_time_mode"] = "both"
link["visible_when"] = "always"
```

## 已知问题

- 当前路径锚点使用记忆花节点上方的估算位置，花朵素材高度差异特别大时，可能需要给记忆节点增加精确 `link_anchor`。
- 已用本机 Godot 4.6.3 完成素材导入、脚本解析、主场景短时启动和 Link 载体实例化冒烟测试。

## 后续扩展

- 给记忆节点 prefab 增加 `LinkAnchor` 子节点，让曲线连接点更精准。
- 为强关系增加更细的花粉粒子，但默认保持低密度。
- 将 `visible_when = "nearby"` 接入玩家距离判断，远处关系降低更新频率。
