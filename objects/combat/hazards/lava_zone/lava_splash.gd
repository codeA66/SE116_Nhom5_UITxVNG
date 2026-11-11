class_name LavaSplash
extends Node3D
## Hiệu ứng dung nham bắn lên khi có thứ rơi / bước vào: giọt dung nham, tia lửa, vòng gợn và đèn chớp ngắn.
## Dùng qua SplashPoolComponent (pool): gọi play(vị trí), xong tự phát finished để pool nhận lại.
## Hiệu năng: hạt một lần, không bóng đổ; chỉ tween theo sự kiện, đèn tắt sau khi chớp.

signal finished

@export_group("Thời gian")
## Tổng thời gian trước khi nhả về pool (s), phải >= lifetime của hạt
@export_range(0.3, 4.0, 0.05) var duration: float = 1.3
@export_range(0.05, 1.0, 0.01) var flash_time: float = 0.3
@export_range(0.1, 3.0, 0.05) var ring_time: float = 0.6
@export_group("Hình ảnh")
@export var flash_energy: float = 4.0
@export var ring_start_scale: float = 0.4
@export var ring_end_scale: float = 2.4

var _tween: Tween

@onready var _drops: GPUParticles3D = $Drops
@onready var _sparks: GPUParticles3D = $Sparks
@onready var _ring: MeshInstance3D = $Ring
@onready var _flash: OmniLight3D = $Flash


func play(world_position: Vector3) -> void:
	global_position = world_position
	if _tween:
		_tween.kill()
	_drops.restart()
	_sparks.restart()
	var ring_mat: StandardMaterial3D = _ring.material_override as StandardMaterial3D
	ring_mat.albedo_color.a = 0.85
	_ring.scale = Vector3(ring_start_scale, 1.0, ring_start_scale)
	_ring.visible = true
	_flash.light_energy = flash_energy
	_flash.visible = true
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_ring, ^"scale", Vector3(ring_end_scale, 1.0, ring_end_scale), ring_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(ring_mat, ^"albedo_color:a", 0.0, ring_time)
	_tween.tween_property(_flash, ^"light_energy", 0.0, flash_time)
	_tween.chain().tween_callback(_flash.hide)
	# Hết duration mới nhả: hạt còn bay tới cuối vòng đời
	_tween.tween_interval(maxf(duration - flash_time, 0.0))
	_tween.chain().tween_callback(finished.emit)
