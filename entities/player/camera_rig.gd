class_name CameraRig
extends Node3D
## Camera tách khỏi player (top_level) để đi theo có độ trễ, không giật theo từng va chạm.
## Nhìn trước theo hướng chạy: không có thì camera luôn tụt sau lưng, người chơi thấy ít phía trước.

const GROUP := &"camera_rig"

@export var follow_speed: float = 8.0

@export_group("Lookahead")
## Khoảng nhìn trước (m) khi chạy từ lookahead_full_speed trở lên. 0 = tắt
@export var lookahead_distance: float = 2.0
## Tốc độ ngang (m/s) đạt nhìn trước tối đa; chậm hơn thì nhìn trước ít hơn theo tỉ lệ
@export var lookahead_full_speed: float = 6.0
## Độ nhanh điểm nhìn trước đổi theo hướng mới. Nhỏ = êm khi đổi hướng liên tục, lớn = bám sát
@export var lookahead_response: float = 3.0

@export_group("Peek")
## Phần quãng đường camera trôi về phía điểm cần xem (0..1): không trôi hẳn để player vẫn còn trong khung
@export_range(0.0, 1.0) var peek_ratio: float = 0.6
## Camera trôi xa nhất bấy nhiêu mét khỏi player
@export var peek_max_distance: float = 8.0
## Độ nhanh trôi tới và trôi về
@export var peek_response: float = 2.5

var _lookahead: Vector3 = Vector3.ZERO
var _peek: Vector3 = Vector3.ZERO
var _peek_target: Vector3 = Vector3.ZERO
var _peek_time_left: float = 0.0

@onready var _target: Node3D = get_parent()
## Không phải CharacterBody3D thì không có vận tốc để nhìn trước, chỉ đi theo
@onready var _target_body: CharacterBody3D = _target as CharacterBody3D
@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	top_level = true
	add_to_group(GROUP)
	snap()


func _physics_process(delta: float) -> void:
	_lookahead = _lookahead.lerp(_get_desired_lookahead(), 1.0 - exp(-lookahead_response * delta))
	if _peek_time_left > 0.0:
		_peek_time_left -= delta
		if _peek_time_left <= 0.0:
			_peek_target = Vector3.ZERO
	_peek = _peek.lerp(_peek_target, 1.0 - exp(-peek_response * delta))
	global_position = global_position.lerp(_target.global_position + _lookahead + _peek, 1.0 - exp(-follow_speed * delta))


## Nhảy ngay tới mục tiêu (dùng khi dịch chuyển), không lướt từ vị trí cũ
func snap() -> void:
	_peek = Vector3.ZERO
	_peek_target = Vector3.ZERO
	_peek_time_left = 0.0
	_lookahead = Vector3.ZERO
	global_position = _target.global_position
	reset_physics_interpolation()


## Cho người chơi liếc thấy một chuyện vừa xảy ra ở xa (cổng mở...) mà không khoá điều khiển.
## Điểm đã nằm trong khung hình thì bỏ qua: người chơi đã thấy rồi
func peek_at(point: Vector3, hold: float) -> void:
	if _camera != null and _camera.is_position_in_frustum(point):
		return
	var offset := point - _target.global_position
	offset.y = 0.0
	_peek_target = offset.limit_length(peek_max_distance) * peek_ratio
	_peek_time_left = hold


func _get_desired_lookahead() -> Vector3:
	if _target_body == null or lookahead_distance <= 0.0:
		return Vector3.ZERO
	var horizontal := Vector3(_target_body.velocity.x, 0.0, _target_body.velocity.z)
	var ratio := minf(horizontal.length() / maxf(lookahead_full_speed, 0.01), 1.0)
	return horizontal.normalized() * lookahead_distance * ratio
