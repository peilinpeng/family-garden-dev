# Family Garden（源码仓库）

Family Garden 是一个 AI 驱动的数字家庭第三空间：用户上传家庭照片、留言、明信片、房间照片，AI 帮助整理成记忆卡片并提出温和的问题，家庭成员补充回答后，记忆在虚拟花园、鱼塘、农场、个人房间、老街等场景中变成可点击、会生长的节点。

> 让家庭记忆长成花园。

- 在线演示（MVP，Web 导出版）：https://peilinpeng.github.io/FamilyGarden/
- 导出产物仓库（仅部署用，勿提交源码）：`peilinpeng/FamilyGarden`
- 比赛：腾讯云 AI 游戏比赛，提交截止 2026-07-15

## 仓库结构

```text
game/      Godot 4.6 工程（打开 game/project.godot）
docs/      全部策划/规范/场景/协作文档（从 00_project_overview.md 开始读）
backend/   supabase/ 数据库 schema；ai/ 云函数与 prompt；mocks/ AI mock JSON
tools/     导出与资产处理脚本
```

## 如何运行

1. 安装 [Godot 4.6](https://godotengine.org/)；
2. Godot → Import → 选择 `game/project.godot` → 运行；
3. 桌面控制：WASD/方向键移动，鼠标点击交互（完整说明见 `game/README.md`）。

## 如何导出 Web 版

1. Godot → Project → Export → Web 预设（已配置：Compatibility 渲染、Thread Support 关闭）；
2. 导出路径为仓库根 `export_web/`（已被 gitignore）；
3. 本地测试：`cd export_web && python3 -m http.server 8000`；
4. 部署：将 `export_web/` 内容推送到 `peilinpeng/FamilyGarden` 仓库（GitHub Pages），后续将迁移至腾讯云 COS+CDN。

## 协作

- 分支：`main`（稳定，保护）/ `dev`（集成）/ `feature/*`（按模块）；
- 规范：见 `CONTRIBUTING.md` 与 `docs/dev/31_handoff_rules.md`；
- AI coding 工具规则：见根目录 `CLAUDE.md`。

## 已知问题与说明

1. **Supabase anon key 硬编码**于 `game/scripts/cloud_service.gd` 且已随公开 Web 版发布；配套 RLS 仅按固定 `family_id` 隔离。比赛期间可接受，正式对外前需更换不可猜测的 family_id 并收紧策略。**严禁**将 service role key、腾讯云 SecretId/SecretKey、AI API key 提交进仓库。
2. **当前美术为占位资产**：仓库中的房间图等大图已压缩至最长边 1600px，仅为 MVP 仓库轻量化，**不代表最终美术规格**；正式资产将按 `docs/09_godot_coordinate_art_spec.md` 的 soft pixel art / 1280×720 规范重新生产（原图备份在仓库外 `_archive/`）。
3. 源码与导出产物分离：本仓库为私有源码仓库；`peilinpeng/FamilyGarden` 仅存放 Web 导出产物。
