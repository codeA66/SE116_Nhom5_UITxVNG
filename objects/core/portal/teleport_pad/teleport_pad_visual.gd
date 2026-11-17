class_name TeleportPadVisual
extends Node3D
## Hình đĩa dịch chuyển (model teleport_pad + tia sáng bay thẳng lên + đèn xanh lơ). Chỉ đổi hình ảnh.
## set_active: tắt thì ẩn hẳn (không vẽ, hạt dừng); bật thì đĩa nở ra từ tâm, đèn sáng dần, tia sáng bay lên.
## Hiệu năng: chỉ tween khi đổi trạng thái, không có _process.

@export var active: bool = false
@export var light_energy: float = 2.5
@export_range(0.0, 3.0, 0.05) var appear_time: float = 1.2
## Cỡ đĩa lúc bắt đầu hiện (tỉ lệ so với cỡ thật)
@export_range(0.01, 1.0, 0.01) var appear_start_scale: float = 0.05

var _tween: Tween

@onready var _model: Node3D = $Model
@onready var _light: OmniLight3D = $Light
@onready var _rays: GPUParticles3D = $Rays


func _ready() -> void:
	set_active(active, true)


func set_active(value: bool, instant: bool = false) -> void:
	active = value
	if not is_node_ready():
		return
	if _tween:
		_tween.kill()
	_rays.emitting = value
	if not value:
		visible = false
		_light.light_energy = 0.0
		return
	visible = true
	if instant or appear_time <= 0.0:
		_model.scale = Vector3.ONE
		_light.light_energy = light_energy
		return
	_model.scale = Vector3(appear_start_scale, 1.0, appear_start_scale)
	_light.light_energy = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_model, ^"scale", Vector3.ONE, appear_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_light, ^"light_energy", light_energy, appear_time)
