class_name IceCrystalGeometry
extends RefCounted
## Dùng chung đúng silhouette tinh thể cho băng mặt đất và viên băng bay.

static func build() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var tip: Vector3 = Vector3(0.18, 1.0, -0.08)
	for side: int in 6:
		var a: float = float(side) * TAU / 6.0
		var b: float = float(side + 1) * TAU / 6.0
		var low_a: Vector3 = Vector3(cos(a) * 0.5, 0.0, sin(a) * 0.5)
		var low_b: Vector3 = Vector3(cos(b) * 0.5, 0.0, sin(b) * 0.5)
		var mid_a: Vector3 = Vector3(cos(a), 0.53, sin(a))
		var mid_b: Vector3 = Vector3(cos(b), 0.53, sin(b))
		for triangle: Array in [[low_a, mid_a, mid_b], [low_a, mid_b, low_b], [mid_a, tip, mid_b]]:
			var normal: Vector3 = (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).normalized()
			for i: int in 3:
				colors.append([Color.RED, Color.GREEN, Color.BLUE][i])
				uvs.append(Vector2(triangle[i].x * 0.5 + 0.5, triangle[i].y))
				vertices.append(triangle[i])
				normals.append(normal)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
