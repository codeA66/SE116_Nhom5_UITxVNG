class_name VortexPortalVisual
extends Node3D
## Hình cổng xoáy năng lượng (đĩa shader vortex_portal + mảnh vụn bay + đèn xanh). Chỉ đổi hình ảnh.
## set_active: bật thì xoáy sáng rực, tắt thì chỉ còn quầng tối mờ. Hiệu năng: chỉ tween khi đổi trạng thái.

@export var active: bool = true
@export var light_energy: float = 3.0
@export_range(0.0, 3.0, 0.05) var switch_time: float = 1.0

var _tween: Tween

@onready var _disc: MeshInstance3D = $Disc
@onready var _light: OmniLight3D = $Light
@onready var _shards: GPUParticles3D = $Shards
@onready var _material: ShaderMaterial = _disc.get_surface_override_material(0) as ShaderMaterial


func _ready() -> void:
	# Mỗi cổng một bản vật liệu: bật / tắt cổng này không ảnh hưởng cổng khác
	_material = _material.duplicate() as ShaderMaterial
	_disc.set_surface_override_material(0, _material)
	set_active(active, true)


func set_active(value: bool, instant: bool = false) -> void:
	active = value
	if not is_node_ready():
		return
	var target: float = 1.0 if value else 0.0
	_shards.emitting = value
	if _tween:
		_tween.kill()
	if instant or switch_time <= 0.0:
		_material.set_shader_parameter(&"intensity", target)
		_light.light_energy = light_energy * target
		_light.visible = value
		return
	_light.visible = true
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_intensity, 1.0 - target, target, switch_time)
	_tween.tween_property(_light, ^"light_energy", light_energy * target, switch_time)


func _set_intensity(v: float) -> void:
	_material.set_shader_parameter(&"intensity", v)
