class_name HitSpark
extends Node3D
## Hiệu ứng chém trúng (pool), ghép từ các lớp màu TRẮNG (lõi HDR, mép sắc) bật theo thứ tự thời gian:
##  1) nét cắt thẳng rất dài, hiện đủ chiều dài ngay rồi co bề dày về 0;
##  2) ngôi sao lóe 4 cánh + vài nét lực toả hình quạt rồi co lại;
##  3) vòng sóng mảnh nằm ngang quanh hông (đòn mạnh có 2 vòng);
##  4) tia lửa ấm có trọng lực (màu theo tham số).
## Tiến trình tính theo delta của game nên lúc hitstop (time_scale thấp) hiệu ứng đứng yên ở khung đầu:
## đó chính là khoảnh khắc đóng băng. CombatFx lấy từ ObjectPool rồi gọi play(); xong tự nhả về pool.

@export_group("Cut Flash")
@export var cut_length: float = 4.5
@export var cut_thickness: float = 0.22
@export var cut_time: float = 0.1
## Lệch của nét cắt so với hướng đòn (độ, quanh trục đứng), dấu ngẫu nhiên; chỉ dùng khi play() không nhận hướng nét cắt
@export var cut_angle_degrees: float = 70.0
## Nghiêng nét cắt lên trên (cộng vào trục) để không nằm bẹt sát sàn khi nhìn từ trên
@export var cut_lift: float = 0.3

@export_group("Star")
@export var star_size: float = 1.9
@export var star_time: float = 0.12
## Lệch xoay ngẫu nhiên của sao (độ)
@export var star_jitter_degrees: float = 10.0

@export_group("Impact Lines")
@export var line_speed_min: float = 16.0
@export var line_speed_max: float = 26.0
@export var line_length_min: float = 1.3
@export var line_length_max: float = 2.1
@export var line_spread_degrees: float = 60.0
@export var lines_normal: int = 4
@export var lines_strong: int = 7

@export_group("Shock Ring")
@export var ring_size: float = 2.4
@export var ring_time: float = 0.18
## Vòng thứ hai (đòn mạnh) lệch nhịp và to hơn
@export var ring2_delay: float = 0.03
@export var ring2_scale: float = 1.35

@export_group("Sparks")
@export var spark_speed_min: float = 4.0
@export var spark_speed_max: float = 9.0
@export var spark_length_min: float = 0.5
@export var spark_length_max: float = 1.0

## Lúc t = 0 các lớp đã ở mức này của kích thước tối đa: hiện ngay frame trúng
const START_SCALE := 0.45

var _age: float = 0.0
var _scale: float = 1.0
var _strong: bool = false
var _end_time: float = 0.0
var _star_spin: float = 0.0

@onready var _cut: MeshInstance3D = $CutFlash
@onready var _star: MeshInstance3D = $Star
@onready var _ring: MeshInstance3D = $Ring
@onready var _ring2: MeshInstance3D = $Ring2
@onready var _sparks: CPUParticles3D = $Sparks
@onready var _lines: CPUParticles3D = $ImpactLines
@onready var _cut_material: ShaderMaterial = _cut.material_override as ShaderMaterial
@onready var _star_material: ShaderMaterial = _star.material_override as ShaderMaterial
@onready var _ring_material: ShaderMaterial = _ring.material_override as ShaderMaterial
@onready var _ring2_material: ShaderMaterial = _ring2.material_override as ShaderMaterial
@onready var _spark_material: ShaderMaterial = _sparks.material_override as ShaderMaterial


func _ready() -> void:
	_sparks.scale_amount_curve = FxUtil.make_curve([Vector2(0.0, 1.0), Vector2(0.6, 0.7), Vector2(1.0, 0.1)])
	_sparks.color_ramp = FxUtil.make_alpha_gradient([[0.0, 1.0], [0.55, 1.0], [1.0, 0.0]])
	# Nét lực bắn ra rồi co lại về 0
	_lines.scale_amount_curve = FxUtil.make_curve([Vector2(0.0, 1.0), Vector2(0.5, 0.8), Vector2(1.0, 0.0)])
	_lines.color_ramp = FxUtil.make_alpha_gradient([[0.0, 1.0], [1.0, 1.0]])
	_sparks.finished.connect(_on_finished)
	set_process(false)


func _process(delta: float) -> void:
	_age += delta
	_apply(_age)
	if _age >= _end_time:
		set_process(false)


