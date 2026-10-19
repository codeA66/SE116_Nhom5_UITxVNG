class_name WindReactivePetals
extends WindReactiveProp
## Cánh hoa trên đất bung thành một lớp bay lên và hạt riêng lẻ.

const PETAL_SHADER: Shader = preload("res://assets/shaders/wind_react_petal.gdshader")

@export_range(0.0, 5.0) var flight_distance: float = 1.0
@export_range(0.0, 5.0) var flight_lift: float = 2.4
@export_range(1, 32) var burst_count: int = 16

var _materials: Array[ShaderMaterial] = []
var _particles: CPUParticles3D
var _gust_progress: float = 1.0


func _setup_visual() -> void:
	_apply_materials(_model)
	_particles = CPUParticles3D.new()
	_particles.name = "FlyingPetals"
	_particles.amount = burst_count
	_particles.lifetime = data.recovery_seconds
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.emitting = false
	_particles.initial_velocity_min = 2.0
	_particles.initial_velocity_max = 3.0
	_particles.spread = 32.0
	_particles.gravity = Vector3(0.0, -2.5, 0.0)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.13, 0.08)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.74, 0.81)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	_particles.mesh = mesh
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)


func _on_reacted(direction: Vector3, strength: float) -> void:
	_gust_progress = 0.0
	for material in _materials:
		material.set_shader_parameter(&"gust_direction", _model.global_basis.inverse() * direction)
		material.set_shader_parameter(&"gust_strength", clampf(strength / maxf(data.full_strength, 0.01), 0.0, 2.0))
		material.set_shader_parameter(&"gust_progress", 0.0)
	_particles.direction = direction + Vector3.UP * 0.8
	_particles.restart()
	_particles.emitting = true
	set_process(true)


func _process(delta: float) -> void:
	_gust_progress = minf(_gust_progress + delta / maxf(data.recovery_seconds, 0.01), 1.0)
	for material in _materials:
		material.set_shader_parameter(&"gust_progress", _gust_progress)
	if _gust_progress >= 1.0:
		set_process(false)


func _on_wind_changed(direction: Vector3, strength: float) -> void:
	for material in _materials:
		material.set_shader_parameter(&"hold_strength", clampf(strength / maxf(data.full_strength, 0.01), 0.0, 2.0))
		if strength > 0.0:
			material.set_shader_parameter(&"hold_direction", _model.global_basis.inverse() * direction)


func _apply_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = PETAL_SHADER
		material.set_shader_parameter(&"flight_distance", flight_distance)
		material.set_shader_parameter(&"flight_lift", flight_lift)
		material.set_shader_parameter(&"flutter_speed", data.flutter_speed)
		mesh_instance.material_override = material
		_materials.append(material)
	for child in node.get_children():
		_apply_materials(child)
