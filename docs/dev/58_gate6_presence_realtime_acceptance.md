# 58｜Gate 6 Presence 实时同场首闭环验收

更新：2026-07-10
分支：`feature/gate6-family-entry-members`

## 1. 交付目标

Gate 6 的第一步不是做完整 MMO，而是让家庭成员“真的同时在场”：

- 两个真实客户端进入农场后，能看到对方角色、昵称和移动；
- Presence 同步瞬时在线状态，不写入 CloudBase 数据库；
- 持久数据继续走 `data_gateway`，实时通道只做轻量事件转发；
- 家人在线时，记忆、明信片、留言、共享仓等持久数据写入后会广播 `world_changed`，
  其他客户端收到后自动刷新云端快照并给出轻提示；
- 共享农场地块 `farm_plots` 进入真实云端模型，种植、收获和占用冲突由 data_gateway
  统一裁决，在线成员通过 `world_changed` 自动刷新；
- 家庭入口支持输入邀请码式 `family_id`，并提供家庭成员面板显示云端成员与在线状态；
- 同一成员多设备同时进入时，实时通道保留最新连接并替换旧连接，避免重复角色；
- 没有配置实时服务时，农场只显示本机玩家，不伪造其他家庭成员在场。

## 2. 本轮改动

### CloudBase 云托管中继

新增 `backend/cloudbase/presence_relay/`：

- Node.js + `ws` WebSocket 服务；
- 首包 `hello` 带本机 `member_token`；
- 服务端调用 `DATA_GATEWAY_URL` 的 `whoami` 解析成员身份；
- 按 `family_id` 分房间，只给同家庭成员广播；
- 支持 `hello_ok / peer_joined / peer_moved / peer_left / world_changed / error`；
- 丢弃旧 `sequence`，避免网络乱序造成位置回滚；
- 对 `world_changed` 做表名与动作白名单校验，只允许共享业务表，不允许触碰 `members`
  等身份表；
- 心跳/超时清理，避免幽灵在线；
- 同一 `family_id + member_id` 再次连接时，旧连接收到 `REPLACED` 并关闭；
- `/healthz` 供云托管健康检查。

### Godot 客户端

新增 `PresenceChannel` autoload：

- 从 `game/config/cloudbase.json` 读取 `presence_endpoint`；
- 无 endpoint 时进入 `disabled` 状态，游戏不报错；
- 等待 `GameIdentity` 就绪后连接 WebSocket；
- 固定频率约 8Hz 以内发送移动，且有位置/状态变化阈值；
- 自动重连、指数退避、离线清理；
- 对外发出 peer snapshot/join/move/left/status 信号。
- 对外发出 `world_changed` 信号；本机云端写入后通过 `announce_world_changed()` 广播轻量事件。

新增 `CloudManager` 共享事件刷新层：

- `persist_record/delete_record` 成功进入 CloudBase 后广播 `world_changed`；
- 仅共享仓 `storehouse` 的库存更新会广播，个人背包不触发其他成员刷新；
- 收到远端事件后合并 0.45 秒内的连续更新，避免请求风暴；
- 刷新 CloudBase 快照后同步 `MemoryManager` 与 `InventoryManager`；
- 云端已就绪时允许空表覆盖本地缓存，保证“最后一条删除”也能同步；
- `SceneManager` 刷新聊天条、旅行地图和当前记忆场景，并显示节制的同步提示。
- `Farm` 场景刷新共享地块，种植/收获使用确认式云端写入，避免扣了种子但云端没落库。
- 角色选择界面新增家庭邀请码输入；未填写时继续使用配置中的默认家庭。
- 底部导航新增“家人”入口，打开家庭成员面板，合并云端成员列表与实时在线状态。

农场场景接入：

- `Farm.tscn` 启动后调用 `PresenceChannel.enter_scene("farm", player)`；
- 只有真实在线成员进入同一农场后，才创建对方的远端角色；
- 远端成员使用 `RemotePlayer` 平滑插值；
- HUD 显示在线/连接/离线状态；
- 离开农场时发送 `leave` 并清理远端玩家。
- 地块从 `farm_plots` 快照渲染，作物阶段按 `planted_at_unix` 本地计算；
- 种植先确认云端空地，再扣本人种子；收获先确认云端删除，再给本人背包产物；
- 同一地块被家人抢先使用或收走时，客户端刷新并给出轻提示。

## 3. 配置与部署

`game/config/cloudbase.json` 新增公开配置：

```json
{
  "presence_endpoint": ""
}
```

部署 presence relay 后填入云托管 WebSocket 地址，例如：

```json
{
  "presence_endpoint": "wss://example.service.tcloudbase.com"
}
```

云托管环境变量：

```bash
PORT=8080
DATA_GATEWAY_URL=https://familygarden-d7gy18huh87fd41d2-1449262000.ap-shanghai.app.tcloudbase.com/data_gateway
PRESENCE_HEARTBEAT_MS=15000
PRESENCE_STALE_MS=45000
```

