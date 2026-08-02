# 61｜M1 照片隐私迁移验收

> 日期：2026-07-31
>
> 审查修复：2026-08-02
>
> 分支：`feature/quality-optimization`
>
> 状态：M1 主链路已完成部署与真实烟测；2026-08-02 审查修复已完成本地验收，待随 PR 部署

## 1. 目标与范围

M1 将旅行地点和明信片的新照片从“客户端直传 Supabase、业务记录保存公开路径”迁移为：

```text
设备照片
  → Godot 解码、缩放、重编码（移除 EXIF 等原始元数据）
  → 带 member_token 上传 data_gateway
  → CloudBase 私有对象（服务端生成家庭/成员隔离路径）
  → 业务记录只保存 photo_upload_id
  → 展示时带 member_token 换取 10 分钟临时 URL
```

本阶段覆盖：

1. Web 与桌面旅行照片的新上传；
2. `travel_places`、`postcards` 的照片引用；
3. 同家庭受控解析与跨家庭拒绝；
4. 地点、明信片、邮箱事件和照片对象的级联删除；
5. 历史 `photo_path` 的只读兼容。

本阶段不执行线上对象搬运，不删除旧 Supabase bucket，也不修改 AI JSON 契约、场景布局或
存档主版本。

## 2. 隐私边界

### 2.1 新写入

- 客户端上传前必须通过 `AIImageUploadService.prepare`；
- 仅接受 JPEG、PNG、WebP；
- 图片先解码，再统一编码为 JPEG，因此不会原样携带 EXIF；
- 客户端不能指定云端路径；
- 网关根据服务端解析出的 `family_id`、`member_id` 和受控 `purpose` 生成路径；
- 共享业务表只保存 `photo_upload_id`，不保存临时 URL；
- 网关会丢弃新写入的 `photo_path`；
- 网关会拒绝不属于当前家庭的 `photo_upload_id`。

### 2.2 读取

- `uploads` 不在通用 CRUD 白名单中；
- `resolve_image` 先按当前身份限定家庭，再签发短期 URL；
- 跨家庭解析返回 404，不暴露对象是否存在；
- Godot 以稳定 `upload_id` 作为纹理缓存键，不持久化临时 URL。

### 2.3 删除

- `delete_place_bundle` 只接受当前家庭内的地点；
- 服务端先删除关联邮箱事件、明信片和地点；
- 关联记录按固定批次持续删除直至清空，不受单次查询 100 条上限截断；
- 仅当图片不再被 `memories`、`travel_places` 或 `postcards` 引用时删除私有对象；
- 任一引用或级联查询失败时停止删除并保留数据，数据库恢复后可安全重试；
- 同家庭成员可删除共享地点，但不能通过普通 `delete_image` 删除他人未关联的上传；
- 24 小时孤儿清理同样检查所有业务引用。

## 3. 兼容策略

- 已有本地存档和云端旧记录中的 `photo_path` 继续只读显示；
- 新建旅行地点不会再调用旧 Supabase 上传函数；
- 新的本地存档记录同时保留空 `photo_path` 字段，避免旧读取代码出现类型变化；
- 历史对象迁移必须作为独立运维任务离线执行，不能由不可信客户端静默搬运；
- 未部署新版网关时，创建和受控读取仍可使用已有 `upload_image/resolve_image`，但地点删除会
  稳定失败并保留本地数据，不会制造“本地已删、云端仍在”的假成功。

## 4. 自动化验收

### Data Gateway

`backend/cloudbase/data_gateway/tests/data_gateway.test.js` 覆盖：

- 私有路径按家庭、成员和用途生成；
- 同家庭解析、跨家庭解析拒绝；
- 公开 `photo_path` 新写入被丢弃；
- 跨家庭 `photo_upload_id` 绑定被拒绝；
- 被记忆或旅行记录引用的图片不能直接删除或被孤儿清理；
- 地点级联删除记录、邮箱事件和私有对象；
- 数据库查询故障时直接删除、孤儿清理和地点级联均失败关闭，不会误删照片或父记录；
- 超过单批上限的 101 张明信片与 201 条邮箱事件能够完整级联；
- 跨家庭地点级联删除拒绝；
- 非上传者不能直接删除孤立图片。

### Godot

`game/tests/photo_privacy_test.tscn` 覆盖：

- PNG 输入经过统一 JPEG 重编码；
- 上传使用 `purpose=travel`；
- 上传结果不会把临时 URL 暴露给业务层；
- 地点和明信片只持久化 `photo_upload_id`；
- 展示前通过身份网关解析 HTTPS 临时 URL；
- 删除地点走服务端级联并回收照片。

