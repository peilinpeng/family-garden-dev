# 03｜美术资产生产与交接规范

## 1. 文档目的

本文档用于指导 Family Garden 的美术资产生成、拆分、命名、交接和导入测试。

本项目的美术资产不能只是“好看的插画”，而必须是可以被游戏系统使用的组件。每一张图都要明确它在游戏中属于：背景、可点击物、碰撞物、前景遮挡、UI、状态变化物件，还是纯装饰。

---

## 2. 总体美术风格

推荐风格：

- 2D 横屏手绘游戏美术；
- 暖色调；
- 低饱和；
- 柔和光影；
- 绘本感或轻水彩质感；
- 轮廓清楚；
- 细节适中；
- 物件圆润、亲切；
- 适合手机横屏点击；
- 不像沉重的社会议题产品。

避免风格：

- 写实 3D；
- 赛博朋克；
- 黑暗幻想；
- 恐怖感；
- 强烈高对比；
- 复杂厚涂；
- 特别像已有商业游戏；
- 过度精细导致小屏幕看不清。

---

## 3. 主画布与导出规格

### 3.1 主场景背景

推荐：

```text
1280 × 720，横屏 16:9
```

主场景背景包括：家庭花园、爸爸鱼塘、爷爷农场、个人房间、老街、旅行区域等。

### 3.2 单独物件

推荐常用尺寸：

| 物件类型 | 推荐尺寸 |
|---|---|
| 小型节点，如记忆花、漂流瓶 | 128×128 或 256×256 |
| 中型物件，如照片牌、木牌、鱼竿 | 256×256 或 384×384 |
| 大型家具，如书桌、床、柜子 | 384×384 或 512×512 |
| UI 面板 | 按实际界面设计，可使用 800×500、960×560 等 |

单独物件必须透明背景，边缘干净。

---

## 4. 资产分层规则

### 4.1 背景层

背景层负责场景氛围，例如地面、水面、天空、墙面、远景、基础小路等。

背景层不要包含：

- 记忆花；
- 漂流瓶；
- 可点击照片牌；
- 场景入口木牌；
- 需要碰撞的家具；
- 需要状态变化的物件。

这些必须单独导出。

### 4.2 可交互物件层

玩家可以点击的物件必须单独导出，例如：

- 记忆花；
- 漂流瓶；
- 照片牌；
- 明信片；
- 场景入口木牌；
- 房间照片墙；
- 老街门牌；
- 农场记忆种子。

### 4.3 碰撞物件层

角色不能穿过的物件，例如：

- 栅栏；
- 桌子；
- 床；
- 柜子；
- 大树树干；
- 鱼塘岸边；
- 房屋；
- 石头。

这些可以单独导出，也可以在引擎中用碰撞区域标注。但资产表中必须标注是否需要碰撞。

### 4.4 前景遮挡层

用于增强层次，例如：

- 树冠；
- 帘子；
- 高柜子；
- 前景草丛；
- 门框；
- 晾衣绳。

前景遮挡必须单独导出，并在引擎中放在更高层级。

### 4.5 多状态物件

状态变化物件要提前准备多张图：

| 物件 | 状态 |
|---|---|
| 记忆花 | new / read / grown |
| 漂流瓶 | closed / open / answered |
| 记忆种子 | seed / sprout / grown |
| 照片牌 | empty / filled |
| 房间物件 | normal / memory_active |

同一物件不同状态尺寸必须一致。

---

## 5. 文件命名规范

不要使用中文文件名。

推荐格式：

```text
类型_场景_名称_编号_状态.png
```

示例：

```text
scene_garden_bg_01.png
node_garden_memory_flower_01_new.png
node_garden_memory_flower_01_read.png
node_garden_memory_flower_01_grown.png
node_fishpond_bottle_01_closed.png
node_fishpond_bottle_01_open.png
prop_room_desk_01.png
prop_room_lamp_01.png
prop_farm_seed_01.png
prop_farm_crop_01_grown.png
ui_memory_card_panel_01.png
ui_upload_button_01.png
```

---

## 6. 文件夹结构建议

