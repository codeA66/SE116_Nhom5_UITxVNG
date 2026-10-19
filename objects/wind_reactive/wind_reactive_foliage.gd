class_name WindReactiveFoliage
extends WindReactiveProp
## Uốn mesh bằng shader và tái dùng một bộ hạt CPU cho vật nhẹ.

const FOLIAGE_SHADER: Shader = preload("res://assets/shaders/wind_react_foliage.gdshader")

@export var particle_lifetime: float = 0.9
@export var particle_color: Color = Color(0.36, 0.62, 0.25)
@export var tint: Color = Color.WHITE
@export var flutter_factor: float = 0.13

var _materials: Array[ShaderMaterial] = []
var _particles: CPUParticles3D


func _setup_visual() -> void:
	_apply_materials(_model)
	_setup_particles()


func _on_reacted(direction: Vector3, strength: float) -> void:
	var gust_started: float = WindReactiveClock.arm(get_tree(), data.recovery_seconds)
	for material in _materials:
		material.set_shader_parameter(&"gust_direction", _model.global_basis.inverse() * direction)
		material.set_shader_parameter(&"gust_strength", clampf(strength / maxf(data.full_strength, 0.01), 0.0, 2.0))
		material.set_shader_parameter(&"gust_time", gust_started)
	_particles.direction = direction + Vector3.UP * 0.6
	_particles.restart()
	_particles.emitting = true


func _on_wind_changed(direction: Vector3, strength: float) -> void:
	for material in _materials:
		material.set_shader_parameter(&"hold_strength", clampf(strength / maxf(data.full_strength, 0.01), 0.0, 2.0))
		if strength > 0.0:
			material.set_shader_parameter(&"hold_direction", _model.global_basis.inverse() * direction)


func _apply_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shader_material := ShaderMaterial.new()
		shader_material.shader = FOLIAGE_SHADER
		shader_material.set_shader_parameter(&"tint", tint)
		shader_material.set_shader_parameter(&"recovery_seconds", data.recovery_seconds)
		shader_material.set_shader_parameter(&"bend_amount", data.bend_amount)
		shader_material.set_shader_parameter(&"flutter_speed", data.flutter_speed)
		shader_material.set_shader_parameter(&"flutter_factor", flutter_factor)
		var bounds: AABB = mesh_instance.get_aabb()
		shader_material.set_shader_parameter(&"anchor_height", bounds.position.y)
		shader_material.set_shader_parameter(&"foliage_height", maxf(bounds.size.y, 0.01))
		mesh_instance.material_override = shader_material
		_materials.append(shader_material)
	for child in node.get_children():
		_apply_materials(child)


func _setup_particles() -> void:
	_particles = CPUParticles3D.new()
	_particles.name = "LoosePieces"
	_particles.amount = maxi(data.loose_particle_count, 1)
	_particles.lifetime = particle_lifetime
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.emitting = false
	_particles.initial_velocity_min = 2.0
	_particles.initial_velocity_max = 4.0
	_particles.spread = 35.0
	_particles.gravity = Vector3(0.0, -5.0, 0.0)
	var piece: PrimitiveMesh = _make_piece_mesh()
	var piece_material := StandardMaterial3D.new()
	piece_material.albedo_color = particle_color
	piece_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	piece.material = piece_material
	_particles.mesh = piece
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)


func _make_piece_mesh() -> PrimitiveMesh:
	var leaf := SphereMesh.new()
	leaf.radius = 0.045
	leaf.height = 0.08
	return leaf
