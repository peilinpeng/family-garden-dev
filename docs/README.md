# Family Garden 项目文档包

本文件夹用于支持 Family Garden 的策划、场景、美术、AI、后端和开发验收。当前全部工作由 xiongweiluo 负责；历史三人分工仅供追溯。

## 当前优化迭代

- [70 全项目优化迭代计划](dev/70_project_optimization_iteration_plan.md)：O0—O8 路线与验收标准。
- [71 优化执行台账](dev/71_optimization_execution_status.md)：单人负责制、任务进度、阻塞与实际证据。
- [72 家庭身份与迁移设计](dev/72_family_identity_and_migration_design.md)：权限矩阵、邀请契约、恢复与迁移顺序（草案，未上线）。

## 推荐阅读顺序

### 比赛验收与提交

- `docs/submission/README.md`：最终交付包导航；
- `docs/07_demo_script.md`：3—5 分钟主演示脚本；
- `docs/submission/06_final_qa_report.md`：最终自动化与人工验收结论。

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
