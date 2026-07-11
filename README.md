# Family Garden

> 让家庭记忆长成花园。

Family Garden 是一个 AI 驱动的数字家庭第三空间。家庭成员可以上传照片、留言、
明信片或房间照片；AI 将已有内容整理成记忆卡片并提出温和的问题，家人补充回答后，
这些记忆会在花园、鱼塘、共享农场和个人房间中变成可探索、可回应、会生长的节点。

- 在线演示（Web）：https://peilinpeng.github.io/FamilyGarden/
- 主要平台：手机横屏 Web，同时兼容桌面浏览器
- 引擎：Godot 4.7
- 比赛：腾讯云 AI 游戏比赛

## 为什么做它

很多家庭并不是联系不上，而是不知道怎样自然地开始交流。照片散落在相册和聊天记录里，
长辈的故事、共同旅行和日常片段也很难被持续补充。Family Garden 不要求用户严肃谈心，
而是用种植、探索、漂流瓶和共同照料等轻量互动，让家人自然地重新发现彼此的故事。

AI 在这里是“记忆整理助手”，不是故事编造者。它只整理用户已经提供的内容、识别房间
中的可见物件并提出开放问题，不推断家庭关系，不评价感情，也不替用户补写事实。

## 核心体验

```text
加入同一家庭花园
  → 上传照片或写下一段记忆
  → AI 生成可编辑的记忆卡片与温和问题
  → 家庭成员补充、回应和建立跨记忆关联
  → 花园长出记忆花与藤蔓
  → 在共享农场共同种植，在鱼塘发现漂流瓶
  → 用房间照片生成可探索的语义房间
```

| 体验 | 当前实现 |
|---|---|
| 家庭入口 | 家庭邀请码、角色身份、家庭成员与所在场景 |
| AI 记忆卡片 | 图片/文字输入、草稿预览、确认后落库、失败降级 |
| 记忆景观 | 记忆花、照片卡片、生长反馈、跨记忆藤蔓与追问 |
| 共享农场 | 同家庭共享地块、种植/生长/收获、在线刷新 |
| 漂流瓶 | AI 家庭问题、幂等回答、岸边记忆生成 |
| 语义房间 | AI 识别物件与区域，受控目录生成可探索 TileMap 房间 |
| 云端协作 | CloudBase 家庭隔离、统一数据网关、在线状态与同步 |
| 稳定性 | 真实 AI/云端链路、mock fallback、自动测试与冒烟测试 |

## 技术设计

```text
Godot 4.7 Web / Desktop
  ├─ AIClient：统一状态、校验、缓存、取消与 fallback
  ├─ CloudService：身份、家庭数据、照片与同步
  └─ Scene Schema：受控节点、slot、zone 与语义房间
          │
          ├── CloudBase AI Gateway ── 内容安全 ── 腾讯混元
          ├── CloudBase Data Gateway ── 家庭隔离数据
          ├── CloudBase Storage ── 家庭照片
          └── Presence Relay ── 在线成员与场景事件
```

关键约束：AI 不输出场景坐标。房间分析只返回 `object_type + zone`，Godot 再通过白名单
目录生成 Scene Schema 和 TileMap，避免模型结果直接控制游戏世界。

## 本地运行

1. 安装 [Godot 4.7](https://godotengine.org/)；
2. 导入 `game/project.godot`；
3. 运行项目；
4. 使用 WASD/方向键移动，点击场景物件或底部入口进行交互。

云端公开 endpoint 位于 `game/config/`，个人身份只保存在设备本地。任何腾讯云密钥、
AI API Key 或 service role key 都不得写入仓库。

## Web 导出

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path game --export-release Web ../export_web/index.html

cd export_web
python3 -m http.server 8000
```

访问 `http://127.0.0.1:8000`。Web 导出目录被忽略，不进入源码仓库。

## 仓库结构

```text
game/       Godot 工程、场景、脚本、测试与游戏资产
backend/    AI Gateway、数据网关、在线中继、Schema 与 mock
docs/       产品、场景、AI、后端、协作与验收文档
tools/      导出和资产处理工具
```

比赛演示与最终交付材料见 [`docs/submission/`](docs/submission/README.md)，完整演示主线见
[`docs/07_demo_script.md`](docs/07_demo_script.md)。

## 当前边界

- Web 端照片选择需要浏览器文件权限；失败时允许保留文字并继续保存。
- 网络或模型技术故障会进入显式 fallback；鉴权、非法输入和内容安全错误不会被 mock 掩盖。
- 仓库保留演示种子数据以保证空存档可玩；真实 AI 结果会记录来源、模型和 prompt 版本。
- 源码仓库与 GitHub Pages 导出仓库分离，`export_web/` 不提交。

## 协作

分支模型为 `main`（稳定）/ `dev`（集成）/ `feature/*`（功能分支）。开发约束见
[`CONTRIBUTING.md`](CONTRIBUTING.md) 与
[`docs/dev/31_handoff_rules.md`](docs/dev/31_handoff_rules.md)。
