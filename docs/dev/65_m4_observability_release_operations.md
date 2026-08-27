# 65｜M4 生产可观测性与发布运维闭环

> 日期：2026-08-25；2026-08-27 完成生产日志输出修复并确认 CLS 投递前置条件
>
> 初始分支：`feature/gate8-observability`；修复分支：`feature/m4-log-delivery`
>
> 状态：M4 已上线；Data Gateway 已改走标准输出，完整的按请求 ID 检索等待 CLS 投递授权

## 1. 目标与边界

M4 只补齐线上定位与可重复验收能力，不改变家庭业务规则、集合 Schema、成员权限或客户端
玩法。本阶段交付：

1. `data_gateway` 的服务端生成请求 ID 与脱敏结构化完成日志；
2. `presence-relay` 的匿名连接健康日志；
3. 无凭据、无写入的公开生产核验脚本；
4. 发布、回滚、备份恢复的最小操作规程。

不做：自动部署、自动回滚、生产数据清理、日志中记录照片/令牌/成员身份，或借排障降低
CloudBase 集合权限。

## 2. 日志契约与隐私边界

### 2.1 Data Gateway

`data_gateway` 每次调用都会在响应顶层返回服务器生成的 `request_id`（形如
`gw_<24 位十六进制>`），并写入一条 JSON 日志：

```json
{
  "event": "data_gateway_request_completed",
  "request_id": "gw_…",
  "action": "farm_action",
  "ok": true,
  "code": 200,
  "duration_ms": 18
}
```

失败时仅额外记录稳定的 `error_class`：`invalid_request`、`unauthorized`、`forbidden`、
`not_found`、`conflict` 或 `internal_error`。`action` 只接受服务端白名单；未知输入一律记录
为 `unknown`。请求 ID 不接受客户端 Header，防止把 token 或私人文本伪装为可记录字段。

审计记录优先通过腾讯 SCF Node 运行时的 `console._stdout.write(JSON.stringify(record) + '\n')` 写入日志
采集流；普通 Node 或兼容运行时不提供该流时，回退 `process.stdout.write()`。换行保证一条审计记录对应一条
可检索日志。当前 CloudBase 内置日志视图仍只展示平台 `Report` 行；要在 CLS 中检索自定义标准输出，需要
完成第 7 节记录的独立 CLS 投递配置。

禁止写入：Authorization、member token、家庭/成员 ID、昵称、图片原文或 URL、上传 Base64、
业务记录正文、数据库/SDK 异常原文及任何密钥。

排障时由用户从客户端响应中取得 `request_id`，再到 CloudBase 云函数日志按该 ID 查询；不要
让用户把 token 或私人照片发到聊天、Issue 或日志系统。

### 2.2 Presence Relay

Presence 仅记录连接健康事件：认证成功/失败、无效消息、连接关闭和同成员替换，以及当前连接
数量。日志不记录 token、成员/家庭 ID、昵称、坐标、外观或 `world_changed` 的业务 ID。

这类日志用于判断“服务是否可连接、认证失败是否集中、连接是否异常波动”，而不是回放家庭成员
行为。

## 3. 公开只读核验

执行：

```bash
./tools/verify_production.sh \
  --index-sha256 369634d984e93f43266241fcea907efd64bc7ff3353bb9b093eb5db8024a1590
```

脚本只检查：

- CloudBase 静态托管的 `index.html`、`index.js`、`index.wasm`；
- `index.pck` 是否支持 HTTP Range（仅取 1 byte，避免下载完整大包）；
- 可选的 `index.html` SHA-256；
- `presence-relay/healthz` 是否返回 `{"ok":true}`。

不请求 `data_gateway`，不带成员 token，不创建测试家庭，也不修改任何线上数据。Cloud Run 可能在
首次请求冷启动，健康检查失败时脚本会等待后重试一次。

当前生产静态入口：

```text
https://familygarden-d7gy18huh87fd41d2-1449262000.tcloudbaseapp.com/
```

## 4. 发布规程

### 4.1 发布前

1. 在独立 `feature/*` 分支完成修改，不直接提交或回退 `main`；
2. 执行 `git diff --check`、对应模块单测、`./tools/test_all.sh`、生产依赖 critical 审计和
   `./tools/check_web_export.sh`；
3. 在 PR 中记录提交 SHA、变更模块、环境变量/集合变更、费用影响、兼容性与回滚目标；
4. 记录当前线上 `data_gateway` 代码包哈希、Presence revision、静态站点版本与已知可用 Web
   包哈希；
5. 确认部署窗口内无人进行真实 smoke 或集合迁移。

### 4.2 发布顺序

