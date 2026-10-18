@tool
class_name BowVisual
extends Node3D
## Cung low-poly: các node MeshInstance3D được tạo trong editor và runtime.

@export_range(0.0, 1.0) var draw_amount: float = 0.0:
	set(value):
		draw_amount = value
		if is_node_ready():
			_update_string()

var _top_string: MeshInstance3D
var _bottom_string: MeshInstance3D


func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("a66a35")
	var grip := StandardMaterial3D.new()
	grip.albedo_color = Color("293c48")
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color("9fe9f1")
	silver.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var points := PackedVector3Array([
		Vector3(0, -0.58, -0.18), Vector3(0, -0.39, 0.07),
		Vector3(0, -0.16, 0.05), Vector3.ZERO,
		Vector3(0, 0.16, 0.05), Vector3(0, 0.39, 0.07), Vector3(0, 0.58, -0.18),
	])
	for index in points.size() - 1:
		var limb := _make_rod("Limb%d" % index, 0.035, wood)
		_place_rod(limb, points[index], points[index + 1])
	var handle := _make_rod("Grip", 0.047, grip)
	_place_rod(handle, Vector3(0, -0.10, 0.025), Vector3(0, 0.10, 0.025))
	_top_string = _make_rod("TopString", 0.009, silver)
	_bottom_string = _make_rod("BottomString", 0.009, silver)
	_update_string()


func _make_rod(node_name: String, radius: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.material = material
	node.mesh = mesh
	add_child(node)
	return node


func _place_rod(node: Node3D, start: Vector3, end: Vector3) -> void:
	var direction := end - start
	node.position = (start + end) * 0.5
	node.quaternion = Quaternion(Vector3.UP, direction.normalized())
	node.scale = Vector3(1.0, direction.length(), 1.0)


func _update_string() -> void:
	var center := Vector3(0, 0, -0.18 - draw_amount * 0.24)
	_place_rod(_top_string, center, Vector3(0, 0.58, -0.18))
	_place_rod(_bottom_string, Vector3(0, -0.58, -0.18), center)
