# 66｜发布加固、环境隔离与恢复演练

> 日期：2026-09-13；2026-09-15 补充 test 落云及生产影子核验；2026-09-16 完成生产切换
>
> 工作分支：`codex/data-gateway-v4-prod`
>
> 基线：PR #38 合并后的 `dev@f23eff4`
>
> 原则：不删除功能、不把密钥写入仓库、不在生产做恢复演练、不把失败的真实验收写成通过

## 1. 十项任务状态

| # | 项目 | 当前状态 | 可验证结论 |
|---:|---|---|---|
| 1 | 合并 PR #37 | 已完成 | 两条 CI 通过；按精确 head `e12bb21` squash 合并到 `dev`，合并提交 `a88ce3bb` |
| 2 | AI Gateway `fast-uri@3.1.7` | 已部署 | 35/35 单测、audit 0；线上回下载 lockfile 确认 `fast-uri=3.1.7`、`ajv=8.20.0` |
| 3 | 带身份 Data Gateway + 真实 AI smoke | 已完成 | `join_family`、Bearer `whoami`、家庭隔离、腾讯 TMS、TokenHub `hy3` 与 Schema 全部真实通过；两组生产凭据轮换并撤销旧钥匙后 `meta.source=ai` |
| 4 | Node 20 + CloudBase SDK 4.x 并行迁移 | 已完成 | 独立 NoSQL test、生产影子和 24 小时观察通过；正式路由已切到 `data_gateway_v4`，切换后四组真实 smoke 全绿，旧函数保留回滚 |
| 5 | PCK 预算 | 已完成 | 128,211,128 → 116,735,284 bytes；平台 130 MB 门槛下余量 13,264,716 bytes（10.20%） |
| 6 | 仓库卫生 | 已完成 | 三个问题 refs 已做完整 bundle 并校验后删除；旧交接与含隐私 `tmp/` 已移到仓库外；海报用途已登记 |
| 7 | 浏览器关键路径 E2E | 已完成 | Playwright 2/2：干净上下文真实渲染与音频解锁、缺片可见失败 |
| 8 | dev/test/prod 独立环境 | 已完成角色隔离 | `family-garden-dev`（PG/体验版）、`family-nosql-test`（NoSQL/个人版）与 prod 为三个独立环境；dev 不可代替 NoSQL test |
| 9 | 数据备份恢复演练 | 逻辑恢复已完成，PITR 受套餐限制 | test 单条合成数据导出 1/1、异名恢复后字段一致、实测丢失 0 条、RTO 41 秒；未定时导出，故持续 RPO 未建立 |
| 10 | 无痕公开 Demo、同步/缓存/权限 | 已完成 | 裸生产 URL 清单/入口哈希与 8 个分片校验通过；全新 Chrome context 2/2；`__auth/`、`cloud-admin/` 发布前后哈希一致 |

## 2. AI Gateway 发布证据

发布前执行：

```bash
cd backend/ai
npm ci
npm test
npm run build:deploy
npm audit --omit=dev --audit-level=moderate
npm ls fast-uri
```

结果：35/35 通过，audit 为 0，依赖树为 `ajv@8.20.0 → fast-uri@3.1.7`。生产旧代码已下载到仓库外：

```text
/Users/xiongweiluo/Family Garden Local Archive/2026-09-13/
  cloud-functions/pre-fast-uri-3.1.7/ai_gateway/
```

CloudBase 部署明确固定原配置：Event 函数、Node.js 18.15、`index.main`、256 MB。
部署成功后再次下载线上代码，`package-lock.json` 确认为 3.1.7。无令牌调用返回稳定
`UNAUTHORIZED`，证明函数可启动且依赖安装完整。2026-09-15 将平台函数超时从 15 秒提高到
60 秒，使其高于 `AI_TIMEOUT_MS=20000` 并覆盖身份及两段内容安全开销。

