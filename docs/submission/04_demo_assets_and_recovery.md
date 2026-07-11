# 04｜演示素材与故障恢复

## 素材包结构

录制设备本地建立以下目录，不提交包含隐私的原图：

```text
FamilyGarden_Demo_Kit/
  01_family_trip.jpg
  02_my_room.jpg
  demo_text.txt
  family_code.txt
  final_video.mp4
  web_export_backup.zip
```

Web 录制地址在正常 Demo 链接后添加 `?demo_hour=14`。这个参数只固定花园时钟，
不改变存档、AI 或云端数据。

图片要求：JPG/PNG/WebP，最长边 1600—2400px，单张尽量小于 4 MB；不得出现证件、门牌、
学校信息、聊天截图或不知情者的清晰正脸。房间照片应能看见 3—6 个典型物件，避免极暗、
严重广角或杂物遮挡。

## 可直接使用的演示文字

记忆输入：

> 去年夏天，我们一起去了海边。爸爸第一次学会用拍立得，妈妈在傍晚捡了很多贝壳。

记忆回答：

> 最开心的是傍晚一起沿着海边走，爸爸拍下了大家都没有看镜头的那一刻。

藤蔓补写：

> 原来两次旅行我们都住在同一条老街附近，爸爸每次都会去找那家早餐店。

漂流瓶回答：

> 小时候爸爸常带我去河边散步，我们会在桥下停下来听水声。

## 仓库内兜底数据

| 能力 | 位置 |
|---|---|
| 记忆卡片 mock | `backend/mocks/memory_card_mock.json` |
| 漂流瓶问题 mock | `backend/mocks/bottle_question_mock.json` |
| 房间分析 mock | `backend/mocks/room_analysis_mock.json` |
| 跨记忆关联 mock | `backend/mocks/cross_memory_link_mock.json` |
| 空存档记忆与藤蔓 | `game/scripts/managers/scene_manager.gd` |
| 房间物件白名单 | `game/assets/manifest/room_object_catalog.json` |

## 60 秒恢复顺序

1. 停止当前操作，不连续重复点击；
2. 关闭当前面板，回到花园确认游戏仍可响应；
3. 网络功能失败时切换到已生成的本地记忆、房间或演示种子；
4. 页面失去响应时使用本地构建重新打开，不在评委面前清缓存或改配置；
5. 仍无法恢复时立即切最终录屏，不花时间现场排查。

## 服务故障边界

- 技术错误可 fallback，并明确记录 `source=fallback`；
- 鉴权失败、输入非法和内容安全失败不可用 mock 掩盖；
- 照片上传失败可继续保存文字，但不能声称照片已经进入云端；
- 实时连接失败不影响本地移动和已同步数据浏览；
- 演示种子用于保证空存档可玩，不作为真实混元输出的证据。
