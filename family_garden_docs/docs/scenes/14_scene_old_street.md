# 14｜场景：老街 / 胡同 / 弄堂 Old Street

## 1. 场景定位

老街场景用于承载童年、老家、祖辈生活、旧照片和城市记忆。比赛阶段建议先做一个通用老街，不必同时开发上海弄堂、北京胡同等多个版本。

后续可以根据家庭记忆扩展为：

- 上海弄堂；
- 北京胡同；
- 苏州水巷；
- 东北大院；
- 老工厂生活区。

---

## 2. 体验目标

老街应该让用户感觉：

- 这里承载过去的生活；
- 老照片和老故事有了可点击的位置；
- 门牌、窗户、自行车、长椅等物件都可能是一段家庭记忆；
- 它不是文化景点，而是家庭记忆里的生活场景。

---

## 3. 核心玩法

玩家可以：

1. 点击门牌查看老家记忆；
2. 点击照片墙查看旧照片；
3. 点击长椅、自行车、窗户等物件查看故事；
4. 上传旧照片后在照片墙生成节点；
5. 返回家庭花园。

---

## 4. 空间布局

```text
┌────────────────────────────────────────────┐
│ 左侧：街口 / 返回入口                       │
│                                            │
│ 中间：老街主路、门、窗、生活物件             │
│                                            │
│ 右侧：照片墙 / 长椅 / 门牌                  │
│                                            │
│ 下方：记忆卡片弹窗                          │
└────────────────────────────────────────────┘
```

---

## 5. 资产清单

| asset_id | 资产名称 | 类型 | 功能 | 可点击 | 碰撞 | 前景遮挡 | 多状态 | 优先级 |
|---|---|---|---|---|---|---|---|---|
| scene_oldstreet_bg_01 | 老街背景 | background | 主场景 | no | no | no | no | P1 |
| prop_oldstreet_doorplate_01 | 门牌 | node | 老家记忆 | yes | no | no | optional | P1 |
| prop_oldstreet_window_01 | 窗户 | node | 旧照片/故事 | yes | no | no | optional | P1 |
| prop_oldstreet_photo_wall_01 | 老照片墙 | node | 展示旧照片 | yes | no | no | yes | P1 |
| prop_oldstreet_bench_01 | 长椅 | prop/collision | 停留与回忆 | optional | yes | no | no | P1 |
| prop_oldstreet_bicycle_01 | 自行车 | prop/collision | 生活气息 | optional | yes | no | no | P1 |
| prop_oldstreet_lamp_01 | 路灯 | prop | 氛围 | no | no | no | no | P2 |
| prop_oldstreet_clothesline_01 | 晾衣绳 | foreground | 生活气息 | no | no | yes | no | P2 |
| prop_oldstreet_sign_back_01 | 返回路牌 | node | 返回花园 | yes | no | no | no | P1 |

---

## 6. AI 数据映射

适合进入老街的 AI 输出：

```json
{
  "memory_type": "old_memory",
  "suggested_scene": "old_street",
  "node_type": "photo_board",
  "question": "这张旧照片让你想起了哪个家里的老地方？"
}
```

游戏系统在老街中生成照片墙节点或门牌节点。

---

## 7. 验收标准

老街完成标准：

1. 可从家庭花园进入；
2. 有老街背景；
3. 至少有两个可点击点：门牌和照片墙；
4. 点击能打开记忆卡片；
5. 可返回家庭花园；
6. 不依赖具体城市版权地标；
7. 有生活感而不是旅游景点感。

---

## 8. 给 Claude / Cline 的开发提示词

```text
请读取 docs/scenes/14_scene_old_street.md。
任务：实现老街场景的基础展示版。只需要背景、门牌节点、照片墙节点和返回入口。不要开发多个城市版本。
```
