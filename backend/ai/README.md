# Family Garden AI Serverless

四项 AI 能力的独立 CloudBase 云函数：

- `generate-memory-card`
- `generate-bottle-question`
- `analyze-room-photo`
- `cross-memory-link`

本目录不替代已经上线的 `backend/cloudbase/data_gateway/`。AI 函数通过 `data_gateway` 的 `whoami` 复用成员身份；业务数据 CRUD 仍由原网关负责。

## 1. 运行架构

```text
Godot（Gate 3 接入）
  → AI HTTP 云函数
      → data_gateway/whoami 校验 member_token
      → TMS/IMS 输入审核
      → TokenHub OpenAI Chat Completions
      → JSON 提取 + Gate 1 Schema 校验
      → TMS 输出审核
      → 统一响应或安全 fallback
```

实现职责：

| 目录/文件 | 职责 |
|---|---|
| `index.js` | CloudBase `main` 入口、HTTP 基础校验、统一错误输出 |
| `router.js` | 四路编排、修复重采样、fallback |
| `providers/tokenhub.js` | TokenHub OpenAI 兼容接口适配 |
| `prompts/` | 四套独立、带版本号的 prompt |
| `schemas/` | Gate 1 JSON Schema 真源 |
| `validators/` | AJV 校验、可靠 JSON 提取与跨记忆语义约束 |
| `safety/` | 本地前置策略 + 腾讯 TMS/IMS 审核 |
| `services/` | 身份、限流、并发、幂等、重试、熔断 |
| `tests/` | 契约、集成、provider、安全和保护机制测试 |

## 2. 本地验证

要求 Node.js 18+。

```bash
cd backend/ai
npm ci
npm test
npm audit --omit=dev
```

Gate 1 Python 契约测试需先安装：

```bash
python3 -m pip install -r backend/ai/tests/requirements.txt
python3 backend/ai/tests/validate_contracts.py
```

Node 测试使用注入的 fake provider、身份服务和审核客户端，不调用真实模型、CloudBase 或收费内容安全接口。

## 3. 环境变量

复制 `.env.example` 的字段到 CloudBase 云函数环境变量。不要创建含真实密钥的可提交文件。

生产必填：

| 变量 | 说明 |
|---|---|
| `NODE_ENV=production` | 启用生产保护 |
| `AUTH_MODE=gateway` | 通过现有 data_gateway 鉴权 |
| `SAFETY_MODE=tencent` | 使用 TMS/IMS 审核 |
| `DATA_GATEWAY_URL` | 已部署 data_gateway 的 HTTPS 地址 |
| `TOKENHUB_BASE_URL` | 境内固定为 `https://tokenhub.tencentmaas.com/v1` |
| `TOKENHUB_API_KEY` | TokenHub 联调或生产 Key，只存云函数环境变量 |
| `CONTENT_SAFETY_SECRET_ID` | 仅供 TMS/IMS 使用的腾讯云子用户凭据 |
| `CONTENT_SAFETY_SECRET_KEY` | 仅供 TMS/IMS 使用的腾讯云子用户凭据 |
| `CONTENT_SAFETY_REGION` | 默认 `ap-shanghai` |
| `HUNYUAN_TEXT_MODEL` | 当前选用 `hy3-preview` |
| `HUNYUAN_VISION_MODEL` | 当前选用 `hy-vision-2.0-instruct` |

可选：`TMS_BIZ_TYPE`、`IMS_BIZ_TYPE`。使用自定义内容安全策略时填写控制台策略编号；否则调用账号默认策略。

推荐填写已创建的 `family_garden_text` 与 `family_garden_image`。模型名称仍由部署环境显式配置，
便于验收不达标时替换；部署前须在 TokenHub 控制台确认 Key 授权范围、计费和模型可用性。

`AUTH_MODE=disabled` 或 `SAFETY_MODE=local` 仅允许 test，或在非 production 环境显式设置 `ALLOW_INSECURE_LOCAL=true`。production 会直接拒绝启动。

## 4. CloudBase 部署

1. 在 CloudBase 新建独立云函数，例如 `ai_gateway`，Node.js 18 运行时；
2. 在 `backend/ai/` 执行 `npm run build:deploy`；
3. 上传生成的 `backend/ai/dist/`，入口设置为 `index.main`；
4. 平台使用 dist 中的 lockfile 安装生产依赖；
5. 配置第 3 节环境变量，不把密钥放进代码包；
6. 为函数绑定 HTTP 访问服务；
7. 平台层设置请求体上限、并发上限、调用频率和超时；
8. 用测试家庭 member_token 对四个路由做一次真实联调；
9. 确认日志中没有 Authorization、用户原文、签名 URL 查询参数或上游原始响应。

