# 53｜记忆藤蔓互动系统验收

更新：2026-07-09
分支：`feature/memory-link-followup`

## 1. 交付目标

本轮把跨记忆关联从“可视化线索”升级为可互动、可补写、可回看的完整体验。

产品语义是“记忆藤蔓”：两段记忆之间被 AI 发现的关系，会在场景里长出一根藤。家人可以顺着藤蔓回答 AI 提出的问题，把这条关系补成一段新的家庭语境。

## 2. 数据设计

继续复用 `nodes` 中的 `memory_link` 节点，不新增后端表，不修改 AI 契约。

新增字段：

| 字段 | 含义 |
|---|---|
| `followup_answer` | 家人围绕这条关联补写的内容 |
| `followup_answered_by` | 最后一次补写/编辑者 |
| `followup_answered_at` | 首次补写时间 |
| `followup_updated_at` | 最近更新时间 |

保存和更新都通过 `MemoryManager.answer_memory_link()` 完成，并继续走现有 `nodes` 同步路径。删除任一端记忆时，关联节点和补写内容沿用现有级联删除逻辑一起移除。

## 3. 场景视觉

未回答藤蔓：

- 柔和藤蔓线；
- 关系标签显示“待补写”；
- 颜色按关系类型区分，但保持克制。

已回答藤蔓：

- 线条更亮；
- 关系标签显示“已补写”；
- 中点长出小花标记，表达这条关系被家人补全。

关系类型显示：

- `same_theme`：相似主题；
- `same_person`：同一家人；
- `same_place`：同一地点；
- `time_sequence`：时间线索；
- `cause_effect`：前因后果；
- `contrast`：对照记忆。

## 4. 记忆藤蔓卡片

点击场景里的藤蔓标签后打开“记忆藤蔓”卡片。

卡片包含：

- 关系类型、可信度、是否已补写；
- 左右两张记忆摘要卡；
- 中间的藤蔓连接视觉；
- AI 提出的追问；
- 家人补写区；
- 打开记忆 A / 打开记忆 B；
- 保存或更新补写。

未回答时，补写区为空，并提示保存后会点亮藤蔓。

已回答时，补写区回填已有内容，允许继续编辑。保存失败时不清空输入。

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

Gate 4 覆盖：

- 关联两端可查询；
- 关联数量可统计；
- 关联回答可首次保存；
- 关联回答可更新；
- 更新回答不创建重复 link；
- 空回答被拒绝；
- 删除记忆继续级联删除 link 和补写内容。

## 6. 人工验收

1. 进入花园，确认记忆藤蔓不严重遮挡主体场景。
2. 点击藤蔓标签，确认打开“记忆藤蔓”卡片。
3. 查看两端记忆摘要、AI 问题、可信度和来源信息是否清楚。
4. 写入补写并保存，确认面板显示成功，场景藤蔓变为已补写状态。
5. 再次打开同一藤蔓，确认补写内容已回填且可编辑。
6. 点击“打开记忆 A / B”，确认可以进入对应记忆卡。
7. 在鱼塘存在岸边记忆关联时，确认藤蔓只渲染当前场景可定位的关联。

## 7. 已知边界

- 本轮不做多轮关联对话，只保存当前这条关联的一段可编辑补写。
- 跨场景关联只在两端记忆都能在当前场景定位时渲染。
- 视觉资源仍使用 Godot 原生线条和面板，没有新增专门美术贴图。
