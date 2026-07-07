# 42 · 瓦片式地图「素材库 + AI 语义生成」交接

> 面向:负责"AI 生成场景"的队友
> 关联:[03 美术资产管线](../03_art_asset_pipeline.md)、[04 AI 接口](../04_ai_interfaces.md)、[36 场景归属与管线](36_scene_ownership_and_pipeline.md)
> 状态:架构已定 + 厨房做了可参考的小样;**生成器本体未做,交给你**

---

## 0. 一句话目标

让 AI **不画图**,而是从**固定素材库**里"挑 tile / 挑家具 + 摆到网格坐标",输出一份 JSON,由加载器把场景搭出来。本质:AI 输出一张**网格布局**,这是 LLM 最擅长、最可控、可校验的形式。

---

## 1. 范围(已和团队定好)

| 场景类型 | 生成方式 | 说明 |
|---|---|---|
| **室内房间**(厨房、卧室…) | ✅ **本任务:瓦片式组合生成** | 地板瓦片 + 家具目录,AI 组合 |
| 室外(farm 等) | ❌ 不在本任务 | 是 AI 出图式 bespoke 美术,保持现状,不要瓦片化 |

只做**室内**。farm 那套(整屏背景 + 手绘 walkable + SortAnchor 遮挡)是另一条线,别动。

---

## 2. 三件套架构(必须照这个分层)

```
① Scene Schema(JSON)—— AI 输出这个,也是唯一契约
   { tileset, size:[w,h], floor, objects:[{id, cell:[x,y]}], ... }

② Object Catalog(数据)—— 定义每个 id 是什么
   id → { 占几格, 贴图块/预制体, 是否碰撞, 排序线 }

③ SceneLoader(代码)—— 读 Schema → 铺地板 → 按 catalog 摆物体 → 碰撞/遮挡自动生效
```

"AI 生成场景" = **AI 吐符合 Schema、只引用 catalog 内 id 的 JSON**。未知 id / 越界一律被校验器拒绝 —— 这是它可控的根本原因。

### Schema 示例(室内厨房)

```json
{
  "room": "kitchen_01",
  "tileset": "kitchen",
  "size": [34, 22],
  "floor": [4, 3],
  "objects": [
    { "id": "fridge",       "cell": [4, 1] },
    { "id": "stove",        "cell": [6, 1] },
    { "id": "dining_table", "cell": [21, 11] },
    { "id": "chair_blue",   "cell": [21, 10] }
  ]
}
```

### Object Catalog 示例(两种条目)

```json
{
  "fridge":       { "kind": "tile_stamp", "size": [1,2], "tiles": [[1,11],[1,12]], "collision": true, "sort": "bottom" },
  "dining_table": { "kind": "tile_stamp", "size": [3,3], "tiles": [[0,17],[1,17],[2,17],[0,18],[1,18],[2,18],[0,19],[1,19],[2,19]], "collision": true },
  "cowhouse":     { "kind": "prefab",     "scene": "res://objects/Cowhouse.tscn" }
}
```

- **tile_stamp**:小重复家具 → loader 把 `tiles` 盖到 Furniture 瓦片层。
- **prefab**:大 bespoke 物件(以后用)→ loader `instantiate` 后摆到 `cell × tile_size`。
- 两种 AI 都不用关心内部,它只写 `{id, cell}`。

---

## 3. 关键技术选择:用 Godot 原生 TileSet,别再手写遮挡

farm 那套遮挡/碰撞是**逐物体手接**的(SortAnchor 手拖、walkable 手绘)。**室内不要走这条路**:

- 在 **TileSet 资源里**给每个 tile 预先配好:**碰撞多边形** + **Y-sort 原点(排序线)**。
- TileMapLayer 开 `y_sort_enabled` 后,**碰撞和遮挡全自动**,loader 只管"盖 tile"。
- 一次性配 TileSet,换来**零自定义遮挡代码**。

> 这是室内相对 farm 最大的简化,务必采用。

---

## 4. 现有可复用 / 可参考的东西