```text
assets/
  scenes/
    garden/
      bg/
      interactive/
      collision/
      foreground/
    fishpond/
      bg/
      interactive/
      collision/
      foreground/
    farm/
      bg/
      interactive/
      collision/
      foreground/
    room/
      bg/
      objects/
      foreground/
    old_street/
      bg/
      interactive/
      props/
    travel/
      bg/
      interactive/
      props/
  ui/
    memory_card/
    upload_panel/
    bottle_panel/
    room_panel/
    buttons/
    icons/
  characters/
  effects/
  prompts/
  references/
  manifest/
```

---

## 7. Asset Manifest 字段

每个资产都必须登记。建议使用 CSV 或表格。

| 字段 | 说明 |
|---|---|
| asset_id | 资产唯一编号 |
| file_name | 文件名 |
| scene | 所属场景 |
| category | background / node / prop / collision / foreground / ui |
| function | 在游戏中的功能 |
| clickable | yes / no |
| collision | yes / no |
| foreground | yes / no |
| states | none / new-read-grown 等 |
| size | 推荐尺寸 |
| transparent | yes / no |
| owner | 负责人 |
| status | todo / generating / ready / tested / imported |
| notes | 备注 |

示例：

| asset_id | file_name | scene | category | function | clickable | collision | foreground | states | size | transparent | owner | status | notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| node_garden_memory_flower_01 | node_garden_memory_flower_01_new.png | garden | node | memory_card_entry | yes | no | no | new/read/grown | 256x256 | yes | A | todo | 点击后打开记忆卡 |
| node_fishpond_bottle_01 | node_fishpond_bottle_01_closed.png | fishpond | node | bottle_question | yes | no | no | closed/open | 256x256 | yes | B | todo | 点击后打开漂流瓶 |

---

## 8. P0 资产清单

### 8.1 家庭花园

| asset_id | 名称 | 类型 | 功能 |
|---|---|---|---|
| scene_garden_bg_01 | 家庭花园背景 | background | 主场景 |
| node_garden_memory_flower_01_new | 新记忆花 | node | 新记忆节点 |
| node_garden_memory_flower_01_read | 已读记忆花 | node | 已查看节点 |
| node_garden_memory_flower_01_grown | 成长记忆花 | node | 已回答节点 |
| prop_garden_photo_board_01_empty | 空照片牌 | node | 等待照片 |
| prop_garden_photo_board_01_filled | 已填照片牌 | node | 展示照片 |
| prop_garden_bottle_entrance_01 | 漂流瓶入口 | node | 进入问题 |
| prop_garden_sign_fishpond_01 | 鱼塘入口牌 | node | 场景跳转 |
| prop_garden_sign_room_01 | 房间入口牌 | node | 场景跳转 |
| prop_garden_tree_foreground_01 | 前景树冠 | foreground | 遮挡 |

### 8.2 爸爸鱼塘

| asset_id | 名称 | 类型 | 功能 |
|---|---|---|---|
| scene_fishpond_bg_01 | 鱼塘背景 | background | 主场景 |
| layer_fishpond_water_01 | 水面层 | background/effect | 水面动效 |
| node_fishpond_bottle_01_closed | 未打开漂流瓶 | node | 打开问题 |
| node_fishpond_bottle_01_open | 已打开漂流瓶 | node | 已读问题 |
| prop_fishpond_fishing_rod_01 | 鱼竿 | prop | 父亲记忆物件 |
| prop_fishpond_sign_01 | 鱼塘木牌 | node | 场景标题/返回 |
| prop_fishpond_stone_edge_01 | 岸边石头 | collision | 边界 |

### 8.3 AI 房间

| asset_id | 名称 | 类型 | 功能 |
|---|---|---|---|
| scene_room_bg_01 | 房间背景 | background | 主场景 |
| prop_room_door_01 | 房间门 | node/collision | 返回入口 |
| prop_room_desk_01 | 书桌 | prop/collision | 房间物件 |
| prop_room_lamp_01 | 台灯 | prop | AI 可识别物件 |
| prop_room_plant_01 | 植物 | prop | AI 可识别物件 |
| prop_room_photo_wall_01 | 照片墙 | node | 查看记忆 |
| prop_room_bed_01 | 床 | collision | 房间结构 |

