# 49｜Gate 1 契约决策与兼容迁移

> 日期：2026-07-05
> 契约版本：`1.0.0`
> 状态：已冻结，待 Gate 2 / Gate 3 实现
> 关联：`docs/04_ai_interfaces.md`、`docs/05_backend_data_model.md`、`docs/dev/46_cloudbase_storage_handoff.md`

---

## 1. 本阶段结论

Gate 1 只冻结接口、字段、错误和兼容策略，不重做已上线 CloudBase，不修改线上集合，不部署云函数，也不提前改 Godot 产品流程。

契约真源按以下优先级读取：

1. `backend/ai/schemas/*.schema.json`：机器校验真源；
2. `docs/04_ai_interfaces.md`：人类可读说明；
3. `backend/mocks/*.json`：合法 fallback 数据；
4. 旧场景文档与旧内联 mock：发现冲突时按迁移表处理，不反向覆盖正式契约。

## 2. 现状审计

| 项目 | 当前真实状态 | Gate 1 决策 |
|---|---|---|
| CloudBase 身份 | `member_token` 解析 `family_id/member_id` | 请求体不再接受身份归属字段 |
| CloudBase 通用 upsert | 服务端强制 `family_id`，但尚未强制 `created_by` | `created_by` 定义为服务端字段，网关增强留到 Gate 5 |
| MemoryManager 身份字段 | `user_id` 当前保存角色 key | 作为 legacy 字段兼容；新审计字段使用 `created_by=member_id` |
| 时间字段 | 多数由 Godot 客户端生成 `created_at` | 新契约以服务端时间为准；旧值继续读取 |
| AI 包络 | 当前 AIClient 直接消费裸 payload | Gate 3 新增包络适配，不在 Gate 1 破坏客户端 |
| 漂流瓶 | 文档是对象，AIClient 异步方法返回数组 | 正式接口固定单对象；场景批量种子与网络接口分离 |
| 房间 objects | 旧文档为字符串数组，代码/mock 为对象数组 | 正式固定 `{object_type, zone}` 对象数组 |
| 跨记忆 | AIClient 返回单个关系，旧规划建议 links | 正式固定 `links` 数组，0～3 项 |
| Schema 校验 | AIClient 只判断非空 | Gate 3 增加分接口验证器；Serverless 在 Gate 2 使用同一约束 |
| AI mock | 三个文件 + 四套内联常量，缺 cross-link 文件 | 补齐四个文件并通过统一契约测试 |
| 旧 Supabase 约束 | `nodes.node_type` 未包含 `memory_seed` | CloudBase 当前无该 CHECK；旧 SQL 仅作历史参考，迁移时需同步 |

## 3. 冻结决策

### D1｜身份字段不由客户端声明

AI 请求只带业务 ID 和必要内容，不带 `family_id/user_id/created_by`。服务端通过 Authorization 解析身份，并校验 memory 与候选记录归属。

### D2｜AI 包络与 CloudBase CRUD 协议分离

AI 使用 `{ok,data,error,meta}` 新包络。已部署 `data_gateway` 暂时保留现状，避免为了形式统一破坏真实存储。Gate 3 在客户端分别适配。

### D3｜漂流瓶网络接口返回单对象

路由名为 `generate-bottle-question`，每次只生成一个问题。当前 `mock_bottle_questions()` 仍可作为离线场景种子辅助方法，但不能代表 HTTP 响应类型。

### D4｜房间物件必须带 zone

`objects` 只接受 `{object_type, zone}`。Schema 拒绝字符串数组、坐标、footprint、asset key 和未知字段。真实位置仍由 manifest 与 ZoneManager 决定。

### D5｜跨记忆关联返回 links 数组

一次增量分析最多返回 3 条关联；没有可靠关联时返回空数组，不构造虚假关系。数组结构同时解决“零结果”和“多个结果”的表达问题。

### D6｜空结果与失败分离

- 合法空结果：`ok=true`、`meta.result=empty`；
- 技术或业务失败：`ok=false` + 稳定错误码；
- 上游技术失败但成功使用安全 fallback：`ok=true`、`source=fallback`、`fallback_reason=<错误码>`。

### D7｜新增字段只做向后兼容扩展

线上旧记录缺少 `schema_version/request_id/generation_source/provider/model/prompt_version/version` 时仍可读取。Gate 1 不清库、不批量回填、不要求立即修改网关。

### D8｜当前删除策略明确为硬删除

Gate 1 不引入没有消费者的 `deleted_at`。未来若需要恢复、审计或跨端删除同步，再升级 schema 并整体引入软删除过滤。

### D9｜乐观锁只用于冲突敏感数据

`version` 优先用于共享仓和共享世界状态，不强迫只追加或低冲突记录承担无意义版本字段。具体事务与冲突响应在 Gate 5 实现。

### D10｜AI 生成信息与业务数据分层

`provider/model/prompt_version/source/request_id` 存在于 AI `meta`；持久化时选择性物化到业务记录。它们不应混进每个 AI `data` 对象，也不应出现在纯手工记录中成为必填。

## 4. Gate 2 / Gate 3 迁移清单

### Gate 2：AI Serverless

- 按四组 request Schema 拒绝非法输入；
- 从身份服务解析家庭和成员，不信请求体身份；
- 为每次调用生成或接受合法 `request_id`；
- 模型输出必须通过对应 response data 约束后才能返回；
- 统一生成 `meta`，fallback 标明原因；
- 记录脱敏日志，不记录令牌、完整图片 URL 查询参数或用户原文；
- 内容不安全、越权和无效请求不得被 fallback 掩盖。

### Gate 3：Godot AIClient

- 新增 HTTP backend 并解析统一包络；
- 将单个漂流瓶 `data` 转换为产品流程需要的结构；
- 将 `cross-memory-link.data.links` 逐条交给节点创建流程；
- 为四个 payload 实现与 Schema 等价的轻量验证；
- 保留当前无 backend 时的离线玩法；
- 逐步消除 `backend/mocks` 与内联常量双真源，但不能删除 fallback。

### Gate 5：CloudBase 数据增强

- 通用 upsert 服务端注入 `created_by` 和服务端时间；
- 为冲突敏感记录增加 `version` 与 `DATA_CONFLICT`；
- 迁移 `travel_places/postcards/messages/mailbox_events`；
- 按需回填 `schema_version=0` 或在读取层默认处理；
- 若启用 `memory_seed`，同步修订仍在使用的旧数据库约束。

## 5. 对场景负责人的影响

场景侧不需要修改坐标或 `.tscn`。唯一需要知晓的稳定输入是：

1. 记忆节点仍只消费 `suggested_scene/node_type`，不接收 AI 坐标；
2. 房间物件固定消费 `object_type/zone`；
3. zone 值来自 `zones_room.json` 的键，坐标仍由场景 manifest 决定；
4. 新增枚举或 zone 必须先更新 Schema 和 manifest，再进入场景。

可直接发送的通知文本：

```text
Gate 1 AI 契约已冻结：AI 不输出坐标；房间 objects 统一为 {object_type, zone}；
漂流瓶 HTTP 每次返回一个问题；跨记忆返回 links 数组。场景坐标与现有 .tscn 无需调整。
后续如新增 node_type、object_type 或 zone，请先同步 docs/04、JSON Schema 与 manifest。
```

## 6. 验证

```bash
python3 -m pip install -r backend/ai/tests/requirements.txt
python3 backend/ai/tests/validate_contracts.py
```

通过标准：全部 Schema 自检通过；四组请求样例和四个 mock 通过；非法枚举、超长问题、过量物件、坐标注入被拒绝；合法空关联与统一错误响应通过。
