# CloudBase 存储部署

Godot 原生用 HTTP,所以走「云函数 HTTP 网关」模式:游戏 → HTTPS → 云函数 `data_gateway` → 云数据库。
对应客户端:`game/scripts/managers/cloudbase_backend.gd`(注入 CloudService 接缝)。

## 1. 准备 CloudBase 环境

1. 开通腾讯云开发(CloudBase),记下 **环境 ID(env id)**。
2. 开通 **云数据库**,**手动创建**以下集合(⚠️ 实测确认:CloudBase 集合**不会**在首次
   写入时自动创建,必须提前建好,否则 `snapshot`/`query` 会直接报
   `ResourceNotFound: Db or Table not exist`):
   ```
   members, families, memories, nodes, answers, rooms, room_objects, inventories, uploads,
   travel_places, postcards, messages, mailbox_events
   ```
   权限都选 **「无权限[ADMINONLY]」**——所有访问只经过 `data_gateway` 这个云函数,
   不允许客户端 SDK 绕过网关直连数据库。

## 2. 部署云函数 data_gateway

**方式 A(控制台,推荐给没装 CLI 的场景)**:
1. 云函数 → 新建云函数,函数名 `data_gateway`,运行环境 Node.js 16+。
2. 把 `index.js`/`package.json`/`package-lock.json` 内容放进代码包,**或**（更稳妥,避免
   复制粘贴导致引号变形/InvalidParameter.IllegalCharacters 报错）把这三个文件打包成
   zip 后**通过「上传代码包」上传**。
3. **务必确认依赖被安装**:创建/更新代码后,留意「是否安装依赖」的提示并确认。
   ⚠️ 实测踩坑:更新代码后如果没有重新触发依赖安装,函数会在每次调用时直接
   `FUNCTION_INVOCATION_FAILED`(`require('@cloudbase/node-sdk')` 找不到模块)——
   每次改代码重新上传后,都要重新确认这一步做了。

**方式 B(有 CLI 权限)**:
```bash
cd backend/cloudbase/data_gateway
npm ci
npm test
npm run audit:prod
tcb fn deploy data_gateway -e <你的环境ID>
```

给该函数绑定 **HTTP 访问服务**(路由配置里"关联资源"选**云函数**、选中 `data_gateway`,
「身份认证」保持关闭——鉴权是我们代码自己做的,不是平台这层),得到一个公网 HTTPS
触发地址(形如 `https://<env-id>-<appid>.<region>.app.tcloudbase.com/data_gateway`)。

## 3. 身份从哪来:玩家自助加入,不用手动种数据(推荐路径)

网关用**每用户的 member_token** 在服务端解析身份({family_id, member_id, role}),
**不是**家庭共享密钥——每个人各自一条令牌,谁的令牌只能动谁自己的东西。

**这条令牌不需要你手动去控制台建**。游戏里已有的「选角色」界面(选立绘 + 起昵称)
选完的那一刻,客户端会自动调 `join_family` 这个 action,服务端随机生成一条新令牌、
建好 `members` 记录、把令牌返回给客户端——客户端自动存进这台设备的 `user://cloud_identity.json`
(不在项目目录里,不会被提交进 git,每台设备各自独立)。**玩家全程不会看到、也不需要
知道"令牌"这个词**,只是选了个角色、起了个名字。

`members` 集合本身只服务端可查,不在网关的 action 白名单里,app 端永远够不着它、
也回传不了任何人的 `member_token`。

> ⚠️ 没有邀请码校验:任何知道 `family_id` 的人调用 `join_family` 都能自助加入。
> 这是产品侧确认接受的权衡(私人家庭游戏,不是要防真实攻击者的公开平台)。

**开发/测试期手动种一条**(比如想在没有游戏 UI 的情况下用 curl 直接测)仍然可以:
```js
db.collection('members').add({
  family_id: 'family1',
  member_token: '<生成一段长随机串,比如 32+ 位,每人不同>',
  role: 'father',              // father / mother / partner / player,对应 characters.json 的角色
  display_name: '爸爸'
})
```

## 4. 填客户端配置

