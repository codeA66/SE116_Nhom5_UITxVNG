@tool
class_name WindSpellbookVisual
extends Node3D
## Pickup giữ việc xoay và tương tác; shader chỉ phụ trách lơ lửng và nét gió.

const BOOK_SHADER: Shader = preload("res://assets/shaders/wind/shrine/wind_spellbook.gdshader")
const RIBBON_SHADER: Shader = preload("res://assets/shaders/wind/shrine/wind_spellbook_ribbon.gdshader")
const MAX_MOTES: int = 16

@export_group("Book")
@export_range(0.1, 1.0) var brightness: float = 0.95
@export_range(0.0, 0.2) var float_amplitude: float = 0.065
@export_range(0.0, 5.0) var float_speed: float = 1.5
@export_range(0.0, 0.5) var emblem_glow: float = 0.06

@export_group("Wind")
@export var wind_color: Color = Color("a6e0ef")
@export_range(0.0, 1.0) var wind_opacity: float = 0.72
@export_range(-3.0, 3.0) var orbit_speed: float = 0.8
@export_range(0, 16) var mote_count: int = 8
@export_range(0.1, 1.5) var mote_radius: float = 0.55
@export_range(0.0, 1.0) var mote_speed: float = 0.12

@export_group("Editor")
@export var preview_motion: bool = true

@onready var _book_meshes: Array[MeshInstance3D] = [$Presentation/Model/Wind_Spellbook/Covers, $Presentation/Model/Wind_Spellbook/Pages, $Presentation/Model/Wind_Spellbook/Spine, $Presentation/Model/Wind_Spellbook/Emblem]
@onready var _emblem: MeshInstance3D = $Presentation/Model/Wind_Spellbook/Emblem
@onready var _ribbons: MeshInstance3D = $Presentation/Model/Wind_Spellbook/BookWindRibbons
@onready var _motes: CPUParticles3D = $Motes


func _ready() -> void:
	var moving: bool = not Engine.is_editor_hint() or preview_motion
	var material_cache: Dictionary[Material, ShaderMaterial] = {}
	for mesh_instance: MeshInstance3D in _book_meshes:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.extra_cull_margin = 0.3
		for surface: int in range(mesh_instance.mesh.get_surface_count()):
			var source: BaseMaterial3D = mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null:
				continue
			# Các phần cùng màu dùng lại material, chỉ tạo khi khởi tạo vật phẩm.
			if not material_cache.has(source):
				var material: ShaderMaterial = ShaderMaterial.new()
				material.shader = BOOK_SHADER
				material.set_shader_parameter(&"book_color", source.albedo_color)
				material.set_shader_parameter(&"brightness", brightness)
				material.set_shader_parameter(&"float_amplitude", float_amplitude)
				material.set_shader_parameter(&"float_speed", float_speed if moving else 0.0)
				material.set_shader_parameter(&"emblem_glow", emblem_glow if mesh_instance == _emblem else 0.0)
				material_cache[source] = material
			mesh_instance.set_surface_override_material(surface, material_cache[source])
	var ribbon_material: ShaderMaterial = ShaderMaterial.new()
	ribbon_material.shader = RIBBON_SHADER
	ribbon_material.set_shader_parameter(&"wind_color", wind_color)
	ribbon_material.set_shader_parameter(&"opacity", wind_opacity)
	ribbon_material.set_shader_parameter(&"orbit_speed", orbit_speed if moving else 0.0)
	ribbon_material.set_shader_parameter(&"float_amplitude", float_amplitude)
	ribbon_material.set_shader_parameter(&"float_speed", float_speed if moving else 0.0)
	_ribbons.material_override = ribbon_material
	_ribbons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ribbons.extra_cull_margin = 0.3
	_motes.amount = clampi(mote_count, 1, MAX_MOTES)
	_motes.emission_sphere_radius = mote_radius
	_motes.initial_velocity_min = mote_speed * 0.6
	_motes.initial_velocity_max = mote_speed
	_motes.color = wind_color
	_motes.emitting = mote_count > 0 and moving
	_motes.visible = mote_count > 0
	set_process(false)
	set_physics_process(false)
