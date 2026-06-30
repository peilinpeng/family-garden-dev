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

## 3. 填客户端配置

编辑 `game/config/cloudbase.json`:

```json
{
  "endpoint": "https://<env-id>.service.tcloudbase.com/data_gateway",
  "env_id": "<你的环境ID>",
  "family_id": "Happy_birthday_David",
  "auth_token": ""
}
```

- `endpoint` 非空 → 游戏启动自动注入 CloudBase 后端、预拉云端、之后 `_sync`/库存写自动上云。
- `endpoint` 留空 → 离线本地兜底(开发/无网照常跑)。

## 4. 协议(data_gateway 接收的 JSON)

| action | 入参 | 返回 |
|---|---|---|
| `snapshot` | `{tables:[...], family_id}` | `{ok, tables:{table:rows}}` |
| `query` | `{table, family_id}` | `{ok, rows}` |
| `upsert` | `{table, row, family_id}` | `{ok, id}` |
| `delete` | `{table, id, family_id}` | `{ok}` |

## 5. 安全(上线前务必加固)

- 现在 `family_id` 由客户端传入,**仅 MVP**。上线接 **CloudBase 身份认证**,从已验证身份取 family_id,别信客户端。
- 可写表用白名单(已在 `index.js` 的 `TABLES`)。
- 共享仓"抢最后一个"等并发,后续在网关里做事务校验(见 `docs/43` A 面)。

## 6. 还没做(下一步)

- **实时同步**(看到家人走动、共享仓即时刷新)= CloudBase 实时,建在存储之上,见 `docs/dev/43`。
- 把旧的 Supabase 直连读路径(`CloudService.load_family_data`)也迁到本网关。
