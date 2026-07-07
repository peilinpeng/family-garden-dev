# 43 · CloudBase 联机(实时同场)方案交接

> 面向:负责后端/联机的队友
> 关联:[05 数据模型](../05_backend_data_model.md)、[40 Supabase 设置](40_supabase_setup.md)、[42 瓦片生成交接](42_tilemap_ai_generation_handoff.md)
> 目标形态:**实时同场**——家庭成员共种一个花园,且能看到彼此角色在花园里走动
> 决策:全线 CloudBase;**不做权威游戏服务器**

---

## 0. 结论先行

1. **不需要权威游戏服务器**(不用 Godot ENet/RPC,理由见 §6)。
2. 把数据分成**两个面**:
   - **A·世界状态**(持久、要校验):花园格子、作物、摆放物 → **CloudBase 数据库 + 云函数**。
   - **B·在场/移动**(瞬时、可丢、不入库):谁在线、角色坐标 → **一个自建的轻量 WebSocket 中继**(跑在 CloudBase 云托管)。
3. **作物生长不在服务器上 tick**:存 `planted_at` 时间戳,客户端用 `now - planted_at` 算阶段。确定性、断线也对。

---

## 1. 现状与关键约束(必读)

- `game/scripts/cloud_service.gd` 当前走 **HTTP REST(`HTTPRequest`)**;持久化已抽成 backend-agnostic 接缝(`set_persistence_backend`),CloudBase 后端实现注进去即可。
- ⚠️ **CloudBase 的实时数据推送 `watch()` 只有它的 JS / 小程序 / 原生 SDK 才有,REST 拿不到。** Godot 原生端(iOS/Android)用 REST,**无法直接订阅 CloudBase 实时**。
- 所以"实时"这层不能指望 CloudBase 的 `watch()`,要**自己搭一条跨端统一的实时通道**(见 §3)。

---

## 2. 两个数据面 × CloudBase 映射

```
                       Godot 客户端(乐观更新 + 本地兜底)
        ┌──────────────────────┴───────────────────────┐
   A·世界状态(持久)                              B·在场/移动(瞬时)
   花园格子 / 作物(planted_at) / 摆放物            谁在线 / 角色 x,y / 朝向 / 动作
        │ 写:HTTP → 云函数(校验)                     │ ~8Hz 广播,不入库,丢包无所谓
        ▼                                              ▼
   CloudBase 数据库 ──(变更后)──► WS中继广播      WebSocket 中继(CloudBase 云托管)
        │  云函数校验 + 数据库安全规则                  │  按 family_id 分房间,只家人互发
        ▼                                              ▼
   CloudBase 云存储(图片/资源)               Godot WebSocketPeer(原生+Web 都能连)
```

| 能力 | CloudBase 组件 | 说明 |
|---|---|---|
| 世界状态存储 | **云数据库** | 文档型;作物存时间戳 |
| 写入校验 / 业务规则 | **云函数(SCF)** | "这格空着才能种"等都在这里裁决 |
| 实时通道 | **云托管(容器)跑 WS 中继** | 云函数是短连接,**扛不了长连 WebSocket**,必须用云托管 |
| 图片/资源 | **云存储 + CDN** | 不变 |
| 鉴权 | **CloudBase 身份认证** | 家庭/成员身份 |

---

## 3. 实时怎么落地:一条自建 WebSocket 中继(核心)

因为 CloudBase 实时只走 SDK、Godot 原生用 REST,**最省事且跨端统一**的做法是:

> 在 **CloudBase 云托管**上跑一个**很小的 WebSocket 中继**(Node 几十行),Godot 用内置 **`WebSocketPeer`** 连它(原生 + Web 同一套代码)。中继**只做按房间扇出转发,无任何游戏逻辑、不存数据**。

中继职责(就这两件):
1. **B 面**:收到某客户端的 `{type:"move", x,y,facing,anim}`,转发给同 `family_id` 房间内其他人。**不落库。**
2. **A 面通知**:世界被改后(云函数写库成功),发一条 `{type:"world_changed", table, id}`,客户端收到后**去数据库重新拉那条**(或中继直接带上变更内容)。

> 这条中继**不是游戏服务器**:没有权威模拟、没有持久化、不裁决玩法,只是哑的消息扇出。和 §6 "不要游戏服务器"不矛盾。

