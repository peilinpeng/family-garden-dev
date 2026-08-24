extends SceneTree

## 原创花园 TileSet 生成器。
##
## 目标是保持既有 PNG 路径、尺寸、TileSet source ID 和存档兼容性，
## 同时用确定性绘制从零产生可再分发的 soft-pixel 占位美术。
## 运行：Godot --headless --path game --script res://tools/generate_original_garden_tileset.gd

const ROOT := "res://assets/garden/tileset"
const TRANSPARENT := Color8(0, 0, 0, 0)
const OUTLINE := Color8(72, 53, 45)
const WOOD_DARK := Color8(105, 69, 47)
const WOOD := Color8(157, 104, 67)
const WOOD_LIGHT := Color8(205, 153, 93)
const LEAF_DARK := Color8(48, 104, 67)
const LEAF := Color8(75, 143, 82)
const LEAF_LIGHT := Color8(121, 177, 99)
const STONE := Color8(139, 137, 128)
const STONE_LIGHT := Color8(186, 181, 162)
const GOLD := Color8(232, 188, 76)

const PROP_SPECS := {
	"props/Banner_Stick_1_Purple.png": Vector2i(24, 59),
	"props/Barrel_Small_Empty.png": Vector2i(16, 20),
	"props/Basket_Empty.png": Vector2i(22, 17),
	"props/Bench_1.png": Vector2i(14, 30),
	"props/Bench_3.png": Vector2i(14, 14),
	"props/BulletinBoard_1.png": Vector2i(44, 42),
	"props/Chopped_Tree_1.png": Vector2i(32, 31),
	"props/Crate_Large_Empty.png": Vector2i(24, 29),
	"props/Crate_Medium_Closed.png": Vector2i(16, 21),
	"props/Crate_Water_1.png": Vector2i(30, 22),
	"props/Fireplace_1.png": Vector2i(30, 26),
	"props/HayStack_2.png": Vector2i(29, 32),
	"props/LampPost_3.png": Vector2i(46, 62),
	"props/Plant_2.png": Vector2i(15, 11),
	"props/Sack_3.png": Vector2i(16, 14),
	"props/Sign_1.png": Vector2i(24, 22),
	"props/Sign_2.png": Vector2i(24, 22),
	"props/Table_Medium_1.png": Vector2i(42, 39),
	"trees/Bush_Emerald_1.png": Vector2i(40, 29),
	"trees/Bush_Emerald_2.png": Vector2i(48, 16),
	"trees/Bush_Emerald_3.png": Vector2i(28, 28),
	"trees/Bush_Emerald_4.png": Vector2i(16, 28),
	"trees/Bush_Emerald_5.png": Vector2i(14, 14),
	"trees/Bush_Emerald_6.png": Vector2i(15, 10),
	"trees/Bush_Emerald_7.png": Vector2i(12, 9),
	"trees/Tree_Emerald_1.png": Vector2i(64, 63),
	"trees/Tree_Emerald_2.png": Vector2i(46, 63),
	"trees/Tree_Emerald_3.png": Vector2i(52, 92),
	"trees/Tree_Emerald_4.png": Vector2i(48, 93),
}


func _initialize() -> void:
	_generate_surface("ground/Tileset_Ground.png", Vector2i(192, 224), "grass")
	_generate_surface("ground/Tileset_Dirt.png", Vector2i(96, 224), "dirt")
	_generate_surface("ground/Tileset_Road.png", Vector2i(96, 224), "road")
	_generate_surface("water/Tileset_Water.png", Vector2i(384, 208), "water")
	for relative_path: String in PROP_SPECS:
		_generate_prop(relative_path, PROP_SPECS[relative_path])
	print("Generated %d original garden assets." % (PROP_SPECS.size() + 4))
	quit()


