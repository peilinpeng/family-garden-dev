# 68｜Web PCK 余量恢复验收

日期：2026-09-17  
分支：`codex/web-pck-headroom`

## 1. 背景

SceneManager 模块化合并后的 Web Release PCK 为 116,784,868 bytes，距离项目内部
117,000,000 bytes 门禁只剩 215,132 bytes。平台硬门槛为 130,000,000 bytes，继续增加一次
普通资源就可能让发布门禁失败。

包体扫描显示 `game/assets/characters/hair_colors/` 包含 80 张非棕发色图集，对应 Godot 导入
资源共 45,490,676 bytes。当前产品状态满足以下条件：

- 角色编辑 UI 已隐藏发色入口；
- `hair_color` 仍按原值保存在存档中，保证未来恢复兼容；
- `AppearanceManager` 渲染时固定选择自然棕完整图集；
- 现有外观回归明确要求非棕发色存档也不能加载 `hair_colors/` 图集。

因此本轮只把该目录排除出 Web Release，不删除源码素材，也不修改存档结构。

## 2. 变更边界

- `game/export_presets.cfg`：Web preset 排除隐藏发色图集；
- `game/scripts/managers/appearance_manager.gd`：用
  `RENDERED_HAIR_COLOR_ID` 明确当前固定渲染色；
- `game/tests/appearance_system_test.gd`：遍历角色、发型、服装与全部历史发色值，禁止解析到
  Web 已排除目录；
- `tools/check_web_export.sh`：确认隐藏发色不进入 PCK，同时确认服装、父母和家庭角色代表图集
  仍存在。

未删除或改写任何 PNG；原生工程仍可访问全部发色素材。

## 3. 实测结果

同一台 macOS arm64 设备、Godot 4.7 stable、Web Release preset：

| 指标 | 优化前 | 优化后 | 变化 |
|---|---:|---:|---:|
| `index.pck` | 116,784,868 bytes | 71,251,232 bytes | -45,533,636 bytes（-38.99%） |
| 117 MB 内部门禁余量 | 215,132 bytes | 45,748,768 bytes | +45,533,636 bytes |
| 130 MB 平台余量 | 13,215,132 bytes | 58,748,768 bytes | +45,533,636 bytes |
| 平台余量比例 | 10.17% | 45.19% | +35.03 个百分点 |
| `index.wasm` | 39,509,339 bytes | 39,509,339 bytes | 不变 |
| 核心四文件合计 | 156,584,880 bytes | 111,051,243 bytes | -45,533,637 bytes |

验收结果：

- `./tools/test_all.sh`：26/26 通过；
- `./tools/check_web_export.sh`：通过；
- `./tools/build_web_release.sh`：通过，PCK/WASM 共生成 6 个分片；
- Chromium 关键路径 E2E：2/2 通过；
- 导出包挂载及主场景启动无脚本或资源错误；
- 动态资源、生产引用和排除边界检查通过；
- 服装、父母、家庭角色正式图集继续进入 Web 包；
- 80 张隐藏发色素材仍完整保留在仓库。

## 4. 恢复发色功能的前置条件

未来重新开放发色入口时，必须在同一 PR 中完成：

1. 移除 Web preset 的 `hair_colors` 排除规则；
2. 让 `AppearanceManager` 按经过验收的发色选择图集；
3. 更新外观回归与 Web 必需资源检查；
4. 重新执行全量回归、Web 导出、浏览器 E2E 和移动端外观验收；
5. 确认恢复后的 PCK 仍低于平台门槛并保留合理余量。

只改 UI 或只改运行时解析都不构成完整恢复。
