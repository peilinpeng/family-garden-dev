# 45 · CloudBase 存储(持久化)落地

> 关联:[43 联机方案](43_cloudbase_multiplayer_handoff.md)、[05 数据模型](../05_backend_data_model.md)、`backend/cloudbase/`
> 状态:**已部署到真实 CloudBase 环境并跑通(环境 `familygarden-d7gy18huh87fd41d2`,
> family_id=`family1`)**。真实线上验证了:身份解析、共享仓跨成员可见、个人背包
> 互相隔离(见 §8)。
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
| `members` | 后台预分发(不进网关白名单,只服务端可查) | family_id, member_token, role, display_name |
| `families` | MemoryManager `_family_row` | id=family_id, cross_member_interaction_count, family_portrait |
| `memories` `nodes` `answers` `rooms` `room_objects` | MemoryManager `_sync` | 各自 id + 业务字段 |
| `inventories` | InventoryManager | id(`backpack:`+member_id 或 `storehouse:`+family_id), kind, owner_member_id(仅backpack), stacks[] |
| `travel_places` `postcards` `messages` `mailbox_events` | 现有 Supabase 直连(待迁) | 见 supabase_schema.sql |

> `SNAPSHOT_TABLES`(cloudbase_backend.gd)= bootstrap 时预拉的表,供同步 `load_table` 读。

## 4. 现在会上云的

- ✅ MemoryManager 的 `_sync` 表(memories/nodes/answers/rooms/room_objects/families)。
- ✅ 库存(背包/共享仓)`inventories`,本地优先 + 推云 + 启动从云覆盖。

## 5. 安全:每用户身份认证(已做)

网关不再信客户端的 family_id/member_id,改用**每用户 member_token** 鉴权(详见 `backend/cloudbase/README.md` §6):
- ✅ 服务端用 `Authorization: Bearer <member_token>` 查 `members` 集合,解析出 `{family_id, member_id, role}`。
- ✅ **members 集合完全不可达**(不在 action 白名单),客户端拿不到、也改不了任何人的 token。
- ✅ **个人库存强隔离**:背包按 `owner_member_id` 强制隔离,家庭成员之间互相看不到对方背包;伪造 id 会被服务端纠正,不会污染他人数据。
- ✅ 共享仓仍按 `family_id` 家庭共享;通用表跨家庭写入会被 403 拒绝。
- ✅ 无效/缺失令牌 → 401。
- 以上用内存模拟数据库跑过完整逻辑测试(9 类场景全部通过),见 README §6。
- 客户端:`config/cloudbase.json` 填**本人的** `member_token`(不再是共享密钥);`GameIdentity` autoload 存 `whoami()` 解析出的身份,`Player`/`Farm` 的本地角色优先取云身份、否则回退本地存档角色。

## 6. 还没做(下一步)

- **迁旧读路径**:`CloudService.load_family_data`(Supabase 直连)→ 走本网关。
- **实时同步**(共享仓即时刷新、看到家人走动)= CloudBase 实时,建在存储之上(`docs/43`);`RemotePlayer.set_target()` 已是现成的接入口。
- 共享仓并发"抢最后一个"→ 网关事务校验。
- 正式登录(微信/手机号)替代预分发的静态令牌。

## 7. 端到端验证结果(诚实汇报)

**本环境没有真实 CloudBase 账号/凭证/CLI**,所以"部署到线上并验证"这一步物理上做不到——
需要你在自己的 CloudBase 账号里完成部署(§1–§4)。以下是在此约束下,能做到的最大程度验证:

### 验证方式
用一个本地 Node HTTP 服务器,**跑真实的 `data_gateway/index.js` 逻辑**(用一个内存版
`@cloudbase/node-sdk` stub 顶替真实 SDK),让 Godot 用**真实的 `HTTPRequest`**、走**真实的
生产触发路径**(`CloudService._ready()` → 判断配置 → 注入后端 → `bootstrap()`)去访问它。
这验证的是"我们的代码"而非"CloudBase 平台本身"——平台连通性仍需你部署后确认。

### 验证到的内容(全部通过)
- 网关鉴权/隔离逻辑:14 项单元场景(401、whoami、个人背包隔离、共享仓同步、伪造 id 纠正、
  跨家庭隔离等)。
- 真实 HTTP 全链路:`CloudService._ready()` 自动读配置、注入后端、`whoami()` 解析身份、
  `GameIdentity` 正确更新、`Farm` 正确按云身份选角色(用 mother 角色验证,非默认值重合)。