真实 smoke 使用随机家庭，依次验证 Data Gateway 身份、TMS 和 TokenHub。2026-09-15
已启用 TMS/IMS，并为专用 CAM 子用户只授予 `TextModeration` 与 `ImageModeration`。
`hy3-preview` 停服后，生产改用已开通免费额度的 `hy3`，TokenHub Key 限定为
`hy3` 与 `hy-vision-2.0-instruct`。最终结果：

```text
PASS Data Gateway 匿名加入返回隔离身份
PASS Data Gateway Bearer 身份与家庭隔离
PASS AI Gateway 腾讯文本内容安全
PASS AI Gateway 真实模型 + 内容安全 + Schema
```

生产继续采用 fail-closed，审核不可用时不得绕过或用 fallback 冒充模型成功。复跑命令：

```bash
cd backend/ai
FG_AI_REAL_SMOKE=1 npm run smoke:real
```

通过标准：四行 `PASS`，最终 `meta.source=ai` 且 `meta.model=hy3`；脚本会留下一个没有业务数据的 smoke 成员记录，
不会打印 member token。

2026-09-15 同时完成两组生产凭据轮换。内容安全专用 CAM 子用户先创建第二组访问密钥并切换
`ai_gateway`，真实 smoke 通过后删除旧密钥，最终只保留一组 Active 凭据。TokenHub 先创建仅绑定
`hy3` 与 `hy-vision-2.0-instruct` 的新 Key，切换函数并通过四项 smoke 后删除旧 Key；删除后的
首次模型请求处于短暂权限传播窗口而返回可识别的 fallback，等待后直接探针恢复
`meta.source=ai`，最终再次执行四项 smoke 全绿。轮换脚本位于仓库外临时目录，输出只包含状态、
数量和模型名，没有记录 SecretId、SecretKey、API Key 或 member token。

## 3. Data Gateway Node 20 / SDK 4.1 canary

截至 2026-09-13，npm 注册表的稳定 `latest` 是 3.18.3，`4.1.0` 只属于 `next`。因此不把
4.1.0 直接称为稳定生产升级，而采用并行 canary：

```text
现有 prod 路由
  → data_gateway / Node 18.15 / SDK 3.18.3（不覆盖，回滚目标）

新建 test 路由
  → data_gateway / Node 20.19 / SDK 4.1.0（先验收）
  → 51 项单测
  → Gate5 数据/隔离 smoke
  → Gate6 农场事务 + 成员 smoke
  → M1 私有图片 Storage smoke
  → 24 小时观察
  → 人工批准后再切 prod 路由
```

候选包已完成：

- `package.json` 明确 `node >=20.19.0`；
- 依赖锁定 `@cloudbase/node-sdk=4.1.0`；
- Node 20.19.5 下 51/51 通过；
- `npm audit --omit=dev --audit-level=moderate` 为 0；
- `npm run build:deploy` 只生成 `index.js`、`package.json`、`package-lock.json`，不包含 `.git`、
  `node_modules`、测试、旧 ZIP 或环境文件。

2026-09-15 新建独立传统 NoSQL 环境 `family-nosql-test`
（`family-nosql-test-d1daoldc62a58f`），创建 17 个 `ADMINONLY` 业务集合，并将候选包部署为
Event / Node.js 20.19 / `index.main` / 256 MB 函数。首次共享仓事务暴露 SDK 4.x 在文档
不存在时抛 `DOCUMENT_NOT_FOUND` 的行为差异；代码现只在可选文档读取路径将该错误映射为
空文档，其他数据库错误继续 fail-closed。修复后本地 51/51，且 Gate 5、Gate 6 农场事务、
Gate 6 成员列表与 M1 私有图片 Storage 四组真实 smoke 全部通过。合成业务数据和临时
HTTP 路由均已清理。生产仍保留 Node 18.15 + SDK 3.18.3，等待观察与人工批准。