func _generate_surface(relative_path: String, size: Vector2i, kind: String) -> void:
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var colors: Array[Color]
	match kind:
		"grass":
			colors = [Color8(91, 154, 87), Color8(109, 169, 92), Color8(71, 132, 77)]
		"dirt":
			colors = [Color8(164, 116, 76), Color8(184, 137, 91), Color8(132, 91, 64)]
		"road":
			colors = [Color8(154, 142, 119), Color8(177, 163, 132), Color8(119, 111, 98)]
		_:
			colors = [Color8(55, 135, 176), Color8(75, 160, 196), Color8(39, 107, 153)]
	image.fill(colors[0])
	for tile_y in range(size.y / 16):
		for tile_x in range(size.x / 16):
			var origin := Vector2i(tile_x * 16, tile_y * 16)
			_fill(image, Rect2i(origin, Vector2i(16, 16)), colors[(tile_x + tile_y) % 2])
			if kind == "water":
				_line(image, origin + Vector2i(2, 5 + (tile_x + tile_y) % 3), origin + Vector2i(8, 5 + (tile_x + tile_y) % 3), colors[1])
				_line(image, origin + Vector2i(7, 11), origin + Vector2i(13, 11), colors[2])
			else:
				var seed := tile_x * 41 + tile_y * 67 + kind.length() * 13
				for index in range(5):
					var px := 2 + posmod(seed + index * 7, 12)
					var py := 2 + posmod(seed * 3 + index * 11, 12)
					image.set_pixel(origin.x + px, origin.y + py, colors[2 if index % 2 == 0 else 0])
			if kind == "road" and (tile_x + tile_y) % 3 == 0:
				_line(image, origin + Vector2i(3, 8), origin + Vector2i(12, 8), colors[2])
	_save(image, ROOT + "/" + relative_path)


func _generate_prop(relative_path: String, size: Vector2i) -> void:
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(TRANSPARENT)
	var name := relative_path.get_file().get_basename()
	if name.begins_with("Tree_"):
		_draw_tree(image, name)
	elif name.begins_with("Bush_"):
		_draw_bush(image, name)
	else:
		match name:
			"Banner_Stick_1_Purple": _draw_banner(image)
			"Barrel_Small_Empty": _draw_barrel(image)
			"Basket_Empty": _draw_basket(image)
			"Bench_1", "Bench_3": _draw_bench(image, name.ends_with("1"))
			"BulletinBoard_1": _draw_board(image)
			"Chopped_Tree_1": _draw_stump(image)
			"Crate_Large_Empty", "Crate_Medium_Closed": _draw_crate(image)
			"Crate_Water_1": _draw_water_crate(image)
			"Fireplace_1": _draw_fireplace(image)
			"HayStack_2": _draw_hay(image)
			"LampPost_3": _draw_lamp(image)
			"Plant_2": _draw_plant(image)
			"Sack_3": _draw_sack(image)
			"Sign_1", "Sign_2": _draw_sign(image, name.ends_with("2"))
			"Table_Medium_1": _draw_table(image)
	_save(image, ROOT + "/" + relative_path)


