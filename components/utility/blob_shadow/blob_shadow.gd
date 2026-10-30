class_name BlobShadow
extends Node3D
## Bóng tròn dưới chân: bắn tia thẳng xuống, đặt bóng tại điểm chạm mặt đất.
## Càng lên cao bóng càng nhỏ và mờ, giúp người chơi biết chỗ tiếp đất khi nhìn từ trên cao.
## Gắn làm con của nhân vật (player, quái...); tự tách khỏi phép quay của cha.

@export var radius: float = 0.45
## Độ cao tối đa còn hiện bóng
@export var max_height: float = 12.0
## Tỉ lệ kích thước bóng ở max_height so với khi đứng trên đất
@export_range(0.0, 1.0) var min_scale: float = 0.35
@export_range(0.0, 1.0) var max_opacity: float = 0.55
## Nâng bóng khỏi mặt đất một chút để không bị nhấp nháy (z-fighting)
@export var surface_offset: float = 0.03
## Chỉ chiếu lên các layer này (mặc định: world)
@export_flags_3d_physics var collision_mask: int = 1

var _material: StandardMaterial3D

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _target: Node3D = get_parent()


func _ready() -> void:
	top_level = true
	# Mỗi bóng giữ vật liệu riêng vì độ mờ thay đổi theo độ cao của từng nhân vật
	_material = (_mesh.material_override as StandardMaterial3D).duplicate()
	_mesh.material_override = _material


func _physics_process(_delta: float) -> void:
	var origin := _target.global_position + Vector3.UP * 0.1
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * max_height, collision_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_mesh.visible = false
		return

	var hit_position: Vector3 = hit.position
	var hit_normal: Vector3 = hit.normal
	var height_ratio := clampf((origin.y - hit_position.y) / max_height, 0.0, 1.0)
	var size := radius * 2.0 * lerpf(1.0, min_scale, height_ratio)

	_mesh.visible = true
	global_position = hit_position + hit_normal * surface_offset
	global_basis = _basis_from_normal(hit_normal).scaled(Vector3(size, 1.0, size))
	_material.albedo_color.a = max_opacity * (1.0 - height_ratio)


## Basis có trục Y trùng pháp tuyến mặt đất, để bóng nằm sát mặt dốc
func _basis_from_normal(normal: Vector3) -> Basis:
	var x_axis := normal.cross(Vector3.FORWARD)
	if x_axis.length_squared() < 0.001:
		x_axis = normal.cross(Vector3.RIGHT)
	x_axis = x_axis.normalized()
	return Basis(x_axis, normal, x_axis.cross(normal).normalized())
