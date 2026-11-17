extends Node3D
## Mặt vũng, hơi nóng và bọt lấy chung bán kính để mép nhìn thấy trùng ranh giới sát thương.

@export_group("Nguội và tắt")
@export var cooling_time: float = 0.8
@export var floor_offset: float = 0.045
@export_range(0.0, 1.0) var normal_pop_ratio: float = 0.50

var _age: float
var _life: float
var _spread_time: float
var _fade_time: float

var _haze_material: ShaderMaterial
@onready var _surface_material: ShaderMaterial = $Surface.material_override as ShaderMaterial
@onready var _haze: MeshInstance3D = $Haze
@onready var _pops: GPUParticles3D = $Pops


func _ready() -> void:
	# Mỗi vũng cần vùng méo riêng để pool không ghi đè độ nóng của nhau.
	_haze_material = (_haze.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	_haze.material_override = _haze_material
	reset()


func _process(delta: float) -> void:
	_age += delta
	var remaining: float = maxf(_life - _age, 0.0)
	var spread: float = smoothstep(0.0, _spread_time, _age)
	var fade: float = clampf(remaining / _fade_time, 0.0, 1.0)
	var cooling: float = 1.0 - smoothstep(0.0, cooling_time, remaining)
	_surface_material.set_shader_parameter(&"spread", spread)
	_surface_material.set_shader_parameter(&"cooling", cooling)
	_surface_material.set_shader_parameter(&"opacity", fade)
	_haze_material.set_shader_parameter(&"vfx_opacity", 0.26 * spread * (1.0 - cooling))
	if remaining <= cooling_time and _pops.emitting:
		_pops.emitting = false


func play(radius: float, lifetime: float, spread_time: float, fade_time: float, hot: bool) -> void:
	_age = 0.0
	_spread_time = maxf(spread_time, 0.001)
	_fade_time = maxf(fade_time, 0.001)
	_life = maxf(lifetime, _spread_time + _fade_time)
	scale = Vector3(radius, 1.0, radius)
	position.y = floor_offset
	_surface_material.set_shader_parameter(&"heat", 1.0 if hot else 0.0)
	_surface_material.set_shader_parameter(&"spread", 0.0)
	_surface_material.set_shader_parameter(&"cooling", 0.0)
	_surface_material.set_shader_parameter(&"opacity", 1.0)
	_haze_material.set_shader_parameter(&"vfx_opacity", 0.0)
	_pops.amount_ratio = 1.0 if hot else normal_pop_ratio
	visible = true
	_pops.show()
	_pops.restart()
	_pops.emitting = true
	set_process(true)


func reset() -> void:
	set_process(false)
	visible = false
	_age = 0.0
	_pops.emitting = false
	_pops.hide()
	_surface_material.set_shader_parameter(&"spread", 0.0)
	_surface_material.set_shader_parameter(&"cooling", 0.0)
	_surface_material.set_shader_parameter(&"opacity", 0.0)
	_surface_material.set_shader_parameter(&"heat", 0.0)
	_haze_material.set_shader_parameter(&"vfx_opacity", 0.0)
