class_name WindVortexVfx
extends Node3D
## Phễu khí thấp có lớp sát sàn, thân mờ, nét sắc và hạt CPU hút vào tâm.

@export var style: FusionWindStyle
@export var flight_mode: bool = false

var _age: float = 0.0
var _stop_age: float = -1.0
var _close_duration: float = 0.0
var _materials: Array[ShaderMaterial] = []
var _radius: float = 1.0
var _projectile: Node3D
var _flight_end_age: float = -1.0

@onready var _streaks: MultiMeshInstance3D = $Streaks
@onready var _wisps: MultiMeshInstance3D = $Wisps
@onready var _sharp: MultiMeshInstance3D = $Sharp
@onready var _core: MeshInstance3D = $Core
@onready var _flash: MeshInstance3D = $Flash
@onready var _shock: MeshInstance3D = $Shock
@onready var _particles: CPUParticles3D = $SuctionParticles
@onready var _impact: CPUParticles3D = $ImpactParticles


func _ready() -> void:
	set_process(false)
	visible = false
	if style == null:
		push_error("WindVortexVfx thiếu FusionWindStyle")
		return
	if flight_mode:
		_prepare_flight()
		return
	var mesh := style.cached_mesh("strip|%d" % style.segments, _build_strip)
	_setup(_streaks, mesh, style.streak_count, 2, 0.50)
	_setup(_wisps, mesh, style.wisp_count, 3, style.body_opacity)
	_setup(_sharp, mesh, style.sharp_count, 4, 0.95)
	_setup_plane(_core, 8, Vector2.ONE, 0.42)
	_setup_plane(_flash, 7, Vector2.ONE, 1.0)
	_setup_plane(_shock, 14, Vector2.ONE, 0.9)
	style.configure_particles(_particles, style.suction_particle_count, style.suction_particle_lifetime, false)
	style.configure_particles(_impact, style.impact_particle_count, style.flash_time * 2.0, true)
	_impact.direction = Vector3.UP
	_impact.spread = 75.0
	_impact.initial_velocity_min = 1.0
	_impact.initial_velocity_max = 3.0


func start_flight(projectile: Node3D) -> void:
	_projectile = projectile
	_age = 0.0
	_flight_end_age = -1.0
	global_transform = projectile.global_transform
	projectile.tree_exiting.connect(_on_flight_ended, CONNECT_ONE_SHOT)
	# Đạn dùng pool không rời cây khi kết thúc, nên cần nghe cả tín hiệu thu hồi.
	if projectile is ArrowProjectile:
		(projectile as ArrowProjectile).finished.connect(_on_pooled_flight_ended, CONNECT_ONE_SHOT)
	visible = true
	_particles.emitting = style.flight_particle_count > 0
	set_process(true)


func prepare_shader_warmup() -> void:
	for material in _materials:
		material.set_shader_parameter(&"age", 0.04 if not flight_mode else 0.1)
		material.set_shader_parameter(&"radius", 2.5)
	# Giữ nguồn tắt; ShaderWarmup tạo bản sao phát hạt trước camera dưới màn đen.
	_particles.preprocess = minf(_particles.lifetime * 0.5, 0.05)
	_particles.emitting = false
	_impact.emitting = false


func _on_flight_ended() -> void:
	if _flight_end_age >= 0.0:
		return
	_flight_end_age = _age
	_projectile = null
	_particles.emitting = false


func _on_pooled_flight_ended(_arrow: ArrowProjectile) -> void:
	_on_flight_ended()


func _prepare_flight() -> void:
	_core.mesh = style.cached_mesh("flight_head|%s" % style.flight_head_size, _flight_quad.bind(style.flight_head_size))
	_core.material_override = style.create_material(11)
	_core.position.z = -0.35
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.mesh = style.cached_mesh("flight_tail|%s" % style.flight_tail_size, _flight_quad.bind(style.flight_tail_size))
	_flash.material_override = style.create_material(12)
	_flash.position.z = -style.flight_tail_size.y * 0.5
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo := MeshInstance3D.new()
	halo.mesh = _core.mesh
	halo.material_override = style.create_material(13)
	halo.position = _core.position - Vector3.UP * 0.02
	halo.scale = Vector3(1.25, 1.0, 1.25)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(halo.material_override as ShaderMaterial).render_priority = -1
	add_child(halo)
	_materials.assign([_core.material_override, _flash.material_override, halo.material_override])
	style.configure_particles(_particles, style.flight_particle_count, style.flight_fade, false)
	_particles.direction = Vector3.FORWARD
	_particles.spread = 12.0
	_particles.position.z = -0.5


