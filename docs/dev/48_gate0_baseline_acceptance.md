# 48｜Gate 0 仓库与运行基线验收

> 验收日期：2026-07-05
> 验收分支：`feature/garden-mvp-loop`
> 基线提交：`b86edfb`
> 引擎：Godot `4.7.stable.official.5b4e0cb0f`
> 结论：**Gate 0 本机运行基线通过，可进入 Gate 1**

---

## 1. 仓库基线

- 当前位于 `feature/garden-mvp-loop`，不是 detached HEAD；
- `b86edfb` 位于远端 `origin/feature/garden-mvp-loop` 的 `d67d8d3` 之上，本地领先 1 个提交；
- `git fsck --full --no-reflogs --unreachable` 未报告缺失或损坏对象；输出的 unreachable 对象是历史强制更新后仍留在本地对象库中的不可达历史，不影响当前分支；
- `AGENTS.md` 按约定保留在本地，不纳入提交；
- `docs/dev/47_system_ai_backend_iteration_plan.md` 是本轮正式计划文档，应纳入后续文档提交；
- `game/assets/characters/garden_tile/garden.png.import` 格式有效，Godot 导入和 Web 导出均实际使用；仓库已有 394 个受版本控制的 `.import` 文件，因此该文件应随原图纳入后续提交；
- `export_web/` 已由 `.gitignore` 排除，不纳入版本控制。

本轮没有执行提交、推送、force-push 或历史改写。

## 2. Godot 导入与运行结果

### 2.1 工程导入

执行 Godot 4.7 无界面编辑器导入，结果：

- 工程文件系统扫描完成；
- autoload 脚本加载完成；
- 无 GDScript 解析错误；
- 无资源缺失错误；
- 无阻断性编辑器错误。

### 2.2 主工程运行

主场景连续运行 10 秒：

- `Main.tscn` 与主要 autoload 正常加载；
- 未出现脚本崩溃或场景加载失败；
- CloudBase 在测试环境不可达时产生 `status: 0` 警告，程序仍继续进入角色选择/花园，属于可恢复离线告警。

### 2.3 核心场景冒烟

以下场景均使用 Godot 4.7 独立启动 30 帧，无解析错误、资源缺失或启动崩溃：

| 功能 | 场景 | 结果 | 验证范围 |
|---|---|---|---|
| 主入口/花园 | `scenes/Main.tscn` | 通过 | 角色选择首屏、花园首屏、底栏导航 |
| 鱼塘 | `scenes/Fishpond.tscn` | 通过 | 场景实例化与脚本启动 |
| 农场 | `scenes/Farm.tscn` | 通过 | 场景实例化、农场脚本与背包 UI 启动 |
| 房间 | `scenes/rooms/AnnaRoom.tscn` | 通过 | 场景实例化与资源加载 |
| 厨房 | `scenes/Kitchen.tscn` | 通过 | 场景实例化与资源加载 |
| 背包 | `scenes/InventoryUI.tscn` | 通过 | UI 实例化与脚本启动；完整交互入口位于农场 |

Web 版实际验证了：角色选择首屏关闭、花园显示、花园 → 世界地图、世界地图 → 花园、记忆树面板、明信片面板及面板关闭。角色“选择”会创建真实云身份，本轮为避免向线上写入测试数据，没有点击最终选择按钮；该链路沿用此前真实环境验证结果。

## 3. Web Release 导出

使用现有 `Web` preset 成功执行 Release 导出：

| 产物 | 大小 |
|---|---:|
| `index.html` | 5,452 B |
| `index.js` | 279,815 B |
| `index.wasm` | 39,509,339 B |
| `index.pck` | 50,449,956 B |

运行条件与结果：

