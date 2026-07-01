# CloudBase 存储部署

Godot 原生用 HTTP,所以走「云函数 HTTP 网关」模式:游戏 → HTTPS → 云函数 `data_gateway` → 云数据库。
对应客户端:`game/scripts/managers/cloudbase_backend.gd`(注入 CloudService 接缝)。

## 1. 准备 CloudBase 环境

1. 开通腾讯云开发(CloudBase),记下 **环境 ID(env id)**。
2. 开通 **云数据库**,**手动创建**以下集合(⚠️ 实测确认:CloudBase 集合**不会**在首次
   写入时自动创建,必须提前建好,否则 `snapshot`/`query` 会直接报
   `ResourceNotFound: Db or Table not exist`):
   ```
   members, families, memories, nodes, answers, rooms, room_objects, inventories
   ```
   权限都选 **「无权限[ADMINONLY]」**——所有访问只经过 `data_gateway` 这个云函数,
   不允许客户端 SDK 绕过网关直连数据库。

## 2. 部署云函数 data_gateway

**方式 A(控制台,推荐给没装 CLI 的场景)**:
1. 云函数 → 新建云函数,函数名 `data_gateway`,运行环境 Node.js 16+。
2. 把 `index.js`/`package.json` 内容贴进在线编辑器,**或**（更稳妥,避免复制粘贴导致引号变形/
   InvalidParameter.IllegalCharacters 报错）把这两个文件打包成 zip 后**通过「上传代码包」上传**。
3. **务必确认依赖被安装**:创建/更新代码后,留意「是否安装依赖」的提示并确认。
   ⚠️ 实测踩坑:更新代码后如果没有重新触发依赖安装,函数会在每次调用时直接
   `FUNCTION_INVOCATION_FAILED`(`require('@cloudbase/node-sdk')` 找不到模块)——
   每次改代码重新上传后,都要重新确认这一步做了。

**方式 B(有 CLI 权限)**:
```bash
cd backend/cloudbase/data_gateway
npm install
tcb fn deploy data_gateway -e <你的环境ID>
```

给该函数绑定 **HTTP 访问服务**(路由配置里"关联资源"选**云函数**、选中 `data_gateway`,
「身份认证」保持关闭——鉴权是我们代码自己做的,不是平台这层),得到一个公网 HTTPS
触发地址(形如 `https://<env-id>-<appid>.<region>.app.tcloudbase.com/data_gateway`)。

## 3. 给每个家庭成员种一条身份(鉴权前提)

网关用**每用户的 member_token** 在服务端解析身份({family_id, member_id, role}),
**不是**家庭共享密钥——爸爸和孩子各自一条令牌,谁的令牌只能动谁自己的东西。

```js
// 控制台云数据库 或 一次性脚本:每个成员各生成一条随机令牌
db.collection('members').add({
  family_id: 'Happy_birthday_David',
  member_token: '<生成一段长随机串,比如 32+ 位,每人不同>',
  role: 'father',              // father / mother / partner / player,对应 characters.json 的角色
  display_name: '爸爸'
})
// ……对 mother / partner / player 各再 add 一条
```

把各自的 `member_token` 分别发给对应的家庭成员——**每人拿到的令牌不同**。
`members` 集合只服务端可查,不在网关的 action 白名单里,app 端永远够不着它、也回传不了 `member_token`。

## 4. 填客户端配置

编辑 `game/config/cloudbase.json`(**每台设备/每个玩家填自己的令牌**):

```json
{
  "endpoint": "https://<env-id>.service.tcloudbase.com/data_gateway",
  "env_id": "<你的环境ID>",
  "member_token": "<该成员自己的 member_token>"
}
```

- `endpoint` 与 `member_token` **都非空** → 启动先 `whoami` 确认身份,再预拉云端、`_sync`/库存写自动上云。
- 任一留空 → 离线本地兜底(不发无鉴权请求)。

## 5. 协议(data_gateway)

鉴权:`Authorization: Bearer <member_token>`(网关据此解析 `{family_id, member_id, role}`;**body 里传的任何 family_id/member_id 一律忽略**)。

| action | 入参 | 返回 |
|---|---|---|
| `whoami` | 无 | `{ok, member_id, family_id, role, display_name}` |
| `snapshot` | `{tables:[...]}` | `{ok, tables:{table:rows}}`(inventories 只含**本人**背包 + 共享仓) |
| `query` | `{table}` | `{ok, rows}` |
| `upsert` | `{table, row}` | `{ok, id}` |
| `delete` | `{table, id}` | `{ok}` |

无效/缺失令牌 → `{ok:false, code:401}`。

## 6. 安全模型(每用户身份,已加固)

- ✅ **身份服务端解析**:由 member_token 查 members 得到 `{family_id, member_id, role}`,**不信客户端**。
- ✅ **个人数据强隔离**:库存表按 `kind` 分流——`backpack` 强制 `id="backpack:"+member_id` 且 `owner_member_id` 由服务端写死,**别的成员连查询都看不到你的背包**;`storehouse` 按 `family_id` 家庭共享。
- ✅ **伪造 id 无效**:客户端传什么 id 都会被服务端按自己的 member_id 重新计算,验证过"伪造别人 id 去写"会被纠正、不污染对方数据。
- ✅ **跨家庭隔离**:通用表(families/memories/...)按 `family_id` 过滤;试图覆盖别家已存在的行 → 403。
- ✅ **未鉴权拒绝**:无有效令牌 → 401。
- ✅ **members 表完全不可达**:不在 action 白名单,客户端无法查询/写入/回传 member_token。
- ✅ **删除限定所有者**:通用表限本家庭;背包删除额外限 `owner_member_id` 匹配本人。
- **轮换/吊销**:删/换某成员的 member_token 行即可让其失效,不影响其他成员。

以上 9 项(未授权拒绝、身份解析、个人隔离、共享仓同步、伪造 id 纠正、跨家庭隔离、跨家庭写拒绝、越权删除拒绝、members 不可达)已用内存模拟数据库跑过逻辑测试,全部通过。

### 仍建议的进一步加固(非阻塞)
- **并发裁决**(共享仓"抢最后一个")→ 网关事务,见 `docs/43` A 面。
- **限流/防爆破**:令牌用足够长的随机串;可加平台层限流。
- **正式登录**:现在是"预先分发令牌",更完善可接 CloudBase 自定义登录(微信/手机号)签发短期 token,而非长期静态令牌。

## 6. 还没做(下一步)

- **实时同步**(看到家人走动、共享仓即时刷新)= CloudBase 实时,建在存储之上,见 `docs/dev/43`。
- 把旧的 Supabase 直连读路径(`CloudService.load_family_data`)也迁到本网关。