2026-09-15 生产预部署时发现环境的旧 CLS 日志集/主题已不存在，陈旧绑定会令所有新函数创建
失败。已按最小配置重建 `family-garden-prod-scf` 日志集与主题（上海、1 分区、7 天标准存储、
全文索引）并通过 CloudBase `BindCls` 绑定。随后新增 `data_gateway_v4` 生产影子函数：Event、
Node.js 20.19、`index.main`、256 MB、15 秒、依赖安装开启；独立
`/data_gateway_v4_canary` 路径首轮四组真实 smoke 全绿，CLS 官方直查 100 条最新日志且未命中
未捕获异常、运行时崩溃或超时标记。正式 `/data_gateway` 仍指向旧 `data_gateway`，旧函数未删除。

CloudBase 环境的 `CustomLogServices` 已更新，但旧兼容字段 `LogServices` 尚未同步，导致 CLI 3.8.1
的 `fn log` 仍查询已删除主题。观察期统一以 `CustomLogServices` 对应主题的 CLS `SearchLog` 直查
为准。test 函数最后修改时间为 2026-09-15 20:18:24（中国标准时间），因此正式切换不得早于
2026-09-16 20:18:24；负责人已授权到点复核通过后执行原子路由切换。

2026-09-16 到达门槛后实际观察时长为 24.06 小时。test 与生产影子函数均保持 `Active`，CLS
分页扫描 642 条观察期日志（7 页），未命中未捕获异常、运行时崩溃、超时、Storage
`AccessDenied`、事务不一致或跨家庭可见标记。切换前 `/data_gateway_v4_canary` 四组真实 smoke
再次全绿。

20:24:04（中国标准时间）通过 `ModifyHTTPServiceRoute` 增量将正式 `/data_gateway` 的上游从
`data_gateway` 改为 `data_gateway_v4`；其他路由未变化，域名状态为 `SUCCESS`。切换后正式入口
四组真实 smoke 全绿，随后对 1,961 条 CLS 日志（20 页）复核，硬错误标记仍为 0。临时 canary
路由已删除并确认不可查询；Node 18 的旧 `data_gateway` 函数未删除，继续作为快速回滚点。

切换完成后的本地复核：Data Gateway 单测 51/51、生产依赖审计 0 漏洞、部署包仍只有 3 个文件；
仓库统一回归 25/25、0 失败。

切换的硬性回滚条件：任一 Storage `AccessDenied`、事务结果不一致、跨家庭可见、图片临时 URL
异常或错误率高于旧函数。触发时只把正式 HTTP 路由切回 `data_gateway`，不删除
`data_gateway_v4`，不回退整个 `main`。

## 4. PCK 预算与发布包

Web Release 只排除三项经全仓引用扫描确认未调用的音频：

- `music/ikoliks_aj-acoustic-spring-mothers-day-music-320427.mp3`；
- `soundeffect/森林河流.mp3`；
- `soundeffect/water-bubbles-2.mp3`。

文件仍保留在仓库和原生工程，仅不进入 Web 包。实际 BGM（garden、globalmap、farm、kitchen、
fishpond）和所有已调用 SFX 均保留。`check_web_export.sh` 默认门禁降到 117,000,000 bytes；
实测 PCK 为 116,735,284 bytes。

2026-09-17 后续又排除了当前 UI 已隐藏且运行时固定不读取的非棕发色图集；素材仍保留，
并由外观与 Web 导出门禁保护恢复条件。最新 PCK 为 71,251,232 bytes，详见
[`68_web_pck_headroom_acceptance.md`](68_web_pck_headroom_acceptance.md)。

`tools/build_web_release.sh <空目录>` 生成可部署版本，PCK/WASM 按 20 MiB 拆分，并写
`release-manifest.json`，记录完整文件及每个分片的大小与 SHA-256。构建拒绝覆盖非空目录，
最终不存在大于 25 MiB 的托管文件。

## 5. 浏览器 E2E

执行：

```bash
./tools/build_web_release.sh /tmp/family-garden-web
E2E_WEB_DIR=/tmp/family-garden-web npm --prefix e2e test
```

覆盖：

1. 新建无历史状态的 Chromium context；
2. 本地静态服务器严格验证 `index.html: no-cache` 与 chunks `immutable`；生产可通过环境变量严格
   匹配 CloudBase CDN 的实测策略（当前两者均为 `max-age=120`）；
