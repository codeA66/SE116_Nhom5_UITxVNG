class_name CameraRig
extends Node3D
## Camera tách khỏi player (top_level) để đi theo có độ trễ, không giật theo từng va chạm.
## Nhìn trước theo hướng chạy: không có thì camera luôn tụt sau lưng, người chơi thấy ít phía trước.

@export var follow_speed: float = 8.0

@export_group("Lookahead")
## Khoảng nhìn trước (m) khi chạy từ lookahead_full_speed trở lên. 0 = tắt
@export var lookahead_distance: float = 2.0
## Tốc độ ngang (m/s) đạt nhìn trước tối đa; chậm hơn thì nhìn trước ít hơn theo tỉ lệ
@export var lookahead_full_speed: float = 6.0
## Độ nhanh điểm nhìn trước đổi theo hướng mới. Nhỏ = êm khi đổi hướng liên tục, lớn = bám sát
@export var lookahead_response: float = 3.0

var _lookahead: Vector3 = Vector3.ZERO

@onready var _target: Node3D = get_parent()
## Không phải CharacterBody3D thì không có vận tốc để nhìn trước, chỉ đi theo
@onready var _target_body: CharacterBody3D = _target as CharacterBody3D


func _ready() -> void:
	top_level = true
	snap()


func _physics_process(delta: float) -> void:
	_lookahead = _lookahead.lerp(_get_desired_lookahead(), 1.0 - exp(-lookahead_response * delta))
	global_position = global_position.lerp(_target.global_position + _lookahead, 1.0 - exp(-follow_speed * delta))


## Nhảy ngay tới mục tiêu (dùng khi dịch chuyển), không lướt từ vị trí cũ
func snap() -> void:
	_lookahead = Vector3.ZERO
	global_position = _target.global_position
	reset_physics_interpolation()


func _get_desired_lookahead() -> Vector3:
	if _target_body == null or lookahead_distance <= 0.0:
		return Vector3.ZERO
	var horizontal := Vector3(_target_body.velocity.x, 0.0, _target_body.velocity.z)
	var ratio := minf(horizontal.length() / maxf(lookahead_full_speed, 0.01), 1.0)
	return horizontal.normalized() * lookahead_distance * ratio
