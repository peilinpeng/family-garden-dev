# 56｜Gate 4 最终 Bug Bash 与交付验收

更新：2026-07-09
分支：`feature/gate4-final-bug-bash`

## 1. 本轮目标

这轮不继续加新功能，而是把 Gate 4 最近连续合入的功能、交互和视觉升级做一次产品收口。

重点检查：

- 首屏进入花园、鱼塘、玩家房间时，玩家是否一眼知道能做什么；
- 记忆花、记忆藤蔓、漂流瓶、房间照片预览是否可读、可点、不遮挡；
- 取消、错误、保存、确认、回看等状态是否有明确反馈；
- 中文 UI 是否仍混入明显英文或内部字段名；
- 存档重启后，记忆、藤蔓补写、漂流瓶回答、AI 房间是否一致恢复。

## 2. 本轮修复

- 统一首屏和底部入口相关文案：家庭聊天、家谱、邮箱、明信片、留言板、旅行地图；
- 清理会直接暴露给玩家的旧英文提示，例如 `Postcards`、`World Chat`、`No photo attached`；
- 修正家谱/邮箱中误露出的内部命名 `MemoryManager.postcards`；
- 将 toast 前缀从 `Family Garden` 统一为“家庭花园”；
- 清理 MemoryManager / RoomLayoutManager 中过期的“阶段1/阶段2”注释，避免误导 Gate 4 后续协作。

## 3. 人工 Bug Bash 清单

### 花园首屏

1. 进入花园后，左上状态卡不遮挡玩家、房屋、家庭树、邮箱和留言板。
2. 底部导航全部为中文，按钮文字不溢出。
3. 点击家庭树、邮箱、留言板、明信片、家庭聊天，面板中不出现明显英文或内部字段名。
4. 记忆花显示“待回应 / 已确认”，点击区域和视觉位置一致。
5. 记忆藤蔓显示叶片和脉冲，点击标签能打开详情卡。

### 记忆藤蔓

1. 未补写时显示“待补写”，已补写时显示“已补写”和盛开标记。
2. 保存补写后，关闭再打开仍能回填内容。
3. 刷新藤蔓视觉后，旧叶片、线条、标签不会残留叠影。
4. 删除任一端记忆后，相关藤蔓不再出现。

### 鱼塘

1. 进入鱼塘时不用等待 AI 问题，玩家可立刻移动。
2. 漂流瓶出现水波/阴影，状态卡数量在后台补齐问题后会刷新。
3. 点击漂流瓶后，问题面板和回答提示为中文。
4. 回答后只生成一段岸边记忆，重进鱼塘仍存在。

### 玩家房间

1. 进入房间后，房间入口卡显示“照片生成房间”或“管理 AI 房间”。
2. 上传房间照片后，预览面板有布局小地图和中文家具清单。
3. 取消预览不创建房间；确认后才生成房间和家具。
4. 已生成房间可重新分析、删除房间、移动/删除家具。

### 旅行与明信片

1. 旅行地图标题为中文。
2. 无照片、加载中、加载失败状态均为中文。
3. 明信片列表空状态、照片状态、打开按钮均为中文。

## 4. 自动化验收

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path game --quit

/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path game --script res://tests/ai_gate3_test.gd

FAMILY_GARDEN_TEST=1 /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path game res://tests/ai_gate4_test.tscn

cd backend/cloudbase/data_gateway && npm test

cd backend/ai && npm test
```

## 5. 交付边界

- 本轮不新增 AI 能力；
- 不改 AI 接口契约；
- 不改后端表结构或云函数逻辑；
- 不替换正式美术资源；
- Web 照片选择仍需要导出 Web 包后做一次真实浏览器人工验收。
