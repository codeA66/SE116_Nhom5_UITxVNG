class_name SabretoothFireVfx
extends Node3D
## Các mesh và vết cháy giữ sẵn; chỉ dò tường khi beam đang hoạt động.

const FIRE := preload("res://entities/bosses/fire/sabretooth/combat/phase_two/sabretooth_fire.gdshader")
const FIRE_RING := preload("res://entities/bosses/fire/sabretooth/combat/phase_two/sabretooth_fire_ring.gdshader")
const SCORCH := preload("res://assets/vfx/fire/fire_arrow/impact/fire_arrow_scorch.gdshader")
const SCORCH_COUNT := 16
const TAIL_RELEASE_TIME := 0.40

var _actor: FireSabretooth
var _ball: MeshInstance3D
var _beam: MeshInstance3D
var _warning: MeshInstance3D
var _burst: MeshInstance3D
var _flame_crown: MeshInstance3D
var _shockwave: MeshInstance3D
var _afterwave: MeshInstance3D
var _tail_root: Node3D
var _tail_skeleton: Skeleton3D
var _tail_bone: int
var _tail_growth: float = 0.0
var _tail_fold: float = 0.0
var _tail_release: bool = false
var _tails: Array[MeshInstance3D] = []
var _marks: Array[MeshInstance3D] = []
var _mark_ages := PackedFloat32Array()
var _mark_cursor: int = 0
var _last_mark := Vector3.INF
var _sparks: CPUParticles3D
var _vanish: CPUParticles3D
var _burst_ribbons: CPUParticles3D
var _impact: CPUParticles3D
var _ray := PhysicsRayQueryParameters3D.new()
var _query := PhysicsShapeQueryParameters3D.new()
var _cylinder := CylinderShape3D.new()
var _beam_from: Vector3
var _beam_to: Vector3
var _tick_left: float = 0.0
var _burst_left: float = 0.0
var _scorch_life: float = 6.0


func _ready() -> void:
	_actor = get_parent() as FireSabretooth
	var sphere := SphereMesh.new()
	sphere.radial_segments = 20
	sphere.rings = 8
	sphere.radius = 1.0
	sphere.height = 2.0
	_ball = _mesh(sphere, 0)
	_burst = _mesh(sphere, 3)
	_flame_crown = _mesh(sphere, 5)
	var cylinder := CylinderMesh.new()
	cylinder.height = 1.0
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.radial_segments = 24
	cylinder.rings = 16
	_beam = _mesh(cylinder, 1)
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	_warning = _ring(false)
	_shockwave = _ring(true)
	_afterwave = _ring(true)
	var visual := _actor.get_node("Model/Visual") as Node3D
	_tail_skeleton = visual.find_child("Skeleton3D", true, false) as Skeleton3D
	_tail_bone = _tail_skeleton.find_bone(&"Sabrecat_Tail0_Tal0_")
	_tail_root = Node3D.new()
	_tail_root.name = "FlameTails"
	visual.add_child(_tail_root)
	var tail_mesh := _tail_mesh()
	for slot: int in 3:
		var tail := _mesh(tail_mesh, 2, _tail_root)
		(tail.material_override as ShaderMaterial).set_shader_parameter(&"tail_slot", float(slot - 1))
		_tails.append(tail)
	for index: int in SCORCH_COUNT:
		var mark := _mesh(plane, 0)
		mark.top_level = true
		var material := ShaderMaterial.new()
		material.shader = SCORCH
		material.set_shader_parameter(&"floor_y", 0.0)
		material.set_shader_parameter(&"size", 3.2)
		material.set_shader_parameter(&"glow_time", 0.8)
		mark.material_override = material
		_marks.append(mark)
		_mark_ages.append(-1.0)
	_sparks = _particles(84, true)
	_vanish = _ribbons(40)
	_vanish.explosiveness = 0.58
	_vanish.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_vanish.emission_box_extents = Vector3(0.72, 0.62, 1.9)
	_vanish.initial_velocity_min = 1.8
	_vanish.initial_velocity_max = 5.0
	_burst_ribbons = _ribbons(28)
	_burst_ribbons.spread = 75.0
	_impact = _particles(22, false)
	_ray.collision_mask = 1
	_ray.hit_from_inside = true
	_ray.exclude = [_actor.get_rid()]
	_query.shape = _cylinder
	_query.collision_mask = 2
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	var busy := _impact.emitting or _sparks.emitting or _vanish.emitting or _burst_ribbons.emitting or _tail_growth > 0.0
	if _tail_growth > 0.0:
		_update_tail_anchor()
		if _tail_release:
			_set_tail_fold(move_toward(_tail_fold, 0.0, delta / TAIL_RELEASE_TIME))
			_tail_release = _tail_fold > 0.0
	for index: int in _marks.size():
		if _mark_ages[index] < 0.0:
			continue
		busy = true
		_mark_ages[index] += delta
		(_marks[index].material_override as ShaderMaterial).set_shader_parameter(&"age", _mark_ages[index])
		if _mark_ages[index] >= _scorch_life:
			_mark_ages[index] = -1.0
			_marks[index].hide()
	if _burst_left > 0.0:
		busy = true
		_burst_left = maxf(0.0, _burst_left - delta)
		_update_burst(1.0 - _burst_left / maxf(_actor.profile.finale_fade_time, 0.01))
	if not busy:
		set_physics_process(false)