- **跨会话持久化**:会话 A 写入共享仓 → 清空本地缓存模拟"全新登录/换设备" → 会话 B correctly 从云端拉回同一份数据。
- **多成员隔离**:两个不同 member_token 各自的背包互不可见、互不污染。
- 离线路径回归:未配置时 Farm 正常运行,无报错。

### 验证中发现并修复的 2 个真实 bug(不是假设,是实际复现)
1. **共享仓覆盖 bug**:`sync_from_cloud()` 用 `from_array()` 覆盖本地库存时会触发 `changed`
   信号,连带触发 `save()` 把(可能过期的)数据**重新推回云端**,与玩家操作发生竞态、
   互相覆盖。复现方式:成员 A 写入共享仓 777 金币,任意成员下次登录触发的
   `_grant_starter_kit()`/`sync_from_cloud()` 会把共享仓覆盖回空。
   **修复**:加 `_loading` 门槛,加载/同步期间不触发再次上云推送;`backpack`/`storehouse`
   改为分开推送(`_push_backpack()`/`_push_storehouse()`),`_grant_starter_kit()`
   只推自己动过的 backpack,绝不连带推送尚未同步过的 storehouse。
2. **身份就绪时序 bug**:`GameIdentity.is_ready()` 原本在 `whoami()` 一返回就为 true,
   早于 `sync_from_cloud()` 真正跑完。若代码在此窗口期读写库存,随后到达的（更早请求到的）
   快照会覆盖这次操作的本地效果。
   **修复**:`bootstrap()` 里 `set_identity()` 挪到全部数据同步完成之后再调用,
   `is_ready()==true` 现在保证数据也已经落地,消除该窗口期。

两个 bug 均已在修复后,用相同的复现步骤重新验证通过(见提交历史)。

### 仍未验证 / 你部署时需要做的
- **真实 CloudBase 平台本身**:云函数冷启动、真实网络延迟、腾讯云 SDK 的实际行为、
  安全规则配置,这些只有部署到你的账号后才能验证。
- 建议部署后按 §5/README 的清单,用真机跑一遍"两个成员同时游戏、共享仓互相可见"作为
  最终验收。

## 8. 真实生产环境部署验证记录

已部署到环境 `familygarden-d7gy18huh87fd41d2`(family_id=`family1`,4 个成员:
father/mother/player/partner),用真实 HTTPS 请求(非本地模拟)验证通过:

- `whoami` 正确解析真实成员身份(含中文昵称)。
- 错误令牌 → 正确返回 `{ok:false, code:401}`。
- 写入共享仓(`upsert` storehouse)→ 另一个成员的 `query` 能读到同一份数据
  ——**跨成员共享在真实环境成立**。
- 成员各自写入背包(`upsert` backpack)→ 对方 `query` 看不到彼此的背包行
  ——**个人隔离在真实环境成立**。
- `snapshot` 横跨全部 7 个业务集合一次性返回成功(真实 `bootstrap()` 会调这个)。

### 部署过程中发现的 2 个真实问题(已修复/已文档化)

1. **集合不会自动创建**(纠正了 §1 早前的错误说法):CloudBase 的集合必须在控制台
   手动创建,`upsert`/`snapshot` 打到不存在的集合会直接报
   `ResourceNotFound: Db or Table not exist`,且 **snapshot 是全有全无**——只要
   `SNAPSHOT_TABLES` 里有一个集合不存在,整个 `bootstrap()` 会失败,不只是那一项缺数据。
   **已修复**:`queryGeneric()`/`queryInventories()` 加了 try/catch,单个集合查询失败会
   降级返回空数组,不再拖垮其它集合的同步(见 `data_gateway/index.js` 对应函数)。
   仍需要:部署前把 README §1 列的 8 个集合都手动建好。

2. **控制台"更新代码"不一定会重装依赖**:上传新版 zip 后,如果没有明确触发/确认
   依赖安装,函数会在**每次调用**时以 `FUNCTION_INVOCATION_FAILED`(内部是
   `require('@cloudbase/node-sdk')` 找不到模块)崩溃,连之前能跑通的 `whoami`
   也会一起失效。排查方法:如果所有 action(包括之前测试通过的)突然一起失败,
   先怀疑依赖没装,而不是代码逻辑本身。已写进 README §2 的部署步骤提醒。
