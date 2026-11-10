class_name WindGustSoftLayer
extends WindGustLayer
## Lớp gió dùng nét mềm trong suốt (shader wind_gust_soft) thay cho nét mực đặc: mỗi node một ShaderMaterial
## riêng để đặt tiến độ (progress) của chính nó; hình dựng sẵn một lần, lúc chạy chỉ đổi transform và progress.

const SOFT_SHADER: Shader = preload("res://assets/shaders/wind/blast/wind_gust_soft.gdshader")

@export_group("Soft")
## Tô thân lốc mờ theo chiều cao, dùng chung shader với dải viền.
@export var volume_mode: bool = false
## Phần cuối lượt (tỉ lệ) bắt đầu tan
@export_range(0.0, 1.0) var erode_start: float = 0.5
@export_range(0.0, 1.0) var opacity: float = 0.95

var _soft: ShaderMaterial


func _ready() -> void:
	super._ready()
	_soft = ShaderMaterial.new()
	_soft.shader = SOFT_SHADER
	_soft.set_shader_parameter(&"core_color", white_core)
	_soft.set_shader_parameter(&"edge_color", cyan_edge)
	_soft.set_shader_parameter(&"volume_mode", volume_mode)
	_soft.set_shader_parameter(&"erode_start", erode_start)
	_soft.set_shader_parameter(&"opacity", opacity)
	material_override = _soft


func _update_shape(phase: float) -> void:
	super._update_shape(phase)
	_soft.set_shader_parameter(&"progress", phase)


## Dải nằm theo đường points; bề ngang mỗi điểm = widths[i], hướng ngang = tiếp tuyến × UP (đường đi -x → +x thì
## mép trước là +z), hoặc thẳng đứng nếu upright (dải quấn quanh thân lốc: UV.y = 0 mép dưới, 1 mép trên).
## lift nâng mép trước (hoặc đẩy mép trên ra ngoài khi upright). UV.x dọc dải, UV.y = 0 mép sau, 1 mép trước
static func build_ribbon(points: PackedVector3Array, widths: PackedFloat32Array, lift: float = 0.0, upright: bool = false) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var last: int = points.size() - 1
	for index: int in points.size():
		var tangent: Vector3 = (points[mini(index + 1, last)] - points[maxi(index - 1, 0)]).normalized()
		var across: Vector3 = Vector3.UP if upright else tangent.cross(Vector3.UP).normalized()
		# Dải đứng: mép trên loe ra ngoài theo hướng tâm (vòng xoáy hơi mở như cột lốc)
		var flare: Vector3 = Vector3(points[index].x, 0.0, points[index].z).normalized() * lift if upright else Vector3.UP * lift
		var half: float = widths[index] * 0.5
		vertices.append(points[index] - across * half)
		vertices.append(points[index] + across * half + flare)
		var u: float = float(index) / float(last)
		uv.append(Vector2(u, 0.0))
		uv.append(Vector2(u, 1.0))
		if index > 0:
			var a: int = (index - 1) * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var ribbon_mesh := ArrayMesh.new()
	ribbon_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return ribbon_mesh


## Gộp nhiều dải thành một mesh (một lần vẽ)
static func merge_ribbons(parts: Array[ArrayMesh]) -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: ArrayMesh in parts:
		builder.append_from(part, 0, Transform3D.IDENTITY)
	return builder.commit()
