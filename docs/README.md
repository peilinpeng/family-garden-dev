# Family Garden 项目文档包

本文件夹用于支持 Family Garden 参赛版本的策划、场景、美术、AI、后端和三人协作开发。

## 推荐阅读顺序

### 全员先读
1. `docs/00_project_overview.md`：项目总定位与核心闭环
2. `docs/01_development_scope.md`：开发边界、优先级与不做事项
3. `docs/02_scene_index.md`：场景结构总览
4. `docs/dev/31_handoff_rules.md`：三人线上协作与交接规则

### 美术/体验负责人重点读
- `docs/03_art_asset_pipeline.md`
- `docs/scenes/*.md`
- `docs/ui/*.md`
- `docs/dev/30_task_breakdown.md`

### AI 模块负责人重点读
- `docs/04_ai_interfaces.md`
- `docs/scenes/*.md` 中的“AI 数据映射”部分
- `docs/dev/32_claude_collaboration_rules.md`

### 游戏系统/后端负责人重点读
- `docs/05_backend_data_model.md`
- `docs/06_mobile_web_adaptation.md`
- `docs/scenes/*.md`
- `docs/dev/31_handoff_rules.md`

## 使用方式

每次使用 Claude / Cline / CodeBuddy 开发时，不要一次性读取所有文档。建议按任务读取：

例如开发鱼塘场景：

```text
请读取：
1. docs/00_project_overview.md
2. docs/03_art_asset_pipeline.md
3. docs/scenes/11_scene_fishpond.md
4. docs/ui/21_ui_bottle_panel.md

任务：实现爸爸鱼塘场景的最小可运行版本。
要求：先用 mock 数据，不要改无关场景，不要重构全局架构。
```

## 项目一句话

Family Garden 是一个 AI 驱动的数字家庭第三空间，通过可生长的记忆景观帮助家庭保存故事、促进代际交流。
