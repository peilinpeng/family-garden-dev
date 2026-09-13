# 66｜发布加固、环境隔离与恢复演练

> 日期：2026-09-13
>
> 工作分支：`feature/release-hardening-complete`
>
> 基线：PR #37 head `e12bb21`
>
> 原则：不删除功能、不把密钥写入仓库、不在生产做恢复演练、不把失败的真实验收写成通过

## 1. 十项任务状态

| # | 项目 | 当前状态 | 可验证结论 |
|---:|---|---|---|
| 1 | 合并 PR #37 | 已完成 | 两条 CI 通过；按精确 head `e12bb21` squash 合并到 `dev`，合并提交 `a88ce3bb` |
| 2 | AI Gateway `fast-uri@3.1.7` | 已部署 | 35/35 单测、audit 0；线上回下载 lockfile 确认 `fast-uri=3.1.7`、`ajv=8.20.0` |
| 3 | 带身份 Data Gateway + 真实 AI smoke | 部分通过 | 随机隔离家庭的 `join_family`、Bearer `whoami`、家庭隔离通过；TMS 返回 `AI_UPSTREAM_ERROR`，模型调用未发生 |
| 4 | Node 20 + CloudBase SDK 4.x 并行迁移 | 候选完成，落云阻塞 | SDK 4.1.0 + Node 20.19.5 的 50/50 回归通过，3 high + 2 moderate 清零；因余额不足无法创建 test 环境 |
| 5 | PCK 预算 | 已完成 | 128,211,128 → 116,735,284 bytes；平台 130 MB 门槛下余量 13,264,716 bytes（10.20%） |
| 6 | 仓库卫生 | 已完成 | 三个问题 refs 已做完整 bundle 并校验后删除；旧交接与含隐私 `tmp/` 已移到仓库外；海报用途已登记 |
| 7 | 浏览器关键路径 E2E | 已完成 | Playwright 2/2：干净上下文真实渲染与音频解锁、缺片可见失败 |
| 8 | dev/test/prod 独立环境 | 账号阻塞 | prod 正常；创建 dev 时 CloudBase 返回余额不足，未产生 dev/test 环境 |
| 9 | 数据备份恢复演练 | 被 #8 阻塞 | 已固化 test-only 规程；没有可用 test 环境时禁止在 prod 代跑 |
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

CloudBase 部署明确固定原配置：Event 函数、Node.js 18.15、`index.main`、15 秒、256 MB。
部署成功后再次下载线上代码，`package-lock.json` 确认为 3.1.7。无令牌调用返回稳定
`UNAUTHORIZED`，证明函数可启动且依赖安装完整。

真实 smoke 使用随机家庭，依次验证 Data Gateway 身份、TMS 和 TokenHub。当前结果停在 TMS：

```text
PASS Data Gateway 匿名加入返回隔离身份
PASS Data Gateway Bearer 身份与家庭隔离
FAIL 内容安全 smoke 失败: AI_UPSTREAM_ERROR
```

生产采用 fail-closed，TMS 不可用时不得绕过安全审核或用 fallback 冒充模型成功。账号同时明确
返回 CloudBase 余额不足，因此先恢复余额与内容安全服务，再运行：

```bash
cd backend/ai
FG_AI_REAL_SMOKE=1 npm run smoke:real
```

通过标准：四行 `PASS`，最终 `meta.source=model`；脚本会留下一个没有业务数据的 smoke 成员记录，
不会打印 member token。

## 3. Data Gateway Node 20 / SDK 4.1 canary

截至 2026-09-13，npm 注册表的稳定 `latest` 是 3.18.3，`4.1.0` 只属于 `next`。因此不把
4.1.0 直接称为稳定生产升级，而采用并行 canary：

```text
现有 prod 路由
  → data_gateway / Node 18.15 / SDK 3.18.3（不覆盖，回滚目标）

新建 test 路由
  → data_gateway / Node 20.19 / SDK 4.1.0（先验收）
  → 50 项单测
  → Gate5 数据/隔离 smoke
  → Gate6 农场事务 + 成员 smoke
  → M1 私有图片 Storage smoke
  → 24 小时观察
  → 人工批准后再切 prod 路由
```

候选包已完成：

- `package.json` 明确 `node >=20.19.0`；
- 依赖锁定 `@cloudbase/node-sdk=4.1.0`；
- Node 20.19.5 下 50/50 通过；
- `npm audit --omit=dev --audit-level=moderate` 为 0；
- `npm run build:deploy` 只生成 `index.js`、`package.json`、`package-lock.json`，不包含 `.git`、
  `node_modules`、测试、旧 ZIP 或环境文件。

切换的硬性回滚条件：任一 Storage `AccessDenied`、事务结果不一致、跨家庭可见、图片临时 URL
异常或错误率高于旧函数。触发时只切回旧 HTTP 路由，不删除 canary，不回退整个 `main`。

## 4. PCK 预算与发布包

Web Release 只排除三项经全仓引用扫描确认未调用的音频：

- `music/ikoliks_aj-acoustic-spring-mothers-day-music-320427.mp3`；
- `soundeffect/森林河流.mp3`；
- `soundeffect/water-bubbles-2.mp3`。

文件仍保留在仓库和原生工程，仅不进入 Web 包。实际 BGM（garden、globalmap、farm、kitchen、
fishpond）和所有已调用 SFX 均保留。`check_web_export.sh` 默认门禁降到 117,000,000 bytes；
实测 PCK 为 116,735,284 bytes。

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
| dev | `family-garden-dev` | 只允许合成数据 | 无 | 因余额不足未创建 |
| test | `family-garden-test` | 固定验收数据 | 无 | 因余额不足未创建 |
| prod | `familygarden-d7gy18huh87fd41d2` | 真实数据 | 100% | Normal；2026-09-30 到期 |

充值后创建命令（上海、1 个月、不自动续费）：

```bash
tcb env create --alias family-garden-dev --package baas_personal \
  --region ap-shanghai --duration 1 --yes --json
tcb env create --alias family-garden-test --package baas_personal \
  --region ap-shanghai --duration 1 --yes --json
```

恢复演练只能在 test：

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

任何命令若目标 env 等于生产 ID，立即停止。当前没有 test 环境，因此没有执行步骤 1—8，也没有
触碰生产数据。

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
- Data/AI smoke 的 TMS 阻塞必须被如实记录；双设备双账号验收继续保持延期状态。

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

## 9. 尚需外部动作

1. 腾讯云账号充值或恢复可用余额，然后创建 dev/test、恢复 TMS，再执行 canary 和恢复演练；
2. 本轮发布加固 PR #38 已创建且 CI 通过，等待仓库维护者审查合并；
3. 双设备双账号真实 UI 联机验收按负责人决定延期，未标记完成；
4. prod 个人版 2026-09-30 到期，必须在到期前续费或完成迁移。
