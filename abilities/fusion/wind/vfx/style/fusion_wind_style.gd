class_name FusionWindStyle
extends Resource
## Thông số hình ảnh riêng cho fusion, chạy trên Compatibility không cần bloom.

const WIND_SHADER: Shader = preload("res://abilities/fusion/wind/vfx/style/fusion_wind.gdshader")
static var _shader_variants: Dictionary[int, Shader] = {}

@export_group("Textures")
@export var streak_texture: Texture2D
@export var noise_texture: Texture2D
@export var wisp_texture: Texture2D
@export var streak_uv_y: Vector2 = Vector2(0.40, 0.61)
@export var wisp_uv_y: Vector2 = Vector2(0.36, 0.66)

@export_group("Color")
@export var core_color: Color = Color(0.96, 0.98, 0.93, 1.0)
@export var body_color: Color = Color(0.42, 0.60, 0.65, 1.0)
@export var edge_color: Color = Color(0.12, 0.22, 0.27, 1.0)
@export_range(0.0, 1.0) var opacity: float = 0.96
@export_range(0.0, 1.0) var emission: float = 0.08
@export_range(0.01, 0.3) var appear_time: float = 0.035
@export_range(0.0, 0.1) var rim_width: float = 0.035
@export_range(0.0, 1.0) var rim_opacity: float = 0.55

@export_group("Sword")
@export_range(8, 96) var segments: int = 48
@export_range(0.5, 3.0) var blade_thickness: float = 1.7
@export_range(0.0, 0.6) var blade_depth: float = 0.22
@export_range(-45.0, 45.0) var blade_roll_degrees: float = -12.0
@export_range(0.0, 0.5) var launch_overshoot: float = 0.18
@export_range(0.01, 0.2) var launch_settle_time: float = 0.07
@export_range(0.01, 0.15) var sweep_time: float = 0.045
@export_range(0.1, 2.0) var launch_flash_size: float = 0.90
@export var wake_length: float = 1.35
@export_range(0.0, 1.0) var wake_opacity: float = 0.42
@export_range(0, 96) var sword_particle_count: int = 28
@export_range(0.04, 0.4) var sword_particle_lifetime: float = 0.22
@export_range(0, 48) var launch_particle_count: int = 12

@export_group("Vortex")
@export_range(1, 12) var streak_count: int = 3
@export_range(0, 8) var wisp_count: int = 3
@export_range(0, 8) var sharp_count: int = 2
@export_range(0.1, 3.0) var inward_speed: float = 1.65
@export_range(0.1, 32.0) var spin_speed: float = 8.0
@export_range(0.1, 4.0) var arc_length: float = 2.5
@export_range(0.02, 2.0) var ribbon_width: float = 0.40
@export_range(0.0, 2.0) var body_width: float = 0.50
@export_range(0.0, 1.0) var body_opacity: float = 0.26
@export var ground_offset: float = 0.08
@export_range(0.0, 4.0) var lift: float = 1.15
@export_range(0.01, 0.45) var close_time: float = 0.22
@export_range(0, 96) var suction_particle_count: int = 32
@export_range(0.05, 0.4) var suction_particle_lifetime: float = 0.32
@export_range(0, 48) var impact_particle_count: int = 12
@export_range(0.02, 0.2) var flash_time: float = 0.085
@export_range(0.04, 0.3) var impact_pull_time: float = 0.15

@export_group("Particles")
@export var particle_size: Vector2 = Vector2(0.13, 0.70)
@export var particle_speed: Vector2 = Vector2(1.5, 3.5)
@export var particle_scale: Vector2 = Vector2(0.55, 1.25)
@export_range(0.0, 90.0) var particle_spread: float = 24.0
@export_range(0.0, 1.0) var particle_opacity: float = 0.8

@export_group("Flight")
@export var flight_head_size: Vector2 = Vector2(0.75, 1.35)
@export var flight_tail_size: Vector2 = Vector2(0.65, 2.6)
@export_range(0, 64) var flight_particle_count: int = 16
@export_range(0.02, 0.3) var flight_fade: float = 0.12
@export_range(0.0, 1.0) var glow_opacity: float = 0.30
@export_range(0.0, 0.3) var glow_expand: float = 0.08
@export_range(-90.0, 90.0) var swing_turn_degrees: float = 25.0

var _material_templates: Dictionary[int, ShaderMaterial] = {}
var _meshes: Dictionary[String, ArrayMesh] = {}
var _particle_mesh: QuadMesh
var _particle_curve: Curve
var _particle_gradient: Gradient
var _cache_signature: int = 0


func create_material(effect_mode: int = 0) -> ShaderMaterial:
	_check_configuration()
	if _material_templates.has(effect_mode):
		return _material_templates[effect_mode].duplicate(false) as ShaderMaterial
	var material := ShaderMaterial.new()
	# Mode cố định theo lớp hình: compiler loại nhánh không dùng, thay vì chạy shader đa năng.
	if not _shader_variants.has(effect_mode):
		var variant := Shader.new()
		variant.code = WIND_SHADER.code.replace("uniform int effect_mode = 0;", "const int effect_mode = %d;" % effect_mode)
		_shader_variants[effect_mode] = variant
	material.shader = _shader_variants[effect_mode]
	for property: StringName in [&"streak_texture", &"noise_texture", &"wisp_texture", &"streak_uv_y", &"wisp_uv_y", &"core_color", &"body_color", &"edge_color", &"opacity", &"appear_time", &"rim_width", &"rim_opacity", &"inward_speed", &"spin_speed", &"arc_length", &"ribbon_width", &"body_width", &"ground_offset", &"lift", &"close_time", &"flash_time"]:
		material.set_shader_parameter(property, get(property))
	material.set_shader_parameter(&"emission_strength", emission)
	material.set_shader_parameter(&"launch_overshoot", launch_overshoot)
	material.set_shader_parameter(&"launch_settle_time", launch_settle_time)
	material.set_shader_parameter(&"sweep_time", sweep_time)
	material.set_shader_parameter(&"swing_turn_degrees", swing_turn_degrees)
	material.set_shader_parameter(&"impact_pull_time", impact_pull_time)
	_material_templates[effect_mode] = material
	return material.duplicate(false) as ShaderMaterial