1. 若接口或事务变化，先发布 `data_gateway`；保留现有运行时、内存、超时、HTTP 路由和环境变量；
2. 若实时协议变化，发布 `presence-relay` 新 revision，确认健康检查后再切换流量；
3. 发布 Web 静态包时使用 CloudBase 静态托管的安全备份/校验能力，保留原有 `__auth/` 与
   `cloud-admin/` 路径；
4. 运行本文件第 3 节的只读核验；涉及真实业务写入时，再由负责人明确授权执行最小 smoke；
5. 记录实际版本、时间、验收结果与任何冷启动现象。

详细命令和云端资源位置以 [CloudBase 部署说明](../../backend/cloudbase/README.md) 与
[64 P1 修复记录](64_p1_review_blockers_resolution.md) 为准；不得把长期密钥写入命令历史或仓库。

## 5. 回滚与恢复

### 5.1 应用回滚

- **静态站点**：在 CloudBase 托管控制台选择本次安全发布自动生成的、已验证的上一份备份恢复；
  恢复后重新运行只读核验，并确认入口哈希回到预期版本。
- **Data Gateway**：使用发布前保存的已知可用代码包及其 SHA-256 恢复代码；不得通过回退整个
  Git `main` 或临时开放集合权限来止血。恢复后验证 `whoami`、健康依赖和授权范围内的最小 smoke。
- **Presence Relay**：将流量切回记录的上一正常 revision；确认 `/healthz` 与 WebSocket 最小握手。

任一回滚都需要记录触发原因、恢复版本、开始/结束时间和后续修复分支。首次冷启动 503 需先以
健康检查预热并重试；仅在重复出现或伴随错误日志时按 P1 处理。

### 5.2 数据恢复

本阶段没有迁移或自动数据操作。未来任何集合 Schema、批量修复或删除前必须：

1. 明确集合与精确筛选范围，导出可恢复备份；
2. 在 PR 中给出正向迁移与反向恢复步骤；
3. 由具备控制台权限的人在执行前确认范围；
4. 恢复后做家庭隔离与最小读写验收。

禁止用无筛选的批量删除、回退 `main` 或公开测试令牌作为恢复手段。

## 6. 本轮验收与剩余项

已完成：

- data_gateway 可观测性与脱敏测试；
- Presence Relay 可观测性与本地协议回归；
- 公开 Web/PCK/Presence 健康检查和入口哈希核验；
- 运维发布、回滚、备份边界文档化；
- `data_gateway` 与 Presence Relay 已部署到生产；Presence Relay `007` 已承接 100% 流量；
- 生产控制台已确认 Presence 的无效令牌 smoke 只记录匿名字段。

待后续独立验收：

- 修复发布后，在 CloudBase 控制台按 `request_id` 实际检索一次 Data Gateway 审计行；
- 双设备、双账号的真实 UI 联机验收；
- `dev / test / prod` 分环境与数据备份恢复演练。

## 7. 2026-08-27 Data Gateway 日志可检索性修复

### 7.1 触发原因

M4 首次生产部署后，`data_gateway` 响应中的服务端 `request_id` 正常，但 CloudBase 函数日志页只显示
平台 `Report` 行，未显示 `data_gateway_request_completed` 审计行。将 `console.info` 固定为
`console.log` 和 `process.stdout.write()` 后问题仍然存在。SCF 官方文档还列出 SCF Node 运行时的
`console._stdout.write()`；因此改为优先使用该日志采集流，并保留 `process.stdout` 兼容回退。

### 7.2 已完成的最小代码修复

将审计写入固定为 SCF `console._stdout.write()`（无该流时回退 `process.stdout.write()`），不改变请求处理、
认证、数据读写、响应字段或日志白名单。生产已部署前一轮标准输出修复，函数配置保持 Node.js 18.15、
256 MB、15 秒、`index.main` 不变；无 token 的 `whoami` 调用返回预期 `401` 和新的服务端 `request_id`。

### 7.3 剩余的 CLS 投递前置条件

生产控制台的内置日志页在修复后的实际调用中仍只显示平台 `Report` 行，未显示用户标准输出。已按负责人
授权开通 CLS，并创建主题 `familygarden-data-gateway-audit`（上海、标准存储、30 天、全文与键值索引），
绑定至 CloudBase 日志投递；投递仅覆盖启用后的新日志，且回迁到云开发日志后无法管理 CLS 投递时间段的
日志。

因此，完整验收需要负责人先确认：允许为 `familygarden-d7gy18huh87fd41d2` 绑定指定 CLS 日志主题并接受
可能的日志费用。启用后，以无 token 的 `whoami` 调用验证：响应返回新的 `gw_` 请求 ID，且 CLS 中可按该
ID 找到唯一的 `data_gateway_request_completed` JSON 行；该行不得包含 token、家庭/成员 ID、图片或业务
正文。