func _draw_banner(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	_fill(image, Rect2i(w / 2 - 1, 3, 3, h - 6), WOOD_DARK)
	_fill(image, Rect2i(w / 2 + 2, 7, maxi(5, w / 2 - 3), h / 3), Color8(123, 84, 174))
	_fill(image, Rect2i(w / 2 + 3, 9, maxi(3, w / 2 - 5), 2), Color8(190, 151, 220))
	_fill(image, Rect2i(w / 2 - 4, h - 4, 9, 3), OUTLINE)


func _draw_barrel(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	_fill(image, Rect2i(2, 3, w - 4, h - 6), WOOD)
	_fill(image, Rect2i(3, 1, w - 6, 3), WOOD_LIGHT)
	_fill(image, Rect2i(3, h - 4, w - 6, 3), WOOD_DARK)
	_fill(image, Rect2i(1, 5, w - 2, 2), OUTLINE)
	_fill(image, Rect2i(1, h - 7, w - 2, 2), OUTLINE)
	_fill(image, Rect2i(w / 2, 4, 1, h - 8), WOOD_DARK)


func _draw_basket(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	_fill(image, Rect2i(2, h / 3, w - 4, h - h / 3 - 2), WOOD)
	_fill(image, Rect2i(4, h / 3 + 2, w - 8, 2), WOOD_LIGHT)
	_line(image, Vector2i(4, h / 2), Vector2i(w / 2, 1), OUTLINE)
	_line(image, Vector2i(w / 2, 1), Vector2i(w - 5, h / 2), OUTLINE)


func _draw_bench(image: Image, tall: bool) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var seat_y := h - 7
	if tall:
		_fill(image, Rect2i(2, 3, w - 4, maxi(3, h / 2)), WOOD)
		_fill(image, Rect2i(3, 5, w - 6, 2), WOOD_LIGHT)
	_fill(image, Rect2i(1, seat_y, w - 2, 4), WOOD_LIGHT)
	_fill(image, Rect2i(3, seat_y + 4, 2, 3), OUTLINE)
	_fill(image, Rect2i(w - 5, seat_y + 4, 2, 3), OUTLINE)


func _draw_board(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	_fill(image, Rect2i(4, 3, w - 8, h - 14), OUTLINE)
	_fill(image, Rect2i(6, 5, w - 12, h - 18), WOOD_LIGHT)
	_fill(image, Rect2i(9, 9, w - 18, 2), Color8(239, 218, 166))
	_fill(image, Rect2i(9, 14, w - 22, 2), Color8(239, 218, 166))
	_fill(image, Rect2i(8, h - 11, 4, 10), WOOD_DARK)
	_fill(image, Rect2i(w - 12, h - 11, 4, 10), WOOD_DARK)


func _draw_stump(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	_circle(image, Vector2i(w / 2, h / 2), mini(w, h) / 2 - 2, WOOD_DARK)
	_circle(image, Vector2i(w / 2, h / 2 - 2), mini(w, h) / 2 - 5, WOOD_LIGHT)
	_circle(image, Vector2i(w / 2, h / 2 - 2), mini(w, h) / 4, WOOD)


func _draw_crate(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	_fill(image, Rect2i(1, 2, w - 2, h - 3), OUTLINE)
	_fill(image, Rect2i(3, 4, w - 6, h - 7), WOOD)
	_line(image, Vector2i(4, 5), Vector2i(w - 5, h - 5), WOOD_LIGHT)
	_line(image, Vector2i(w - 5, 5), Vector2i(4, h - 5), WOOD_DARK)


func _draw_water_crate(image: Image) -> void:
	_draw_crate(image)
	_fill(image, Rect2i(4, 5, image.get_width() - 8, 6), Color8(69, 151, 194))
	_fill(image, Rect2i(6, 6, image.get_width() - 12, 1), Color8(150, 219, 224))


func _draw_fireplace(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	_fill(image, Rect2i(2, h - 8, w - 4, 6), STONE)
	_fill(image, Rect2i(5, h - 11, w - 10, 4), STONE_LIGHT)
	_circle(image, Vector2i(w / 2, h - 10), 6, Color8(224, 94, 46))
	_circle(image, Vector2i(w / 2, h - 12), 3, GOLD)


func _draw_hay(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	_circle(image, Vector2i(w / 2, h - 10), mini(w, h) / 2 - 3, Color8(201, 157, 62))
	_line(image, Vector2i(3, h - 8), Vector2i(w - 4, h - 13), GOLD)
	_line(image, Vector2i(5, h - 16), Vector2i(w - 6, h - 5), Color8(151, 111, 49))


func _draw_lamp(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	_fill(image, Rect2i(w / 2 - 2, 12, 4, h - 17), OUTLINE)
	_fill(image, Rect2i(w / 2 - 8, 5, 16, 13), OUTLINE)
	_fill(image, Rect2i(w / 2 - 5, 7, 10, 8), GOLD)
	_fill(image, Rect2i(w / 2 - 7, h - 5, 14, 4), OUTLINE)


func _draw_plant(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	_fill(image, Rect2i(w / 2, 4, 1, h - 4), LEAF_DARK)
	_circle(image, Vector2i(w / 2 - 3, 5), 3, LEAF)
	_circle(image, Vector2i(w / 2 + 3, 4), 3, LEAF_LIGHT)


func _draw_sack(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	_circle(image, Vector2i(w / 2, h - 6), mini(w, h) / 2 - 2, Color8(194, 167, 119))
	_fill(image, Rect2i(w / 2 - 3, 1, 6, 4), Color8(151, 121, 81))


func _draw_sign(image: Image, arrow: bool) -> void:
	var w := image.get_width()
	var h := image.get_height()
	_fill(image, Rect2i(w / 2 - 1, 7, 3, h - 8), WOOD_DARK)
	_fill(image, Rect2i(2, 2, w - 4, 8), OUTLINE)
	_fill(image, Rect2i(4, 4, w - 8, 4), WOOD_LIGHT)
	if arrow:
		_line(image, Vector2i(7, 6), Vector2i(w - 7, 6), WOOD_DARK)
		image.set_pixel(w - 7, 5, WOOD_DARK)
		image.set_pixel(w - 7, 7, WOOD_DARK)


func _draw_table(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	_circle(image, Vector2i(w / 2, h / 2 - 5), mini(w, h) / 2 - 3, OUTLINE)
	_circle(image, Vector2i(w / 2, h / 2 - 6), mini(w, h) / 2 - 6, WOOD_LIGHT)
	_fill(image, Rect2i(w / 2 - 2, h / 2 + 7, 4, h / 2 - 9), WOOD_DARK)


func _draw_bush(image: Image, name: String) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var radius := maxi(2, mini(w, h) / 3)
	_circle(image, Vector2i(w / 3, h - radius), radius, LEAF_DARK)
	_circle(image, Vector2i(w * 2 / 3, h - radius), radius, LEAF)
	_circle(image, Vector2i(w / 2, h - radius - maxi(1, radius / 2)), radius, LEAF_LIGHT)
	if name.ends_with("2") or name.ends_with("5"):
		for x in range(3, w - 2, maxi(4, w / 6)):
			image.set_pixel(x, h / 2, Color8(238, 184, 205))


func _draw_tree(image: Image, name: String) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var trunk_width := maxi(3, w / 8)
	_fill(image, Rect2i(w / 2 - trunk_width / 2, h * 2 / 3, trunk_width, h / 3 - 2), WOOD_DARK)
	var radius := maxi(5, mini(w, h) / 4)
	_circle(image, Vector2i(w / 2, h / 3), radius, LEAF_DARK)
	_circle(image, Vector2i(w / 3, h / 2), radius, LEAF)
	_circle(image, Vector2i(w * 2 / 3, h / 2), radius, LEAF)
	_circle(image, Vector2i(w / 2, h / 2 - radius / 2), radius, LEAF_LIGHT)
	if name.ends_with("3") or name.ends_with("4"):
		for offset in [-radius, 0, radius]:
			image.set_pixel(clampi(w / 2 + offset, 0, w - 1), clampi(h / 2, 0, h - 1), Color8(231, 187, 87))


func _fill(image: Image, area: Rect2i, color: Color) -> void:
	var bounds := area.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if bounds.has_area():
		image.fill_rect(bounds, color)


func _line(image: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var x0 := from.x
	var y0 := from.y
	var x1 := to.x
	var y1 := to.y
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var error := dx + dy
	while true:
		if x0 >= 0 and y0 >= 0 and x0 < image.get_width() and y0 < image.get_height():
			image.set_pixel(x0, y0, color)
		if x0 == x1 and y0 == y1:
			break
		var doubled := error * 2
		if doubled >= dy:
			error += dy
			x0 += sx
		if doubled <= dx:
			error += dx
			y0 += sy


func _circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			if Vector2i(x, y).distance_squared_to(center) <= radius * radius:
				image.set_pixel(x, y, color)


func _save(image: Image, path: String) -> void:
	var error := image.save_png(path)
	if error != OK:
		push_error("Failed to save %s: %s" % [path, error_string(error)])
