# PR #32 · P1 审查阻断项修复记录

> 日期：2026-08-24
> 范围：第三方素材许可、家庭农场云端同步、共享仓并发一致性

## 1. 结论

本轮按审查意见完成三个 P1 阻断项的代码修复：

1. 删除无运行时引用且禁止再分发的 `game/assets/tilemap_gardening/`、字节级相同的 `game/assets/characters/garden_tile/garden.png` 副本及 5 张无引用 Atlas/动画副本；对正式场景依赖的 33 张同源图片，用项目内确定性生成器从零绘制的原创同尺寸 PNG 替换；
2. 农场作物和畜牧改为服务端权威事务，启动快照与 Presence 刷新均覆盖完整状态；
3. 共享仓禁止客户端整份快照覆盖，改用带幂等键和版本号的服务端增量事务。

素材要从公共仓库的可下载历史彻底消失，还需要在本次修改提交后重写并强制更新所有包含原素材提交的远端分支；该操作不属于普通删除提交，执行范围见第 6 节。

原创替代资产由 `game/tools/generate_original_garden_tileset.gd` 产生，保留了原有 PNG 路径、像素尺寸、TileSet source ID 与玩家摆放存档 ID。来源说明见 `game/assets/garden/tileset/ORIGINAL_ASSETS.md`。对原禁止目录的 Git blob 与当前 `game/assets` 做了全量哈希交集检查，结果为空。

## 2. 共享仓事务

新增 data_gateway 动作：

```json
{
  "action": "mutate_storehouse",
  "operation_id": "craft:tomato_egg:...",
  "consumes": [{ "id": "produce_corrato", "quantity": 2, "max_stack": 99 }],
  "grants": [{ "id": "dish_tomato_egg", "quantity": 1, "max_stack": 99 }]
}
```

服务端在一个 CloudBase `runTransaction` 中完成：

- 读取家庭共享仓权威文档；
- 检查幂等操作记录；
- 校验全部扣除项；
- 扣料与发放；
- 增加 `version`；
- 保存最近 32 个操作键并返回权威 `stacks`。

客户端不再允许 `upsert inventories(kind=storehouse)` 整行覆盖。厨房配方、订单、AI 料理和家庭晚餐均一次提交完整扣发集合；普通 `give/take/deposit/withdraw` 也改为服务端增量事务。客户端只应用不低于当前版本的权威快照，避免响应乱序导致回滚。

## 3. 农场事务与远端模型

新增 data_gateway 动作 `farm_action`：

- `plant`：检查地块为空，优先从共享仓、其次从当前成员背包扣种子，再创建地块；
- `water`：更新服务端浇水时间；
- `fertilize`：检查未施肥并原子扣除肥料；
- `harvest`：按服务端时间验证成熟，删除地块并发放服务端计算的产物；
- `uproot`：不发放产物奖励，直接删除已种地块，用于玩家放弃种植与验收数据清理；
- `collect_livestock`：按家庭共享冷却检查畜牧产出并发放物品。

`farm_plots` 和 `farm_livestock` 的通用 `upsert/delete` 已禁用，防止旧客户端或脚本绕过上述事务语义。

作物地块继续使用稳定 ID `farm_plot:<family_id>:<plot_index>`。畜牧新增集合
`farm_livestock`，稳定 ID 为 `farm_livestock:<family_id>:<source_id>`。

客户端启动和 Presence 刷新现在同时拉取：

- `farm_plots`；
- `farm_livestock`；
- `inventories` 权威版本。

无 CloudBase 配置时仍使用原有本地存档与离线玩法，不要求联网。

## 4. 并发与失败语义

- 同一家庭两名成员争抢最后一份库存：只有一个事务成功；
- 同时在同一地块播种：只有一个事务成功且只扣一颗种子；
- 同时收集同一畜牧产出：只有一个事务通过冷却检查；
- 客户端重试同一个 `operation_id`：服务端返回 `duplicate=true`，不重复扣发；
- 库存不足、仓库已满、地块占用、作物未成熟：返回稳定 `409`，不产生部分写入；
- 共享仓旧版整份快照写入：返回 `409 storehouse snapshot writes disabled`。

## 5. 测试覆盖

data_gateway 单元测试新增：

- 共享仓原子扣发、幂等与版本递增；
- 两请求并发争抢最后一份库存；
- 农场播种—浇水—施肥—收获完整事务；
- 两成员并发播种同一地块；
- 两成员并发收集畜牧产出。

Godot 新增 `shared_farm_inventory_transaction_test.tscn`，验证：

- `FarmManager` 只提交一次服务端播种事务；
- 客户端应用服务端权威地块和库存；
- 一份厨房配方只提交一次共享仓事务；
- 全部材料与成品在同一请求中处理。

2026-08-25 最终验收结果：

- `./tools/test_all.sh`：25/25 通过，0 失败；
- data_gateway：49 项测试通过；
- presence_relay：7 项测试通过，含 `farm_livestock` 事件；
- Web Release 导出与启动审计通过，PCK 128,211,128 bytes（上限 130,000,000）；
- 原禁止素材目录 blob 与当前 `game/assets` 文件哈希交集为空。

## 6. 部署与历史清理顺序

生产部署建议按以下顺序：

1. 部署新版 `data_gateway`；
2. 部署新版 `presence_relay`，允许 `farm_livestock` 世界事件；
3. 确认 CloudBase 自动创建 `farm_livestock` 集合，或提前手动创建；
4. 发布新版 Godot/Web 客户端；
5. 两个真实家庭成员完成共享仓、同地块播种和畜牧并发烟测。

素材历史清理必须覆盖仍包含提交 `af46dc6` 的远端引用。执行时需同时清除禁止目录路径和该目录中所有旧 blob ID，以便删除它们在其他路径下的副本，但保留当前原创替代文件。执行前应保留仅本地备份；备份引用不得推送，且会有意保留旧对象，因此验收必须在仅含重写后公开分支的隔离副本中执行：

```bash
git rev-list --objects \
  feature/garden-tilemap \
  feature/quality-optimization \
  feature/release-ui-final-polish \
  | grep 'tilemap_gardening'
```

输出为空，且用旧 blob ID 与重写后上述全部公开引用做交集也为空，才算完成公开分支历史清理。本地恢复备份应保留到协作成员确认迁移完成后再单独处置。

## 7. 已知边界

- 事务接口解决数据一致性，不承担公开竞技游戏的反作弊；家庭成员客户端仍属于受信业务端；
- `farm_livestock` 上线前必须先部署支持该动作的 data_gateway；
- AI 料理内容记录与共享仓扣料分属两个业务阶段：AI 草稿生成不扣料，提交草稿时先确认扣料，再持久化料理记录；失败记录继续沿用现有 AI 同步 outbox。
