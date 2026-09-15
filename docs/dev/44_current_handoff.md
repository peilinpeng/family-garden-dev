# 44｜当前工程交接入口

> 更新日期：2026-09-15
>
> 当前工作分支：`feature/release-hardening-complete`
>
> 分支基线：PR #37 head `e12bb21`；该 PR 已 squash 合并为 `dev@a88ce3bb`
>
> 最新集成分支：`dev@a88ce3bb`
>
> 状态：发布加固候选与生产 Web 已验收；NoSQL canary 函数已落 test，但 test 为 PG 模式；TMS 仍阻塞

## 1. 当前结论

Family Garden 已完成比赛候选版本的主要产品闭环、家庭云同步、照片隐私、Web 导出、CI 和
生产可观测性。本机 2026-09-13 重新执行统一回归，25/25 个执行单元通过；同日发布拆分 Web 包，
公开生产入口/清单哈希、8 个分片、Presence 健康检查和裸 URL 无痕 E2E 2/2 全部通过。

当前阶段不再把 2026-06 的池塘专项交接当作全项目状态。历史池塘实现可继续参考：

- [`37_fishpond_asset_integration.md`](37_fishpond_asset_integration.md)；
- [`../handoff_garden_build_inventory_fishing_2026-07-13.md`](../handoff_garden_build_inventory_fishing_2026-07-13.md)；
- [`../handoff_garden_ui_fishpond_followup_2026-07-15.md`](../handoff_garden_ui_fishpond_followup_2026-07-15.md)。

## 2. 分支与工作树

### 2.1 版本基线

| 项目 | 当前状态 | 说明 |
|---|---|---|
| 当前分支 | `feature/release-hardening-complete` | 从 PR #37 head `e12bb21` 创建，承载发布加固 |
| 最新集成分支 | `dev@a88ce3bb` | PR #37 已在 2026-09-13 squash 合并 |
| 当前分支与 `origin/dev` | 当前分支承载本轮发布加固 | 基线内容已进入 dev，本轮修改仍需独立 PR |
| `main` | `bb681b6` | 明显落后，不作为当前功能或发布基线，也不得回退开发 |

### 2.2 当前发布加固内容

- AI Gateway `fast-uri=3.1.7` 已部署，线上回下载 lockfile 已核对；
- Data Gateway 的 Node 20.19 + SDK 4.1.0 canary、浏览器 E2E、PCK 预算和可部署分片构建已落地；
- canary 函数已部署到隔离 test 并为 Available，但该环境是 PostgreSQL 模式、没有文档型数据库，
  不能执行现有网关的真实数据 smoke；
- 拆分 Web 包已发布生产，裸公开地址 E2E 2/2；认证页与管理页发布前后哈希一致；
- 两张宣传海报保留并登记用途；旧交接文档和含个人隐私的 `tmp/` 已移到仓库外；
- 完整状态、阻塞项和恢复步骤见 [`66_release_hardening_completion.md`](66_release_hardening_completion.md)。

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
| `index.pck` | 116,735,284 bytes |
| PCK 内部门禁 | 117,000,000 bytes |
| 相对平台 130 MB 余量 | 13,264,716 bytes（10.20%） |
| `index.wasm` | 39,509,339 bytes |
| 核心四文件合计 | 156,535,296 bytes |

三项未调用音频只从 Web 包排除，源码与原生构建仍保留。新增大资源前必须重新导出验证，不能
只根据仓库文件大小估算。

### 4.3 CloudBase 恢复核验

CloudBase 曾返回 `SERVICE_FORBIDDEN / Your server is isolated`。负责人恢复服务后，于
2026-09-13 重新执行：

```bash
./tools/verify_production.sh \
  --index-sha256 f534769a19839e37a623750ee901c4a7b0cb90a2ca91c4356420aacf6736102b \
  --manifest-sha256 3063bc06b73156036cbf033eef6e97d473c88265beb48c2f30f76f3312b71023
```

以下只读检查全部通过：

- `index.html`、`index.js`、`release-manifest.json` 可访问；
- 6 个 PCK 分片与 2 个 WASM 分片的远端字节数与清单完全一致；
- `index.html` 和发布清单 SHA-256 与已知构建一致；
- Presence `/healthz` 返回健康。

裸生产 URL 的全新 Chrome context E2E 2/2 通过（真实 Canvas 渲染/音频解锁，以及分片 503 的
稳定失败 UI）。CloudBase CDN 当前对入口与分片返回 `max-age=120`；源站切换后等待该窗口，再次
验证裸 URL 通过。发布未使用 `--prune`，`__auth/device/index.html` 与 `cloud-admin/index.html`
的发布前后 SHA-256 一致。

