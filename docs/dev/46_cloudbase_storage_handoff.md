# 46 · CloudBase 存储现状交接

> 面向:接手后端/数据这条线的同学
> 关联:[43 联机方案](43_cloudbase_multiplayer_handoff.md)、[45 存储落地全过程](45_cloudbase_storage.md)(含调试细节,本文档是干净摘要)
> 状态:**已部署到真实 CloudBase 环境并跑通,玩家侧完全自助、无需人工干预**
>
> 2026-07-31 更新：本文保留最初交接背景；`travel_places/postcards/messages/mailbox_events`
> 已接入 CloudBase，旅行照片的新写入也已迁移到私有对象 + `photo_upload_id` + 临时 URL。
> 当前验收准则见 `61_m1_photo_privacy_acceptance.md`。

---

## 0. 一句话现状

CloudBase 存储**已经在真实线上环境跑通**(不是本地模拟)。玩家打开游戏 → 选角色 → 起昵称 → 直接进花园,**全程不接触任何令牌/配置**,身份和数据自动上云。已验证:多个真实成员之间共享仓互相可见、个人背包互相隔离。

---

## 1. 架构总览

```
Godot(HTTP)
  └ CloudService(接缝:persist_record/load_table/delete_record,scripts/cloud_service.gd)
       └ CloudBaseBackend(scripts/managers/cloudbase_backend.gd)
            └ HTTPS → 云函数 data_gateway(backend/cloudbase/data_gateway/)
                 └ CloudBase 云数据库(文档型)
```

为什么这样:Godot 原生只有 HTTP,CloudBase 的实时/数据库 SDK 只有 JS/小程序端有,所以用一个云函数当纯 HTTP 网关做所有 CRUD,Godot 端全走 REST。

## 2. 真实部署信息

| 项 | 值 |
|---|---|
| CloudBase 环境 ID | `familygarden-d7gy18huh87fd41d2` |
| 云函数 | `data_gateway`(Node.js,代码见 `backend/cloudbase/data_gateway/index.js`) |
| HTTP 触发地址 | `https://familygarden-d7gy18huh87fd41d2-1449262000.ap-shanghai.app.tcloudbase.com/data_gateway` |
| 当前家庭 | `family1`(4 个成员:father/mother/player/partner,昵称是测试用的占位名) |
| 已建集合 | `members, families, memories, nodes, answers, rooms, room_objects, inventories`(共 8 个,全部 ADMINONLY 权限) |

## 3. 身份模型:玩家自助加入(全自动,已完成)

**不需要任何人手动建 members 记录或分发令牌。** 流程:

1. 玩家在游戏已有的选角色界面(`scene_manager.gd` 的 `_show_role_select()`)选一个角色卡、起昵称、点确认。
2. `_confirm_role_selection()` 后台(不阻塞进花园)调用 `CloudService.ensure_cloud_identity(role, display_name)`。
3. 若本设备是第一次玩(没有本地令牌)→ 调云函数的 `join_family` action(**唯一不需要令牌的 action**,因为这一步就是发令牌本身)→ 服务端随机生成一条新令牌 + 建 `members` 记录 → 返回令牌 → 客户端存进 **`user://cloud_identity.json`**(设备私有目录,不在项目路径下,**永不进 git**)。
4. 之后每次启动,`CloudService._ready()` 检测到本地已有令牌,直接自动同步,不会再弹选角色界面里的注册逻辑。

配置文件职责拆分:

