# CloudBase 存储部署

Godot 原生用 HTTP,所以走「云函数 HTTP 网关」模式:游戏 → HTTPS → 云函数 `data_gateway` → 云数据库。
对应客户端:`game/scripts/managers/cloudbase_backend.gd`(注入 CloudService 接缝)。

## 1. 准备 CloudBase 环境

1. 开通腾讯云开发(CloudBase),记下 **环境 ID(env id)**。
2. 开通 **云数据库**;集合按需自动创建(首次 upsert 即建)。
   集合列表见 `docs/dev/45_cloudbase_storage.md`。

## 2. 部署云函数 data_gateway

```bash
cd backend/cloudbase/data_gateway
npm install            # 安装 @cloudbase/node-sdk
# 用 CloudBase CLI 或控制台上传该目录为云函数 data_gateway
tcb fn deploy data_gateway   # 或在控制台手动新建并上传 index.js + package.json
```

- 运行时:Node.js 16+。
- 给该函数绑定 **HTTP 访问服务**,得到一个公网 HTTPS 触发地址(形如
  `https://<env-id>.service.tcloudbase.com/data_gateway`)。

## 3. 种家庭访问密钥(鉴权前提)

网关用「家庭访问密钥」在服务端解析 family_id。先给该家庭种一条 `families` 行:

```js
// 控制台云数据库 或 一次性脚本:生成随机密钥并写入
db.collection('families').doc('Happy_birthday_David').set({
  family_id: 'Happy_birthday_David',
  access_key: '<生成一段长随机串,比如 32+ 位>'
})
```

把这段 `access_key` 发给该家庭的成员(它就是"家庭口令")。

## 4. 填客户端配置

编辑 `game/config/cloudbase.json`:

```json
{
  "endpoint": "https://<env-id>.service.tcloudbase.com/data_gateway",
  "env_id": "<你的环境ID>",
  "access_key": "<上一步的家庭访问密钥>",
  "family_id": "Happy_birthday_David"
}
```

- `endpoint` 与 `access_key` **都非空** → 启动注入 CloudBase、预拉云端、`_sync`/库存写自动上云。
- 任一留空 → 离线本地兜底(不发无鉴权请求)。

## 5. 协议(data_gateway)

鉴权:`Authorization: Bearer <access_key>`(网关据此解析 family_id;**body 里的 family_id 一律忽略**)。

| action | 入参 | 返回 |
|---|---|---|
| `snapshot` | `{tables:[...]}` | `{ok, tables:{table:rows}}` |
| `query` | `{table}` | `{ok, rows}` |
| `upsert` | `{table, row}` | `{ok, id}` |
| `delete` | `{table, id}` | `{ok}` |

无效/缺失密钥 → `{ok:false, code:401}`。

## 6. 安全模型(已加固)

- ✅ **family_id 服务端解析**:由 access_key 查 families 得到,**不信客户端**。跨家庭读写被隔离。
- ✅ **未鉴权拒绝**:无有效密钥 → 401。
- ✅ **保护字段**:客户端永不能写 `access_key`(upsert 时剥离 + merge 保留服务端值);查询不回传。
- ✅ **删除限本家庭**:只删 `family_id` 匹配的行。
- ✅ **表白名单**:`index.js` 的 `TABLES`。
- **轮换/吊销**:改 families 行的 `access_key` 即让旧密钥失效。

### 仍建议的进一步加固(非阻塞)
- **每用户身份**(区分爸爸/娃,防成员越权改他人个人背包):接 CloudBase 身份认证 + 自定义登录签发 token,网关从已验证身份取 uid+family_id(比共享家庭口令更强)。
- **并发裁决**(共享仓"抢最后一个")→ 网关事务,见 `docs/43` A 面。
- **限流/防爆破**:密钥用足够长的随机串;可加平台层限流。

## 6. 还没做(下一步)

- **实时同步**(看到家人走动、共享仓即时刷新)= CloudBase 实时,建在存储之上,见 `docs/dev/43`。
- 把旧的 Supabase 直连读路径(`CloudService.load_family_data`)也迁到本网关。
