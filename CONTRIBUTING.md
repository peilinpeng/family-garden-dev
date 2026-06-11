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

正文用中文说明动机与影响范围。

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