| 文件 | 内容 | 是否可提交 |
|---|---|---|
| `game/config/cloudbase.json`(res://) | `endpoint`、`family_id` | ✅ 可以,不是密钥 |
| `user://cloud_identity.json` | `member_token` | ❌ 绝不,自动生成/自动读写,玩家/开发者都不用手碰 |

**已知权衡**:`join_family` 没有邀请码校验,任何知道 `family_id` 的人都能自助加入——这是产品侧明确选择接受的(私人家庭游戏场景,不需要防真实攻击者)。

## 4. 数据模型(集合)

| 集合 | 谁写 | 关键字段 |
|---|---|---|
| `members` | 服务端(`join_family` 内部) | `family_id, member_token, role, display_name`。**不进 API 白名单,客户端永远查不到、改不了**,只能被网关内部 `resolveMember()` 直接查。 |
| `families` | `MemoryManager._sync` | `id=family_id, cross_member_interaction_count, family_portrait` |
| `memories/nodes/answers/rooms/room_objects` | `MemoryManager._sync` | 各自 id + 业务字段,按 `family_id` 隔离 |
| `inventories` | `InventoryManager` | `id`(`backpack:`+member_id 或 `storehouse:`+family_id)、`kind`、`owner_member_id`(仅 backpack)、`stacks[]` |
| `travel_places/postcards/messages/mailbox_events` | 已接入 CloudBase；旅行照片只保存 `photo_upload_id`，不再新写永久公开 URL |

## 5. 安全模型

- 身份完全由服务端从 `member_token` 解析(`{family_id, member_id, role}`),**客户端传的任何 id 一律忽略**。
- 个人库存(`backpack`)按 `owner_member_id` 强隔离,家庭成员之间互相看不到对方背包;共享仓(`storehouse`)按 `family_id` 家庭共享。
- `join_family` 的角色参数有白名单(`father/mother/grandfather/grandmother/partner/player`),乱传会被拒绝。
- 跨家庭写入/删除会被 403 拒绝;未鉴权(无效令牌)一律 401。
- 详细的验证记录(21 项逻辑测试 + 真实线上多成员交叉验证)见 `docs/dev/45` §7/§8/§9,或 `backend/cloudbase/README.md` §6。

## 6. 还没做 / 需要你接手的

- **实时同步**(共享仓即时刷新给正在线的其他家人、看到家人在花园里走动)——现在只有"启动时拉一次快照"这种冷同步,没有推送。这块建在存储之上,方案见 `docs/dev/43`;`scripts/farm/remote_player.gd` 的 `set_target()` 已经是现成的接入口,联机来了直接接,不用改可视化代码。
- **历史照片迁移**：已存在的 Supabase `photo_path` 仍保留只读兼容；正式下线旧环境前，
  需要离线迁移历史对象并清理旧 bucket。新照片已经不再写入该路径。
- **共享仓并发裁决**:现在"两人同时改共享仓"是后写覆盖前写(last-write-wins),没有事务/乐观锁。真要玩起来人多了可能需要在网关里加一层。
- **正式登录**:现在是"自助加入即签发一个长期静态令牌",没有邀请码、没有找回机制(令牌丢了=这个人的身份丢了,只能重新 `join_family` 生成一个新的,变成"新的一个人")。要更完善可以接 CloudBase 自定义登录(微信/手机号）。
- **members 管理后台**:现在没有任何管理界面能看"家里有哪些成员/删除某个成员",只能去 CloudBase 控制台的数据库页面直接看 `members` 集合、手动删行。
- **`snapshot` 之外的表**尚未接入实时;只在 `bootstrap()` 时拉一次。

## 7. 运维踩坑记录(帮你少走弯路)

1. **CloudBase 集合不会自动创建**,必须在控制台手动建好(见 §2 列的 8 个),否则 `upsert`/`snapshot` 直接报 `ResourceNotFound`。`snapshot` 是**全有全无**的(已修复:单表查询失败会降级为空数组,不再拖垮其它表,但集合本身还是要建)。
2. **控制台"上传代码包"更新云函数后,必须重新确认依赖安装**,否则函数会在每次调用时 `FUNCTION_INVOCATION_FAILED`(`require('@cloudbase/node-sdk')` 找不到模块),连之前能跑的 `whoami` 都会一起挂。排查线索:如果所有 action 突然一起失败(不只是新改的那个),先怀疑依赖没装。
3. 复制粘贴 JSON/代码进控制台在线编辑器容易因为引号被"美化"成花体引号而报 `InvalidParameter.IllegalCharacters`——**优先用"上传代码包"传 zip**,避免这个坑。

## 8. ⚠️ 线上有测试数据,正式发布前记得清

调试过程中在真实线上写过测试数据,还没清:
- `inventories` 集合:`storehouse:family1` 里有 `{id:"coin", count:666}`;某个 mother 成员的背包里有 `{id:"seed_corrato", count:3}`。
- `members` 集合里的 4 条记录昵称是占位测试昵称("爹系男友喜欢吗"等),真实上线前应该让各家庭成员自己走一遍"自助加入"重新起真名,或者直接在控制台把这几条 display_name 改掉。

去 CloudBase 控制台的文档型数据库页面,手动删/改这几条即可,不涉及代码改动。

## 9. 代码地图

| 文件 | 作用 |
|---|---|
| `backend/cloudbase/data_gateway/index.js` | 云函数本体(唯一需要部署的后端代码) |
| `backend/cloudbase/README.md` | 部署步骤 + 协议 + 安全模型说明(比本文档更详细) |
| `game/config/cloudbase.json` | 项目级配置(endpoint/family_id,可提交) |
| `game/scripts/cloud_service.gd` | 持久化接缝(`CloudManager` autoload)+ `ensure_cloud_identity` |
| `game/scripts/managers/cloudbase_backend.gd` | 接缝的 CloudBase 实现:HTTP、本地镜像缓存、`join_family`、`bootstrap` |
| `game/scripts/managers/game_identity.gd` | 本地玩家的云身份(`GameIdentity` autoload) |
| `game/scripts/managers/inventory_manager.gd` | 库存(背包+共享仓),已接云端读写 |
| `game/scripts/managers/scene_manager.gd` | `_confirm_role_selection` 里接了 `ensure_cloud_identity` 那一小段 |

---

有问题看 `docs/dev/45` 里更详细的调试全过程(包括每个 bug 是怎么复现、怎么修的),或直接问场景线的人对齐上下文。
