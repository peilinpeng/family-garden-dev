class_name MemoryLinkPath
extends RefCounted

const DEFAULT_BAKE_INTERVAL := 8.0

static func build_curve(source: Vector2, target: Vector2, curve_points: Array = []) -> Curve2D:
	var curve := Curve2D.new()
	curve.bake_interval = DEFAULT_BAKE_INTERVAL

	var explicit_points: Array[Vector2] = _parse_points(curve_points)
	if explicit_points.size() >= 2:
		for point in explicit_points:
			curve.add_point(point)
		return curve

	var delta: Vector2 = target - source
	var distance: float = maxf(delta.length(), 1.0)
	var normal: Vector2 = Vector2(-delta.y, delta.x).normalized()
	if normal == Vector2.ZERO:
		normal = Vector2.UP

	var seed: int = int(abs(hash(str(source) + str(target))))
	if seed % 2 == 0:
		normal = -normal

	var arch: float = clampf(distance * 0.18, 28.0, 92.0)
	var lift: Vector2 = Vector2(0.0, -clampf(distance * 0.08, 18.0, 54.0))
	var control_a: Vector2 = source + delta * 0.34 + normal * arch + lift
	var control_b: Vector2 = source + delta * 0.66 + normal * arch + lift

	curve.add_point(source, Vector2.ZERO, control_a - source)
	curve.add_point(target, control_b - target, Vector2.ZERO)
	return curve

static func sample(curve: Curve2D, progress: float) -> Vector2:
	if curve == null:
		return Vector2.ZERO
	var length: float = curve.get_baked_length()
	if length <= 0.0:
		return curve.get_point_position(0) if curve.point_count > 0 else Vector2.ZERO
	return curve.sample_baked(clampf(progress, 0.0, 1.0) * length)

static func tangent(curve: Curve2D, progress: float) -> Vector2:
	var a: Vector2 = sample(curve, progress)
	var b: Vector2 = sample(curve, clampf(progress + 0.01, 0.0, 1.0))
	var delta: Vector2 = b - a
	if delta.length_squared() <= 0.001:
		return Vector2.RIGHT
	return delta.normalized()

static func _parse_points(raw_points: Array) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for raw_point in raw_points:
		if raw_point is Vector2:
			points.append(raw_point)
		elif raw_point is Array and (raw_point as Array).size() >= 2:
			var pair: Array = raw_point
			points.append(Vector2(float(pair[0]), float(pair[1])))
		elif raw_point is Dictionary:
			var row: Dictionary = raw_point
			points.append(Vector2(float(row.get("x", 0.0)), float(row.get("y", 0.0))))
	return points