## 5. 本地验收结果

执行：

```bash
./tools/test_all.sh
```

结果：

- [x] 修改前基线：23/23 执行单元通过；
- [x] Data Gateway：44/44 测试通过；
- [x] 照片隐私 Godot 场景：通过；
- [x] 修改后全量回归：24/24 执行单元通过，0 失败；
- [x] Godot Web Release：完整导出成功（HTML、JS、WASM、PCK 均生成）；
- [x] 生产依赖审计：critical=0；
- [x] M1 初始版本已部署，云端回下载的 `index.js` 与当次部署源码 SHA-256 一致；
- [x] 真实 CloudBase 烟测：私有上传、同家庭读取、跨家庭拒绝与级联删除全部通过；
- [x] 线上清理复核：两个临时家庭在 5 个集合中的记录计数均为 0，私有对象目录为空。

## 6. 真实环境部署记录

目标：

- CloudBase 环境：`familygarden-d7gy18huh87fd41d2`（上海）；
- 云函数：`data_gateway`；
- 首次部署时间：2026-07-31 16:31（CST）；
- 最终兼容修复部署时间：2026-07-31 17:22（CST）；
- CLI：CloudBase CLI 3.7.0；
- 部署方式：仅上传 `index.js`、`package.json`、`package-lock.json`，云端按 lockfile 安装依赖。

部署结果：

1. CLI 返回 `Cloud function updated successfully`；
2. 云函数最终修改时间为 `2026-07-31 17:22:45`，状态为 `Active/Available`；
3. 从云端回下载 `index.js`，与本地文件的 SHA-256 均为
   `ca2ab5d43caa3faa535cc22daf97fa6be34b2f98a8848d9cc6693b0c9bbd626f`；
4. 云端回下载的 `package.json` 和 lockfile 均锁定 `@cloudbase/node-sdk=3.18.3`；
5. 现有函数运行时为 `Nodejs18.15`。腾讯 SCF 的既有函数运行时不能通过配置接口原地修改；
6. `@cloudbase/node-sdk 4.0.3` 要求 Node.js 20.19，且在现有 18.15 函数中真实上传返回
   Storage `AccessDenied`，因此回退到此前线上验证过的 3.18.3；
7. 3.18.3 的数据库与 Storage 链路均通过真实烟测；已知传递依赖告警由网关入口结构限制
   缓解，生产审计维持 critical=0。

### 6.1 真实烟测结果

执行：

```bash
cd backend/cloudbase/data_gateway
FG_M1_PHOTO_REAL_SMOKE=1 npm run smoke:m1:photo:real
```

结果：

- [x] 上传成员创建受控 `purpose=travel` 私有对象；
- [x] 同家庭另一成员可解析并下载 10 分钟临时 URL；
- [x] 隔离家庭解析同一图片返回 404；
- [x] 隔离家庭不能把该 `photo_upload_id` 绑定到自己的地点；
- [x] 新建地点不持久化客户端伪造的永久 `photo_path`；
- [x] 被地点和明信片引用的图片不能直接删除；
- [x] 隔离家庭不能级联删除地点；
- [x] 同家庭另一成员可级联删除地点、明信片、邮箱事件与私有对象；
- [x] 删除后三个业务表查询均无对应记录，图片解析返回 404。

### 6.2 清理复核

烟测结束后，以本次两个唯一临时家庭标识直接查询云数据库：

- `members`：0；
- `uploads`：0；
- `travel_places`：0；
- `postcards`：0；
- `mailbox_events`：0；
- Cloud Storage `private_uploads`：空。

失败轮次和成功轮次生成的 6 条测试成员已按精确 `_id` 删除，没有删除正式家庭成员。

## 7. 后续运维边界

- M1 新照片链路已可用；2026-08-02 的失败关闭与分页修复需在 PR 合入并通过 CI 后部署
  `data_gateway`，再复跑 M1 真实烟测，部署前不得宣称线上已包含本次审查修复；
- 临时 URL 过期后的重新签发由相同 `resolve_image` 路径完成，单元测试覆盖元数据稳定性；
- SDK 4.x / Node.js 20.19 迁移需新建并行函数、复制配置、验证 Storage 后切换路由，不能删除
  当前可用函数后原地试错；
- 历史 Supabase 对象离线迁移和旧 bucket 清理仍应作为独立运维任务执行。
