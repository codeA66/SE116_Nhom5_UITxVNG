class_name RoomDimmer
extends Node
## Làm tối cả phòng bằng cách nhân màu vật liệu tường / sàn / vòm (model kit màu xám nhạt làm phòng chói hơn phòng bên).
## Gắn làm con của phòng (hoặc chỉ định target). Chạy một lần lúc vào cây, không có _process.
## Bỏ qua nhân vật, quái, vật nhặt và vùng (CharacterBody3D / Area3D) và vật liệu không phải StandardMaterial3D có bóng
## (VFX, đèn, nước shader), để chỉ kiến trúc tối đi còn điểm sáng giữ nguyên.

## Nhân màu vật liệu (1 = giữ nguyên, 0.7 = tối đi 30%)
@export_range(0.1, 1.0, 0.01) var brightness: float = 0.75
## Node chứa phòng; trống = cha của node này
@export var target: Node

## Vật liệu gốc + độ sáng -> bản tối, dùng chung giữa các phòng để không nhân bản vật liệu thừa
static var _cache: Dictionary = {}


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	if is_equal_approx(brightness, 1.0):
		return
	# Đợi phòng dựng xong con (model kit là scene con) rồi mới duyệt
	_apply.call_deferred(target if target else get_parent())


func _apply(root: Node) -> void:
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node != root and (node is CharacterBody3D or node is Area3D):
			continue
		var mesh := node as MeshInstance3D
		if mesh and mesh.mesh:
			_dim_mesh(mesh)
		var multi := node as MultiMeshInstance3D
		if multi and multi.multimesh and multi.multimesh.mesh:
			_dim_multimesh(multi)
		stack.append_array(node.get_children())


func _dim_mesh(mesh: MeshInstance3D) -> void:
	if mesh.material_override:
		var dimmed := _dimmed(mesh.material_override)
		if dimmed:
			mesh.material_override = dimmed
		return
	for i in mesh.mesh.get_surface_count():
		var dimmed := _dimmed(mesh.get_active_material(i))
		if dimmed:
			mesh.set_surface_override_material(i, dimmed)


## Nền gạch / tường dựng bằng MultiMesh: chỉ có material_override cho cả khối, lấy vật liệu bề mặt đầu nếu chưa có
func _dim_multimesh(multi: MultiMeshInstance3D) -> void:
	var source: Material = multi.material_override
	if source == null and multi.multimesh.mesh.get_surface_count() == 1:
		source = multi.multimesh.mesh.surface_get_material(0)
	var dimmed := _dimmed(source)
	if dimmed:
		multi.material_override = dimmed


func _dimmed(source: Material) -> Material:
	var standard := source as StandardMaterial3D
	if standard == null or standard.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or standard.emission_enabled:
		return null
	var key := "%d_%.3f" % [standard.get_instance_id(), brightness]
	if _cache.has(key):
		return _cache[key]
	var copy := standard.duplicate() as StandardMaterial3D
	var c := standard.albedo_color
	copy.albedo_color = Color(c.r * brightness, c.g * brightness, c.b * brightness, c.a)
	_cache[key] = copy
	return copy
