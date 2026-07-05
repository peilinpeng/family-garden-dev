# 05｜后端数据模型与存储设计

## 1. 设计原则

Family Garden 比赛版本不需要重后端，也不需要复杂实时多人系统。

推荐架构：

```text
游戏前端
↓
轻量数据库
↓
对象存储，用于图片和游戏资源
↓
Serverless AI 中转
↓
AI 模型服务
```

核心原则：

1. AI 不直接暴露给前端；
2. 图片和资源可以放腾讯云 COS/CDN；
3. 数据库保持简单；
4. 每个 AI 功能都有 mock/fallback；
5. 不为了“架构完整”牺牲交付稳定性。

---

## 2. 当前技术组合

项目已经从早期 Supabase 暂留方案切换为 CloudBase 主存储。以下是当前真实基线，不再是候选方案：

| 模块 | 推荐方案 |
|---|---|
| 游戏引擎 | Godot 4.7 |
| 游戏包托管 | 腾讯云 COS + CDN |
| 用户上传图片 | 腾讯云 COS |
| AI 中转 | 腾讯云云函数 / Serverless Function |
| 数据库 | CloudBase 云数据库（已部署） |
| 数据网关 | CloudBase 云函数 `data_gateway`（已部署） |
| 成员身份 | 每成员 `member_token`，由服务端解析家庭和成员身份 |
| 实时移动 | 尚未接入；后续使用轻量 WebSocket 中继 |
| 本地兜底 | mock JSON + 预设图片 |

Godot 通过 HTTP 调用 `data_gateway`，不直接访问数据库 SDK。已上线集合包括
`members / families / memories / nodes / answers / rooms / room_objects / inventories`。
`travel_places / postcards / messages / mailbox_events` 仍保留旧读路径，统一迁移属于 Gate 5，
不在 Gate 1 修改线上数据。

身份原则：除自助加入外，`family_id`、`member_id`、`created_by` 等归属字段必须由服务端
根据 Authorization 中的成员身份派生，不能信任客户端请求体中的同名字段。

---

## 3. 最小数据表设计

比赛版本建议使用简化数据模型。

### 3.1 families

存家庭空间。

| 字段 | 类型 | 说明 |
|---|---|---|
| id | string | 家庭 ID |
| name | string | 家庭名称 |
| invite_code | string | 邀请码 |
| created_by | string | 创建者 user_id |
| created_at | timestamp | 创建时间 |

### 3.2 members

存家庭成员。

| 字段 | 类型 | 说明 |
|---|---|---|
| id | string | 成员记录 ID |
| family_id | string | 所属家庭 |
| user_id | string | 用户 ID |
| display_name | string | 显示名称 |
| role | string | owner / member / guest |
| avatar_url | string | 头像 |
| character_type | string | 角色类型 |
| created_at | timestamp | 加入时间 |

比赛版可简化为预设成员。

### 3.3 memories

核心表，存用户上传的原始记忆和 AI 结果。

| 字段 | 类型 | 说明 |
|---|---|---|
| id | string | 记忆 ID |
| family_id | string | 家庭 ID |
| user_id | string | 上传者 |
| input_type | string | photo / room_photo / text / postcard / bottle_answer |
| raw_text | text | 用户输入文字 |
| image_url | string | 图片地址 |
| status | string | uploaded / ai_processing / ai_done / ai_failed / published |
| ai_card | json | AI 生成的记忆卡片 |
| created_at | timestamp | 创建时间 |
| updated_at | timestamp | 更新时间 |

### 3.4 nodes

地图上的可点击节点。

| 字段 | 类型 | 说明 |
|---|---|---|
| id | string | 节点 ID |
| family_id | string | 家庭 ID |
| memory_id | string | 关联记忆 |
| scene_id | string | garden / fishpond / farm / room / old_street / travel_area |
| node_type | string | memory_flower / bottle / photo_board / room_object / postcard |
| asset_key | string | 对应美术资产 |
| slot_id | string | 场景槽位 ID |
| state | string | new / read / answered / grown |
| clickable | boolean | 是否可点击 |
| created_at | timestamp | 创建时间 |

注意：AI 不输出坐标。`slot_id` 由游戏系统分配。

### 3.5 bottles

漂流瓶问题。

| 字段 | 类型 | 说明 |
|---|---|---|
| id | string | 漂流瓶 ID |
| family_id | string | 家庭 ID |
| scene_id | string | 通常为 fishpond 或 garden |
| question | text | 问题 |
| created_by | string | user_id 或 ai |
| created_by_ai | boolean | 是否 AI 生成 |
| target_memory_type | string | shared_memory / childhood / travel 等 |
| status | string | floating / opened / answered / archived |
| created_at | timestamp | 创建时间 |

### 3.6 answers

漂流瓶或记忆卡片的回答。

| 字段 | 类型 | 说明 |
|---|---|---|
| id | string | 回答 ID |
| family_id | string | 家庭 ID |
| bottle_id | string | 可选，关联漂流瓶 |
| memory_id | string | 可选，关联记忆卡 |
| user_id | string | 回答者 |
| answer_text | text | 回答内容 |
| created_at | timestamp | 回答时间 |

### 3.7 rooms

个人房间。

