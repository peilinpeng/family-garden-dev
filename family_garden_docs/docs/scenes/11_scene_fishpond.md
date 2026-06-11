# 11｜场景：爸爸鱼塘 Fishpond

## 1. 场景定位

爸爸鱼塘是 Family Garden 中承载“漂流瓶问题”和父亲相关记忆的核心场景。它不是养鱼玩法，也不是普通装饰地图，而是一个让家庭问题从水面漂来的空间。

鱼塘适合承载：

- 父亲的爱好；
- 钓鱼、河边、周末、童年出游等回忆；
- AI 生成的温和家庭问题；
- 家庭成员回答后的新记忆节点。

---

## 2. 体验目标

玩家进入鱼塘时应该感到：

- 这里是一个安静的、可以慢慢打开问题的地方；
- 漂流瓶不是任务压力，而是一个轻轻提醒家人回忆的媒介；
- 父亲相关的回忆可以通过鱼竿、木牌、漂流瓶和水面节点被看见。

---

## 3. 核心玩法

玩家可以：

1. 从家庭花园进入鱼塘；
2. 点击水边的漂流瓶；
3. 打开一个 AI 或家庭成员生成的问题；
4. 输入回答；
5. 回答后鱼塘中生成一个新记忆节点；
6. 点击新节点查看记忆卡片；
7. 返回家庭花园。

---

## 4. 空间布局

推荐 1280×720 横屏布局：

```text
┌────────────────────────────────────────────┐
│ 左上：返回花园       中间：鱼塘水面          │
│                                            │
│ 木屋 / 鱼竿       漂流瓶漂浮区域       木牌  │
│                                            │
│ 下方：漂流瓶问题面板 / 回答框               │
└────────────────────────────────────────────┘
```

中心水面应保持清晰，不要放太多装饰。漂流瓶要足够明显。

---

## 5. 资产清单

| asset_id | 资产名称 | 类型 | 功能 | 可点击 | 碰撞 | 前景遮挡 | 多状态 | 优先级 |
|---|---|---|---|---|---|---|---|---|
| scene_fishpond_bg_01 | 鱼塘背景 | background | 主场景底图 | no | no | no | no | P0 |
| layer_fishpond_water_01 | 水面层 | background/effect | 水面动效 | no | no | no | optional | P1 |
| node_fishpond_bottle_01_closed | 未打开漂流瓶 | node | 打开问题 | yes | no | no | yes | P0 |
| node_fishpond_bottle_01_open | 已打开漂流瓶 | node | 已读问题 | yes | no | no | yes | P0 |
| node_fishpond_memory_ripple_01 | 水面记忆涟漪 | node | 回答后生成记忆 | yes | no | no | yes | P1 |
| prop_fishpond_fishing_rod_01 | 鱼竿 | prop | 父亲记忆物件 | optional | no | no | no | P0 |
| prop_fishpond_sign_01 | 鱼塘木牌 | node | 标题/返回 | yes | no | no | no | P0 |
| prop_fishpond_fish_shadow_01 | 鱼影 | prop/effect | 氛围 | no | no | no | optional | P1 |
| prop_fishpond_water_grass_01 | 水草 | foreground | 氛围/遮挡 | no | no | yes | no | P1 |
| prop_fishpond_stone_edge_01 | 岸边石头 | collision | 边界 | no | yes | no | no | P1 |
| ui_bottle_panel_01 | 漂流瓶面板 | ui | 展示问题和回答 | no | no | no | no | P0 |

---

## 6. 资产拆分要求

不要把漂流瓶画在背景里。漂流瓶必须是单独节点，并至少有 closed/open 两个状态。

鱼竿、木牌、漂流瓶、水面记忆涟漪也应单独导出，方便后期点击和状态变化。

---

## 7. AI 数据映射

漂流瓶问题接口返回：

```json
{
  "question": "小时候有没有一次和家人一起出门玩，让你现在还记得？",
  "target_memory_type": "childhood",
  "suggested_scene": "fishpond",
  "prompt_type": "shared_memory",
  "tone": "warm"
}
```

用户回答后，可以生成新的 memory：

```json
{
  "input_type": "bottle_answer",
  "raw_text": "我记得小时候有一次爸爸带我去河边玩，那天天气很好。",
  "suggested_scene": "fishpond",
  "node_type": "memory_flower"
}
```

游戏系统处理逻辑：

1. 打开漂流瓶后显示问题；
2. 用户回答后保存 answer；
3. 根据回答创建新 memory；
4. AI 可整理回答生成 memory_card；
5. 在鱼塘预设槽位生成新节点。

---

## 8. 交互状态

| 状态 | 表现 | 说明 |
|---|---|---|
| bottle_closed | 漂流瓶未打开 | 可点击 |
| bottle_open | 漂流瓶已打开 | 显示问题 |
| answered | 用户已回答 | 生成新记忆节点 |
| memory_ripple | 水面涟漪或小花 | 新记忆出现 |

---

## 9. 验收标准

鱼塘完成标准：

1. 可以从家庭花园进入；
2. 可以返回家庭花园；
3. 有可点击漂流瓶；
4. 点击漂流瓶能打开问题面板；
5. 用户可以输入回答；
6. 回答后鱼塘中出现一个新节点；
7. 新节点可点击并显示记忆卡片；
8. AI 失败时使用 mock 问题；
9. 手机横屏下漂流瓶足够明显；
10. 这个场景能表达“家庭问题从水面漂来”的感觉。

---

## 10. 给 Claude / Cline 的开发提示词

```text
请读取 docs/00_project_overview.md、docs/03_art_asset_pipeline.md、docs/04_ai_interfaces.md、docs/scenes/11_scene_fishpond.md 和 docs/ui/21_ui_bottle_panel.md。

任务：实现爸爸鱼塘场景的最小可运行版本。

要求：
1. 先用 mock 漂流瓶问题，不接真实 AI；
2. 实现背景、漂流瓶节点、点击打开问题面板、输入回答、回答后生成一个记忆节点；
3. 不要修改家庭花园以外的无关场景；
4. 不要重构全局架构；
5. 给出修改文件列表和测试步骤。
```