3. 页面启动前并行 HEAD 校验全部 PCK/WASM 分片与字节数；
4. 启动按钮变为可用，点击后 Web Audio 解锁层移除，Canvas 获得焦点；
5. Canvas 截图不是空白页，且无 page error / console error；
6. 强制首个 PCK 分片返回 503 时，用户看到“加载失败”，入口保持禁用且错误指出缺失分片。

## 6. 仓库与隐私卫生

三个本地问题引用已写入完整 bundle：

```text
/Users/xiongweiluo/Family Garden Local Archive/2026-09-13/backup-history-cleanup.bundle
SHA-256 bf299a7e6c133bcdedf2b653b5142c40b17fe8d46b9f059b36e356fa77fded84
```

`git bundle verify` 确认完整历史和 3 个预期 refs 后，才删除本地引用。恢复示例：

```bash
git fetch '/Users/xiongweiluo/Family Garden Local Archive/2026-09-13/backup-history-cleanup.bundle' \
  'refs/heads/backup/*:refs/heads/recovered/*'
```

旧 `docs/dev/59_full_project_handoff.md` 已归档到 `legacy-untracked/`。`tmp/` 内是一页含手机号、
邮箱与住址的个人简历截图，已整体移动到仓库外 `private-temp/tmp/`；根级 `/tmp/` 已加入
`.gitignore`。禁止 `git add -A` 前不看状态，也禁止打包 `.git` 或 `git push --mirror`。

## 7. 环境隔离与 test-only 恢复演练

目标环境：

| 环境 | CloudBase alias | 数据 | 对外流量 | 当前状态 |
|---|---|---|---|---|
| dev | `family-garden-dev` | 只允许合成数据 | 无 | 独立体验环境，PostgreSQL 模式；旧 alias `family-garden-test` 已更名，不作 NoSQL canary |
| test | `family-nosql-test` | 固定验收数据 | 无 | 独立个人版，传统 NoSQL；Data Gateway 四组真实 smoke 已通过 |
| prod | `familygarden-d7gy18huh87fd41d2` | 真实数据 | 100% | Normal；2026-09-30 到期 |

如需再创建同类环境，命令如下（上海、1 个月、不自动续费）：

```bash
tcb env create --alias family-garden-dev --package baas_personal \
  --region ap-shanghai --duration 1 --yes --json
tcb env create --alias family-garden-nosql-test --package baas_personal \
  --region ap-shanghai --duration 1 --yes --json
```

时间点回档规程只能在 test：

1. 写入唯一标识的 `restore_drill` 测试文档，记录 UTC 时间与文档 ID；
2. `tcb db nosql backup time -e <test-env> --json` 取得可恢复时间；
3. 用 `backup collection --time <time> --filters restore_drill` 确认集合可恢复；
4. 修改或删除该测试文档；
5. 用下列映射恢复到新集合，禁止覆盖原集合：

```bash
tcb db nosql backup restore -e <test-env> --time '<UTC time>' \
  --tables '[{"OldTableName":"restore_drill","NewTableName":"restore_drill_recovered"}]' --json
```

6. `backup task` 等待成功；对比文档 ID、字段和数量；
7. 记录 RPO（恢复时间点与故障时间差）和 RTO（发起到校验完成）；
8. 演练记录获批后清理两个测试集合。

任何命令若目标 env 等于生产 ID，立即停止。2026-09-15 在
`family-nosql-test-d1daoldc62a58f` 写入唯一合成记录后，可恢复时间窗口已覆盖该记录，
但 `backup collection` 对所有集合返回空列表。原因是当前个人版套餐不支持数据库回档，
因此不得把 PITR 标记为通过。

为验证现有套餐可执行的灾备链路，同日完成 test-only 逻辑备份/异名恢复：

- `db nosql dump restore_drill` 导出成功 1/1，失败 0，备份 SHA-256 为
  `128ecf88a19d9554bf38e514bd7d1086677334d180bc859505a73f0eb36afb7f`；
