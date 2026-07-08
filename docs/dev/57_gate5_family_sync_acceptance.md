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

cd backend/ai && npm test
```

## 5. 交付边界

- 本轮不新增 AI route；
- 不改变 Gate 4 AI 契约；
- 不新增 CloudBase 集合名，继续使用已在 data_gateway 白名单中的集合；
- 不处理正式登录、邀请码、成员管理后台；
- 真实 Web 照片选择和双设备联机仍需人工在目标部署环境做最终烟测。