编辑 `game/config/cloudbase.json`(**项目级,可以提交进 git**——这两个字段都不是密钥):

```json
{
  "endpoint": "https://<env-id>.service.tcloudbase.com/data_gateway",
  "env_id": "<你的环境ID>",
  "family_id": "<这个游戏对应的家庭标识,如 family1>"
}
```

- `endpoint` 非空 → 启动会注入 CloudBase 后端。
- 这台设备**第一次**玩(`user://cloud_identity.json` 还不存在)→ 先不自动同步,
  等玩家在选角色界面选完角色 → 自动调 `join_family` 拿令牌、存本地 → 立刻补一次同步。
- **之后每次启动**(令牌已经存在本地)→ 直接自动同步,不会再经过选角色界面里的注册逻辑。
- `endpoint` 留空 → 离线本地兜底,全程不发任何请求。
- `member_token` **不再放在这个文件里**——它是密钥,自动生成、自动存 `user://`,永不出现在
  项目目录/git 仓库中。

## 5. 协议(data_gateway)

鉴权:`Authorization: Bearer <member_token>`(网关据此解析 `{family_id, member_id, role}`;**body 里传的任何 family_id/member_id 一律忽略**)。

| action | 入参 | 返回 | 是否需要令牌 |
|---|---|---|---|
| `join_family` | `{family_id, role, display_name}` | `{ok, member_token, member_id}` | **不需要**(这一步就是发令牌) |
| `whoami` | 无 | `{ok, member_id, family_id, role, display_name}` | 需要 |
| `snapshot` | `{tables:[...]}` | `{ok, tables:{table:rows}}`(inventories 只含**本人**背包 + 共享仓) | 需要 |
| `query` | `{table}` | `{ok, rows}` | 需要 |
| `upsert` | `{table, row}` | `{ok, id}` | 需要 |
| `delete` | `{table, id}` | `{ok}` | 需要 |
| `upload_image` | `{content_type, base64_data}` | `{ok, upload_id, image_url, expires_in}` | 需要 |
| `resolve_image` | `{upload_id}` | `{ok, image_url, expires_in}` | 需要 |
| `delete_image` | `{upload_id}` | `{ok}` | 需要，且仅上传者可删 |

`uploads` 是网关内部元数据集合，不在通用表白名单中。客户端只持久化 `upload_id`；
`image_url` 是短期签名地址，只用于预览和本次 AI 调用，重启后通过 `resolve_image` 刷新。
上传只接受 JPEG/PNG/WebP，解码前后均限制为 6 MB；存储路径由服务端按家庭与成员生成，
不接受客户端自定义路径。

除 `join_family` 外,无效/缺失令牌 → `{ok:false, code:401}`。

## 6. 安全模型(每用户身份,已加固)

- ✅ **身份服务端解析**:由 member_token 查 members 得到 `{family_id, member_id, role}`,**不信客户端**。
- ✅ **个人数据强隔离**:库存表按 `kind` 分流——`backpack` 强制 `id="backpack:"+member_id` 且 `owner_member_id` 由服务端写死,**别的成员连查询都看不到你的背包**;`storehouse` 按 `family_id` 家庭共享。
- ✅ **伪造 id 无效**:客户端传什么 id 都会被服务端按自己的 member_id 重新计算,验证过"伪造别人 id 去写"会被纠正、不污染对方数据。
- ✅ **跨家庭隔离**:通用表(families/memories/...)按 `family_id` 过滤;试图覆盖别家已存在的行 → 403。
- ✅ **未鉴权拒绝**:无有效令牌 → 401(`join_family` 除外,那是发令牌本身)。
- ✅ **members 表完全不可达**:不在 action 白名单,客户端无法查询/写入/回传 member_token。
- ✅ **删除限定所有者**:通用表限本家庭;背包删除额外限 `owner_member_id` 匹配本人。
- ✅ **自助加入的角色白名单**:`join_family` 只接受 `father/mother/partner/player` 四个合法角色,乱传会被拒绝。
- ✅ **危险对象结构拒绝**:进入数据库 SDK 前拒绝原型链键、超深或异常庞大的对象。
- ✅ **AI 图片受控上传**:服务端生成隔离路径；元数据表不对 CRUD 白名单开放；家庭外不可解析、非上传者不可删除。
- **轮换/吊销**:删/换某成员的 member_token 行即可让其失效,不影响其他成员。
- **已知权衡**:`join_family` 没有邀请码校验,任何知道 `family_id` 的人都能自助加入
  (产品侧已确认接受,私人家庭游戏场景)。

