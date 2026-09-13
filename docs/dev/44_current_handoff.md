# 44｜当前工程交接入口

> 更新日期：2026-09-13
>
> 当前工作分支：`feature/dependency-handoff-refresh`
>
> 分支基线：`origin/dev@cad0412`
>
> 最新集成分支：`origin/dev@cad0412`
>
> 状态：本地候选版本健康，CloudBase 公开入口已恢复；AI 依赖修复尚未提交和部署

## 1. 当前结论

Family Garden 已完成比赛候选版本的主要产品闭环、家庭云同步、照片隐私、Web 导出、CI 和
生产可观测性。本机 2026-09-13 重新执行统一回归，25/25 个执行单元通过；同日执行公开生产
只读核验，Web 静态资源、PCK Range、构建哈希和 Presence 健康检查全部通过。

当前阶段不再把 2026-06 的池塘专项交接当作全项目状态。历史池塘实现可继续参考：

- [`37_fishpond_asset_integration.md`](37_fishpond_asset_integration.md)；
- [`../handoff_garden_build_inventory_fishing_2026-07-13.md`](../handoff_garden_build_inventory_fishing_2026-07-13.md)；
- [`../handoff_garden_ui_fishpond_followup_2026-07-15.md`](../handoff_garden_ui_fishpond_followup_2026-07-15.md)。

## 2. 分支与工作树

### 2.1 版本基线

| 项目 | 当前状态 | 说明 |
|---|---|---|
| 当前分支 | `feature/dependency-handoff-refresh` | 从 `origin/dev@cad0412` 创建，承载本次依赖与交接更新 |
| 最新集成分支 | `origin/dev@cad0412` | 2026-08-27 完成 M4 CLS 日志验收闭环 |
| 当前分支与 `origin/dev` | 基线一致 | 当前仅包含本次两个待提交修改 |
| `main` | `bb681b6` | 明显落后，不作为当前功能或发布基线，也不得回退开发 |

### 2.2 当前本地待处理内容

- `backend/ai/package-lock.json`：`fast-uri` 已从 `3.1.4` 更新到 `3.1.7`，尚未提交、尚未部署；
- 本文档：更新全项目交接入口；
- `docs/dev/59_full_project_handoff.md`、`docs/submission/posters/`、`tmp/` 仍为未跟踪内容，
  提交前必须逐项确认，禁止直接 `git add -A`。

任何接手者开始工作前先执行：

```bash
git status --short --branch
git log -1 --oneline
git diff --check
```

## 3. 已完成能力

### 3.1 产品与玩法

- 三章主线和主线结束后的开放成长目标；
- 家庭花园、池塘、共享农场、厨房、旅行地图和语义房间；
- 记忆卡、记忆花、跨记忆藤蔓、漂流瓶问题和家庭补写；
- 钓鱼、种植、浇水、施肥、收获、畜牧和共享仓事务；
- 家庭角色创建、外观、昼夜、关怀模式和 Web 音频解锁；
- 空存档演示种子和 AI 技术故障 fallback。

### 3.2 AI、云端与隐私

- AI Gateway 五项路由、JSON Schema 校验、错误分类、缓存、取消和受控 fallback；
- 用户确认内容二次审核，图片通过私有上传 ID 与临时签名 URL 使用；
- Data Gateway 负责身份、家庭隔离、CRUD、照片、共享仓和农场权威事务；
- Presence Relay 负责同家庭在线、移动和 `world_changed` 通知；
- 服务端请求 ID、脱敏结构化日志和 CLS 按请求 ID 检索。

### 3.3 M0—M4 质量阶段

| 阶段 | 状态 | 验收记录 |
|---|---|---|
| M0 本地质量基线 | 已完成 | [`60_m0_quality_baseline.md`](60_m0_quality_baseline.md) |
| M1 照片隐私 | 已完成并部署验收 | [`61_m1_photo_privacy_acceptance.md`](61_m1_photo_privacy_acceptance.md) |
| M2 Web 包瘦身 | 已完成 | [`62_m2_web_export_optimization.md`](62_m2_web_export_optimization.md) |
| M3 CI 质量门禁 | 已完成 | [`63_m3_ci_quality_gate.md`](63_m3_ci_quality_gate.md) |
| P1 审查阻断修复 | 已完成并部署验收 | [`64_p1_review_blockers_resolution.md`](64_p1_review_blockers_resolution.md) |
| M4 可观测性与运维 | 已完成并部署验收 | [`65_m4_observability_release_operations.md`](65_m4_observability_release_operations.md) |

## 4. 2026-09-13 验证状态

### 4.1 本地全量回归

执行：

```bash
./tools/test_all.sh
```

结果：25/25 通过，0 失败，总耗时 28 秒。其中包括 21 个 Godot 场景测试，以及 AI Gateway、
AI JSON Schema、Data Gateway 和 Presence Relay 四个后端/契约执行单元。

### 4.2 Web Release

执行：

```bash
./tools/check_web_export.sh
```

结果：导出、动态资源、生产引用边界和导出包启动检查通过。

| 文件 | 当前大小 |
|---|---:|
| `index.pck` | 128,211,128 bytes |
| PCK 门禁 | 130,000,000 bytes |
| 剩余余量 | 1,788,872 bytes（约 1.79 MB） |
| `index.wasm` | 39,509,339 bytes |
| 核心四文件合计 | 168,010,160 bytes |

