# 71 优化执行台账

> 更新日期：2026-11-03。唯一负责人：xiongweiluo。
> 范围：[70 优化计划](70_project_optimization_iteration_plan.md) 的 43 项任务。
> 用户已授权按顺序完成；常规代码、测试、文档和 PR 准备连续推进。费用和破坏性生产操作单独确认。

## 当前执行位置

O0 执行中，尚未宣称阶段完成。演示基线经 [PR #46](https://github.com/peilinpeng/family-garden-dev/pull/46) 合入 dev（`aa9c69d`），独立修复 #48、#49 随后通过门禁并合入，业务代码基线为 `968382b`。main 未改动，未部署生产。

- 代码评审：4 个未集成提交主要为 HUD／弹窗遮挡、中文字体、面板长文本和演示文档修复。长文本仍需在 O6 补完整阅读体验，不能把裁剪显示当作全文阅读完成。
- 本地证据：2026-11-03 全量回归 26/26、Web 导出与启动审计通过；PCK 73,627,924 bytes。
- 历史 CI：`59cbccb` 的运行 35458545464 失败于 npm 审计接口 HTTP 400（Invalid package tree）；本地游戏测试成功不能替代该门禁。
- 最新依赖审计发现并修复 fast-uri、axios、follow-redirects、qs 风险；三个服务生产依赖审计均为 0。仅更新锁文件及 axios override，CloudBase SDK 未更换。
- 浏览器 CI 曾因旧环境 INVALID_ENV 触发 CORS 失败。资源与桥接测试现使用受控业务失败响应，未过滤 console/pageerror；真实云 smoke 仍独立阻塞，详见 `e2e/README.md`。
- #46 最终 head `f027a00` 的运行 41557852004、41557859358 均完整通过，随后合入 dev。本地浏览器 E2E 4/4 通过。
- CloudBase CLI 3.8.3 已找到，但只读 `env list --json` 返回需要登录。公开 Presence 返回 404 / INVALID_ENV；环境、存储和账单的真实状态未核实。
- 已尝试浏览器替代途径，Edge 打开 CloudBase 控制台后跳转腾讯云登录页，同样没有可用会话；登录标签页已保留。
- 用户已收到登录／现环境 ID 的问题；继续本地独立工作，不索取或记录密钥。

## 已确定的执行规则

当前所有开发、场景、美术、产品和验收职责归 xiongweiluo。原两位搭档不再是任务依赖；仍保留最小改动、功能分支、PR、测试和不重写共享模块的纪律。

本轮先封闭试用，公开 Demo 只用合成内容，真实家庭独立隔离。恢复生产不能重新开放已知的“仅家庭 ID 即可加入”入口。新周期范围按本次用户授权执行，历史比赛冻结日期不阻止优化。

## 任务状态

| 任务 | 状态 | 负责人 |
|---|---|---|
| O0-01 | 已完成：PR #46 有效 CI 后合入 dev | xiongweiluo |
| O0-02 | 阻塞：CLI 登录 | xiongweiluo |
| O0-03 | 方案已确认 | xiongweiluo |
| O0-04 | 执行中 | xiongweiluo |
| O1-01 | 草案完成，恢复语义与真实 owner 盘点待闭环，见 72 | xiongweiluo |
| O1-02 | 待开始 | xiongweiluo |
| O1-03 | 待开始 | xiongweiluo |
| O1-04 | 待开始 | xiongweiluo |
| O1-05 | 待开始 | xiongweiluo |
| O2-01 | 失败保护已通过 CI 并合入 #48；分页契约及真实 smoke 未完成 | xiongweiluo |
| O2-02 | 待开始 | xiongweiluo |
| O2-03 | 待开始 | xiongweiluo |
| O2-04 | 待开始 | xiongweiluo |
| O2-05 | 待开始 | xiongweiluo |
| O2-06 | 待开始 | xiongweiluo |
| O2-07 | 待开始 | xiongweiluo |
| O3-01 | 不可重试错误单点修复已通过 CI 并合入 #49；总时间预算仍待实现 | xiongweiluo |
| O3-02 | 待开始 | xiongweiluo |
| O3-03 | 待开始 | xiongweiluo |
| O3-04 | 待开始 | xiongweiluo |
| O3-05 | 待开始 | xiongweiluo |
| O4-01 | 待开始 | xiongweiluo |
| O4-02 | 待开始 | xiongweiluo |
| O4-03 | 待开始 | xiongweiluo |
| O4-04 | 待开始 | xiongweiluo |
| O4-05 | 待开始 | xiongweiluo |
| O5-01 | 待开始 | xiongweiluo |
| O5-02 | 待开始 | xiongweiluo |
| O5-03 | 待开始 | xiongweiluo |
| O5-04 | 待开始 | xiongweiluo |
| O6-01 | 待开始 | xiongweiluo |
| O6-02 | 待开始 | xiongweiluo |
| O6-03 | 待开始 | xiongweiluo |
| O6-04 | 待开始 | xiongweiluo |
| O7-01 | 待开始 | xiongweiluo |
| O7-02 | 待开始 | xiongweiluo |
| O7-03 | 待开始 | xiongweiluo |
| O7-04 | 待开始 | xiongweiluo |
| O7-05 | 待开始 | xiongweiluo |
| O8-01 | 待开始 | xiongweiluo |
| O8-02 | 待开始 | xiongweiluo |
| O8-03 | 待开始 | xiongweiluo |
| O8-04 | 待开始 | xiongweiluo |

## 版本矩阵

| 范围 | 提交或证据 | 状态 |
|---|---|---|
| 当前业务代码基线 | 968382b | #46、#48、#49 已通过门禁并合入 |
| dev 已集成范围 | #46、#48、#49 | 演示修复、依赖审计修复、受控浏览器测试、快照保护和 AI 重试；后续文档提交不改变此业务代码基线 |
| main | bb681b6 | 历史版本，未改动 |
| 公开生产 | 现环境待核实 | 不用历史部署记录推断今日可用 |
| 集成 PR | #46 | 已合并；未部署 |

## 首批独立修复证据

| 内容 | 本地提交与证据 | 仍未覆盖 |
|---|---|---|
| 失败快照保护 | [PR #48](https://github.com/peilinpeng/family-garden-dev/pull/48)，已合并为 `09a8af1`：Data Gateway 54/54；全量 27/27；Web 导出通过，PCK 73,628,724 bytes；CI 41558303477、41558330785 均通过 | 1000 条上限、并发快照一致性、云端故障注入 |
| 不可重试错误 | [PR #49](https://github.com/peilinpeng/family-garden-dev/pull/49)，已合并为 `968382b`：AI Node 37/37；400 只调用一次，503 保持有界重试；CI 41558332294、41558365855 均通过 | 总请求时限、取消、跨实例配额 |
| 家庭身份设计 | [72 设计草案](72_family_identity_and_migration_design.md) | 未实现或迁移；需要响应丢失恢复验证、旧 owner 盘点和备份恢复 |

以上测试均使用本地／合成数据。未执行真实云端 smoke、真机完整流程或家庭试用，不计作完成。

## 本批修改文件与影响范围

既有演示提交只评审与集成；本轮新增修改如下，均由独立 PR 留存差异。

| 范围 | 文件清单 | 影响 |
|---|---|---|
| 单人规则与导航（#47） | `AGENTS.md`、`docs/README.md`、`docs/dev/37_role_boundaries_and_grey_zones.md`、`docs/dev/44_current_handoff.md` | 当前负责人、历史状态提示及文档入口 |
| 计划与证据（#47） | `docs/dev/70_project_optimization_iteration_plan.md`、`docs/dev/71_optimization_execution_status.md`、`docs/dev/72_family_identity_and_migration_design.md`、`backend/cloudbase/README.md` 中身份风险说明 | 43 项路线、进度与未上线的身份迁移设计；更正历史准入说明 |
| 依赖修复（#46） | `backend/ai/package-lock.json`、`backend/cloudbase/data_gateway/package.json`、`backend/cloudbase/data_gateway/package-lock.json` | 服务端传递依赖与 axios override；需部署才影响生产 |
| 浏览器门禁（#46） | `e2e/README.md`、`e2e/fixtures/cloud_unavailable.js`、`e2e/tests/mobile_web.spec.js`、`e2e/tests/web_release.spec.js` | 本地／CI 资源与桥接测试；不改生产配置 |
| 快照服务端（#48） | `backend/cloudbase/README.md`、`backend/cloudbase/data_gateway/index.js`、`backend/cloudbase/data_gateway/tests/data_gateway.test.js` | 查询失败协议与回归覆盖 |
| 快照客户端（#48） | `game/scripts/cloud_service.gd`、`game/scripts/managers/cloudbase_backend.gd`、`game/tests/cloud_snapshot_recovery_test.gd`、其 `.gd.uid` 与 `.tscn` | 同步失败时保留数据与身份就绪时序 |
| AI 重试（#49） | `backend/ai/services/protection.js`、`backend/ai/tests/protection.test.js` | 不可重试异常立即返回；其他重试上限保留 |

验收步骤：

1. 在集成版本执行 `./tools/test_all.sh`、`./tools/check_web_export.sh`；三个服务分别执行 `npm audit --omit=dev --audit-level=moderate`。
2. 按 `e2e/README.md` 构建到空目录并运行浏览器测试；核查四条路径均通过。桌面模拟手机视口不算真机验收。
3. CloudBase 登录且隔离环境恢复后，部署服务端修复再部署客户端；单表读取失败时确认既有记忆不变，恢复后确认成功空表可同步。
4. 身份阶段先核对真实 owner、备份与恢复，按 72 完成接口验证后实施；不直接修改生产身份数据。

## 环境恢复选择

1. 登录后若原环境与数据仍存在，先核实套餐／路由／托管故障原因，导出配置清单和恢复前备份；需费用时提供可审阅方案后确认。
2. 若已经迁移，验证新环境 ID、路由、数据与旧发布记录的对应关系，再统一配置和部署；不能只改一个 URL 宣称完成迁移。
3. 若原环境不可恢复，先核查现有备份可恢复范围，再设计新环境；禁止用演示种子冒充恢复出的真实数据。

## 测量与人工验收登记

| 项目 | 测量定义 | 当前状态 |
|---|---|---|
| 首次可操作时间 | 导航到角色可移动、主要入口可响应；单列用户音频解锁等待 | 待测，冷／热缓存分别至少 5 次 |
| 场景性能 | 同设备记录切场景耗时、帧时间和可观测内存；100／1000／2500 条数据 | 待测 |
| 首次有效交流 | 新用户首次创建记忆或回应，排除演示夹具 | 口径已登记，埋点待 O6 |
| 家庭协作 | 第二成员加入率、记忆回应率、7 天内第二次有效互动 | 口径已登记，分母需按真实试用人数记录 |
| iPhone Safari | 真实设备、系统与浏览器版本、无键盘完整主线 | 设备版本与可用时间待负责人提供 |
| Android Chrome | 至少包含一台非高性能手机 | 设备与可用时间待负责人提供 |
| 桌面 Chromium | 桌面关键路径及双端配对 | 自动化可执行，双端真实行为待 O4 |

## 工时与容量

70 号原先估算仅覆盖系统负责人 41—67 个净工作日，现已说明其不包含全部场景和美术工作。改为单人后不能继续使用旧数字承诺总工期。O0 结束时根据解锁区域现有资产、移动交互适配和设备可用性补估，14 天家庭试用仍为真实观察窗口。

## 阻塞解除条件

- CloudBase：本机登录完成并能只读列出正确地域环境；随后核实生产、隔离测试环境及备份状态。
- 基线集成：已解除；后续 PR 同样要求当前 head 完整门禁，不继承其他提交的通过结论。
- 真实设备与家庭试用：到对应阶段提供设备和自愿参与者；不能自动标记人工验收完成。