- 恢复到 `restore_drill_recovered`，原/新集合的 `_id`、标记、写入时间和计数字段完全一致；
- 本次数据差异为 0 条，单次导出用时 14.4 秒，从发起恢复到校验完成的 RTO 为 41 秒；
- 当前没有定时逻辑备份，因此这次“丢失 0 条”不构成持续 RPO 承诺；要建立 RPO，需另行确定
  定时导出频率和仓库外加密保留策略，或升级套餐并完成 PITR 验收；
- 验收后删除 `restore_drill` 和 `restore_drill_recovered`，`DescribeTable` 均确认 `ResourceNotFound`；
- 备份文件只在仓库外临时目录中短暂保留，不含真实业务数据，交付前清理。

## 8. 最终发布门禁

生产 Web 发布必须满足：

- `./tools/test_all.sh` 全绿；
- 三个 Node 工作区 moderate 及以上 audit 为 0；
- `./tools/check_web_export.sh` 通过；
- 本地 Playwright 2/2 通过；
- `tcb hosting deploy <release-dir> --safe --verify --entry index.html`，不使用 `--prune`，保留
  `__auth/` 与 `cloud-admin/`；
- 使用新 `index.html` 和 `release-manifest.json` SHA-256 跑 `verify_production.sh`；
- 以 `E2E_BASE_URL=<production>` 在全新 context 重跑 Playwright；
- Data/AI 四项真实 smoke 必须持续全绿；双设备双账号验收继续保持延期状态。

2026-09-13 已完成该门禁。发布时网络多次出现 TLS 断连、`ECONNRESET` 与 COS DNS 失败，因此先
逐个上传并校验 8 个分片，再发布非入口资源和清单，最后单独安全切换 `index.html`；未使用
`--prune`。最终证据：

```text
index.html SHA-256              f534769a19839e37a623750ee901c4a7b0cb90a2ca91c4356420aacf6736102b
release-manifest.json SHA-256   3063bc06b73156036cbf033eef6e97d473c88265beb48c2f30f76f3312b71023
PCK parts                       6/6，116,735,284 bytes
WASM parts                      2/2，39,509,339 bytes
裸生产 URL Playwright            2/2（40.4 秒）
__auth/device/index.html        b15768d6e4d2436eaebe334e6aa155e9007568df2b04c1c6c75438a76cbfbfc6
cloud-admin/index.html          06ed341b4bd13eb03b00c9f6b3ceca8016654abac57daea38c2ff72fe293371f
```

CloudBase 源站对象更新后，裸 URL 曾在 120 秒窗口内短暂返回旧入口；带版本参数立即取得新哈希，
窗口结束后裸 URL 复核通过。发布前完整托管备份位于仓库外：

```text
/Users/xiongweiluo/Family Garden Local Archive/2026-09-13/hosting/pre-web-hardening/
```

2026-09-17 追加发布移动 Web 修复和 PCK 瘦身结果：生产安全增量部署 14/14 文件成功，远端
校验通过，自动备份为 `.cloudbase-backup/1789647000372/`，未使用 `--prune`。新包为 4 个
PCK 分片（71,251,472 bytes）和 2 个 WASM 分片（39,509,339 bytes）；入口与清单 SHA-256
分别为 `4b9242ba87e91d054f8a10320ba58b6fe4a6fb7852decb77f08365ca8119da4d` 和
`004ad9b4829e5bb252d733ab00c4743d032780a37a5a1f11f52a9ac4cf0c147d`。生产只读核验、
Presence 冷启动后二次健康检查和 HTTPS 浏览器 E2E 4/4 通过；认证页与管理页哈希保持不变。

## 9. 尚需外部动作

1. 如需时间点回档，先升级 test 套餐，再按本文异名恢复规程验收；
2. 双设备双账号真实 UI 联机验收按负责人决定延期，未标记完成；
3. prod 个人版 2026-09-30 到期，必须在到期前续费或完成迁移。
