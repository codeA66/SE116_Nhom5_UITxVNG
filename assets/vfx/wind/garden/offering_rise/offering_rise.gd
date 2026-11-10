class_name GardenOfferingRise
extends Node3D
## VFX được tạo sẵn trên mỗi bàn tế; tween và hạt chỉ chạy khi đặt chuối.

@export_range(0.0, 12.0, 0.1) var flash_energy: float = 5.0

var _tween: Tween
var _column_material: ShaderMaterial
var _ring_material: ShaderMaterial
var _half_height: float
var _particle_material: StandardMaterial3D

@onready var _column: MeshInstance3D = $Column
@onready var _ring: MeshInstance3D = $BasePulse
@onready var _streaks: CPUParticles3D = $RisingStreaks
@onready var _sparks: CPUParticles3D = $Sparks
@onready var _light: OmniLight3D = $PlacementLight

func _ready() -> void:
	_column_material = _column.material_override.duplicate() as ShaderMaterial
	_column.material_override = _column_material
	_ring_material = _ring.material_override.duplicate() as ShaderMaterial
	_ring.material_override = _ring_material
	_half_height = _column.mesh.get_aabb().size.y*0.5
	_particle_material = (_streaks.mesh.material as StandardMaterial3D).duplicate() as StandardMaterial3D
	_streaks.material_override = _particle_material
	_sparks.material_override = _particle_material
	hide()
	set_process(false)
	set_physics_process(false)

func play(duration: float, tint: Color) -> void:
	if is_instance_valid(_tween): _tween.kill()
	_column_material.set_shader_parameter("tint",tint)
	_ring_material.set_shader_parameter("tint",tint)
	_streaks.color = tint
	_sparks.color = tint
	_light.light_color = tint
	show()
	_animate(0.0)
	_streaks.restart()
	_sparks.restart()
	_tween = create_tween()
	_tween.tween_method(_animate,0.0,1.0,maxf(duration,0.1))
	_tween.finished.connect(_finish)

func _finish() -> void:
	_streaks.emitting = false
	_sparks.emitting = false
	hide()

func _animate(progress: float) -> void:
	var envelope: float = smoothstep(0.0,0.1,progress) * (1.0-smoothstep(0.55,1.0,progress))
	var growth: float = lerpf(0.05,1.0,smoothstep(0.0,0.3,progress))
	_column.scale.y = growth
	_column.position.y = _half_height*growth
	_column_material.set_shader_parameter("strength",envelope)
	_ring.scale = Vector3.ONE*lerpf(0.6,1.4,progress)
	_ring_material.set_shader_parameter("strength",1.0-smoothstep(0.2,0.7,progress))
	_light.light_energy = flash_energy*envelope
	# Fade cả geometry của hạt, không chỉ cột sáng; emission cũng phải giảm về 0.
	var tail: float = 1.0-smoothstep(0.50,1.0,progress)
	_particle_material.albedo_color.a = tail
	_particle_material.emission_energy_multiplier = 2.0*tail
