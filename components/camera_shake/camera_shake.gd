class_name CameraShake
extends Node
## Rung camera theo trauma của ScreenShake: độ rung = trauma², nhiễu mượt (FastNoiseLite) thay vì ngẫu nhiên giật.
## Đặt làm con của Camera3D. Chỉ chạy process khi đang có trauma; hết trauma thì trả offset về giá trị gốc.

@export var camera: Camera3D

@export_group("Shake")
## Lệch ngang / dọc tối đa khi trauma = 1 (m, theo h_offset / v_offset). Camera game xa ~30 m nên cần lớn mới thấy
@export var max_offset: float = 1.8
## Nghiêng tối đa (độ) khi trauma = 1
@export var max_roll_degrees: float = 1.2
## Tốc độ nhiễu (càng cao rung càng nhanh)
@export var frequency: float = 18.0

## Mỗi trục lấy nhiễu ở một hàng riêng để không rung đồng pha
const NOISE_ROW_H := 13.7
const NOISE_ROW_V := 37.0
const NOISE_ROW_ROLL := 91.0
const MIN_REAL_DELTA_SCALE := 0.001

var _noise: FastNoiseLite
var _time: float = 0.0
var _base_h: float = 0.0
var _base_v: float = 0.0
var _base_roll: float = 0.0


func _ready() -> void:
	if camera == null:
		camera = get_parent() as Camera3D
	if camera == null:
		push_error("%s cần Camera3D (con trực tiếp hoặc gán camera)" % get_path())
		set_process(false)
		return
	_base_h = camera.h_offset
	_base_v = camera.v_offset
	_base_roll = camera.rotation.z
	# Tạo noise một lần, dùng lại mọi frame
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = randi()
	# Bắt đầu ở điểm ngẫu nhiên: gần gốc toạ độ simplex noise xấp xỉ 0 nên rung yếu
	_time = randf() * 1000.0 / frequency
	ScreenShake.trauma_added.connect(_on_trauma_added)
	# Có thể đã có trauma trước khi node vào cây
	set_process(ScreenShake.trauma > 0.0)


func _process(delta: float) -> void:
	if ScreenShake.trauma <= 0.0:
		_restore()
		set_process(false)
		return
	_time += delta / maxf(Engine.time_scale, MIN_REAL_DELTA_SCALE)
	var power := ScreenShake.trauma * ScreenShake.trauma
	var t := _time * frequency
	camera.h_offset = _base_h + max_offset * power * _noise.get_noise_2d(t, NOISE_ROW_H)
	camera.v_offset = _base_v + max_offset * power * _noise.get_noise_2d(t, NOISE_ROW_V)
	camera.rotation.z = _base_roll + deg_to_rad(max_roll_degrees) * power * _noise.get_noise_2d(t, NOISE_ROW_ROLL)


func _on_trauma_added(_amount: float) -> void:
	set_process(true)


func _restore() -> void:
	camera.h_offset = _base_h
	camera.v_offset = _base_v
	camera.rotation.z = _base_roll