**为什么不用别的:**
- CloudBase `watch()`:Godot 原生订阅不了(只有 SDK 有)。
- 轮询数据库:8Hz 移动靠轮询又慢又贵,不行。
- 往数据库高频写坐标:写放大、烧钱,坐标根本不该入库。

---

## 4. 移动同步细节(休闲游戏档)

- 频率 **~8–10Hz** 广播自己坐标;远端在两次更新间**插值**(或简单 dead-reckoning),看着就平滑。
- **客户端权威**:自己报自己位置,别人照收。家庭花园是合作非竞技,走动**不需要防作弊**。
- **房间 = `family_id`**:只有同一花园的家人互相收发,带宽极小。
- **presence 不入库**:谁在线/在哪只活在中继内存里;断线自动从房间移除。
- Godot 侧:一个 `PresenceChannel`(连 WS、发坐标、收坐标)+ 每个远端成员一个 `RemotePlayer` 节点,在 `_process` 里向目标位置插值。

---

## 5. 世界状态写入(A 面)与校验

- 客户端**乐观更新**:本地先种上,同时发请求。
- 写路径:**Godot HTTP → 云函数**。云函数里校验(这格空吗?是你家的花园吗?是你成员吗?)→ 写数据库 → 通过中继广播 `world_changed`。
- 读路径:进场景时 HTTP 拉一次全量(沿用现有 `cloud_service` 的 REST 风格);之后靠 `world_changed` 增量重拉。
- 冲突:每格 last-write-wins 通常够;争抢同一格才在云函数里做事务校验。
- **生长不写库**:只在种下/收获时写一次(含 `planted_at`),中间阶段全靠客户端算。

---

## 6. 为什么不用 Godot 自带高层多人(ENet/RPC)

简述(详见之前讨论):
1. 它要一个**常驻权威服务器进程**,你得自己托管保活——而你状态只是 DB 几行,纯浪费。
2. **ENet 是 UDP,Web 导出用不了**;你们要手机+Web,这条直接断。
3. 它是**会话制**、无持久化:断线改动、离线增长、跨会话归属都不管,**最后还得再加 DB**,基础设施翻倍。
4. 权威/防作弊它不对着你的业务规则——而云函数 + 数据库安全规则本就免费给你。

ENet/RPC 适合**会话制实时对战**(联机副本/竞技/赛车,打完不留);家庭花园不是那种。

---

## 7. 数据模型(CloudBase 文档库,建议)

| 集合 | 入库? | 字段要点 |
|---|---|---|
| `families` | ✅ | id、name、invite_code |
| `members` | ✅ | family_id、user_id、角色、昵称 |
| `garden_plots` | ✅ | family_id、cell、crop_id、`planted_at`、stage 由时间算 |
| `placed_objects` | ✅ | family_id、object_id、cell |
| **presence(在场)** | ❌ **不入库** | 只活在 WS 中继内存:user_id、x、y、facing、anim、last_seen |

---

## 8. 安全

- 客户端只放**匿名/受限 key**;敏感凭证(service key、AI key)只在**云函数**里。
- 可作弊的写操作(种/收/摆)一律**经云函数校验**,不让客户端直写库。
- WS 中继校验入场身份(family_id + 简单 token),只转发本房间。

---

## 9. 最小闭环(建议先打通)

1. **云托管起一个 WS 中继**(按 family_id 分房间,纯转发)。
2. Godot 写 `PresenceChannel`(`WebSocketPeer` 连中继,发/收坐标)+ `RemotePlayer` 插值。→ **两个客户端能看到对方走动**。
3. 世界写操作接一个**云函数**(校验 + 写库 + 广播 `world_changed`)。
4. 客户端收 `world_changed` → 重拉那条 → 刷新花园。→ **一人种菜,另一人看到**。
5. 接 CloudBase 持久化后端到现有接缝(`set_persistence_backend`),A 面落到 CloudBase。

打通 1–2 就有"实时同场",3–4 就有"共享花园"。

---

## 10. 待拍板

- WS 中继的部署形态(CloudBase 云托管容器 vs 腾讯云 API 网关 WebSocket)。
- 鉴权细节(进 WS 房间用什么 token;复用 CloudBase 身份认证)。
- `world_changed` 是"只发 id 让客户端重拉" 还是"直接带变更内容"(省一次往返)。
- 是否需要把 presence 的 `last_seen` 做超时清理(防幽灵在线)。

有疑问找后端/场景线对齐;架构背景见本文件 §2–§3。