func charge(orb_center: Vector3, progress: float) -> void:
	global_basis = _actor.model.global_basis.orthonormalized()
	_ball.global_position = orb_center
	_ball.scale = Vector3.ONE * maxf(0.02, _actor.profile.beam_ball_radius * progress)
	_ball.show()
	_tail_release = false
	_update_tail_aim(orb_center)
	_set_tail_fold(smoothstep(0.0, 0.7, progress))
	_scorch_life = _actor.profile.scorch_duration
	_tick_left = 0.0
	_last_mark = Vector3.INF


func beam(orb_center: Vector3, direction: Vector3, delta: float, jaw: Vector3) -> void:
	global_basis = _actor.model.global_basis.orthonormalized()
	_beam_from = orb_center
	_ray.from = Vector3(jaw.x, orb_center.y, jaw.z)
	_ray.to = orb_center + direction * _actor.profile.beam_range
	var contact := get_world_3d().direct_space_state.intersect_ray(_ray)
	_beam_to = contact.position if not contact.is_empty() else _ray.to
	var length := maxf(0.0, (_beam_to - orb_center).dot(direction))
	var facing := Basis.looking_at(direction, Vector3.UP, true)
	var beam_transform := Transform3D(facing * Basis(Vector3.RIGHT, PI * 0.5), (orb_center + _beam_to) * 0.5)
	_beam.global_transform = beam_transform
	_beam.scale = Vector3(_actor.profile.beam_radius, maxf(length, 0.01), _actor.profile.beam_radius)
	_beam.visible = length > 0.01
	_ball.global_position = orb_center
	_update_tail_aim(orb_center)
	_impact.emitting = not contact.is_empty()
	if not contact.is_empty():
		_impact.global_position = _beam_to
		if contact.normal.is_zero_approx():
			_impact.emitting = false
		elif _last_mark.distance_to(_beam_to) > 0.65:
			_scorch(_beam_to, contact.normal)
		else:
			_mark_ages[(_mark_cursor + SCORCH_COUNT - 1) % SCORCH_COUNT] = 0.0
	_tick_left = maxf(0.0, _tick_left - delta)
	if _tick_left <= 0.0 and length > 0.01:
		_tick_left = maxf(_actor.profile.beam_tick, 0.05)
		_cylinder.radius = _actor.profile.beam_radius
		_cylinder.height = length
		_query.transform = beam_transform
		for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(_query, 32):
			var hurtbox := result.collider as HurtboxComponent
			if hurtbox and _beam_reaches(hurtbox, orb_center.y):
				hurtbox.receive_hit(DamageInfo.new(_actor.profile.beam_damage, DamageInfo.Type.FIRE, Vector3.ZERO, _actor))
	set_physics_process(true)


func _beam_reaches(hurtbox: HurtboxComponent, height: float) -> bool:
	var previous_end := _ray.to
	_ray.to = Vector3(hurtbox.global_position.x, height, hurtbox.global_position.z)
	var clear := get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()
	_ray.to = previous_end
	return clear


func stop_beam() -> void:
	_ball.hide()
	_beam.hide()
	_impact.emitting = false
	_tail_release = _tail_fold > 0.0


func set_tail_growth(growth: float) -> void:
	_tail_growth = growth
	if growth <= 0.0:
		_set_tail_fold(0.0)
		_tail_release = false
	else:
		_update_tail_anchor()
		set_physics_process(true)
	for tail: MeshInstance3D in _tails:
		(tail.material_override as ShaderMaterial).set_shader_parameter(&"tail_growth", growth)
		tail.visible = growth > 0.0