PCK 当前通过门禁，但已使用 98.62% 的内部预算。新增大资源前必须重新导出验证，不能只根据
仓库文件大小估算。

### 4.3 CloudBase 恢复核验

CloudBase 曾返回 `SERVICE_FORBIDDEN / Your server is isolated`。负责人恢复服务后，于
2026-09-13 重新执行：

```bash
./tools/verify_production.sh \
  --index-sha256 369634d984e93f43266241fcea907efd64bc7ff3353bb9b093eb5db8024a1590
```

以下只读检查全部通过：

- `index.html`、`index.js`、`index.wasm` 可访问；
- `index.pck` 支持 HTTP 206 Range；
- `index.html` SHA-256 与已知构建一致；
- Presence `/healthz` 返回健康。

该脚本不携带成员 token，不调用 Data Gateway 或真实 AI，也不写业务数据。因此它证明公开 Web
运行时和 Presence 已恢复，但不替代带身份的 Data Gateway、AI 或双设备 UI 验收。

## 5. 当前风险与边界

### 5.1 包装与许可卫生

旧的 192 MB `Family_Garden/` 快照和 176 MB 源码 ZIP 已从仓库根目录移到仓库外本地归档，
没有删除。当前 `HEAD`、`origin/dev` 和所有 `origin/*` 引用均不包含已移除的
`tilemap_gardening` 路径。

当前这台工作机仍有三个本地 `backup/*` 分支可达 277 个旧素材路径：

- `backup/history-cleanup/quality-optimization`；
- `backup/history-cleanup/release-ui-final-polish`；
- `backup/pr32-before-p1-fixes`。

这些引用没有推到远端。禁止执行 `git push --mirror`、交付整个 `.git`、或制作包含全部 refs 的
bundle；正常基于干净提交的 GitHub PR、clone 或定向 archive 不受影响。

### 5.2 生产依赖

- AI Gateway：本地 lockfile 已把 `fast-uri` 更新到 `3.1.7`；AI 单测 35/35、生产依赖审计
  0 漏洞，但该修改尚未提交和部署；
- Data Gateway：当前审计仍报告 3 high + 2 moderate，主要来自固定的
  `@cloudbase/node-sdk@3.18.3` 及传递依赖；
- Presence Relay：当前生产依赖审计 0 漏洞；
- CI 目前只以 critical 作为阻断等级，因此不会阻断上述 Data Gateway 告警。

Data Gateway 不能直接原地升级 SDK 4.x：现有生产函数是 Node.js 18.15，历史真实验证中 SDK 4.x
还出现过 Storage `AccessDenied`。迁移应建立 Node.js 20.19+ 并行函数，完成数据库、私有图片、
家庭隔离和事务 smoke 后再切换路由。详细边界见 [`../../backend/cloudbase/README.md`](../../backend/cloudbase/README.md)。

### 5.3 明确延期的验收

负责人已决定把“双设备、双账号真实 UI 联机验收”推迟，先处理其他工程风险。当前不得把它
标记为已完成；正式公开交付前仍需恢复为必验项。

同时尚未完成：

- 浏览器级关键路径 E2E；
- `dev / test / prod` 独立环境和备份恢复演练；
- 真实手机横屏、旋转恢复和照片选择最终复核；
- CloudBase 本次恢复后的带身份 Data Gateway 与真实 AI 最小 smoke。

### 5.4 可维护性

- `game/scripts/managers/scene_manager.gd` 当前为 7,225 行，占 `game/scripts` GDScript 约 26.44%；
- `project.godot` 注册 24 个 autoload；
- 当前 25/25 回归通过，尚无证据表明初始化顺序正在造成线上故障；
- 拆分 `scene_manager.gd` 属于长期维护任务，必须使用独立分支和 PR，不与依赖、发布或玩法修改
  混在一起，也不得以“重构”为由删除现有功能。

## 6. 推荐工作顺序

1. 提交 AI Gateway `fast-uri@3.1.7` lockfile 修复，并在部署窗口重新构建和部署 AI Gateway；
2. 为 Data Gateway 的 SDK 4.x / Node 20 并行迁移建立独立方案，不直接修改当前生产函数；
3. 在不删除运行时资源的前提下继续降低 PCK，目标余量由实际发布预算决定；
4. 增加浏览器关键路径 E2E；
5. 最后在独立分支评估 `scene_manager.gd` 拆分；
6. 正式发布前完成已延期的双设备 UI、真机和带身份云端验收。

## 7. 安全交接规则

- TokenHub API Key、腾讯云 SecretId/SecretKey、Supabase service role key、`member_token` 不得写入
  仓库、文档、截图、Issue 或日志；
- 业务数据写入继续经过 Data Gateway，Presence 只承载瞬时状态和刷新通知；
- 普通回归不得调用真实云端或收费接口；真实 smoke 必须使用隔离家庭并由负责人明确授权；
- 开始修改前阅读 [`32_claude_collaboration_rules.md`](32_claude_collaboration_rules.md) 和
  [`37_role_boundaries_and_grey_zones.md`](37_role_boundaries_and_grey_zones.md)。
