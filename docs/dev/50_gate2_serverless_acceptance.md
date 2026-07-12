# 50｜Gate 2 AI Serverless 验收记录

> 日期：2026-07-05；TokenHub 迁移与云端联调：2026-07-06
> 分支：`feature/garden-mvp-loop`
> 范围：AI Serverless 公共基础设施
> 结论：实现、本地验收与四项真实云端联调全部通过

---

## 1. 交付范围

本轮新增独立 `backend/ai/` 云函数，不修改已经上线的 CloudBase `data_gateway`，不修改 Godot 客户端，不写入线上数据。

已实现：

- 一个 CloudBase `index.main` 入口；
- 四个 action / route；
- TokenHub 混元文字与图片 provider；
- TMS 文本和 IMS 图片审核；
- 四套独立 prompt 与版本号；
- Gate 1 Schema 的 AJV 严格校验；
- JSON / Markdown JSON 提取；
- 一次修复重采样；
- 技术失败安全 fallback；
- data_gateway `whoami` 身份复用；
- 限流、并发、幂等、超时、重试、退避和熔断；
- 日志脱敏；
- dev / test / production 配置保护；
- 部署、配置、测试和运维说明。
- 可复现部署构建器：自动打包运行代码、Schema 与 Gate 1 fallback，不复制密钥或测试依赖。

## 2. 官方接口与 SDK 基线

2026-07-06 复核腾讯云官方迁移公告后，模型调用由旧混元 SDK 迁移到 TokenHub；TMS/IMS
继续使用腾讯云官方 SDK：

| 能力 | 包 | 锁定版本 |
|---|---|---:|
| 混元文字/图片 | TokenHub OpenAI 兼容 HTTPS API | `v1/chat/completions` |
| 文本内容安全 | `tencentcloud-sdk-nodejs-tms` | 4.1.257 |
| 图片内容安全 | `tencentcloud-sdk-nodejs-ims` | 4.1.257 |
| JSON Schema | `ajv` | 8.20.0 |

TokenHub 使用 Bearer API Key 和非流式 OpenAI Chat Completions。文字模型 `hy3-preview`
携带由 Gate 1 Schema 派生的 `response_format.json_schema`；图片模型
`hy-vision-2.0-instruct` 使用一个 `image_url` 与一个 `text`。模型名称由部署环境提供，
便于质量验收后替换。旧 `tencentcloud-sdk-nodejs-hunyuan` 已从生产依赖移除。

TMS 输入为 UTF-8 Base64；IMS 输入为 HTTPS `FileUrl`。审核 `Suggestion` 非 `Pass` 时 fail-closed。

## 3. 测试结果

执行：

```bash
cd backend/ai
npm ci
npm test
npm audit --omit=dev
```

2026-07-06 TokenHub 迁移复验：Node 自动测试 32/32 通过，Gate 1 契约测试通过，生产依赖
审计 0 漏洞，独立部署目录完成 `npm ci --omit=dev` 并可正常加载。

覆盖范围：

- 四个路由正常返回；
- 文字与图片 TokenHub 请求形状、Bearer 认证与结构化输出；
- TokenHub 401/403、429、5xx、超时、截断与非 JSON 响应；
- 上游超时与限流；
- 模型空文本；
- Markdown JSON；
- 缺字段与非法枚举；
- 输入超长与请求体限制；
- 六类本地安全前置规则；
- TMS/IMS Pass、Review、Block；
- 输出不安全；
- 密钥缺失；
- 重复 request ID 与内容冲突；
- 修复重采样与 fallback；
- 重试、并发、熔断；
- 日志脱敏；
- 跨记忆自连、越界 ID、同一无序记忆对重复连线；
- 跨记忆技术降级不生成带示例 ID 的假连线；
- 上游阶段与错误码可诊断，但不记录上游消息或凭据。

测试不连接真实腾讯云，不产生模型或审核费用。TokenHub HTTPS transport 与腾讯云审核 SDK
均通过注入 fake 实现验证字段。

## 4. 安全结论

- 仓库不含真实 SecretId、SecretKey、member_token 或模型 Key；
- `.env.example` 只有变量名和空值；
- production 禁止 `AUTH_MODE=disabled` 和 `SAFETY_MODE=local`；
- Authorization 不进入普通日志；
- 用户原文和 prompt 不进入普通日志；
- 图片 URL 日志去掉查询参数；
- 内容不安全、鉴权失败和非法请求不允许 fallback；
- 图片 URL 拒绝 HTTP、本机与常见私网地址，降低 SSRF 风险；
- npm 通过 override 使用已修复的 `uuid`，生产依赖审计为 0 漏洞。
- TokenHub API Key 与仅限 TMS/IMS 的子用户 SecretId/SecretKey 分离；
- production 缺少身份网关、模型、TokenHub Key 或审核凭据时启动即失败。

## 5. CloudBase 与身份边界

AI 云函数不访问 `members` 集合，也不复制成员解析逻辑。它把原 Authorization 转发给 `data_gateway` 的 `whoami`，只接收 `member_id/family_id/role`。

当前 AI 接口只根据用户随请求提供的数据生成结果，不读取或写入其他家庭记录。Gate 3 负责 Godot HTTP 客户端，Gate 4 才接产品数据写入流程。

## 6. fallback 策略

允许 fallback：

- `AI_TIMEOUT`；
- `AI_UPSTREAM_ERROR`；