以上边界已落成 `tests/data_gateway.test.js` 的 29 项可重复逻辑测试。

Gate 5 真实云端联调可用以下命令显式触发。它会自助加入两个同家庭测试成员和一个隔离
家庭测试成员，验证旅行地点、明信片、留言、邮箱事件的真实写入、跨成员读取、审计字段、
跨家庭隔离和删除清理：

```bash
cd backend/cloudbase/data_gateway
FG_GATE5_REAL_SMOKE=1 npm run smoke:gate5:real
```

默认使用 `game/config/cloudbase.json` 的公开 endpoint，并创建临时测试家庭，避免污染正式
`family_id` 的业务内容。若要刻意在配置家庭里验收，可额外设置
`FG_GATE5_USE_CONFIG_FAMILY=1`。业务测试记录会在脚本结束时清理；`join_family` 生成的
测试成员记录没有客户端删除入口，会留在 `members` 集合中，显示名带 `Gate5` 前缀。

Gate 5 四张共享集合如果在旧环境里尚未手动创建，最新版 `data_gateway` 会在首次查询或
写入时自动创建并继续执行；旧版云函数仍会返回 `DATABASE_COLLECTION_NOT_EXIST`，此时先
部署本目录最新代码包。

依赖门禁使用固定 lockfile，生产审计要求 **critical=0**。CloudBase SDK 3.x 自身仍固定依赖
带 prototype-pollution 公告的 `@cloudbase/database` 1.x；当前通过入口结构拒绝降低可利用面，
待腾讯 SDK 4.x 的云函数初始化迁移验证完成后再升级，不在未验证时强行跨 major。

### 仍建议的进一步加固(非阻塞)
- **并发裁决**(共享仓"抢最后一个")→ 网关事务,见 `docs/43` A 面。
- **限流/防爆破**:令牌用足够长的随机串;可加平台层限流。
- **正式登录**:现在是"预先分发令牌",更完善可接 CloudBase 自定义登录(微信/手机号)签发短期 token,而非长期静态令牌。

## 6. 还没做(下一步)

- **实时同步**(看到家人走动、共享仓即时刷新)= CloudBase 实时,建在存储之上,见 `docs/dev/43`。
- 把旧的 Supabase 直连读路径(`CloudService.load_family_data`)也迁到本网关。

## 7. Gate 6 Presence Relay

`backend/cloudbase/presence_relay/` 是实时同场的第一步：一个部署在 CloudBase 云托管的
WebSocket 中继。它不保存业务数据，只校验成员身份、按 `family_id` 分房间并转发在线成员
位置。

本地测试：

```bash
cd backend/cloudbase/presence_relay
npm install
npm test
```

云托管部署时设置环境变量：

```bash
PORT=8080
DATA_GATEWAY_URL=https://familygarden-d7gy18huh87fd41d2-1449262000.ap-shanghai.app.tcloudbase.com/data_gateway
```

`DATA_GATEWAY_URL` 可省略；relay 已内置当前项目公开 `data_gateway` 地址作为默认值。迁移到
其他 CloudBase 环境时再显式覆盖。

部署成功后，把云托管 WebSocket 地址填入 `game/config/cloudbase.json` 的
`presence_endpoint`。为空时客户端不会连接实时服务，农场仍保持离线占位演示。

当前 Gate 6 线上地址：

```text
wss://familygarden-d7gy18huh87fd41d2-1449262000.ap-shanghai.app.tcloudbase.com/presence-relay
```

健康检查：

```bash
curl https://familygarden-d7gy18huh87fd41d2-1449262000.ap-shanghai.app.tcloudbase.com/presence-relay/healthz
```
