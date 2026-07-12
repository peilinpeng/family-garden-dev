# 57｜Gate 5 家庭同步与上线可靠性验收

更新：2026-07-09
分支：`feature/gate5-family-sync-acceptance`

## 1. 交付目标

Gate 5 把 Gate 4 的“本地 AI 产品体验完成”推进到“真实家庭同步可交付”。

本轮重点不是新增 AI 能力，而是收口多人家庭数据：

- 旅行地点、明信片、家庭留言、邮箱事件优先走 CloudBase 每成员身份链路；
- 启动快照包含 Gate 4 + 家庭共享数据，其他设备能同步看到；
- CloudBase 不可用或尚未自助加入时，本地存档仍可继续运行；
- data_gateway 对家庭共享表强制 `family_id` 和成员审计字段，客户端不能伪造归属；
- 保留旧 Supabase 路径作为未登录/未配置 CloudBase 时的兼容回退。

## 2. 本轮改动

### Godot 客户端

- `CloudBaseBackend.SNAPSHOT_TABLES` 新增：
  - `travel_places`
  - `postcards`
  - `messages`
  - `mailbox_events`
- `CloudService.load_family_data()` 在已有 CloudBase 身份时优先读取 CloudBase 本地镜像缓存；
- `create_place_with_postcard()`、`create_message()`、`delete_place_and_postcards()`、`mark_mailbox_read()`、`has_unread_mailbox_events()` 优先走 CloudBase；
- `MemoryManager.pull_remote()` 拉取并落盘家庭共享数据，弱网重启时可回看最近一次同步结果；
- 明信片已读状态会通过 `postcards` 表同步回云端；
- 旅行地点表单和云端生成的明信片/邮箱事件标题统一中文。

### data_gateway

- 通用家庭共享表继续强制服务端 `family_id`；
- 新增服务端审计字段：
  - `created_by_member_id`
  - `updated_by_member_id`
  - `updated_at`
- 客户端伪造的 `family_id`、`created_by_member_id`、`updated_by_member_id` 会被忽略；
- 已有记录更新时保留原创建者，只更新最近修改者。

## 3. 家庭同步验收

### 双设备/双成员

1. 设备 A 选择角色并进入花园，确认自动自助加入 CloudBase。
2. 设备 B 使用另一角色进入同一家庭。
3. 设备 A 创建记忆并确认，设备 B 重启/刷新后能看到记忆花。
4. 设备 B 补写记忆藤蔓，设备 A 重启/刷新后能看到补写内容。
5. 设备 A 在旅行地图添加地点并生成明信片，设备 B 能看到明信片和邮箱提醒。
6. 设备 B 新增家庭留言，设备 A 能在家庭聊天/留言板看到。
7. 设备 A 生成 AI 房间，设备 A 重启后房间和家具位置一致。

### 弱网/离线

1. 无网络启动时，游戏仍进入本地存档。
2. 最近一次 CloudBase 快照中的记忆、明信片、留言、房间仍可回看。
3. 云端写入失败时，本地创建的内容不丢失，并继续保存到本地存档。
4. 网络恢复后，新启动/新同步不会覆盖掉已经存在的云端家庭数据。

### 权限/隔离

1. 无 token 调用 `whoami/query/upsert/delete` 返回 401。
2. 无效 token 返回 401。
3. 不同家庭 token 不能读取、覆盖或删除对方数据。
4. 客户端伪造 `family_id` 会被服务端覆盖为当前 token 所属家庭。
5. 客户端伪造 `created_by_member_id` / `updated_by_member_id` 会被服务端忽略。
6. 同家庭成员更新共享记录时，`created_by_member_id` 保持原创建者，`updated_by_member_id` 变为当前成员。

## 4. 自动化验收

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path game --quit

/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path game --script res://tests/ai_gate3_test.gd

FAMILY_GARDEN_TEST=1 /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path game res://tests/ai_gate4_test.tscn

cd backend/cloudbase/data_gateway && npm test

cd backend/cloudbase/data_gateway && FG_GATE5_REAL_SMOKE=1 npm run smoke:gate5:real

