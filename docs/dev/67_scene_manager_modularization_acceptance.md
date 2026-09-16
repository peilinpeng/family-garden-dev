# 67｜SceneManager 模块化拆分验收

日期：2026-09-16  
分支：`codex/scene-manager-modularization`

## 1. 目标与约束

原 `game/scripts/managers/scene_manager.gd` 共 7,225 行、294 个函数，同时承担场景路由、
运行时建场、记忆、钓鱼、房间、旅行、聊天和通用 UI。仓库中存在大量对
`SceneManager` 字段、常量和下划线方法的直接调用，因此本次采用兼容门面迁移：

- `SceneManager` 继续是唯一同名 autoload；
- 原有字段、常量和方法签名继续由门面公开；
- 内部模块作为 `SceneManager` 子节点存在，不新增 autoload；
- 只移动实现，不修改玩法、存档、云端、AI 契约、资产或发布配置。

## 2. 模块边界

| 模块 | 职责 |
|---|---|
| `scene_ui_controller.gd` | 基础 UI、角色创建、通用面板与样式 |
| `world_chat_controller.gd` | 世界聊天预览、发送与历史面板 |
| `garden_scene_controller.gd` | 花园引导、场景构建、角色、动物与种植 |
| `memory_scene_controller.gd` | 记忆节点、关系连线、档案与记忆卡 |
| `scene_navigation_controller.gd` | 全局地图、场景路由与传送 |
| `fishpond_scene_controller.gd` | 鱼塘、钓鱼与漂流瓶 |
| `room_scene_controller.gd` | 房间构建、AI 房间草稿与物件编辑 |
| `travel_scene_controller.gd` | 旅行地图、照片、记忆草稿与明信片详情 |
| `family_social_controller.gd` | 留言板、家庭成员、信箱与 NPC 对话 |
| `scene_runtime_module.gd` | 内部模块共享状态代理；不承载业务实现 |

`scene_manager.gd` 只保留生命周期、云同步、自动保存、内部模块装配以及兼容转发。

## 3. 兼容策略

外部脚本仍调用 `SceneManager.goto_scene()`、`SceneManager._show_toast()` 等原入口。
门面把调用转交给对应模块。内部模块通过基类访问同一份共享状态，避免复制
`world`、`player`、`active_modal`、照片缓存等可变数据。

新增功能应直接进入对应模块；除生命周期、模块装配或必须保持兼容的转发外，不再把业务实现
写回 `scene_manager.gd`。新增独立场景仍遵守 `.tscn` 优先原则。

## 4. 自动验收

`scene_manager_modularity_test.tscn` 检查：

1. 关键公开方法、常量和状态仍存在；
2. 九个内部模块均由 `SceneManager` 持有且没有注册为额外 autoload；
3. 门面不超过 1,800 行，单个职责模块不超过 1,500 行。

本地统一回归使用：

```bash
./tools/test_all.sh
```

Web 导出仍使用现有发布检查脚本，不调用真实 AI、CloudBase 或收费接口。

2026-09-16 验收结果：

- `scene_manager.gd`：1,645 行；
- 九个职责模块：285–1,416 行；
- 统一回归：26/26 通过；
- Web Release 导出审计通过，PCK 为 116,784,868 bytes；
- 动态资源、生产引用边界与导出包启动检查通过。

## 5. 回滚边界

本次没有迁移数据或修改远端状态。若合并后出现结构性回归，可整体回滚本 PR；不要只恢复旧
`scene_manager.gd` 而保留内部模块，也不要把本 PR 与玩法提交混合回滚。
