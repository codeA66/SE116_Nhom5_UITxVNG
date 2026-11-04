extends Node3D
var _age: float = 0.0
var _ring: MeshInstance3D
var _material: StandardMaterial3D
var _particles: CPUParticles3D
var _flash: MeshInstance3D
var _flash_material: StandardMaterial3D
var _smoke: CPUParticles3D
var _smoke_material: StandardMaterial3D
var _embers: CPUParticles3D
func _ready() -> void:
	top_level = true
	_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.9; torus.outer_radius = 1.0; torus.rings = 32; torus.ring_segments = 4
	_ring.mesh = torus
	_material = StandardMaterial3D.new(); _material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; _material.albedo_color = Color(1,0.75,0.02,1)
	_ring.material_override = _material; _ring.position.y = 0.08; add_child(_ring)
	_particles = CPUParticles3D.new(); _particles.amount = 36; _particles.one_shot = true; _particles.explosiveness = 1.0
	_particles.lifetime = 0.7; _particles.direction = Vector3.UP; _particles.spread = 85
	_particles.initial_velocity_min = 3; _particles.initial_velocity_max = 8; _particles.gravity = Vector3.DOWN*12
	_particles.scale_amount_min = 0.07; _particles.scale_amount_max = 0.17
	_particles.mesh = BananaGeometry.fruit()
	var chunks: StandardMaterial3D = StandardMaterial3D.new(); chunks.vertex_color_use_as_albedo = true; chunks.cull_mode = BaseMaterial3D.CULL_DISABLED
	_particles.material_override = chunks; _particles.emitting = false; add_child(_particles)
	_flash = MeshInstance3D.new(); var core: SphereMesh = SphereMesh.new(); core.radius = 0.5; core.height = 1; core.radial_segments = 12; core.rings = 6
	_flash.mesh = core; _flash.position.y = 0.2; _flash_material = _glow(Color(1,0.87,0.38)); _flash.material_override = _flash_material
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(_flash)
	_smoke = CPUParticles3D.new(); _smoke.name = "Smoke"; _smoke.amount = 16; _smoke.one_shot = true; _smoke.explosiveness = 1
	_smoke.lifetime = 1.25; _smoke.direction = Vector3.UP; _smoke.spread = 75; _smoke.gravity = Vector3.UP*0.16
	_smoke.initial_velocity_min = 0.22; _smoke.initial_velocity_max = 0.65
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; _smoke.emission_sphere_radius = 0.25
	_smoke.scale_amount_min = 0.18; _smoke.scale_amount_max = 0.36
	var cloud: SphereMesh = SphereMesh.new(); cloud.radius = 0.5; cloud.height = 1; cloud.radial_segments = 8; cloud.rings = 4; _smoke.mesh = cloud
	_smoke_material = _glow(Color(0.25,0.23,0.19,0.7)); _smoke.material_override = _smoke_material
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; _smoke.emitting = false; add_child(_smoke)
	_embers = CPUParticles3D.new(); _embers.name = "Embers"; _embers.amount = 24; _embers.one_shot = true; _embers.explosiveness = 1
	_embers.lifetime = 0.5; _embers.direction = Vector3.UP; _embers.spread = 100; _embers.gravity = Vector3.DOWN*1.5
	_embers.initial_velocity_min = 0.8; _embers.initial_velocity_max = 1.8; _embers.scale_amount_min = 0.012; _embers.scale_amount_max = 0.035
	_embers.mesh = core; _embers.material_override = _glow(Color(1,0.45,0.06)); _embers.emitting = false
	_embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(_embers)
	pool_released()
func play(at: Vector3, radius: float, red: bool = false) -> void:
	global_position = at; scale = Vector3.ONE*radius; _age = 0.0
	reset_physics_interpolation()
	_material.albedo_color = Color(1,0.25,0.025) if red else Color(1,0.75,0.02)
	_flash_material.albedo_color = Color(1,0.65,0.25) if red else Color(1,0.92,0.45)
	visible = true; set_process(true); _particles.restart(); _particles.emitting = true
	_smoke.restart(); _smoke.emitting = true; _embers.restart(); _embers.emitting = true
func _process(delta: float) -> void:
	_age += delta
	_ring.scale = Vector3.ONE * lerpf(0.1,1.0,minf(_age/0.45,1.0))
	_material.albedo_color.a = 1.0-minf(_age/0.65,1.0)
	_flash.scale = Vector3.ONE*lerpf(0.04,0.75,minf(_age/0.2,1))
	_flash_material.albedo_color.a = 1.0-minf(_age/0.24,1)
	_smoke_material.albedo_color.a = 0.65*(1.0-smoothstep(0.35,1.5,_age))
	_smoke.scale = Vector3.ONE*lerpf(0.5,1.35,minf(_age/0.9,1))
	if _age >= 1.6: (get_parent() as ObjectPool).release(self)
func pool_released() -> void:
	visible = false; set_process(false)
	if _particles: _particles.emitting = false
	if _smoke: _smoke.emitting = false
	if _embers: _embers.emitting = false
func _glow(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new(); material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