- 本地地址：`http://127.0.0.1:8765/`；
- 视口：1280×720；
- 页面标题：`Family Garden MVP v2`；
- WebAssembly、PCK、纹理、主场景均成功加载；
- Compatibility 渲染启用，Web 线程支持关闭；
- 浏览器无资源 404、WASM 初始化失败或脚本崩溃；
- CloudBase 请求在本地浏览器环境返回 `Failed to fetch`，客户端按当前逻辑继续运行。

导出产物仅用于本地验收，位于被忽略的 `export_web/`。

## 4. 功能状态矩阵

| 功能链路 | 当前状态 | 说明 |
|---|---|---|
| 角色选择与玩家身份 | 真实接入 | 选角色会通过 CloudBase 自助加入；本轮只验证选择首屏，未写入线上测试身份 |
| 花园、地图、记忆树、明信片导航 | 真实可用 | Web 版已实际点击验证 |
| 花园记忆花/记忆卡片/成长 | mock-first | 本地数据链路存在，卡片内容由 `AIClient` mock 提供 |
| 鱼塘漂流瓶回答与岸边记忆 | mock-first | 场景和交互链路存在，问题仍来自 mock |
| 房间分析与家具布局 | mock-first/占位输入 | 布局与持久化链路存在；真实选图、上传和 AI backend 未接入 |
| 跨记忆关联 | mock | 使用 `AIClient.mock_link()` |
| 四项 AI 接口 | mock + fallback 骨架 | `AIClient` 已统一入口，但未注入真实 HTTP backend |
| CloudBase 身份与业务数据 | 真实接入 | 本地不可达时保留本地运行能力；本轮未做线上写入 |
| 背包/共享仓 | 真实数据模型 | 农场内有 UI；共享仓并发裁决仍未完成 |
| 实时多人 | 未完整接入 | 当前以冷同步和远端玩家骨架为主 |
| 室内语义场景生成 | 未接入 | 只有架构交接，生成器本体尚未实现 |

## 5. 已知问题

### P0

无。未发现阻止工程导入、核心场景启动或 Web 导出的错误。

### P1

1. **Web 中文乱码**：花园标题旁的一段中文提示显示为方框/乱码。英文界面正常，疑似 Web 导出缺少覆盖对应汉字的字体或文本编码来源异常。进入 Gate 1 前可独立定位，不阻断当前运行基线。
2. **本地 CloudBase 请求噪声**：无网络/CORS 不满足时，每个冷同步请求都会记录 `Failed to fetch` 与 `status: 0`。功能可继续，但应在后续统一错误状态机中合并、降噪并给出用户可理解的离线提示。

### P2

1. 背包 UI 目前只实例化在农场，不是所有场景的全局入口；是否需要全局化应作为产品/UI 决策，不在 Gate 0 擅自调整。
2. `git fsck` 可见强制更新留下的不可达历史；当前分支无对象损坏，但团队仍应遵守不 force-push 集成分支的约定。
3. 真机手机横屏、触摸热区、微信内置浏览器未在本机桌面浏览器验收中覆盖，进入发布验收时必须补测。

## 6. 复现与验收步骤

```bash
/Applications/Godot.app/Contents/MacOS/Godot --version
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path game --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --quit-after 30 res://scenes/Main.tscn
mkdir -p export_web
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --export-release Web ../export_web/index.html
python3 -m http.server 8765 --directory export_web
```

浏览器打开 `http://127.0.0.1:8765/`，检查：

1. 角色选择首屏出现；
2. 关闭选择面板后花园完整显示；
3. 点击 Map，世界地图出现；
4. 点击 World，返回花园；
5. 打开 Tree 与 Postcards 面板并正常关闭；
6. 控制台除已记录的 CloudBase 离线告警外，无新增崩溃或资源错误。

## 7. Gate 0 结论

本机仓库、Godot 4.7 导入、核心场景加载和 Web Release 导出均已形成可复现基线。两个 P1 问题均非阻断项，后续可从 Gate 1 的契约定稿继续推进。团队层面的“不 force-push、各自在独立分支开发”属于持续协作纪律，由全员共同确认和遵守。
