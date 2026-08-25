class_name AIImageUploadService
extends RefCounted

## Gate 4 图片预处理。所有支持格式先解码，再统一重编码为 JPEG：
## - 消除路径/文件名信任；
## - 去除 EXIF 等元数据；
## - 自适应压缩到 CloudBase HTTP 入口可稳定承载的体积，控制上传与 AI 延迟。

const MAX_SOURCE_BYTES := 12 * 1024 * 1024
## HTTP 访问服务会对 Base64 后的整个 JSON 请求体限流；40 KiB 原始 JPEG
## 编码后约 54 KiB，给 header/JSON 留出安全余量。
const MAX_UPLOAD_BYTES := 40 * 1024
const MAX_EDGE := 1600
const MIN_EDGE := 32
const ALLOWED_TYPES := ["image/jpeg", "image/png", "image/webp"]

static func prepare(bytes: PackedByteArray, content_type: String) -> Dictionary:
	var mime := content_type.to_lower().strip_edges()
	if mime not in ALLOWED_TYPES:
		return _error("UNSUPPORTED_TYPE", "请选择 JPEG、PNG 或 WebP 图片。")
	if bytes.is_empty():
		return _error("EMPTY_IMAGE", "图片内容为空。")
	if bytes.size() > MAX_SOURCE_BYTES:
		return _error("SOURCE_TOO_LARGE", "原图不能超过 12 MB。")
	var image := Image.new()
	var load_error := ERR_FILE_UNRECOGNIZED
	match mime:
		"image/jpeg": load_error = image.load_jpg_from_buffer(bytes)
		"image/png": load_error = image.load_png_from_buffer(bytes)
		"image/webp": load_error = image.load_webp_from_buffer(bytes)
	if load_error != OK or image.is_empty():
		return _error("INVALID_IMAGE", "图片无法读取或内容与格式不一致。")
	if mini(image.get_width(), image.get_height()) < MIN_EDGE:
		return _error("IMAGE_TOO_SMALL", "图片尺寸至少需要 32×32。")
	var source_size := Vector2i(image.get_width(), image.get_height())
	image.convert(Image.FORMAT_RGB8)
	var attempts := [
		{"edge": MAX_EDGE, "quality": 0.82},
		{"edge": 1200, "quality": 0.70},
		{"edge": 900, "quality": 0.60},
		{"edge": 720, "quality": 0.52},
		{"edge": 560, "quality": 0.45},
		{"edge": 420, "quality": 0.38},
		{"edge": 360, "quality": 0.32},
	]
	var encoded := PackedByteArray()
	for attempt in attempts:
		_resize_to_edge(image, int(attempt.edge))
		encoded = image.save_jpg_to_buffer(float(attempt.quality))
		if not encoded.is_empty() and encoded.size() <= MAX_UPLOAD_BYTES:
			break
	if encoded.is_empty() or encoded.size() > MAX_UPLOAD_BYTES:
		return _error("ENCODE_TOO_LARGE", "图片压缩后仍超过云端传输限制，请换一张构图更简单的图片。")
	return {
		"ok": true,
		"bytes": encoded,
		"content_type": "image/jpeg",
		"source_size": source_size,
		"output_size": Vector2i(image.get_width(), image.get_height()),
		"source_bytes": bytes.size(),
		"output_bytes": encoded.size(),
	}

static func _resize_to_edge(image: Image, max_edge: int) -> void:
	var edge := maxi(image.get_width(), image.get_height())
	if edge <= max_edge:
		return
	var scale := float(max_edge) / float(edge)
	image.resize(maxi(1, roundi(image.get_width() * scale)), maxi(1, roundi(image.get_height() * scale)), Image.INTERPOLATE_LANCZOS)

static func _error(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message}}
