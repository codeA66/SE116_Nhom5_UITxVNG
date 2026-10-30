class_name FireVortexVfx
extends Node3D
## VFX TẠM cho lốc lửa: vòng lửa xoáy quanh tâm hố hút khi hố bốc lửa, tắt khi hố thôi hút.
## Chỉ nghe signal (caught_fire của FireVortex, stopped của hố), không chạy gì mỗi frame (particle do GPU lo).
##
## TRẠNG THÁI (2026-10-30): bản tạm để test nhìn thấy hố bốc lửa. CHƯA ĐẠT về thẩm mỹ: sẽ giao AI khác làm bản đẹp
## (giữ nguyên cách nối signal, không đụng FireVortex / WindVortex).

@export var fire_vortex: FireVortex

@onready var _ring: GPUParticles3D = $Ring


## Nối signal; mặc định tắt
func _ready() -> void:
	_ring.emitting = false
	if fire_vortex == null:
		return
	fire_vortex.caught_fire.connect(_on_caught_fire)
	if fire_vortex.vortex:
		fire_vortex.vortex.stopped.connect(_on_stopped)


## Hố bốc lửa: vòng lửa theo bán kính hố
func _on_caught_fire() -> void:
	var mat := _ring.process_material as ParticleProcessMaterial
	var radius := fire_vortex.vortex.radius if fire_vortex.vortex else 2.5
	mat.emission_ring_radius = radius * 0.8
	mat.emission_ring_inner_radius = radius * 0.4
	_ring.emitting = true


## Hố thôi hút: tắt lửa (hạt đang bay tự tàn)
func _on_stopped() -> void:
	_ring.emitting = false
