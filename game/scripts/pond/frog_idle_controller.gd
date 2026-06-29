extends AnimatedSprite2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sprite_frames == null:
		sprite_frames = _build_sprite_frames()
	if sprite_frames != null and sprite_frames.has_animation(&"idle"):
		play(&"idle")

func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle")
	frames.set_animation_loop(&"idle", true)
	frames.set_animation_speed(&"idle", 3.0)
	for i in range(1, 5):
		var path := "res://assets/pond/frog/frog_unknown_%02d.png" % i
		if ResourceLoader.exists(path):
			frames.add_frame(&"idle", load(path))
	return frames
