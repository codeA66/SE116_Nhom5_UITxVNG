class_name FireWindVfx
extends Node3D
## VFX TẠM cho lửa theo vết gió: một chùm lửa phủ dọc phần vết gió đang cháy, bay xuôi gió.
## Chỉ nghe signal fired của FireWind, không chạy gì mỗi frame (particle do GPU lo). Nằm trong FireWind nên +Z = hướng gió.
##
## TRẠNG THÁI (2026-10-30): bản tạm để test nhìn thấy lửa theo gió. CHƯA ĐẠT về thẩm mỹ: sẽ giao AI khác làm bản đẹp
## (giữ nguyên cách nối signal, không đụng FireWind).

@export var fire_wind: FireWind

@onready var _trail: GPUParticles3D = $Trail


## Nối signal; mặc định tắt
func _ready() -> void:
	_trail.emitting = false
	if fire_wind:
		fire_wind.fired.connect(_on_fired)


## Vết lửa bật / kéo dài: phủ hạt đúng đoạn từ start tới cuối vết rồi phát một chùm
func _on_fired(start: float, length: float, width: float) -> void:
	var mat := _trail.process_material as ParticleProcessMaterial
	mat.emission_box_extents = Vector3(width * 0.4, 0.3, length * 0.5)
	_trail.position = Vector3(0.0, _trail.position.y, start + length * 0.5)
	_trail.restart()