`build:deploy` 会从 `backend/mocks/` 复制四个 Gate 1 mock 到 dist，仅用于部署打包；源文件仍是唯一真源。dist 被 `.gitignore` 排除，不提交构建产物。

入口同时支持两种路由方式：

```text
POST /api/ai/generate-memory-card
```

或在单一 CloudBase HTTP 路由无法保留子路径时：

```json
{
  "action": "generate-memory-card",
  "memory_id": "mem_001",
  "input_type": "text",
  "raw_text": "一次家庭旅行",
  "language": "zh-CN"
}
```

身份只放在 `Authorization: Bearer <member_token>`，请求体不得放 `family_id`、`created_by` 或云服务密钥。

## 5. TokenHub、混元与内容安全

混元新模型通过 TokenHub 的 OpenAI 兼容接口调用：

- `https://tokenhub.tencentmaas.com/v1/chat/completions`；
- `Authorization: Bearer <TOKENHUB_API_KEY>`；
- `hy3-preview`：三个文字接口，并携带由 Gate 1 response Schema 派生的数据 Schema；
- `hy-vision-2.0-instruct`：单张房间图片理解，结果继续经过 Gate 1 Schema 二次校验；
- 非流式请求，文字最大输出默认 16384 tokens，视觉默认 4096 tokens。

内容安全继续使用官方腾讯云 SDK：

- `tencentcloud-sdk-nodejs-tms`：用户文字与模型文字输出审核；
- `tencentcloud-sdk-nodejs-ims`：图片输入审核。

TokenHub Key 与腾讯云子用户 SecretId/SecretKey 不得混用。图片请求包含一个 `text` 和一个
`image_url` content。TMS 文本按官方要求使用 UTF-8 Base64；IMS 使用 HTTPS `FileUrl`。
变量名不使用 CloudBase 保留的 `TENCENTCLOUD_`、`SCF_` 或 `QCLOUD_` 前缀。

审核建议为 `Review` 或 `Block` 时统一返回 `CONTENT_UNSAFE`，不会把用户内容送给模型，也不会用 mock 掩盖。审核服务自身不可用时采用 fail-closed：返回上游错误，不绕过审核。

## 6. fallback 与错误

仅以下技术失败允许返回通过同一 Schema 的 fallback：

- `AI_TIMEOUT`
- `AI_UPSTREAM_ERROR`

鉴权、越权、非法请求、内容不安全、服务配置错误不会被 fallback 掩盖。fallback 响应包含 `source=fallback` 和 `fallback_reason`。

模型首次返回无法解析或不符合 Schema 时，会附带约束提示重采样一次；第二次失败返回 `AI_INVALID_OUTPUT`，由 Gate 3 客户端状态机决定是否使用本地 fallback。

跨记忆结果还会校验三条业务语义：不得自连、不得引用本次输入之外的 `memory_id`、同一无序
记忆对最多一条连线。技术故障降级时返回空 `links`，不会把 mock 中的示例 ID 写入真实花园。
跨记忆请求必须同时提供新记忆的标题、描述和类型；仅提供 ID 无法进行内容比较，会按非法请求拒绝。

## 7. 服务保护和运维

- 进程内按成员限流；
- 进程内并发上限；
- 同一 request ID 幂等合并，不同内容冲突；
- 上游超时、有限重试和指数退避；
- 连续失败熔断；
- 日志只保留 request ID、route、错误码、来源和耗时；上游失败仅额外记录脱敏后的阶段与错误码，
  不记录上游消息、用户内容或凭据。

云函数可能多实例扩容，因此进程内限流、幂等和熔断不是全局强一致。生产必须同时配置 CloudBase/API 网关层限流；需要跨实例强幂等时再引入短期共享存储。

建议普通应用日志保留 7 天，安全审计日志按团队策略单独配置；不得记录私人原文、完整图片 URL 查询参数或令牌。

## 8. 未在本地自动完成的动作

以下动作需要腾讯云账号和可能产生费用，不由代码测试代替：

- 开通 TokenHub 并确认文字与图片模型授权范围；
- 开通 TMS/IMS 并配置策略；
- 设置真实环境变量；
- 部署 CloudBase 云函数与 HTTP 访问服务；
- 使用测试家庭账号做真实端到端调用。

这些不是缺失代码，但在正式发布前必须按第 4 节人工验收。
