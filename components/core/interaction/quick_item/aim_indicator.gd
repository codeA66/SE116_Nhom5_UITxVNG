class_name AimIndicator
extends Node3D
## Hình nhắm khi giữ phím dùng vật phẩm: vòng tầm quanh player (bán kính = tầm) + dấu ở chỗ sẽ dùng.
## Đặt top_level để không xoay theo player. Chỉ đổi vị trí khi QuickItemUser gọi aim_at, không có _process.

## Độ nâng khỏi mặt sàn (m) để không chớp lẫn với sàn
@export_range(0.0, 0.5, 0.01) var lift: float = 0.04

@onready var _ring: MeshInstance3D = $Ring
@onready var _marker: MeshInstance3D = $Marker


func _ready() -> void:
	top_level = true
	hide()


## Hiện vòng tầm bán kính radius tâm center (chân player) và dấu ở target
func aim_at(center: Vector3, radius: float, target: Vector3) -> void:
	global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	_ring.global_position = center + Vector3.UP * lift
	# Mesh vòng có bán kính 1 m: phóng theo tầm
	_ring.scale = Vector3(radius, 1.0, radius)
	_marker.global_position = target + Vector3.UP * lift
	show()


func get_marker_position() -> Vector3:
	return _marker.global_position - Vector3.UP * lift
