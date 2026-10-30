class_name FireSpreadVfx
extends Node3D
## VFX TẠM cho luồng lửa lan: một chùm lửa phụt theo hướng gió mỗi lần FireSpread bật.
## Chỉ nghe signal fired, không chạy gì mỗi frame (particle do GPU lo). Nằm trong FireSpread nên +Z = hướng gió.
##
## TRẠNG THÁI (2026-10-30): bản tạm để test nhìn thấy lửa lan. CHƯA ĐẠT về thẩm mỹ: sẽ giao AI khác làm bản đẹp
## (giữ nguyên cách nối signal, không đụng FireSpread / BurnableComponent).

@export var spread: FireSpread

@onready var _jet: GPUParticles3D = $Jet


## Nối signal của luồng lửa; không có luồng thì đứng im
func _ready() -> void:
	_jet.emitting = false
	if spread:
		spread.fired.connect(_on_fired)


## Luồng lửa bật: chỉnh tốc độ hạt cho vừa chạm cuối luồng rồi phát một chùm
func _on_fired(_direction: Vector3) -> void:
	var mat := _jet.process_material as ParticleProcessMaterial
	var length := spread.data.length if spread.data else 4.0
	mat.initial_velocity_min = length / _jet.lifetime * 0.7
	mat.initial_velocity_max = length / _jet.lifetime * 1.0
	_jet.restart()
