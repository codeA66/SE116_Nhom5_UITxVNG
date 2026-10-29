class_name BananaGeometry
extends RefCounted
## Mesh thật với mặt phẳng ít polygon; vỏ có bốn cánh dày, uốn cong và cuộn nhẹ ở đầu.

static func fruit() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring: int in 9:
		for side: int in 6:
			var u: float = float(ring) / 9.0
			var v: float = float(ring + 1) / 9.0
			var a: Vector3 = _fruit_point(u, side)
			var b: Vector3 = _fruit_point(u, side + 1)
			var c: Vector3 = _fruit_point(v, side)
			var d: Vector3 = _fruit_point(v, side + 1)
			var color: Color = Color(0.98, 0.69 + float(side % 3) * 0.07, 0.045)
			if ring == 0 or ring == 8: color = Color(0.23, 0.16, 0.055)
			_quad(surface, a, b, c, d, color)
	surface.generate_normals()
	return surface.commit()

static func peel() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for flap: int in 4:
		var angle: float = float(flap) * TAU / 4.0 + 0.2
		var forward: Vector3 = Vector3(sin(angle), 0.0, cos(angle))
		var right: Vector3 = forward.cross(Vector3.UP)
		for step: int in 9:
			var a: Vector3 = _peel_point(float(step) / 9.0, forward)
			var b: Vector3 = _peel_point(float(step + 1) / 9.0, forward)
			var wa: float = sin(PI * (float(step) / 9.0 * 0.88 + 0.06)) * 0.15
			var wb: float = sin(PI * (float(step + 1) / 9.0 * 0.88 + 0.06)) * 0.15
			_quad(surface, a - right * wa, a + right * wa, b - right * wb, b + right * wb, Color(1.0, 0.84, 0.19))
			var down: Vector3 = Vector3.DOWN * 0.035
			_quad(surface, a + right * wa + down, a - right * wa + down, b + right * wb + down, b - right * wb + down, Color(0.77, 0.49, 0.025))
			_quad(surface, a - right * wa + down, a - right * wa, b - right * wb + down, b - right * wb, Color(0.53, 0.41, 0.035))
			_quad(surface, a + right * wa, a + right * wa + down, b + right * wb, b + right * wb + down, Color(0.63, 0.48, 0.04))
	for side: int in 6:
		var a: float = float(side) * TAU / 6.0
		var b: float = float(side + 1) * TAU / 6.0
		_quad(surface, Vector3(cos(a) * 0.07, 0.25, sin(a) * 0.07), Vector3(cos(b) * 0.07, 0.25, sin(b) * 0.07), Vector3(cos(a) * 0.035, 0.55, sin(a) * 0.035), Vector3(cos(b) * 0.035, 0.55, sin(b) * 0.035), Color(0.9, 0.59, 0.04))
	surface.generate_normals()
	return surface.commit()

static func _fruit_point(u: float, side: int) -> Vector3:
	var center: Vector3 = Vector3((u - 0.5) * 0.8, -sin(PI * u) * 0.22, 0.0)
	var angle: float = float(side) * TAU / 6.0
	var width: float = 0.018 + pow(maxf(sin(PI * u), 0.0), 0.6) * 0.092
	return center + Vector3(0.0, cos(angle) * width, sin(angle) * width)

static func _peel_point(u: float, forward: Vector3) -> Vector3:
	var height: float = lerpf(0.34, 0.07, u) + sin(u * TAU) * 0.14
	return forward * (0.025 + u * 0.67) + Vector3.UP * maxf(height, 0.045)

static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	surface.set_color(color)
	for point: Vector3 in [a, c, b, b, c, d]: surface.add_vertex(point)
