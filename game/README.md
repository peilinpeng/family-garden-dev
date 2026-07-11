# Family Garden｜Godot 客户端

本目录是 Family Garden 的 Godot 4.7 客户端，逻辑画布为 1280×720，手机横屏优先，
同时支持桌面 Web 与本地运行。

## 当前可玩内容

- 家庭邀请码、角色选择、家庭成员与在线场景；
- 花园记忆花、记忆卡片、家庭画像和跨记忆藤蔓；
- 图片/文字记忆创建、AI 草稿预览、确认与错误恢复；
- 鱼塘漂流瓶问题、回答与岸边记忆；
- 共享农场种植、成长、收获与家庭同步；
- 房间照片选择、AI 语义分析、布局预览和 TileMap 房间生成；
- 个人背包、共享仓、场景切换、本地存档与 CloudBase 同步。

空存档会生成少量演示记忆和漂流瓶，保证离线状态仍可理解核心体验。启用云端身份后，
记忆、成员、农场和在线状态会按家庭隔离同步。

## 运行

1. 安装 Godot 4.7；
2. 导入本目录的 `project.godot`；
3. 运行主场景 `res://scenes/Main.tscn`。

操作方式：

| 输入 | 行为 |
|---|---|
| WASD / 方向键 | 移动角色 |
| 鼠标或触摸 | 点击入口、物件和面板 |
| 底部导航 | 打开记忆、地图、背包和家人等功能 |

## 配置与安全

- `config/ai.json`：公开 AI Gateway endpoint 与客户端开关；
- `config/cloudbase.json`：公开 CloudBase endpoint、在线中继与默认家庭配置；
- `user://cloud_identity.json`：设备个人身份，只保存在本地；
- 客户端和仓库不保存腾讯云密钥、AI API Key 或 service role key。

AI 请求统一经过 `AIClient`，具备输入/输出契约校验、状态管理、并发合并、缓存、取消和
技术错误 fallback。房间 AI 只输出语义物件及区域，不输出坐标；坐标与可用资产由客户端
Scene Schema 白名单控制。

## Web 导出

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path game --export-release Web ../export_web/index.html
```

Web 端照片选择通过浏览器原生文件选择器接入。请通过 HTTP 服务访问导出目录，不要直接
双击 `index.html`。

## 验收

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path game --quit

FAMILY_GARDEN_TEST=1 /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path game res://tests/ai_gate4_test.tscn

/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path game res://tests/gate7_room_scene_test.tscn
```

比赛级完整验收步骤见 `../docs/submission/06_final_qa_report.md`。
