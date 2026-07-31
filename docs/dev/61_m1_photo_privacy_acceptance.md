# 61｜M1 照片隐私迁移验收

> 日期：2026-07-31
>
> 分支：`feature/quality-optimization`
>
> 状态：本地实现与自动化验收完成；线上启用需部署最新版 `data_gateway`

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
- 仅当图片不再被 `memories`、`travel_places` 或 `postcards` 引用时删除私有对象；
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
- [x] Data Gateway：41/41 测试通过；
- [x] 照片隐私 Godot 场景：通过；
- [x] 修改后全量回归：24/24 执行单元通过，0 失败；
- [x] Godot Web Release：完整导出成功（HTML、JS、WASM、PCK 均生成）；
- [ ] 真实 CloudBase 烟测：部署最新版 `data_gateway` 后显式执行。

## 6. 上线步骤

1. 在目标 CloudBase 环境确认 `uploads` 集合存在且权限为 `ADMINONLY`；
2. 部署 `backend/cloudbase/data_gateway/` 最新代码并确认安装 lockfile 依赖；
3. 使用两个同家庭测试成员和一个隔离家庭测试成员验证上传、解析和删除；
4. 确认数据库新记录只有 `photo_upload_id`，没有新的 `photo_path`；
5. 确认临时 URL 过期后可重新解析，跨家庭解析保持 404；
6. 上线稳定后再制定历史 Supabase 对象离线迁移和旧 bucket 清理方案。

真实部署会修改外部云环境，不包含在本地代码提交中，必须由环境负责人明确确认后执行。