## world_position: điểm trúng; direction: hướng đòn (đẩy lùi); color: màu tia lửa;
## power: 1 = thường, > 1 = đòn mạnh / kết liễu (nhiều nét lực hơn, 2 vòng sóng).
## cut_direction: hướng nét cắt (ngang) theo chiều vung của nhát; ZERO = lệch ngẫu nhiên cut_angle_degrees
func play(world_position: Vector3, direction: Vector3, color: Color, effect_scale: float = 1.0, power: float = 1.0, cut_direction: Vector3 = Vector3.ZERO, cut_scale: float = 1.0) -> void:
	_scale = maxf(effect_scale, 0.01)
	_strong = power > 1.0
	global_position = world_position
	var dir := direction.normalized() if direction.length_squared() > 0.0001 else Vector3.UP
	var cut_axis := Vector3(cut_direction.x, 0.0, cut_direction.z)
	if cut_axis.length_squared() < 0.0001:
		var flat := Vector3(dir.x, 0.0, dir.z)
		cut_axis = (flat if flat.length_squared() > 0.0001 else Vector3.RIGHT).normalized()
		var sign_random := 1.0 if randf() < 0.5 else -1.0
		cut_axis = cut_axis.rotated(Vector3.UP, deg_to_rad(cut_angle_degrees) * sign_random)
	cut_axis = (cut_axis.normalized() + Vector3.UP * cut_lift).normalized()
	var cut_mul := maxf(cut_scale, 0.01)
	_cut_material.set_shader_parameter(&"axis", cut_axis)
	_cut_material.set_shader_parameter(&"length_m", cut_length * _scale * cut_mul * (1.25 if _strong else 1.0))
	_cut_material.set_shader_parameter(&"thickness_m", cut_thickness * _scale * cut_mul)
	_star_spin = _screen_angle(world_position, cut_axis) + deg_to_rad(randf_range(-star_jitter_degrees, star_jitter_degrees))
	_star_material.set_shader_parameter(&"spin", _star_spin)

	_lines.amount = lines_strong if _strong else lines_normal
	_lines.direction = dir
	_lines.spread = line_spread_degrees
	_lines.initial_velocity_min = line_speed_min * _scale
	_lines.initial_velocity_max = line_speed_max * _scale
	var length_boost := 1.4 if _strong else 1.0
	_lines.scale_amount_min = line_length_min * _scale * length_boost
	_lines.scale_amount_max = line_length_max * _scale * length_boost

	_spark_material.set_shader_parameter(&"tint", color)
	_sparks.direction = dir
	_sparks.initial_velocity_min = spark_speed_min * _scale
	_sparks.initial_velocity_max = spark_speed_max * _scale
	_sparks.scale_amount_min = spark_length_min * _scale
	_sparks.scale_amount_max = spark_length_max * _scale

	_age = 0.0
	_end_time = maxf(maxf(cut_time, star_time), ring_time + (ring2_delay if _strong else 0.0))
	_cut.visible = true
	_star.visible = true
	_ring.visible = true
	_ring2.visible = _strong
	_apply(0.0)
	_sparks.restart()
	_lines.restart()
	set_process(true)


## ObjectPool gọi khi nhả về: dừng hết để không tốn xử lý
func pool_released() -> void:
	if _sparks == null:
		return
	_sparks.emitting = false
	_lines.emitting = false
	set_process(false)


## Đặt trạng thái các lớp tại thời điểm age (s)
func _apply(age: float) -> void:
	var cut_t := clampf(age / cut_time, 0.0, 1.0)
	_cut_material.set_shader_parameter(&"progress", cut_t)
	_cut.visible = cut_t < 1.0

	var star_t := clampf(age / star_time, 0.0, 1.0)
	# Bung ease-out expo rồi teo ở nửa sau
	var burst := lerpf(START_SCALE, 1.0, _ease_out_expo(star_t))
	var shrink := 1.0 - smoothstep(0.5, 1.0, star_t)
	_star.scale = Vector3.ONE * star_size * _scale * burst * shrink * (1.3 if _strong else 1.0)
	_star.visible = star_t < 1.0

	_update_ring(_ring, _ring_material, age, 1.0)
	if _strong:
		_update_ring(_ring2, _ring2_material, age - ring2_delay, ring2_scale)


func _update_ring(ring: MeshInstance3D, material: ShaderMaterial, age: float, size_factor: float) -> void:
	var t := clampf(age / ring_time, 0.0, 1.0)
	material.set_shader_parameter(&"progress", _ease_out_expo(t))
	ring.scale = Vector3.ONE * ring_size * _scale * size_factor
	ring.visible = t < 1.0


func _ease_out_expo(t: float) -> float:
	return 1.0 if t >= 1.0 else 1.0 - pow(2.0, -10.0 * t)


## Góc (rad) của trục theo thế giới khi chiếu lên màn hình, để cánh dài của sao thẳng hàng nét cắt
func _screen_angle(world_position: Vector3, axis: Vector3) -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(world_position):
		return 0.0
	var delta := camera.unproject_position(world_position + axis) - camera.unproject_position(world_position)
	return -atan2(delta.y, delta.x)


func _on_finished() -> void:
	var pool := get_parent() as ObjectPool
	if pool:
		pool.release(self)
