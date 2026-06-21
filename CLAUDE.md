# CLAUDE.md — AI 协作规则（Claude / Cline / CodeBuddy 通用）

本文件对所有在本仓库工作的 AI coding 工具生效。详细协作规范见 `docs/dev/32_claude_collaboration_rules.md`。

## 语言

- 工作语言、解释语言、文档语言、commit 说明正文：**中文**；
- 代码文件名、变量名、类名、函数名、JSON 字段、Godot API：英文。

## 修改纪律

1. 每次修改前**先列出计划**（要改哪些文件、为什么、风险），等确认后再动手；任务非常小且明确时可直接做；
2. **不要回退 main**；
3. **不要删除已有功能**；
4. **不要大规模重构**（包括"为了更优雅"推倒重来；main.gd 拆分等结构调整必须走独立分支与 PR）;
5. **不要跨任务修改无关模块**；确需跨模块修改时，必须说明原因；
6. 修改完成后必须输出：修改文件清单、影响范围、验收步骤；
7. **不确定时先问，不要编造**（API 用法、平台兼容性、密钥配置等尤其如此）；
8. 任何 service role key、腾讯云 SecretId/SecretKey、AI API key 一律不得写入仓库（见 .gitignore）。

## 项目速览

- 引擎：Godot 4.7，工程在 `game/`（打开 `game/project.godot`）；
- 画布与美术规范：1280×720 逻辑画布 + soft pixel art 2x 显示，见 `docs/09_godot_coordinate_art_spec.md`（方案 C′）；
- AI 接口契约：`docs/04_ai_interfaces.md`（AI 不输出坐标；每个 AI 功能必须有 mock，mock 在 `backend/mocks/`）；
- 后端：Supabase（暂）+ 计划中的腾讯云 COS/CDN 与云函数，见 `docs/05_backend_data_model.md`；
- 分支模型：main（保护）/ dev（集成）/ feature/*，commit 格式见 `CONTRIBUTING.md`。

## 角色默认负责人（软边界，允许交叉救火，不作硬权限）

| 角色 | 职责 | 默认负责人 |
|---|---|---|
| A | 产品统筹 + 美术体验（docs/、game/assets/） | peilinpeng |
| B | AI 模块 + 内容安全（backend/ai/、backend/mocks/） | 待定 |
| C | 游戏系统 + 后端稳定（game/scripts/、game/scenes/） | 待定 |

详见 `docs/dev/30_task_breakdown.md` 与 `docs/dev/31_handoff_rules.md`。