func set_tail_dissolve(progress: float) -> void:
	for tail: MeshInstance3D in _tails:
		(tail.material_override as ShaderMaterial).set_shader_parameter(&"dissolve", progress)


func warn(at: Vector3, progress: float) -> void:
	_warning.global_position = at + Vector3.UP * 0.035
	_warning.global_basis = Basis.IDENTITY.scaled(Vector3.ONE * _actor.profile.finale_radius)
	(_warning.material_override as ShaderMaterial).set_shader_parameter(&"progress", progress)
	_warning.show()


func burst(at: Vector3) -> void:
	_warning.hide()
	_burst.global_position = at + Vector3.UP * 0.6
	_burst_left = maxf(0.01, _actor.profile.finale_fade_time)
	_flame_crown.global_position = at + Vector3.UP * 0.12
	_shockwave.global_position = at + Vector3.UP * 0.055
	_afterwave.global_position = at + Vector3.UP * 0.07
	_update_burst(0.0)
	var radius := _actor.profile.finale_radius
	_sparks.global_position = at + Vector3.UP * 1.25
	_sparks.emission_sphere_radius = radius * 0.14
	_sparks.initial_velocity_min = radius * 0.48
	_sparks.initial_velocity_max = radius * 0.90
	_sparks.restart()
	_burst_ribbons.global_position = at + Vector3.UP * 0.72
	_burst_ribbons.emission_sphere_radius = radius * 0.23
	_burst_ribbons.initial_velocity_min = radius * 0.60
	_burst_ribbons.initial_velocity_max = radius * 1.22
	_burst_ribbons.restart()
	set_physics_process(true)


func vanish(at: Vector3) -> void:
	warn(at, 0.0)
	_vanish.global_transform = Transform3D(_actor.model.global_basis.orthonormalized(), at + Vector3.UP * 1.12)
	_vanish.restart()
	set_physics_process(true)


func cancel() -> void:
	stop_beam()
	_warning.hide()
	_burst.hide()
	_flame_crown.hide()
	_shockwave.hide()
	_afterwave.hide()
	_burst_left = 0.0
	_sparks.emitting = false
	_vanish.emitting = false
	_burst_ribbons.emitting = false


func _update_burst(progress: float) -> void:
	var radius := _actor.profile.finale_radius
	var core := radius * lerpf(0.12, 0.55, smoothstep(0.0, 0.16, progress))
	_burst.scale = Vector3(core, core * 0.86, core)
	(_burst.material_override as ShaderMaterial).set_shader_parameter(&"progress", smoothstep(0.02, 0.34, progress))
	_burst.visible = progress < 0.34
	var crown := radius * lerpf(0.28, 0.95, smoothstep(0.0, 0.22, progress))
	_flame_crown.scale = Vector3(crown, crown * lerpf(0.22, 0.55, progress), crown)
	(_flame_crown.material_override as ShaderMaterial).set_shader_parameter(&"progress", progress)
	_flame_crown.visible = progress < 0.9
	_shockwave.scale = Vector3.ONE * radius * lerpf(0.28, 1.08, smoothstep(0.0, 0.18, progress))
	(_shockwave.material_override as ShaderMaterial).set_shader_parameter(&"progress", progress)
	_shockwave.visible = progress < 0.55
	var after := clampf((progress - 0.075) * 1.18, 0.0, 1.0)
	_afterwave.scale = Vector3.ONE * radius * lerpf(0.16, 0.83, smoothstep(0.0, 0.48, after))
	(_afterwave.material_override as ShaderMaterial).set_shader_parameter(&"progress", after)
	_afterwave.visible = progress > 0.075 and after < 0.55


func _update_tail_anchor() -> void:
	var bone := _tail_skeleton.get_bone_global_pose(_tail_bone)
	_tail_root.global_position = _tail_skeleton.to_global(bone.origin)


func _update_tail_aim(mouth: Vector3) -> void:
	_update_tail_anchor()
	for tail: MeshInstance3D in _tails:
		(tail.material_override as ShaderMaterial).set_shader_parameter(&"mouth_local", _tail_root.to_local(mouth))


func _set_tail_fold(fold: float) -> void:
	_tail_fold = fold
	for tail: MeshInstance3D in _tails:
		(tail.material_override as ShaderMaterial).set_shader_parameter(&"fold", fold)


