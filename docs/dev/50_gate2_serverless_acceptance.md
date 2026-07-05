# 50｜Gate 2 AI Serverless 验收记录

> 日期：2026-07-05
> 分支：`feature/garden-mvp-loop`
> 范围：AI Serverless 公共基础设施
> 结论：本地测试环境通过，可进入 Gate 3；真实腾讯云联调待配置环境后执行

---

## 1. 交付范围

本轮新增独立 `backend/ai/` 云函数，不修改已经上线的 CloudBase `data_gateway`，不修改 Godot 客户端，不写入线上数据。

已实现：

- 一个 CloudBase `index.main` 入口；
- 四个 action / route；
- 混元文字与图片 provider；
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

## 2. 官方 SDK 基线

实现前直接核对了腾讯云官方 npm 包及类型定义：

| 能力 | 包 | 锁定版本 |
|---|---|---:|
| 混元 | `tencentcloud-sdk-nodejs-hunyuan` | 4.1.188 |
| 文本内容安全 | `tencentcloud-sdk-nodejs-tms` | 4.1.257 |
| 图片内容安全 | `tencentcloud-sdk-nodejs-ims` | 4.1.257 |
| JSON Schema | `ajv` | 8.20.0 |

混元使用非流式 `ChatCompletions`。文字消息使用 `Message.Content`；图片消息使用 `Message.Contents`，包含 `Type=text` 和 `Type=image_url`。模型名称不写死，由部署环境提供。

TMS 输入为 UTF-8 Base64；IMS 输入为 HTTPS `FileUrl`。审核 `Suggestion` 非 `Pass` 时 fail-closed。

## 3. 测试结果

执行：

```bash
cd backend/ai
npm ci
npm test
npm audit --omit=dev
```

覆盖范围：

- 四个路由正常返回；
- 文字与图片混元请求形状；
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
- 日志脱敏。

测试不连接真实腾讯云，不产生模型或审核费用。官方 SDK 请求通过注入 fake client 验证字段。

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

## 7. 已知限制

1. 进程内限流、幂等和熔断只覆盖单个热实例；生产需叠加 CloudBase/API 网关层限流。
2. Promise 超时不能主动取消腾讯 SDK 已发出的底层请求，但结果会被丢弃；SDK 自身同时配置请求超时。
3. 本地关键词检查是前置防线，不替代腾讯 TMS/IMS；production 已强制使用腾讯审核。
4. 真实模型名、账号权限、计费、TMS/IMS 策略和 CloudBase HTTP 路由必须在部署账号中确认。
5. CloudBase 当前以统一 JSON 包络表达错误；若平台层需要非 200 HTTP 状态，应在 HTTP 访问服务映射层配置，不能改变业务包络。

## 8. 真实环境待验收

以下动作需要腾讯云账号、环境变量并可能产生费用，本轮没有擅自执行：

- 开通或确认混元文字/图片模型；
- 开通 TMS/IMS，确认 BizType；
- 部署 `ai_gateway` 云函数；
- 配置 HTTP 访问服务和平台级限流；
- 使用测试家庭 member_token 调四个真实接口；
- 检查真实日志脱敏与计费。

完成这些动作后记录 endpoint、模型、策略版本和真实 request ID，不记录任何密钥。

## 9. 影响范围

- 新增：`backend/ai/` Serverless 实现、测试和部署说明；
- 更新：Gate 1 条件 Schema 的 AJV 严格兼容标注、`.gitignore`、Gate 2 计划状态；
- 未修改：`game/`、`backend/cloudbase/data_gateway/`、场景、线上集合和线上数据。
