# 58｜Gate 6 Presence 实时同场首闭环验收

更新：2026-07-09
分支：`feature/gate6-presence-realtime`

## 1. 交付目标

Gate 6 的第一步不是做完整 MMO，而是让家庭成员“真的同时在场”：

- 两个真实客户端进入农场后，能看到对方角色、昵称和移动；
- Presence 只同步瞬时在线状态，不写入 CloudBase 数据库；
- 持久数据继续走 `data_gateway`，实时通道只做轻量转发；
- 没有配置实时服务时，农场仍保留原占位家人漫步，不影响离线演示。

## 2. 本轮改动

### CloudBase 云托管中继

新增 `backend/cloudbase/presence_relay/`：

- Node.js + `ws` WebSocket 服务；
- 首包 `hello` 带本机 `member_token`；
- 服务端调用 `DATA_GATEWAY_URL` 的 `whoami` 解析成员身份；
- 按 `family_id` 分房间，只给同家庭成员广播；
- 支持 `hello_ok / peer_joined / peer_moved / peer_left / error`；
- 丢弃旧 `sequence`，避免网络乱序造成位置回滚；
- 心跳/超时清理，避免幽灵在线；
- `/healthz` 供云托管健康检查。

### Godot 客户端

新增 `PresenceChannel` autoload：

- 从 `game/config/cloudbase.json` 读取 `presence_endpoint`；
- 无 endpoint 时进入 `disabled` 状态，游戏不报错；
- 等待 `GameIdentity` 就绪后连接 WebSocket；
- 固定频率约 8Hz 以内发送移动，且有位置/状态变化阈值；
- 自动重连、指数退避、离线清理；
- 对外发出 peer snapshot/join/move/left/status 信号。

农场场景接入：

- `Farm.tscn` 启动后调用 `PresenceChannel.enter_scene("farm", player)`；
- 真实在线成员进入后，替换同角色占位家人；
- 远端成员使用 `RemotePlayer` 平滑插值；
- HUD 显示在线/连接/离线演示状态；
- 离开农场时发送 `leave` 并清理远端玩家。

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
8. 清空 `presence_endpoint` 后，农场仍可进入，并显示离线演示状态。

## 6. 交付边界

- 本轮只做 Presence 和移动同步；
- 不做共享事件广播；
- 不做农场种植/收获的实时世界事件；
- 不做正式登录、邀请码、成员管理后台；
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
