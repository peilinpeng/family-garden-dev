# 31｜线上协作与交接规则

## 1. 为什么需要交接规则

Family Garden 是三人线上合作项目。线上合作最容易出问题的地方不是能力不足，而是：

- 资产不知道怎么用；
- AI 输出不能被游戏读取；
- 场景文件多人同时改；
- 最后才发现无法合并；
- 任务没有负责人；
- bug 没人兜底。

因此，本项目采用“接口先行、分批交付、每日同步、小步合并”的协作方式。

---

## 2. 总规则

1. 不随意回退 main；
2. 不删除已有可运行功能；
3. 不为重构而重构；
4. 每次只改一个明确模块；
5. 每个模块必须有 owner；
6. 每个交付物必须能被别人接；
7. 所有 AI 功能必须有 mock；
8. 所有 P0 美术资产必须经过导入测试；
9. 6.23 后大功能必须谨慎；
10. 7.08 后只修 bug 和包装。

---

## 3. 美术交接规则

A 或美术负责人每完成一批资产，必须立刻交给 C 测试。

### 3.1 每个资产必须附带信息

```text
asset_id:
file_name:
scene:
category:
function:
clickable:
collision:
foreground:
states:
size:
transparent:
notes:
```

### 3.2 示例

```text
asset_id: node_fishpond_bottle_01
file_name: node_fishpond_bottle_01_closed.png
scene: fishpond
category: node
function: bottle_question
clickable: yes
collision: no
foreground: no
states: closed/open
size: 256x256
transparent: yes
notes: 点击后打开漂流瓶问题面板
```

### 3.3 C 收到后必须反馈

- 能否导入；
- 尺寸是否合适；
- 点击区域是否足够；
- 是否需要透明背景；
- 是否需要补状态图；
- 是否影响角色移动或遮挡；
- 是否可以进入 tested/imported 状态。

---

## 4. AI 输出交接规则

B 负责 AI 输出，但必须提前与 C 固定字段。

AI 不能只返回自然语言，必须返回 JSON。

### 4.1 memory_card 必须字段

```json
{
  "title": "一次家庭旅行",
  "description": "这是一段温暖的家庭旅行记忆。",
  "memory_type": "travel",
  "suggested_scene": "garden",
  "question": "你还记得这次旅行中最开心的一件事吗？",
  "node_type": "memory_flower",
  "confidence": 1.0
}
```

### 4.2 C 的对接方式

C 先用 mock JSON 开发，不等真实 AI。

开发顺序：

1. mock JSON → 生成节点；
2. 真实 AI JSON → 替换 mock；
3. AI 失败 → 回到 mock。

---

## 5. 场景交接规则

每个场景必须有一个 owner，不允许多人同时改同一个核心场景文件。

### 5.1 场景 owner

| 场景 | 建议 owner |
|---|---|
| 家庭花园 | C 负责系统，A 负责美术 |
| 鱼塘 | C 负责系统，A 负责资产 |
| AI 房间 | C 负责逻辑，B 负责 AI，A 负责资产 |
| 农场 | A 负责设计，C 接入 |
| 老街 | A 负责设计，C 接入 |

### 5.2 场景合并前必须确认

- 背景是否准备好；
- 交互物件是否单独导出；
- 是否有返回入口；
- 是否有 mock 数据；
- 是否影响主流程；
- 是否通过手机横屏测试。

---

## 6. 代码协作规则

### 6.1 分支建议

| 分支 | 用途 |
|---|---|
| main | 稳定版本 |
| dev | 集成开发版本 |
| feature/scene-garden | 家庭花园 |
| feature/scene-fishpond | 鱼塘 |
| feature/ai-memory-card | AI 记忆卡片 |
| feature/storage-cos | 存储 |
| feature/mobile-web-test | 移动端适配 |

小团队也可以简化，但至少保证 main 不被随意破坏。

### 6.2 提交信息建议

```text
feat(scene): add fishpond bottle interaction
fix(upload): show selected file name on mobile
docs(ai): add memory card json contract
art(garden): add memory flower assets
```

---

## 7. 每日同步规则

每天每人用固定格式同步：

```text
今天完成：
明天交付：
当前卡点：
需要谁配合：
是否影响主流程：
```

如果某人卡住超过半天，需要立即说出来，不要等晚上。

---

## 8. 联调规则

每个核心功能都按三步联调：

```text
假数据跑通
↓
真实模块接入
↓
美术/体验替换
```

例如漂流瓶：

1. C 用 mock 问题生成漂流瓶；
2. B 接入真实 AI 问题；
3. A 替换漂流瓶和面板美术。

这样可以避免大家互相等待。

---

## 9. Bug 处理规则

Bug 按优先级分：

| 级别 | 说明 | 处理 |
|---|---|---|
| P0 | 主流程无法演示 | 立即修 |
| P1 | 核心体验受影响 | 当天修 |
| P2 | 视觉或小交互问题 | 打磨阶段修 |
| P3 | 不影响提交 | 比赛后修 |

P0 例子：

- 游戏打不开；
- 上传完全不可用；
- AI/mock 无法返回；
- 地图节点不生成；
- 记忆卡片打不开；
- 场景无法返回。

---

## 10. 第三人接手包

6.15 第三个人加入前，需要准备：

1. 项目总览；
2. 开发边界；
3. 场景清单；
4. AI 输出格式；
5. 美术 asset manifest；
6. 当前代码运行说明；
7. 已有 bug 列表；
8. 第一批任务；
9. mock 数据；
10. 不允许改动的文件或模块。

第一批任务必须具体，不要只写“负责后端”。

示例：

```text
6.15—6.17：用 mock memory_card JSON 实现 map_node 生成。验收：家庭花园中出现一朵可点击记忆花，点击后打开记忆卡片。
```