该脚本不携带成员 token，不调用 Data Gateway 或真实 AI，也不写业务数据。因此它证明公开 Web
运行时和 Presence 已恢复，但不替代带身份的 Data Gateway、AI 或双设备 UI 验收。

## 5. 当前风险与边界

### 5.1 包装与许可卫生

旧的 192 MB `Family_Garden/` 快照和 176 MB 源码 ZIP 已从仓库根目录移到仓库外本地归档，
没有删除。当前 `HEAD`、`origin/dev` 和所有 `origin/*` 引用均不包含已移除的
`tilemap_gardening` 路径。

三个可达旧素材的本地 `backup/*` 引用已写入仓库外完整 bundle，`git bundle verify` 通过后删除。
bundle SHA-256 与恢复命令见 `66`。禁止执行 `git push --mirror` 或交付整个 `.git`；正常基于
干净提交的 GitHub PR、clone 或定向 archive 不受影响。

### 5.2 生产依赖

- AI Gateway：`fast-uri=3.1.7` 已部署；AI 单测 35/35、生产依赖审计 0，线上 lockfile 已回读核对；
- Data Gateway：Node 20.19 + `@cloudbase/node-sdk=4.1.0` canary 在 Node 20.19.5 下 50/50 通过，
  原 3 high + 2 moderate 清零；尚未部署生产；
- Presence Relay：当前生产依赖审计 0 漏洞；
- CI 已提升为 moderate 及以上阻断，并加入浏览器 E2E。

Data Gateway 不能直接原地升级 SDK 4.x：npm 的稳定 `latest` 仍为 3.18.3，4.1.0 只在 `next`；
迁移必须建立 Node.js 20.19 test 并行函数，完成数据库、私有图片、家庭隔离和事务 smoke 后再
切换路由。2026-09-15 已在 `family-garden-test` 部署符合配置的函数，但该环境是 PostgreSQL
模式且 `Databases=[]`；创建文档集合失败。直接调用函数执行合成 `join_family` 也 fail-closed
返回 500，明确报告缺少文档数据库，且未写入成员数据。重新创建传统模式环境仍被计费 API 以
余额不足拒绝。

### 5.3 明确延期的验收

负责人已决定把“双设备、双账号真实 UI 联机验收”推迟，先处理其他工程风险。当前不得把它
标记为已完成；正式公开交付前仍需恢复为必验项。

同时尚未完成：

- `dev / test / prod` 独立环境和备份恢复演练（账号余额阻塞）；
- 真实手机横屏、旋转恢复和照片选择最终复核；
- TMS 恢复后的真实 AI 最小 smoke；当前 Data Gateway 身份/隔离已通过，TMS fail-closed 阻断。

### 5.4 可维护性

- `game/scripts/managers/scene_manager.gd` 当前为 7,225 行，占 `game/scripts` GDScript 约 26.44%；
- `project.godot` 注册 24 个 autoload；
- 当前 25/25 回归通过，尚无证据表明初始化顺序正在造成线上故障；
- 拆分 `scene_manager.gd` 属于长期维护任务，必须使用独立分支和 PR，不与依赖、发布或玩法修改
  混在一起，也不得以“重构”为由删除现有功能。

## 6. 推荐工作顺序

1. 在当前 CLI 账号补足可购买个人版的现金余额，创建传统 NoSQL dev/test，完成 canary 与恢复演练；
2. 审查并合并已通过 CI 的本轮发布加固 PR #38；
3. 生产环境在 2026-09-30 到期前续费或完成迁移；
4. 最后在独立分支评估 `scene_manager.gd` 拆分；
5. 正式发布前完成已延期的双设备 UI 与真机验收。

## 7. 安全交接规则

- TokenHub API Key、腾讯云 SecretId/SecretKey、Supabase service role key、`member_token` 不得写入
  仓库、文档、截图、Issue 或日志；
- 业务数据写入继续经过 Data Gateway，Presence 只承载瞬时状态和刷新通知；
- 普通回归不得调用真实云端或收费接口；真实 smoke 必须使用隔离家庭并由负责人明确授权；
- 开始修改前阅读 [`32_claude_collaboration_rules.md`](32_claude_collaboration_rules.md) 和
  [`37_role_boundaries_and_grey_zones.md`](37_role_boundaries_and_grey_zones.md)。
