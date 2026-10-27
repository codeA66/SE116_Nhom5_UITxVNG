class_name ArrowImpact
extends Node3D
## Hiệu ứng mũi tên trúng (pool, CombatFx gọi play()), dựng theo bản Blender "Bow_VFX" pha Impact:
##  1) đĩa sáng quay mặt camera bung to rồi tắt dần;
##  2) vòng sóng vuông góc hướng bay lan rộng rồi mỏng dần;
##  3) tia lửa cam có trọng lực văng ngược về phía bắn.
## Tiến trình theo delta của game; xong tự nhả về pool.

@export_group("Burst")
## Đường kính tối đa của đĩa sáng (m)
@export var burst_size: float = 1.0
## Thời gian bung tới cỡ tối đa, rồi tắt dần tới burst_time (s)
@export var burst_grow_time: float = 0.07
@export var burst_time: float = 0.17
@export var burst_intensity: float = 3.0

@export_group("Ring")
## Cạnh quad của vòng sóng (m); bán kính vòng lúc lan hết ~ nửa cạnh
@export var ring_size: float = 1.0
@export var ring_time: float = 0.17

@export_group("Sparks")
@export var spark_speed_min: float = 3.5
@export var spark_speed_max: float = 7.0
@export var spark_length_min: float = 0.2
@export var spark_length_max: float = 0.45

@export_group("Sound")
## Âm thanh trúng; để trống = im lặng (chỗ cắm sẵn)
@export var impact_sound: AudioStream

var _age: float = 0.0
var _scale: float = 1.0
var _end_time: float = 0.0

@onready var _burst: MeshInstance3D = $Burst
@onready var _ring: MeshInstance3D = $Ring
@onready var _sparks: CPUParticles3D = $Sparks
@onready var _sound: AudioStreamPlayer3D = $ImpactSound
@onready var _burst_material: ShaderMaterial = _burst.material_override as ShaderMaterial
@onready var _ring_material: ShaderMaterial = _ring.material_override as ShaderMaterial


func _ready() -> void:
	_sparks.scale_amount_curve = FxUtil.make_curve([Vector2(0.0, 1.0), Vector2(0.6, 0.7), Vector2(1.0, 0.1)])
	_sparks.color_ramp = FxUtil.make_alpha_gradient([[0.0, 1.0], [0.55, 1.0], [1.0, 0.0]])
	_sparks.finished.connect(_on_finished)
	_sound.stream = impact_sound
	set_process(false)


func _process(delta: float) -> void:
	_age += delta
	_apply(_age)
	if _age >= _end_time:
		set_process(false)


## world_position: điểm trúng; direction: hướng mũi tên bay tới; effect_scale: nhân kích thước
func play(world_position: Vector3, direction: Vector3, effect_scale: float = 1.0) -> void:
	_scale = maxf(effect_scale, 0.01)
	global_position = world_position
	var dir := direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	# PlaneMesh nằm trong mặt XZ (pháp tuyến Y): xoay Y theo hướng bay để vòng đứng vuông góc đường tên
	_ring.basis = Basis(Quaternion(Vector3.UP, dir)).scaled(Vector3.ONE * ring_size * _scale)
	# Tia lửa văng ngược về phía bắn, hơi chếch lên
	_sparks.direction = (-dir + Vector3.UP * 0.6).normalized()
	_sparks.initial_velocity_min = spark_speed_min * _scale
	_sparks.initial_velocity_max = spark_speed_max * _scale
	_sparks.scale_amount_min = spark_length_min * _scale
	_sparks.scale_amount_max = spark_length_max * _scale
	_age = 0.0
	_end_time = maxf(burst_time, ring_time)
	_burst.visible = true
	_ring.visible = true
	_apply(0.0)
	_sparks.restart()
	if _sound.stream:
		_sound.play()
	set_process(true)


## ObjectPool gọi khi nhả về: dừng hết để không tốn xử lý
func pool_released() -> void:
	if _sparks == null:
		return
	_sparks.emitting = false
	set_process(false)


func _apply(age: float) -> void:
	var grow := clampf(age / maxf(burst_grow_time, 0.001), 0.0, 1.0)
	var fade := 1.0 - clampf((age - burst_grow_time) / maxf(burst_time - burst_grow_time, 0.001), 0.0, 1.0)
	_burst.scale = Vector3.ONE * burst_size * _scale * _ease_out(grow)
	# Cộng sáng (blend_add): giảm cường độ = mờ dần
	_burst_material.set_shader_parameter(&"intensity", burst_intensity * fade)
	_burst.visible = age < burst_time

	var ring_t := clampf(age / maxf(ring_time, 0.001), 0.0, 1.0)
	_ring_material.set_shader_parameter(&"progress", _ease_out(ring_t))
	_ring.visible = ring_t < 1.0


func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


func _on_finished() -> void:
	var pool := get_parent() as ObjectPool
	if pool:
		pool.release(self)
