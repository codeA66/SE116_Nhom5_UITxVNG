class_name ArmillarySpin
extends Node
## Quay chậm một phần quả cầu thiên văn ở tâm đền quanh trục đứng (chỉ để nhìn, không có va chạm).
## Mỗi phần quay riêng một node: chỉnh tốc độ / chiều từng vòng mà không sửa code.

@export var target: Node3D
@export var axis: Vector3 = Vector3.UP
## Độ / giây, âm = quay ngược
@export_range(-180.0, 180.0, 0.5) var degrees_per_second: float = 6.0


func _ready() -> void:
	if target == null or is_zero_approx(degrees_per_second):
		set_process(false)
		return
	# Quay theo khung hình nên tắt nội suy vật lý cho mục tiêu, không thì giật theo nhịp vật lý
	target.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	axis = axis.normalized()


func _process(delta: float) -> void:
	target.rotate(axis, deg_to_rad(degrees_per_second) * delta)
