# Gate 4｜四项 AI 产品功能验收

更新：2026-07-08
分支：`feature/ai-gate4`

## 1. 本轮交付

Gate 4 把 Gate 3 的四个通用 AI 接口接入真实产品流程。统一原则是：

```text
用户输入 → 本地校验/图片压缩 → 受控上传 → AI 草稿
        → 用户预览/修改/确认 → 幂等落库 → 场景渲染
```

生成草稿不会创建 `memory`、`node`、`room` 或 `room_object`。只有用户点击确认后才写入；
`workflow_key` 保证重复点击、回调重入和同一草稿二次确认不会生成重复数据。

## 2. 四条产品链路

### 2.1 记忆卡

- 底部新增“记忆”入口；
- 支持仅文字、仅图片、图文组合；
- 标明图片本地压缩、上传、AI 生成阶段；
- 标题、描述、追问和落点场景可在确认前修改；
- AI 来源、模型和 prompt 版本在预览中可追踪；
- 只支持当前已有动态槽位的花园/鱼塘，其他 AI 场景建议安全回落到花园；
- 确认后创建 memory/node，并在后台增量计算跨记忆关联；
- 取消草稿会删除本次尚未使用的云端图片。

### 2.2 漂流瓶

- 进入鱼塘先同步恢复已保存问题，不等待网络；
- 后台异步调用 `generate-bottle-question` 补齐问题；
- 问题文本哈希去重，问题及 AI 元数据保存在 bottle node；
- 回答操作以 bottle ID 幂等，重复提交不会重复创建岸边记忆或 answer；
- 回答后的记忆、互动计数和场景节点走现有持久化接缝。

### 2.3 房间照片

- 房间按钮已移除 `(mock)`；
- 复用桌面 FileDialog 和 Web 原生图片选择桥；
- 本地解码 JPEG/PNG/WebP，限制原图 12 MB、长边 1600，并重编码 JPEG 去除元数据；
- 图片通过 `data_gateway` 写入家庭/成员隔离路径；
- 分析结果先预览，契约非法、未知家具、非法 zone 或无落点家具不会进入数据层；
- 用户确认后才创建 room/room_objects；
- 支持换照片重新分析、删除整个 AI 房间、移动或删除单件家具；
- 持久化保存 `upload_id`，临时 URL 到期后可重新解析。

### 2.4 跨记忆关联

- 新记忆确认后最多筛选 12 条候选；
- 排除自身、已关联和缺少有效 AI 卡片的候选；
- 只接受契约关系枚举和 `confidence >= 0.65` 的结果；
- 规范化双端 ID 生成 `pair_key`，禁止自连接和重复边；
- fallback 返回空关联，不伪造家庭关系；
- 删除记忆会级联删除相关 node、answer 和 memory_link。

## 3. 图片安全与隐私

- `uploads` 集合为 `ADMINONLY`，且不在 data_gateway 通用 CRUD 白名单；
- 上传路径由服务端生成，客户端无法指定；
- 家庭外无法解析 upload ID，只有上传者可删除；
- 服务端只接受 JPEG/PNG/WebP，解码前后均限制 6 MB；
- 客户端不持久化原始 base64，不记录图片内容；
- `image_url` 为十分钟临时 URL，业务记录以 `upload_id` 为长期引用；
- API Key、SecretId、SecretKey、member token 均未写入仓库。

## 4. 自动化验收

```bash
# data_gateway：27 项身份、CRUD、上传与隔离测试
cd backend/cloudbase/data_gateway && npm test

# Gate 3 回归
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path game --script res://tests/ai_gate3_test.gd

# Gate 4 产品工作流
FAMILY_GARDEN_TEST=1 /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path game res://tests/ai_gate4_test.tscn
```

Gate 4 自动化覆盖：三种记忆输入、草稿零写入、重复确认、图片预处理、受控上传、漂流瓶恢复/
回答幂等、房间预览/确认/家具编辑、跨记忆去重与删除级联。

## 5. 线上部署与人工验收

CloudBase 已完成 Gate 4 前置与后端部署：

- 数据库已创建 `uploads` 集合，权限为 `ADMINONLY`；
- `data_gateway` 已更新代码包并执行“保存并安装依赖”；
- `ai_gateway` 无需因 Gate 4 修改。

云端烟测已通过：

| 检查项 | 结果 |
|---|---|
| `whoami` 成员身份校验 | 通过 |
| `upload_image` 上传图片 | 通过，返回 `upload_id` 与十分钟临时 URL |
| `resolve_image` 重新解析临时 URL | 通过 |
| `delete_image` 删除上传图片 | 通过 |

部署后的验收顺序：

1. 运行游戏，分别用仅文字、仅图片、图文组合创建记忆；草稿取消后确认无新节点；
2. 确认一条记忆，重按确认不产生重复节点，重启后仍存在；
3. 进入鱼塘时界面立即可操作，AI 问题随后出现；回答两次只产生一条岸边记忆；
4. 在桌面与 Web 各选择一次房间照片，确认预览后生成房间；重启后位置一致；
5. 移动、删除一件家具；换照片重新分析；删除房间；
6. 断网重复上述入口，确认显示 fallback/错误但不会留下半条数据；
7. 在 CloudBase 日志中用 request ID 核对 AI 调用，不应出现图片 base64、token 或密钥。