func _scorch(at: Vector3, normal: Vector3) -> void:
	_last_mark = at
	var mark := _marks[_mark_cursor]
	var axis := Vector3.RIGHT if absf(normal.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK
	var right := axis.cross(normal).normalized()
	mark.global_transform = Transform3D(Basis(right, normal, right.cross(normal)), at + normal * 0.025)
	var material := mark.material_override as ShaderMaterial
	material.set_shader_parameter(&"scorch_time", _scorch_life)
	material.set_shader_parameter(&"age", 0.0)
	_mark_ages[_mark_cursor] = 0.0
	mark.show()
	_mark_cursor = (_mark_cursor + 1) % SCORCH_COUNT


func _mesh(geometry: Mesh, kind: int, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = geometry
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = FIRE
	material.set_shader_parameter(&"kind", kind)
	node.material_override = material
	(parent if parent else self).add_child(node)
	node.hide()
	node.extra_cull_margin = 6.0
	return node


func _ring(shockwave: bool) -> MeshInstance3D:
	var node := _mesh(_ring_mesh(not shockwave), 0)
	var material := ShaderMaterial.new()
	material.shader = FIRE_RING
	material.set_shader_parameter(&"shockwave", shockwave)
	node.material_override = material
	return node


func _ring_mesh(flames: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 64
	const QUAD := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
	for layer: int in (2 if flames else 1):
		for segment: int in SEGMENTS:
			for corner: Vector2 in QUAD:
				var along := (segment + corner.x) / SEGMENTS
				var angle := along * TAU
				var radius := lerpf(0.87, 1.13, corner.y) if layer == 0 else lerpf(0.985, 1.035, corner.y)
				var height := 0.0 if layer == 0 else corner.y * 0.112
				surface.set_uv(Vector2(along, corner.y))
				surface.set_uv2(Vector2(float(layer), 0.0))
				surface.add_vertex(Vector3(cos(angle) * radius, height, sin(angle) * radius))
	return surface.commit()


func _ribbons(count: int) -> CPUParticles3D:
	var node := _particles(count, true)
	var flame := CylinderMesh.new()
	flame.top_radius = 0.0
	flame.bottom_radius = 0.24
	flame.height = 3.1
	flame.radial_segments = 4
	flame.rings = 0
	flame.material = (node.mesh as SphereMesh).material
	node.mesh = flame
	node.lifetime = 0.96
	node.particle_flag_align_y = true
	node.direction = Vector3.UP
	node.spread = 45.0
	node.gravity = Vector3.UP * 2.4
	node.scale_amount_min = 0.21
	node.scale_amount_max = 0.55
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.54))
	taper.add_point(Vector2(0.16, 1.0))
	taper.add_point(Vector2(1.0, 0.0))
	node.scale_amount_curve = taper
	return node


func _particles(amount: int, burst_only: bool) -> CPUParticles3D:
	var node := CPUParticles3D.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.amount = amount
	node.one_shot = burst_only
	node.explosiveness = 1.0 if burst_only else 0.0
	node.lifetime = 1.4 if burst_only else 0.6
	node.local_coords = false
	node.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	node.emission_sphere_radius = 1.5 if burst_only else 0.2
	node.direction = Vector3.UP
	node.spread = 180.0 if burst_only else 45.0
	node.initial_velocity_min = 4.0 if burst_only else 0.8
	node.initial_velocity_max = 8.0 if burst_only else 2.4
	node.gravity = Vector3(0.0, 1.2, 0.0)
	node.scale_amount_min = 0.06
	node.scale_amount_max = 0.18
	var geometry := SphereMesh.new()
	geometry.radial_segments = 4
	geometry.rings = 2
	geometry.radius = 1.0
	geometry.height = 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color(1.0, 0.35, 0.04)
	geometry.material = material
	node.mesh = geometry
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1.0, 0.90, 0.45), Color(1.0, 0.25, 0.02), Color(0.18, 0.015, 0.004)])
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	node.color_ramp = gradient
	add_child(node)
	node.emitting = false
	return node


func _tail_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment: int in 24:
		for side: int in 8:
			for point: Vector2 in [Vector2(segment, side), Vector2(segment + 1, side), Vector2(segment + 1, side + 1), Vector2(segment, side), Vector2(segment + 1, side + 1), Vector2(segment, side + 1)]:
				surface.set_uv(Vector2(point.x / 24.0, point.y / 8.0))
				surface.set_normal(Vector3.UP)
				surface.add_vertex(Vector3(point.y * 0.01, point.x * 0.01, 0.0))
	return surface.commit()
