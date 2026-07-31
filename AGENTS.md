# AGENTS.md — AI 协作规则（Codex / Cline / CodeBuddy 通用）

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
8. 任何 service role key、腾讯云 SecretId/SecretKey、AI API key 一律不得写入仓库（见 .gitignore）；
9. **每次完成一个任务后，必须在回复结尾单独给出“推荐下一步”**：明确下一项最优先的动作、推荐原因，以及是否需要用户确认；如果确实没有必要的后续，也要明确说明“暂无必须后续”。

## 项目速览

- 引擎：Godot 4.7，工程在 `game/`（打开 `game/project.godot`）；
- 画布与美术规范：1280×720 逻辑画布 + soft pixel art 2x 显示，见 `docs/09_godot_coordinate_art_spec.md`（方案 C′）；
- AI 接口契约：`docs/04_ai_interfaces.md`（AI 不输出坐标；每个 AI 功能必须有 mock，mock 在 `backend/mocks/`）；
- 后端：Supabase（暂）+ 计划中的腾讯云 COS/CDN 与云函数，见 `docs/05_backend_data_model.md`；
- 分支模型：main（保护）/ dev（集成）/ feature/*，commit 格式见 `CONTRIBUTING.md`。

## 角色默认负责人（软边界，允许交叉救火，不作硬权限）

> **当前实际分工（2026-06）**：原 B+C（游戏系统 / 数据 / 后端 / **AI 模块端到端**）由
> **xiongweiluo 一人全权负责**——含游戏客户端调用 → Serverless 云函数 → 接混元 → 藏 Key →
> 拼 prompt → 校验 JSON → 内容安全，以及功能链路上的功能性 UI/动画；
> **两位搭档当前都在「场景设计 + 搭建」线**（`.tscn`、美术、Y-Sort、碰撞、场景内布局）。
> 详细边界与灰色地带见 `docs/dev/37_role_boundaries_and_grey_zones.md`。
> 下表为**初始规划模型**（A/B/C），保留作参考。

| 角色 | 职责 | 默认负责人 |
|---|---|---|
| A | 产品统筹 + 美术体验（docs/、game/assets/） | peilinpeng |
| B | AI 模块 + 内容安全（backend/ai/、backend/mocks/） | xiongweiluo（与 C 合并） |
| C | 游戏系统 + 后端稳定（game/scripts/、game/scenes/ 系统侧） | xiongweiluo |
| 场景 | 各场景设计 + 搭建（`.tscn`、美术、碰撞、布局） | 两位搭档（按 `docs/dev/36` 认领） |

详见 `docs/dev/30_task_breakdown.md`、`docs/dev/31_handoff_rules.md` 与
`docs/dev/37_role_boundaries_and_grey_zones.md`。