### 8.4 UI

| asset_id | 名称 | 类型 | 功能 |
|---|---|---|---|
| ui_memory_card_panel_01 | 记忆卡片面板 | ui | 展示 AI 卡片 |
| ui_upload_panel_01 | 上传面板 | ui | 上传照片/房间图 |
| ui_bottle_panel_01 | 漂流瓶问题面板 | ui | 回答问题 |
| ui_room_result_panel_01 | 房间结果面板 | ui | 展示房间识别 |
| ui_loading_ai_01 | AI 生成中 | ui | 等待反馈 |
| ui_error_fallback_01 | 错误提示 | ui | 兜底 |
| ui_rotate_phone_01 | 横屏提示 | ui | 手机竖屏提示 |

---

## 9. 通用 AI 美术提示词

### 9.1 通用风格提示词

```text
Warm hand-painted 2D mobile game art, cozy family memory garden, soft watercolor texture, gentle sunlight, rounded shapes, low saturation colors, peaceful and healing atmosphere, storybook illustration style, clean composition, clear readable objects, suitable for a horizontal 16:9 mobile game scene, soft shadows, no harsh contrast, no realistic 3D, no photorealism, no complex perspective, no text, no logos.
```

### 9.2 通用负面提示词

```text
photorealistic, realistic 3D, cyberpunk, dark fantasy, horror, dramatic lighting, high contrast, cluttered details, messy composition, text, watermark, logo, UI text, distorted objects, broken perspective, overly detailed, anime character focus, copyrighted style, fighting scene, weapons, monsters.
```

### 9.3 场景背景模板

```text
Create a horizontal 16:9 background for a cozy 2D mobile game scene.

Scene: [SCENE_NAME]
Mood: warm, peaceful, healing, family memory atmosphere.
Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes, low saturation colors, gentle sunlight.
Composition: clear open space in the center for player movement and interactive objects. Keep important objects separated and readable. Do not include UI, text, logos, characters, or clickable icons.
Output: background only, 1280x720, no text.
```

### 9.4 单独物件模板

```text
Create a single 2D game prop asset.

Object: [OBJECT_NAME]
Function in game: [FUNCTION]
Style: warm hand-painted 2D mobile game art, soft watercolor texture, rounded shapes, cozy family memory atmosphere.
Requirements: isolated object, transparent background, clean silhouette, readable at small size, suitable for click interaction in a mobile game.
Do not include text, logos, shadows outside the object, or background scene.
```

### 9.5 UI 面板模板

```text
Create a soft 2D game UI panel for a cozy family memory game.

UI type: [UI_TYPE]
Mood: warm, gentle, friendly, low-pressure.
Style: hand-painted storybook UI, rounded corners, soft beige paper texture, subtle shadow, clean layout, no text.
Requirements: suitable for mobile horizontal screen, readable space for title, image, description, question, and button area.
No logo, no actual text, no icons unless requested.
```

---

## 10. 资产生产流程

### 第一步：生成背景草图

先生成场景背景，不包含关键可交互物件。

### 第二步：生成核心交互物件

按 node / prop / ui 分类生成，单独透明背景导出。

### 第三步：登记 manifest

每个资产填入 asset manifest，标注功能、是否可点击、是否碰撞、状态等。

### 第四步：交给游戏系统测试

美术资产不要等整批完成后才交付。每完成一批 P0 资产，就交给 C 导入测试。

### 第五步：根据导入反馈修改

C 需要反馈：

- 尺寸是否合适；
- 边缘是否干净；
- 是否需要切图；
- 是否影响点击；
- 是否需要补状态图；
- 是否需要碰撞简化。

---

## 11. 资产验收标准

一个资产可进入游戏的标准：

1. 文件名符合规范；
2. 尺寸合适；
3. 是否透明背景明确；
4. 可点击物件没有画死在背景里；
5. manifest 已登记；
6. C 已导入测试；
7. 手机横屏下可读可点；
8. 没有文字、logo、水印或版权风险；
9. 不与项目整体风格冲突。
