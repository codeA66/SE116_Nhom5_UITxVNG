class_name CameraRig
extends Node3D
## Camera tách khỏi player (top_level) để đi theo có độ trễ, không giật theo từng va chạm.

@export var follow_speed: float = 8.0

@onready var _target: Node3D = get_parent()


func _ready() -> void:
	top_level = true
	snap()


func _physics_process(delta: float) -> void:
	global_position = global_position.lerp(_target.global_position, 1.0 - exp(-follow_speed * delta))


## Nhảy ngay tới mục tiêu (dùng khi dịch chuyển), không lướt từ vị trí cũ
func snap() -> void:
	global_position = _target.global_position
	reset_physics_interpolation()
