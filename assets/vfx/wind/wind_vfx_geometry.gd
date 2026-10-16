@tool
class_name WindVfxGeometry
extends RefCounted
## Mesh dùng chung cho mọi VFX gió. Tạo một lần rồi cache, mọi vùng gió và cú thổi dùng lại.
## Hình dạng thật của nét do shader tính, mesh chỉ cung cấp UV (dọc nét, ngang nét).

## Số đoạn dọc một nét: đủ mịn cho nét cuộn mà vẫn rẻ
const STROKE_SEGMENTS := 24

static var _strip: ArrayMesh
static var _quad: QuadMesh
static var _plane: PlaneMesh


## Dải nét: UV.x 0 = đuôi, 1 = đầu; UV.y 0..1 ngang nét
static func strip() -> ArrayMesh:
	if _strip:
		return _strip
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for index in STROKE_SEGMENTS + 1:
		var t := float(index) / STROKE_SEGMENTS
		vertices.append(Vector3(t, 0.0, 0.0))
		vertices.append(Vector3(t, 1.0, 0.0))
		uv.append(Vector2(t, 0.0))
		uv.append(Vector2(t, 1.0))
		if index < STROKE_SEGMENTS:
			var a := index * 2
			indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	_strip = ArrayMesh.new()
	_strip.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _strip


## Quad 1x1 cho hạt và hơi mờ (shader tự quay về camera)
static func quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
	return _quad


## Mặt phẳng 1x1 nằm ngang cho dấu mặt đất và vòng sóng
static func plane() -> PlaneMesh:
	if _plane == null:
		_plane = PlaneMesh.new()
		_plane.size = Vector2.ONE
	return _plane


## MultiMesh với custom data ngẫu nhiên cố định theo seed: dựng một lần khi cấu hình đổi, không dựng mỗi frame
static func build_multimesh(mesh: Mesh, count: int, seed_value: int) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in count:
		multimesh.set_instance_transform(index, Transform3D.IDENTITY)
		multimesh.set_instance_custom_data(index, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	return multimesh