cd backend/ai && npm test
```

### 真实云端联调 smoke

`npm run smoke:gate5:real` 默认跳过真实请求，必须显式设置 `FG_GATE5_REAL_SMOKE=1`。

脚本覆盖：

- `join_family` 创建两个同家庭测试成员和一个隔离家庭成员；
- 缺失/无效 token 返回 401；
- `travel_places / postcards / messages / mailbox_events` 真实写入 CloudBase；
- 同家庭成员能通过 `query` 和 `snapshot` 看到彼此写入；
- 明信片与邮箱事件已读状态能跨成员更新；
- 服务端覆盖伪造的 `family_id / created_by_member_id / updated_by_member_id`；
- 同家庭更新保留原创建者、更新最近修改者；
- 隔离家庭不能读取、覆盖或删除主家庭记录；
- 结束时清理四张业务表的测试记录。

默认使用 `game/config/cloudbase.json` 的公开 endpoint，并创建临时测试家庭，避免污染正式
`family_id`。如需刻意在配置家庭里做最终人工前烟测，可额外设置
`FG_GATE5_USE_CONFIG_FAMILY=1`。`join_family` 生成的测试成员没有客户端删除入口，会在
`members` 集合留下少量显示名带 `Gate5` 前缀的记录。

为降低部署踩坑，`data_gateway` 已对 Gate 5 四张共享集合增加缺失自愈：旧环境未提前建
`travel_places / postcards / messages / mailbox_events` 时，最新版云函数会在首次查询或
写入时自动创建集合并重试。若真实 smoke 仍返回 `DATABASE_COLLECTION_NOT_EXIST`，说明线上
`data_gateway` 尚未部署本轮代码。

### 2026-07-09 联调记录

- 本地 `data_gateway` 语法检查通过；
- 本地 `data_gateway` 单元测试通过：29 项；
- `git diff --check` 通过；
- 真实 CloudBase smoke 已发起到
  `https://familygarden-d7gy18huh87fd41d2-1449262000.ap-shanghai.app.tcloudbase.com/data_gateway`；
- 真实身份链路通过：缺 token / 无效 token 返回 401，`join_family` 可创建两个同家庭成员
  与一个隔离家庭成员，`whoami` 可正确解析；
- 真实 Gate 5 业务表写入阻塞在 `travel_places`：
  线上返回 `DATABASE_COLLECTION_NOT_EXIST`，说明当前线上 `data_gateway` 仍未部署本轮
  集合自愈代码，或目标环境尚未手动创建 Gate 5 四张集合；
- 本机没有有效 CloudBase CLI 登录态，无法自动替用户部署云函数或创建线上集合。

下一步需要先在 CloudBase 控制台上传
`backend/cloudbase/data_gateway/data_gateway.zip` 并确认依赖安装，或手动创建
`travel_places / postcards / messages / mailbox_events` 四个集合。完成后重新执行：

```bash
cd backend/cloudbase/data_gateway
FG_GATE5_REAL_SMOKE=1 npm run smoke:gate5:real
```

### 2026-07-09 复验记录

上传包含 Gate 5 集合自愈的 `data_gateway.zip` 后，真实 smoke 继续推进：

- 缺 token / 无效 token 返回 401；
- `join_family` 可创建两个同家庭成员和一个隔离家庭成员；
- `whoami` 可正确解析同家庭成员；
- `travel_places` 首次真实写入通过；
- 同家庭成员可查询到对方写入的 `travel_places`；
- 测试业务记录可正常清理。

复验暴露出第二个线上兼容问题：CloudBase 读取已有文档时返回内部 `_id`，旧代码更新已有
文档时会把 `_id` 一起写回，线上拒绝并返回 `不能更新_id的值`。本地已修复为更新前剥离
`_id`，并把单元测试模拟改成同样拒绝 `_id` 回写。修复后本地 `data_gateway` 29 项测试通过，
`data_gateway.zip` 已重新生成。需要再次上传最新 zip 后重跑真实 smoke。

### 2026-07-09 最终复验通过

重新上传包含 `_id` 剥离修复的 `data_gateway.zip` 并确认依赖安装后，真实 CloudBase smoke
完整通过：

- 缺 token / 无效 token 返回 401；
- 两个同家庭成员与一个隔离家庭成员可通过 `join_family` 创建；
- `whoami` 可解析成员身份；
- `travel_places` 可真实创建、跨成员查询、跨成员更新；
- 伪造 `family_id / created_by_member_id / updated_by_member_id` 会被服务端覆盖；
- 同家庭更新会保留原创建者，更新最近修改者；
- `postcards` 可跨成员更新已读状态；
- `messages` 可跨成员读取；
- `mailbox_events` 可跨成员更新已读状态；
- `snapshot` 包含 Gate 5 四张表；
- 隔离家庭不能读取、覆盖或删除主家庭记录；
- smoke 结束后四张业务表测试记录已清理。

通过命令：

```bash
cd backend/cloudbase/data_gateway
FG_GATE5_REAL_SMOKE=1 npm run smoke:gate5:real
```

## 5. 交付边界

- 本轮不新增 AI route；
- 不改变 Gate 4 AI 契约；
- 不新增 CloudBase 集合名，继续使用已在 data_gateway 白名单中的集合；
- 不处理正式登录、邀请码、成员管理后台；
- 真实 Web 照片选择和双设备联机仍需人工在目标部署环境做最终烟测。