| 路径 | 是什么 | 怎么用 |
|---|---|---|
| `game/assets/tilemap/` | 三个素材包(见 §6) | 选 tile 来源 |
| `game/assets/kitchen/tileset.png` | 厨房 16×16 图集(9×37) | 已导入 |
| `game/assets/kitchen/kitchen_tileset.tres` | **已建好的 TileSet 资源**,333 格全部 `create_tile` 完毕 | 直接拿来当 §2① 的 `tileset:"kitchen"` |
| `game/scenes/KitchenTiled.tscn` | **小样**:Floor + Furniture 两层,脚本摆好的厨房 | 参考布局法;它就是"手写版的 Schema 结果" |
| `game/scripts/farm/farm.gd` 的 `_apply_anchor_z` | 递归按锚点设 z 的遮挡同步 | 仅供理解 farm 那套,**室内别照搬** |

### 建 TileSet 的方法(新素材包照做)

Godot 的图集 tile **必须先 `create_tile` 才能画**。厨房那份是用 headless 脚本批量建的,模式如下(给 Serene Village 等新图集同样处理):

```gdscript
# 用 godot --headless -s 跑
var ts := TileSet.new(); ts.tile_size = Vector2i(16,16)
var src := TileSetAtlasSource.new()
src.texture = load("res://assets/.../tileset.png")
src.texture_region_size = Vector2i(16,16)
for y in rows: for x in cols: src.create_tile(Vector2i(x,y))
ts.add_source(src, 0)
ResourceSaver.save(ts, "res://assets/.../xxx_tileset.tres")
# ★ 进阶:在这里顺便给需要碰撞/遮挡的 tile 配 physics layer 多边形 + y_sort_origin
```

---

## 5. 建议的最小闭环(先打通,再铺开)

1. **配 TileSet**:给厨房 tileset 里几个家具 tile 配好碰撞 + Y-sort 原点。
2. **写小 Catalog**:`fridge / stove / counter / dining_table / chair / plant` 6 个 id。
3. **写 SceneLoader**:读 Schema → 铺地板 → 盖家具 → TileMap 自动出碰撞/遮挡。
4. **手写一段 JSON** 跑通(地板 + 1 冰箱 + 1 桌 + 几把椅子),验证遮挡和碰撞自动生效。
5. **接 AI**:给 LLM 提供"可用 tileset + catalog id 清单 + 房间尺寸",让它**只输出符合 Schema 的 JSON**;加一个**校验器**(未知 id / 越界 / 重叠 → 拒绝或修正)。

打通后,"AI 生成室内场景"就只剩"调 prompt 让它写好这段 JSON"。

---

## 6. 素材包清单(`game/assets/tilemap/`)

| 包 | 尺寸 | 适合 | 备注 |
|---|---|---|---|
| `Kitchen and more tileset [16x16]` | 16×16 | 厨房室内 | 已建好 `kitchen_tileset.tres` |
| `SERENE_VILLAGE_REVAMPED` | 16/32/48 都有 + **autotiles** | 室内外通用、村庄风 | 有自动连接图块(墙/地自动收边),很适合房间生成;选一种尺寸用 |
| `Modern tiles_Free` | 见包内 README | 现代室内 | 备选风格 |

> 包里带了 RPG Maker VX/MV/XP、Construct 3、`.ase`、`.gif` 等**非 Godot 格式变体**,Godot 只用对应的 `.png`,其余忽略即可(后续可清理瘦身)。
> 用前看每个包的 `LICENSE.txt` / `READ ME.txt`。

---

## 7. 踩过的坑(省你时间)

- **图集 tile 要先 `create_tile`** 才能 paint,否则刷不上。
- **裁切过的不规则精灵表**(每帧大小不一)要先**重打包成对齐脚底的均匀网格**再做动画,否则播放会抖(见 cow 的处理:`scripts/farm/cow.gd` + `assets/farm/cow_frames.png`)。
- **多段深度的物体**(如牛棚:上挡/中不挡/下挡)用一条排序线不够,要**按深度拆成几件,每件一条排序线**(节点原点=排序线 + Y-sort)。室内若有这种物件,同理;能用 TileSet 的 per-tile y_sort_origin 就更省。
- **网格是 AI 和引擎的共同坐标语言**:Schema 里一律用格子坐标 `[x,y]`,loder 再 `× tile_size` 转像素。

---

## 8. 待定 / 需要你拍板

- Schema 字段最终定义(floor 是单 tile 还是整网格?要不要多图层?墙/门怎么表达?)。
- Catalog 用 JSON 还是 Godot `Resource`。
- AI 输出的**校验与纠错策略**(拒绝 / 自动夹取 / 重采样)。
- 是否需要"房间模板"(AI 在模板槽位里填,而非全自由),通常更稳。

有疑问找场景线的人对齐;架构背景可回看本文件 §2–§3。