禁止 fallback：

- `INVALID_REQUEST`；
- `UNAUTHORIZED / FORBIDDEN`；
- `CONTENT_UNSAFE`；
- `AI_INVALID_OUTPUT`（二次结构校验失败，交给 Gate 3 决定客户端 fallback）；
- `INTERNAL_ERROR`（尤其是密钥或模型配置缺失）。

fallback 自身仍需通过相同 Schema 和输出安全检查，并记录 `fallback_reason`。
`cross-memory-link` 的技术 fallback 固定返回空 `links`，不复用示例记忆 ID。

## 7. 已知限制

1. 进程内限流、幂等和熔断只覆盖单个热实例；生产需叠加 CloudBase/API 网关层限流。
2. TokenHub transport 由本层超时保护；平台层仍需将函数超时设为大于 `AI_TIMEOUT_MS`。
3. 本地关键词检查是前置防线，不替代腾讯 TMS/IMS；production 已强制使用腾讯审核。
4. TokenHub Key 授权范围、真实模型质量、账号计费、TMS/IMS 策略和 CloudBase HTTP 路由必须在部署账号中确认。
5. CloudBase 当前以统一 JSON 包络表达错误；若平台层需要非 200 HTTP 状态，应在 HTTP 访问服务映射层配置，不能改变业务包络。

## 8. 真实环境验收进度

已在 CloudBase 环境 `familygarden-d7gy18huh87fd41d2` 独立部署 `ai_gateway`，并保留原
`data_gateway`。HTTP 路由为 `/ai_gateway`；环境 ID 与公共路由可记录，密钥和成员 token
均未写入仓库或本文。

真实调用结果：

| action | request ID | 结果 | 备注 |
|---|---|---|---|
| `generate-memory-card` | `real-memory-card-20260706-001` | 通过 | `hy3-preview`，Schema 与内容安全通过 |
| `generate-bottle-question` | `real-bottle-20260706-002` | 通过 | 合法场景枚举 `fishpond`；首次错误值 `pond` 被契约正确拒绝 |
| `cross-memory-link` | `real-memory-link-v3-20260706-001` | 通过 | 契约 `1.1.0` 提供新记忆完整内容；`memory-link-v3` 只返回一条最强关系，字段与 ID 均通过语义校验 |
| `analyze-room-photo` | `real-room-analysis-v4-20260706-002` | 通过 | CloudBase 云存储图片通过 IMS；`hy-vision-2.0-instruct` + `room-analysis-v2` 返回合法房型、主题、物件和 zone |

四项真实输出均通过对应 Schema，provider 为 TokenHub。联调过程中所有非法请求、重复关联、
缺字段和非法枚举均被服务端拦截，没有半成品进入游戏，也没有用 fallback 掩盖内容安全失败。
最终云端只更新了 `ai_gateway`；`data_gateway`、HTTP 路由和环境变量保持不变。

2026-07-11 再次完成真实生产复测并更新 `ai_gateway`、`data_gateway` 代码，HTTP 路由与环境变量保持不变：

- `moderate-user-content` 通过腾讯内容安全，审核路由可用；
- `memory-card-v3` 将追问从复述原文改为补充感官、对话和后续细节；
- `bottle-question-v3` 不再根据 `fishpond` 游戏场景虚构现实中的鱼池经历；
- `memory-link-v4` 只保留有文本证据的最强关系；
- `room-analysis-v4` 通过受控 `upload_id` 解析图片，忽略界面叠层并在物件不确定时优先省略；
- 真实 HTTP 入口验证约 78 KiB JPEG 经 Base64 后会被平台 413 拒绝，因此客户端改为自适应压缩到 40 KiB；20 KiB、480×317 测试图上传、视觉推理和删除均通过。

图片来源验收还确认：Wikimedia 与 GitHub Raw 链接在 IMS 侧返回 `IMS_IMAGE_FETCH_FAILED`，
CloudBase 云存储临时 HTTPS 链接可稳定通过。生产图片应使用 CloudBase/COS/CDN 等腾讯可达
存储，并确保签名链接在整个审核与推理窗口内有效；临时链接过期时客户端应重新获取。

2026-07-06 首次创建函数时确认 CloudBase 禁止自定义环境变量使用 `TENCENTCLOUD_`、
`SCF_` 或 `QCLOUD_` 保留前缀。内容安全凭据已统一改为 `CONTENT_SAFETY_SECRET_ID`、
`CONTENT_SAFETY_SECRET_KEY` 与 `CONTENT_SAFETY_REGION`，并重新完成本地测试和部署构建。

同日确认原线上 `data_gateway` 版本缺少 `join_family`。更新为仓库当前版本后，带非法参数的
无副作用探针正确返回 `family_id required, role must be one of father/mother/partner/player`；
Godot 随后生成本地 `cloud_identity.json`，`whoami` 返回测试家庭 `family1`、角色 `partner`。

## 9. 影响范围

- 新增：`backend/ai/` Serverless 实现、测试和部署说明；
- 更新：Gate 1 条件 Schema 的 AJV 严格兼容标注、`.gitignore`、Gate 2 计划状态；
- 更新：Godot CloudBase 公共配置与已有离线角色的一次性云身份迁移；
- 云端更新：`data_gateway` 当前仓库版本、独立 `ai_gateway` 与其 HTTP 路由；
- 未修改：场景、美术资源与线上业务集合数据。
