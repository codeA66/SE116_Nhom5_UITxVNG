class_name BurningVfx
extends Node3D
## VFX TẠM cho trạng thái cháy: lửa nhỏ bám người + đèn cam khi BurnableComponent đang cháy.
## Chỉ nghe signal ignited / extinguished, không chạy gì mỗi frame (particle do GPU lo).
##
## TRẠNG THÁI (2026-10-30): bản tạm để test thấy quái đang cháy. CHƯA ĐẠT về thẩm mỹ:
## sẽ giao AI khác làm bản đẹp (giữ nguyên cách nối signal, không đụng BurnableComponent).

@export var burnable: BurnableComponent
## Cường độ đèn lúc cháy; 0 = không bật đèn (nhiều quái cháy cùng lúc thì nên tắt cho nhẹ)
@export var light_energy: float = 0.8

@onready var _flames: GPUParticles3D = $Flames
@onready var _light: OmniLight3D = $Light


func _ready() -> void:
	_flames.emitting = false
	_light.visible = false
	if burnable == null:
		return
	burnable.ignited.connect(_on_ignited)
	burnable.extinguished.connect(_on_extinguished)


func _on_ignited() -> void:
	_flames.emitting = true
	_light.light_energy = light_energy
	_light.visible = light_energy > 0.0


func _on_extinguished() -> void:
	_flames.emitting = false
	_light.visible = false
