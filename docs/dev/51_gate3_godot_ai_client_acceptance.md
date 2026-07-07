# 51｜Gate 3 Godot AI 客户端验收记录

> 日期：2026-07-07
> 分支：`feature/ai-godot-client`
> 依赖：AI 契约 `1.1.0`、已部署 `ai_gateway`、设备私有 CloudBase 身份
> 状态：本地验收与四个真实 AI 接口全部通过

## 1. 交付范围

- `AIHttpBackend`：CloudBase HTTP、设备身份、超时、HTTP/JSON 错误和取消代次；
- `AIContractValidator`：四接口 request、success/failure envelope、data 与跨记忆语义校验；
- `AIClient`：启动注入、统一状态机、来源/错误元数据、技术 fallback、去重与缓存；
- `SceneManager`：切场景取消旧 AI 回调，现有房间 mock 按钮不发送空图片请求；
- 自动化测试与显式收费真实冒烟脚本。

## 2. 安全边界

- `game/config/ai.json` 只包含公共 endpoint、超时、缓存时间和版本 namespace；
- `member_token` 继续只从 `user://cloud_identity.json` 读取；
- TokenHub API Key、腾讯云 SecretId/SecretKey 不进入 Godot；
- 日志和测试只输出 route、state、source、request ID，不输出令牌、原文或签名 URL；
- `CONTENT_UNSAFE`、鉴权、越权和非法请求不会被 mock 掩盖；
- 缓存只在进程内保存，key 为 SHA-256，不持久化私人原始输入。

## 3. 状态与 fallback

统一状态：

```text
idle → loading → success
               ↘ fallback
               ↘ error
               ↘ cancelled
```

只有 `AI_TIMEOUT / AI_UPSTREAM_ERROR / AI_INVALID_OUTPUT / NETWORK_OFFLINE` 使用客户端
fallback。服务端已经返回合法 `source=fallback` 时客户端保留其 meta。无 backend 时保持离线
可玩；跨记忆离线 fallback 固定空 links，不创建示例 ID 连线。

## 4. 缓存、去重与取消

- 相同 route + payload + `cache_namespace` 生成 SHA-256 key；
- 同 key 并发请求共享一个 ticket，只发送一次 HTTP；
- 记忆卡片、房间分析、跨记忆成功结果使用 5 分钟进程内缓存；
- 漂流瓶问题不缓存，保留每次生成差异；
- 切场景递增请求代次，旧响应即使到达也只进入 `cancelled`，不会写入数据层。

## 5. 自动化验收

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path game --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game \
  --script res://tests/ai_gate3_test.gd
```

覆盖：四类数据验证、非法枚举、房间 zone、跨记忆重复对、1.0 旧请求拒绝、成功包络、
技术 fallback、内容安全不 fallback、离线模式、非法请求短路、嵌套 `ai_card` 扁平化、缓存、
并发合并和取消。

## 6. 真实 CloudBase HTTP 验收

收费测试必须显式设置 `FG_AI_REAL_SMOKE=1`。2026-07-07 已通过 Godot 原生
`HTTPRequest`：

只补测图片接口时同时设置 `FG_AI_ONLY_IMAGE=1` 和临时 `FG_AI_IMAGE_URL`，可避免重复调用
三次文字模型。签名 URL 只作为进程环境变量传入，不写入命令历史、仓库或日志。

| action | request ID | state | source |
|---|---|---|---|
| `generate-memory-card` | `godot_342_26172203` | success | ai |
| `generate-bottle-question` | `godot_6204_1d14e06d` | success | ai |
| `cross-memory-link` | `godot_8998_0c0e8fbd` | success | ai |
| `analyze-room-photo` | `godot_488_1e360693` | success | ai |

图片验收使用 CloudBase 临时下载链接，仅通过进程环境变量传入；链接本身未进入仓库、文档或日志。

## 7. 影响范围与后续边界

Gate 3 只提供通用客户端能力，不在本阶段新增产品 UI 或持久化 AI 草稿。Gate 4 负责真实选图/
上传、用户预览编辑确认，以及四项结果进入 `MemoryManager` / 节点流程。固定 demo 种子继续使用
mock，启动游戏不会自动消耗 AI。