func _flight_quad(size: Vector2) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var x := size.x * 0.5
	var z := size.y * 0.5
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-x, 0, z), Vector3(x, 0, z), Vector3(-x, 0, -z), Vector3(x, 0, -z)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func play(effect_radius: float) -> void:
	if _materials.is_empty():
		return
	_age = 0.0
	_stop_age = -1.0
	(_flash.material_override as ShaderMaterial).set_shader_parameter(&"flash_at", 0.0)
	_radius = maxf(effect_radius, 0.01)
	var extent := _radius + absf(style.body_width) + absf(style.lift) + absf(style.ground_offset)
	var bounds := AABB(-Vector3.ONE * extent, Vector3.ONE * extent * 2.0)
	for visual: MultiMeshInstance3D in [_streaks, _wisps, _sharp]:
		visual.multimesh.custom_aabb = bounds
	_particles.visibility_aabb = bounds.grow(_radius)
	for material in _materials:
		material.set_shader_parameter(&"radius", _radius)
		material.set_shader_parameter(&"lift", style.lift * clampf(_radius / 2.5, 0.1, 2.0))
		material.set_shader_parameter(&"age", 0.0)
		material.set_shader_parameter(&"stop_age", -1.0)
	_core.scale = Vector3.ONE * _radius * 0.60
	_flash.scale = Vector3.ONE * minf(_radius * 0.65, 1.2)
	_shock.scale = Vector3.ONE * _radius * 2.0
	_configure_suction()
	visible = true
	if style.suction_particle_count > 0:
		_particles.restart()
	_particles.emitting = style.suction_particle_count > 0
	if style.impact_particle_count > 0:
		_impact.restart()
		_impact.emitting = true
	set_process(true)


func stop(fade_budget: float) -> void:
	if _materials.is_empty():
		return
	_stop_age = _age
	_close_duration = maxf(minf(style.close_time, fade_budget), 0.001)
	(_flash.material_override as ShaderMaterial).set_shader_parameter(&"flash_at", _age + _close_duration * 0.8)
	_particles.emitting = false
	for material in _materials:
		material.set_shader_parameter(&"stop_age", _stop_age)
		material.set_shader_parameter(&"close_time", _close_duration)


func _process(delta: float) -> void:
	_age += delta
	if flight_mode:
		if is_instance_valid(_projectile):
			global_transform = _projectile.global_transform
		for material in _materials:
			material.set_shader_parameter(&"age", _age)
			if _flight_end_age >= 0.0:
				material.set_shader_parameter(&"dissolve", clampf((_age - _flight_end_age) / maxf(style.flight_fade, 0.001), 0.0, 1.0))
		if _flight_end_age >= 0.0 and _age - _flight_end_age >= style.flight_fade:
			queue_free()
		return
	for material in _materials:
		material.set_shader_parameter(&"age", _age)
	# Hạt còn sống tiếp tục vào tâm trong lúc các dải khí co lại.
	var particle_tail := _particles.lifetime if style.suction_particle_count > 0 else 0.0
	if _stop_age >= 0.0 and _age - _stop_age >= maxf(_close_duration, particle_tail):
		visible = false
		set_process(false)


func _configure_suction() -> void:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var count := maxi(style.suction_particle_count, 8)
	for i in count:
		var angle := float(i) / float(count) * TAU
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := Vector3(-sin(angle), 0.0, cos(angle))
		points.append(radial * _radius * (0.82 + 0.12 * sin(float(i) * 2.4)) + Vector3.UP * style.ground_offset)
		normals.append((-radial + tangent * 0.40 + Vector3.UP * 0.12).normalized())
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_DIRECTED_POINTS
	_particles.emission_points = points
	_particles.emission_normals = normals
	_particles.spread = 3.0
	# Hết tuổi trước khi vượt tâm: khoảng cách và vận tốc đều tỉ lệ theo bán kính.
	var speed := _radius * 0.65 / _particles.lifetime
	_particles.initial_velocity_min = speed * 0.95
	_particles.initial_velocity_max = speed
	var visual_scale := clampf(_radius / 2.5, 0.1, 2.0)
	_particles.scale_amount_min = style.particle_scale.x * visual_scale
	_particles.scale_amount_max = style.particle_scale.y * visual_scale
	_particles.radial_accel_min = -_radius * 2.0
	_particles.radial_accel_max = -_radius * 1.5


func _setup(visual: MultiMeshInstance3D, mesh: ArrayMesh, count: int, mode: int, alpha: float) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true
	batch.mesh = mesh
	batch.instance_count = maxi(count, 0)
	for i in batch.instance_count:
		var phase := float(i) / maxf(float(count), 1.0)
		batch.set_instance_transform(i, Transform3D.IDENTITY)
		batch.set_instance_custom_data(i, Color(phase, fmod(phase * 1.618 + float(mode) * 0.13, 1.0), fmod(float(i) * 0.618, 1.0), 1.0))
	visual.multimesh = batch
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := style.create_material(mode)
	material.set_shader_parameter(&"layer_opacity", alpha)
	visual.material_override = material
	_materials.append(material)


func _setup_plane(visual: MeshInstance3D, mode: int, size: Vector2, alpha: float) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	visual.mesh = plane
	visual.position.y = style.ground_offset + 0.02
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := style.create_material(mode)
	material.set_shader_parameter(&"layer_opacity", alpha)
	visual.material_override = material
	_materials.append(material)


func _build_strip() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var segments := maxi(style.segments, 2)
	for i in segments + 1:
		var u := float(i) / float(segments)
		vertices.append(Vector3(u, 0.0, -0.5))
		vertices.append(Vector3(u, 0.0, 0.5))
		uvs.append(Vector2(u, 0.0))
		uvs.append(Vector2(u, 1.0))
	for i in segments:
		var a := i * 2
		indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