`DATA_GATEWAY_URL` 可省略；relay 已内置当前项目公开 `data_gateway` 地址作为默认值。其他环境部署时再用环境变量覆盖。

当前线上 WebSocket 地址：

```text
wss://familygarden-d7gy18huh87fd41d2-1449262000.ap-shanghai.app.tcloudbase.com/presence-relay
```

## 4. 自动化验收

```bash
cd backend/cloudbase/presence_relay && npm test

cd backend/cloudbase/presence_relay && npm run smoke:local

cd backend/cloudbase/presence_relay && FG_GATE6_REAL_SMOKE=1 npm run smoke:real

cd backend/cloudbase/data_gateway && FG_GATE6_FARM_REAL_SMOKE=1 npm run smoke:gate6:farm:real

cd backend/cloudbase/data_gateway && FG_GATE6_MEMBERS_REAL_SMOKE=1 npm run smoke:gate6:members:real

/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path game --quit

/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path game --scene res://scenes/Farm.tscn --quit-after 20

git diff --check
```

## 5. 人工验收

1. 部署 `presence_relay` 到 CloudBase 云托管；
2. 在 `game/config/cloudbase.json` 填入 `presence_endpoint`；
3. 设备 A 进入农场；
4. 设备 B 使用另一个成员身份进入农场；
5. A/B 均能看到对方昵称、角色和移动；
6. 任一设备离开农场或关闭页面，另一端远端角色消失；
7. 断网/刷新后可重连，不出现重复角色或幽灵角色；
8. A 新增留言、明信片或记忆后，B 在线客户端自动刷新并出现轻提示；
9. B 更新共享仓后，A 自动刷新共享仓；
10. A 在农场种下作物后，B 在线客户端自动看到作物；
11. B 收获成熟作物后，A 在线客户端该地块清空；
12. A/B 同时操作同一空地时，只允许一个人种植成功；
13. 角色选择页输入另一个家庭邀请码后，会作为新的 `family_id` 加入；
14. 点击底部“家人”按钮，能看到同家庭成员、角色、在线/离线和所在场景；
15. 同一成员在第二台设备进入后，旧设备连接被替换，不出现重复角色；
16. 清空 `presence_endpoint` 后，农场仍可进入，且只显示本机玩家。

## 6. 交付边界

- 本轮做 Presence、移动同步和持久数据轻量刷新事件；
- `world_changed` 只广播“需要刷新哪张共享表”，业务数据仍由客户端重新走
  `data_gateway` 拉取，不在 WebSocket 消息里传完整数据；
- 农场种植/收获已接入 data_gateway 的确认式裁决，但不引入复杂交易市场或农作物经济；
- 本轮的“家庭邀请码”是轻量 `family_id` 入口，不做正式邀请码校验、退出家庭或成员管理后台；
- 不引入权威游戏服务器，仍按家庭协作游戏的轻量中继方案推进。

## 7. 2026-07-09 真实部署记录

本地已恢复 CloudBase CLI 登录态，Docker daemon 可用。首次尝试部署时，CloudBase 返回
`[CreateCloudRunServer] 云托管资源未开通`。开通云托管资源后，重新部署通过：

```bash
cd backend/cloudbase/presence_relay
npx --yes -p @cloudbase/cli cloudbase cloudrun deploy \
  -e familygarden-d7gy18huh87fd41d2 \
  --serviceName presence-relay \
  --source . \
  --port 8080 \
  --force
```

随后创建 HTTP 访问路由：

```bash
npx --yes -p @cloudbase/cli cloudbase routes add \
  -e familygarden-d7gy18huh87fd41d2 \
  --data '{"domain":"familygarden-d7gy18huh87fd41d2-1449262000.ap-shanghai.app.tcloudbase.com","routes":[{"path":"/presence-relay","upstreamResourceType":"CBR","upstreamResourceName":"presence-relay","enable":true,"enableAuth":false,"enableSafeDomain":false,"enablePathTransmission":false}]}'
```

真实验收结果：

- `presence-relay` 云托管服务状态：normal；
- 公网访问：Allowed；
- `/presence-relay/healthz` 返回 `{"ok":true}`；
- WebSocket 握手成功；
- 无效 token 返回 `UNAUTHORIZED` 并关闭连接；
- 临时创建两个同家庭成员和一个隔离家庭成员后，真实云端 WebSocket smoke 通过：
  - A/B 同家庭可互相看见加入；
  - A 的移动只广播给 B；
  - 隔离家庭 C 收不到 A 的移动；
  - B 离开后 A 收到 `peer_left`。

结论：Gate 6 Presence 首闭环已在真实 CloudBase 云托管环境跑通。后续可以进入共享事件
广播，例如新记忆、农场种植/收获、季节变化和共享仓变化。

## 8. 2026-07-09 共享事件广播补充

新增 `world_changed` 轻量协议：