func cached_mesh(key: String, builder: Callable) -> ArrayMesh:
	_check_configuration()
	if not _meshes.has(key):
		_meshes[key] = builder.call() as ArrayMesh
	return _meshes[key]


## Ba kiểu buffer cần shader riêng trên Compatibility: mesh, instancing và hạt CPU.
## Trả node có hình/material thật, không chỉ preload shader (preload chưa làm GPU biên dịch).
func create_warmup_sources() -> Array[Node]:
	var sources: Array[Node] = []
	for mode: int in [0, 1, 7, 8, 9, 10, 11, 12, 13, 14]:
		var visual := MeshInstance3D.new()
		visual.mesh = QuadMesh.new()
		visual.material_override = create_material(mode)
		(visual.material_override as ShaderMaterial).set_shader_parameter(&"age", 0.08)
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sources.append(visual)
	for mode: int in [2, 3, 4]:
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_custom_data = true
		batch.mesh = QuadMesh.new()
		batch.instance_count = 1
		batch.set_instance_transform(0, Transform3D.IDENTITY)
		batch.set_instance_custom_data(0, Color(0.25, 0.3, 0.5, 1.0))
		batch.custom_aabb = AABB(-Vector3.ONE * 3.0, Vector3.ONE * 6.0)
		var visual := MultiMeshInstance3D.new()
		visual.multimesh = batch
		visual.material_override = create_material(mode)
		(visual.material_override as ShaderMaterial).set_shader_parameter(&"age", 0.08)
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sources.append(visual)
	var particles := CPUParticles3D.new()
	configure_particles(particles, 2, 0.2, false)
	particles.preprocess = 0.1
	particles.direction = Vector3.RIGHT
	sources.append(particles)
	return sources


## Hạt CPU có fade/scale theo tuổi; shader giữ chiều dài theo vận tốc.
func configure_particles(particles: CPUParticles3D, count: int, duration: float, burst: bool) -> void:
	_check_configuration()
	particles.emitting = false
	particles.amount = maxi(count, 1)
	particles.visible = count > 0
	particles.lifetime = maxf(duration, 0.01)
	particles.one_shot = burst
	particles.explosiveness = 1.0 if burst else 0.0
	particles.local_coords = false
	particles.gravity = Vector3.ZERO
	particles.direction = Vector3.BACK
	particles.spread = particle_spread
	particles.initial_velocity_min = particle_speed.x
	particles.initial_velocity_max = particle_speed.y
	particles.scale_amount_min = particle_scale.x
	particles.scale_amount_max = particle_scale.y
	particles.particle_flag_align_y = true
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.fixed_fps = 60
	particles.visibility_aabb = AABB(-Vector3.ONE * 20.0, Vector3.ONE * 40.0)
	if _particle_mesh == null:
		_particle_curve = Curve.new()
		_particle_curve.add_point(Vector2(0.0, 0.2))
		_particle_curve.add_point(Vector2(0.12, 1.0))
		_particle_curve.add_point(Vector2(0.55, 0.65))
		_particle_curve.add_point(Vector2(1.0, 0.0))
		_particle_gradient = Gradient.new()
		_particle_gradient.offsets = PackedFloat32Array([0.0, 0.08, 0.45, 1.0])
		_particle_gradient.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, particle_opacity), Color(0.8, 0.9, 0.95, particle_opacity * 0.65), Color(0.5, 0.7, 0.8, 0.0)])
		_particle_mesh = QuadMesh.new()
		_particle_mesh.size = particle_size
		_particle_mesh.material = create_material(5)
	particles.scale_amount_curve = _particle_curve
	particles.color_ramp = _particle_gradient
	particles.mesh = _particle_mesh


## Chỉ chạy khi tạo/tái dùng tài nguyên, không chạy trong _process.
## Đổi thông số ở Inspector không được giữ lại mesh/material từ cấu hình cũ.
func _check_configuration() -> void:
	var signature := hash([streak_texture, noise_texture, wisp_texture, streak_uv_y, wisp_uv_y, core_color, body_color, edge_color, opacity, emission, appear_time, rim_width, rim_opacity, blade_thickness, blade_depth, segments, wake_length, launch_overshoot, launch_settle_time, sweep_time, swing_turn_degrees, inward_speed, spin_speed, arc_length, ribbon_width, body_width, ground_offset, lift, close_time, flash_time, impact_pull_time, particle_size, particle_opacity])
	if signature == _cache_signature:
		return
	_cache_signature = signature
	_material_templates.clear()
	_meshes.clear()
	_particle_mesh = null
	_particle_curve = null
	_particle_gradient = null
