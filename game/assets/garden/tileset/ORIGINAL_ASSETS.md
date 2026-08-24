# Family Garden 原创花园 TileSet

本目录中用于 `GardenTiled` 与花园搭建器的地面、道路、水面、道具和树木 PNG，
由项目内的确定性生成器 `game/tools/generate_original_garden_tileset.gd` 从零绘制。

生成器保留了原有文件路径和像素尺寸，用于兼容已有 TileSet source ID、场景布局与
用户花园摆放存档；图像内容不复制或改写第三方素材。

重新生成：

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path game \
  --script res://tools/generate_original_garden_tileset.gd
```