```json
{
  "type": "world_changed",
  "table": "messages",
  "id": "message_123",
  "action": "upsert",
  "event_id": "member:timestamp:sequence"
}
```

服务端只把事件转发给同 `family_id` 的其他在线成员，并回给发送方
`world_changed_ack`。接收方不会信任消息里的业务数据，只把它当成“某张共享表变了”的
刷新提示，然后重新从 `data_gateway` 拉取快照。

已纳入本地自动验收：

- 同家庭 B 收到 A 的 `world_changed`；
- 隔离家庭 C 收不到；
- 不在白名单内的表名会被拒绝；
- 本地 smoke 覆盖 join、move、world_changed、leave。

真实云端验收命令：

```bash
cd backend/cloudbase/presence_relay
FG_GATE6_REAL_SMOKE=1 npm run smoke:real
```

本轮真实云端 smoke 已通过：

- `presence-relay` 服务状态：normal；
- `/presence-relay/healthz` 返回 `{"ok":true}`；
- 无效 token 被拒绝；
- 同家庭 A/B 可互相看见加入；
- A 的移动只广播给 B；
- A 的 `world_changed` 只广播给 B；
- 隔离家庭 C 收不到 A 的移动与共享事件；
- B 离开后 A 收到 `peer_left`。

## 9. 2026-07-10 共享农场玩法闭环

新增 `farm_plots` 共享集合：

```json
{
  "id": "farm_plot:<family_id>:<plot_index>",
  "plot_index": 0,
  "crop_id": "corrato",
  "planted_at": "2026-07-10T...",
  "planted_at_unix": 1780000000
}
```

服务端规则：

- `farm_plots` 强制按当前成员的 `family_id` 写入；
- 文档 ID 由服务端稳定生成为 `farm_plot:<family_id>:<plot_index>`；
- `plot_index` 限制在 0–35；
- `crop_id` 只接受安全短字符串；
- 已占用地块再次种植返回 `409 plot occupied`；
- 删除仍按家庭隔离，隔离家庭不能收获别家的地块；
- 旧环境缺 `farm_plots` 集合时自动创建。

客户端规则：

- 农场进入后读取 `farm_plots` 快照；
- 作物阶段由 `planted_at_unix` 和本机时间计算，生长过程不持续写库；
- 种植先等云端确认成功，再扣本人种子；
- 收获先等云端删除成功，再发放本人背包产物；
- 收到 `farm_plots` 的 `world_changed` 后刷新地块并显示轻提示。

真实云端 smoke 命令：

```bash
cd backend/cloudbase/data_gateway
FG_GATE6_FARM_REAL_SMOKE=1 npm run smoke:gate6:farm:real
```

本轮真实云端 smoke 已通过：

- `data_gateway` 已部署最新版；
- `presence-relay` 已部署最新版，健康检查返回 `{"ok":true}`；
- `farm_plots` 真实种植成功；
- 同家庭成员能读取对方种下的地块；
- 已占用地块再次种植返回冲突；
- 隔离家庭看不到、也不能删除别家的地块；
- 同家庭成员收获后，原种植者再次查询时地块已清空；
- `presence-relay` 真实 WebSocket smoke 已验证 `farm_plots` 的 `world_changed` 同家庭转发。

## 10. 2026-07-10 成员体验与家庭入口收口

新增 `list_family_members` 只读动作：

```json
{
  "action": "list_family_members"
}
```

返回只包含同家庭公开字段：

```json
{
  "ok": true,
  "family_id": "family1",
  "members": [
    {
      "member_id": "member_x",
      "family_id": "family1",
      "role": "father",
      "display_name": "爸爸"
    }
  ]
}
```

服务端规则：

- 必须带有效 `member_token`；
- `family_id` 来自服务端身份解析，不信客户端入参；
- 只返回当前成员同家庭的成员；
- 不返回 `member_token`；
- `members` 仍不在通用 CRUD 白名单中。

客户端收口：

- 角色选择页新增家庭邀请码输入，默认填当前配置或本地身份中的家庭；
- 成功加入后继续把 `member_token/member_id/family_id/role/display_name` 写入本地身份；
- 底部导航新增“家人”，弹窗展示家庭邀请码、云端成员和实时在线状态；
- 在线信息来自 `PresenceChannel.peers()` 与本机身份，离线成员来自 `list_family_members`。

真实云端验收：

```bash
cd backend/cloudbase/data_gateway
FG_GATE6_MEMBERS_REAL_SMOKE=1 npm run smoke:gate6:members:real

cd backend/cloudbase/presence_relay
FG_GATE6_REAL_SMOKE=1 npm run smoke:real
```

本轮真实云端 smoke 已通过：

- `data_gateway` 已部署最新版；
- 同家庭 A/B 成员互相可见；
- 隔离家庭 C 只能看到自己；
- 成员列表不泄漏 `member_token`；
- `presence-relay` 已部署最新版，健康检查返回 `{"ok":true}`；
- 同一成员第二次连接后，旧连接收到 `REPLACED` 并被关闭。
