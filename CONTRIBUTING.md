# CONTRIBUTING — 协作规范速查

完整规则见 `docs/dev/31_handoff_rules.md`（交接）与 `docs/dev/32_claude_collaboration_rules.md`（AI 工具）。

## 分支模型

| 分支 | 用途 | 规则 |
|---|---|---|
| `main` | 稳定可演示版本 | 保护分支：禁止 force push，仅 PR 合入（1 人 approve） |
| `dev` | 日常集成 | 功能分支合入处，保持随时可运行 |
| `feature/*` | 单模块开发 | 如 `feature/scene-fishpond`、`feature/ai-memory-card`、`feature/split-main` |

## Commit 格式

```text
feat(scene): add fishpond bottle interaction
fix(upload): show selected file name on mobile
docs(ai): add memory card json contract
art(garden): add memory flower assets
chore(repo): update gitignore
```

从 **2026-11-05** 起，所有分支上的新增 Git 提交统一使用**英文标题和英文正文**；正文如需说明动机与影响范围，也必须用英文。

- 适用于所有贡献者与 AI 工具，包括普通提交、merge commit、squash commit、revert commit 及工具自动生成的提交。
- PR 标题使用英文，避免合并时自动生成中文提交标题；PR 描述、日常沟通与项目文档仍可使用中文。
- 合并前检查最终提交标题与正文；若 GitHub 或其他工具自动带入中文 PR 描述、提交列表或旧提交说明，应改写为英文后再提交。
- 保留必要的代码标识符、路径、链接与署名；无需翻译这些标识信息。
- 本规则仅适用于后续新提交，不重写或强制推送历史提交。

## 模块默认负责人（软边界）

- A（产品+美术）：`docs/`、`game/assets/` — peilinpeng
- B（AI+内容安全）：`backend/ai/`、`backend/mocks/`
- C（游戏系统）：`game/scripts/`、`game/scenes/`

允许交叉救火；跨模块修改在 PR 描述中说明原因。`docs/04_ai_interfaces.md` 是三方接口契约，改动需全员知晓。

## 每日同步模板

```text
今天完成：
明天交付：
当前卡点：
需要谁配合：
是否影响主流程：
```

卡住超过半天必须立刻同步，不要等晚上。

## 红线

1. 不回退 main；2. 不删除已有可运行功能；3. 不为重构而重构；4. AI 功能必须有 mock/fallback；5. 密钥不进仓库；6. P0 美术资产必须经导入测试（manifest status 推进到 tested）；7. 7.08 后只修 bug 和包装。

## 提交前验收

日常修改运行：

```bash
./tools/test_all.sh
```

涉及 Web 发布范围、动态资源或导出配置时，还必须运行：

```bash
./tools/check_web_export.sh
```

GitHub Actions 的必需检查名为 `全量回归与 Web 导出`。功能分支合入 `dev`、`dev` 合入
`main` 前必须通过；真实云端烟测不在自动门禁内，仍按对应阶段验收文档人工执行。