| 字段 | 类型 | 说明 |
|---|---|---|
| id | string | 房间 ID |
| family_id | string | 家庭 ID |
| user_id | string | 房间所属成员 |
| room_name | string | 房间名称 |
| room_type | string | bedroom / study / living_room 等 |
| style | string | warm_cozy / simple / nostalgic 等 |
| background_asset | string | 背景资产 key |
| created_at | timestamp | 创建时间 |

### 3.8 room_objects

房间中的物件。

| 字段 | 类型 | 说明 |
|---|---|---|
| id | string | 物件 ID |
| room_id | string | 房间 ID |
| object_type | string | desk / lamp / plant 等 |
| asset_key | string | 对应资产 |
| slot_id | string | 房间槽位 |
| clickable | boolean | 是否可点击 |
| collision | boolean | 是否碰撞 |
| source_memory_id | string | 来源记忆 |
| created_at | timestamp | 创建时间 |

### 3.9 契约 v1 公共元数据

新建或由 AI 更新的业务记录逐步补充以下字段。为兼容现有 CloudBase 线上数据，全部采用增量字段：旧记录缺失时按默认值读取，不清库、不要求一次性回填。

| 字段 | 默认/来源 | 说明 |
|---|---|---|
| schema_version | 新记录为 `1`；旧记录按 `0` | 数据结构版本，不等同于 prompt 版本 |
| created_by | 服务端解析的 `member_id` | 客户端传入值必须忽略 |
| created_at | 服务端时间优先 | 旧客户端时间继续兼容读取 |
| updated_at | 服务端时间优先 | 记录最近一次有效更新 |
| request_id | AI Serverless 生成或透传 | 串联一次生成和持久化 |
| generation_source | `ai / fallback / manual` | 区分真实生成、兜底和人工输入 |
| provider | AI Serverless 写入 | 例如 `hunyuan`；非 AI 记录可为空 |
| model | AI Serverless 写入 | 实际模型版本；非 AI 记录可为空 |
| prompt_version | AI Serverless 写入 | 例如 `memory-card-v1` |
| version | 共享可变记录从 `1` 开始 | 优先用于共享仓、共享世界状态等冲突敏感记录 |

删除策略：MVP 延续现有硬删除。没有审计、恢复或合规需求前不新增 `deleted_at`；若后续引入软删除，必须升级 `schema_version` 并让所有默认查询过滤已删除记录。

幂等策略：AI 请求使用 `request_id`；业务写入继续使用稳定记录 `id`。Gate 2 的 AI Serverless 应拒绝同一 `request_id` 对不同请求内容的复用。CloudBase 通用 CRUD 的幂等与乐观锁增强留到 Gate 5。

---

## 4. 数据生命周期

### 4.1 上传照片到生成节点

```text
用户上传照片
↓
图片上传到 COS
↓
创建 memories 记录，status = uploaded（归属字段由服务端写入）
↓
调用 AI 中转，status = ai_processing
↓
AI 返回 ai_card，status = ai_done，并记录生成来源与模型元数据
↓
游戏读取 ai_card.suggested_scene 和 ai_card.node_type
↓
创建 nodes 记录
↓
地图显示节点
```

### 4.2 漂流瓶回答生成新记忆

```text
用户打开漂流瓶
↓
用户回答问题
↓
创建 answers 记录
↓
可选：创建新的 memories 记录，input_type = bottle_answer
↓
AI 整理回答
↓
生成新节点
```

### 4.3 房间照片生成房间物件

```text
用户上传房间照片
↓
创建 memories 记录，input_type = room_photo
↓
AI 分析房间照片
↓
创建 rooms 记录
↓
根据 AI objects 创建 room_objects
↓
游戏显示个人房间
```

---

## 5. 腾讯云 COS/CDN 使用建议

### 5.1 可以迁移到 COS/CDN 的内容

- 游戏 Web 构建包；
- 用户上传照片；
- 美术静态资源；
- 示例图片；
- 演示视频或截图。

### 5.2 不建议一开始迁移的内容

- 结构化数据库，如果当前 Supabase 可用；
- 用户系统，如果当前已经跑通；
- 所有后端逻辑。

### 5.3 上传建议

生产环境建议使用预签名 URL：

```text
前端请求云函数获取上传 URL
↓
云函数生成 COS 预签名 URL
↓
前端直接上传图片到 COS
↓
前端/云函数记录 image_url 到数据库
```

比赛版如果时间不足，可以先用后端中转上传或预设图片兜底。

---

## 6. Serverless AI 中转

AI Key 不应放前端。

推荐流程：

```text
游戏前端
↓
/api/ai/generate-memory-card
↓
云函数读取 image_url 和 text
↓
调用 AI 模型
↓
校验 JSON
↓
写入 memories.ai_card
↓
返回前端
```

云函数负责：

- 隐藏 API Key；
- 拼接 prompt；
- 校验 AI 输出；
- 清洗字段；
- 失败时返回 mock 数据；
- 写入数据库或返回结果。

---

## 7. 后端 MVP 验收标准

后端最小可用版本需要做到：

1. 图片能上传并返回 URL；
2. memory 能创建；
3. AI 卡片能保存；
4. node 能根据 memory 生成；
5. bottle 能创建和回答；
6. room 能根据 AI 输出生成基础物件；
7. 失败时能使用 mock 数据；
8. 刷新页面后演示数据不丢失，或至少有本地演示兜底。
