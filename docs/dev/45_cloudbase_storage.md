# 45 · CloudBase 存储(持久化)落地

> 关联:[43 联机方案](43_cloudbase_multiplayer_handoff.md)、[05 数据模型](../05_backend_data_model.md)、`backend/cloudbase/`
> 状态:**客户端适配器 + 云函数网关 + 接缝注入 已落地;待你部署云函数 + 填 endpoint 即点亮**
> 负责:数据/后端线

---

## 0. 架构(Godot 原生 → HTTP → 云函数 → 云数据库)

```
Godot
  └ CloudService(接缝:persist_record/load_table/delete_record)
       └ CloudBaseBackend(scripts/managers/cloudbase_backend.gd)
            └ HTTPS → 云函数 data_gateway(backend/cloudbase/) → CloudBase 云数据库
```

为什么这样:CloudBase 实时/数据库 SDK 只有 JS/小程序/原生,**Godot 用 REST**(见 43)。所以用一个云函数当 HTTP 网关做 CRUD。

## 1. 读写路径(关键设计)

- **写**:`persist_record`/`delete_record` → fire-and-forget HTTP,同时乐观更新本地镜像缓存。`MemoryManager._sync(...)` 和库存写**自动上云**。
- **读**:`CloudService.load_table` 是**同步**的(`pull_remote` 同步调),所以 `CloudBaseBackend.load_table` 同步返回**本地镜像缓存**;启动时 `bootstrap()` 异步 `snapshot` 把云端预拉进缓存,再触发 `MemoryManager.pull_remote()` / `InventoryManager.sync_from_cloud()`。
- **未配置 endpoint** → 全部安全降级为本地(写 no-op、读空),离线照常跑。

## 2. 配置与部署

1. 部署云函数 + 绑 HTTP:见 `backend/cloudbase/README.md`。
2. 填 `game/config/cloudbase.json` 的 `endpoint` / `env_id`。
   - 非空 = 上云;留空 = 离线本地。

## 3. 集合(表)与字段

每行带 `family_id`。`id` 作主键(set 即 upsert)。

| 集合 | 来源 | 关键字段 |
|---|---|---|
| `families` | MemoryManager `_family_row` | id=family_id, cross_member_interaction_count, family_portrait |
| `memories` `nodes` `answers` `rooms` `room_objects` | MemoryManager `_sync` | 各自 id + 业务字段 |
| `inventories` | InventoryManager | id(backpack/storehouse), kind, stacks[] |
| `travel_places` `postcards` `messages` `mailbox_events` | 现有 Supabase 直连(待迁) | 见 supabase_schema.sql |

> `SNAPSHOT_TABLES`(cloudbase_backend.gd)= bootstrap 时预拉的表,供同步 `load_table` 读。

## 4. 现在会上云的

- ✅ MemoryManager 的 `_sync` 表(memories/nodes/answers/rooms/room_objects/families)。
- ✅ 库存(背包/共享仓)`inventories`,本地优先 + 推云 + 启动从云覆盖。

## 5. 安全加固(已做)

网关不再信客户端的 `family_id`,改用**家庭访问密钥**鉴权(详见 `backend/cloudbase/README.md` §6):
- ✅ family_id 由 `Authorization: Bearer <access_key>` 在服务端解析(查 families 集合)。
- ✅ 无效密钥 → 401;`access_key` 客户端永不可写;删除只限本家庭;表白名单。
- 客户端:`config/cloudbase.json` 填 `access_key`;`is_configured()` 要求 endpoint+access_key 都非空,否则保持离线(不发无鉴权请求)。

## 6. 还没做(下一步)

- **每用户身份**:现为"家庭共享口令";要区分成员(防越权改他人个人背包)→ 接 CloudBase 身份认证 + 自定义登录 token。
- **迁旧读路径**:`CloudService.load_family_data`(Supabase 直连)→ 走本网关。
- **实时同步**(共享仓即时刷新、看到家人走动)= CloudBase 实时,建在存储之上(`docs/43`)。
- 共享仓并发"抢最后一个"→ 网关事务校验。
