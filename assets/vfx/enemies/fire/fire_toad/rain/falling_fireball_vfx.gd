extends Node3D
## Vòng báo bám theo kích thước vùng sát thương, kể cả khi đổi dữ liệu của từng lượt.

const ImpactVfx = preload("res://assets/vfx/enemies/fire/fire_toad/impact/fire_toad_impact_vfx.gd")

@export_group("Vòng báo")
@export var ring_floor_offset: float = 0.055
@export var orb_size_per_radius: float = 0.43
@export_range(0.0, 1.0) var normal_trail_ratio: float = 0.68

var _elapsed: float
var _warn_time: float
var _radius: float
var _hot: bool

@onready var falling: Node3D = $Falling
@onready var _warning: Node3D = $Warning
@onready var _field_material: ShaderMaterial = $Warning/Field.material_override as ShaderMaterial
@onready var _tail: GPUParticles3D = $Falling/Trail
@onready var _impact: ImpactVfx = $Impact


func _ready() -> void:
	reset()


func _process(delta: float) -> void:
	_elapsed += delta
	var progress: float = clampf(_elapsed / _warn_time, 0.0, 1.0)
	_field_material.set_shader_parameter(&"progress", progress)


func warn(radius: float, warn_time: float, hot: bool) -> void:
	_radius = radius
	_warn_time = maxf(warn_time, 0.001)
	_hot = hot
	_elapsed = 0.0
	_warning.position.y = ring_floor_offset
	_warning.scale = Vector3(radius, 1.0, radius)
	_field_material.set_shader_parameter(&"progress", 0.0)
	_field_material.set_shader_parameter(&"opacity", 1.0 if hot else 0.83)
	_warning.show()
	visible = true
	set_process(true)


func start_fall(height: float) -> void:
	falling.position = Vector3.UP * height
	falling.scale = Vector3.ONE * (_radius * orb_size_per_radius)
	falling.show()
	falling.reset_physics_interpolation()
	_tail.amount_ratio = 1.0 if _hot else normal_trail_ratio
	_tail.show()
	_tail.restart()
	_tail.emitting = true


func burst(flash_time: float) -> void:
	set_process(false)
	_warning.hide()
	_tail.emitting = false
	falling.hide()
	_impact.play(global_position, _radius, ImpactVfx.Kind.RAIN, _hot, flash_time)


func reset() -> void:
	set_process(false)
	visible = false
	_warning.hide()
	falling.hide()
	falling.position = Vector3.ZERO
	_tail.emitting = false
	_tail.hide()
	_impact.reset()
