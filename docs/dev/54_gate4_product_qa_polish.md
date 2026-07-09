# 54｜Gate 4 产品 QA 与体验打磨

更新：2026-07-09
分支：`feature/gate4-product-qa-polish`

## 1. 本轮目标

这轮不新增 AI 契约，也不改数据结构，专门做 Gate 4 的产品级验收与体验收口：

- 统一玩家可见的 loading、错误提示和确认前后反馈；
- 检查记忆创建、房间照片、漂流瓶、记忆藤蔓四条链路是否仍然闭环；
- 清理容易误导后续协作的旧阶段说明；
- 把人工验收步骤沉淀成可重复执行的清单。

## 2. 覆盖入口

| 入口 | 重点检查 |
|---|---|
| 家庭记忆创建 | 仅文字、仅照片、图文组合；草稿生成前不落库；取消草稿不残留节点 |
| 房间照片生成 | 桌面 FileDialog、Web 原生选择桥、上传/分析/预览/确认/删除 |
| 鱼塘漂流瓶 | 进入场景立即可操作；AI 问题后台补齐；回答幂等 |
| 记忆藤蔓 | 场景连线、关系标签、详情卡片、补写保存与回填 |
| 通用照片选择桥 | 中文选择提示、读取失败提示、上传成功/失败提示 |

## 3. 本轮修复项

- 桌面照片选择弹窗标题改为“选择照片”，文件筛选显示“图片文件”；
- Web 照片选择流程改为中文提示：等待选择、选择器未就绪、选择失败、读取失败；
- 云端照片上传提示改为中文：上传中、上传失败降级、不带照片保存、上传成功、保存到家庭云端；
- 旅行地图的照片状态从 `No photo selected` 统一为“未选择照片”，避免同一照片桥在不同入口出现中英混杂；
- 场景管理器中的旧 `Stage1` 日志和“阶段/mock”注释改为当前 Gate 4 工作流描述；
- 明确空存档演示种子与真实 Gate 4 AI 关联的边界，避免把演示藤蔓误认为正式链路。

## 4. 验收矩阵

| 场景 | 成功标准 | 失败时应看到 |
|---|---|---|
| 选择照片 | 标签显示文件名和大小 | 中文错误提示，不清空已输入文本 |
| 上传照片 | 显示上传中和上传成功 | 显示上传失败，并继续允许不带照片保存 |
| 创建记忆草稿 | 草稿预览可编辑，确认前不创建节点 | 失败提示保留在面板内，可重试 |
| 确认记忆 | 创建 memory/node，并后台计算关联 | 重复点击不生成重复节点 |
| 分析房间照片 | 预览房间布局，确认后才创建房间 | 契约非法或网络失败时不落半条数据 |
| 回答漂流瓶 | 只创建一条岸边记忆 | 重复提交不重复创建 |
| 补写记忆藤蔓 | 标签变为已补写，内容可回填编辑 | 空回答被拒绝，保存失败不丢输入 |

## 5. 自动化验收

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path game --quit

/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path game --script res://tests/ai_gate3_test.gd

FAMILY_GARDEN_TEST=1 /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path game res://tests/ai_gate4_test.tscn

cd backend/cloudbase/data_gateway && npm test

cd backend/ai && npm test
```

## 6. 人工验收步骤

1. 从干净存档进入花园，确认演示记忆和演示藤蔓能正常出现，日志不再出现旧阶段标签。
2. 打开“记忆”，分别提交仅文字、仅照片、图文组合，确认 loading 和失败提示都在面板内可读。
3. 取消一条草稿，确认不会多出记忆花；确认一条草稿，重启后仍存在。
4. 在桌面选择一张房间照片，完成分析、预览、确认、移动家具、删除家具、删除房间。
5. 在 Web 构建中走一次照片选择桥，确认浏览器选择、失败和读取异常均为中文提示。
6. 进入鱼塘，确认漂流瓶问题恢复和后台补齐不阻塞移动；回答后重进仍能看到岸边记忆。
7. 点击花园或鱼塘中的记忆藤蔓，补写并保存，再次打开确认内容回填。

## 7. 已知边界

- 本轮不替换视觉资源，仍使用现有 Godot 原生面板、线条和贴图；
- 旅行地图仍保留一部分英文表单文案，本轮只统一会被 Gate 4 共用的照片选择与上传提示；
- 真实 Web 照片选择需要导出 Web 包后人工验收，headless 测试只能覆盖 Godot 逻辑侧。

## 8. 2026-07-10 演示前全链路 bug bash

本轮覆盖 Gate 6、Gate 7 和主演示入口，不新增大功能，专门处理“明天录屏会直接看见或
直接报错”的问题：

- 修复主场景启动时 `z_index` 超出 Godot 4.7 允许范围的错误；
- 修复玩家节点入树前访问 `/root/CharacterDB` 导致的外观初始化报错；
- 修复无头验收退出时 BGM 资源仍被持有的问题；headless 环境跳过音频播放；
- 复跑 `Main.tscn`、`Farm.tscn`、Gate 4 房间链路、Gate 7 语义房间链路；
- 复跑 `backend/ai`、`data_gateway`、`presence_relay` 自动化测试；
- 更新 `docs/07_demo_script.md`，把家庭入口、成员面板、共享农场和语义房间纳入 5 分钟演示节奏。

自动化验收命令：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --scene res://scenes/Main.tscn --quit-after 20
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --scene res://scenes/Farm.tscn --quit-after 20
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --scene res://tests/ai_gate4_test.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --scene res://tests/gate7_room_scene_test.tscn

cd backend/ai && npm test
cd backend/cloudbase/data_gateway && npm test
cd backend/cloudbase/presence_relay && npm test && npm run smoke:local
```

已知非阻塞项：

- Web 端真实文件选择仍需导出后人工点选一次，headless 只能验证通用逻辑。
