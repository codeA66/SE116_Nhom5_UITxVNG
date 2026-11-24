class_name SabretoothFireVfx
extends Node3D
## Các mesh và vết cháy giữ sẵn; chỉ dò tường khi beam đang hoạt động.

const FIRE := preload("res://entities/bosses/fire/sabretooth/combat/phase_two/sabretooth_fire.gdshader")
const CHARGE_RAYS := preload("res://entities/bosses/fire/sabretooth/combat/phase_two/sabretooth_charge_rays.gdshader")
const BLITZ := preload("res://entities/bosses/fire/sabretooth/combat/phase_two/sabretooth_blitz.gdshader")
const FIRE_RING := preload("res://entities/bosses/fire/sabretooth/combat/phase_two/sabretooth_fire_ring.gdshader")
const SCORCH := preload("res://assets/vfx/fire/fire_arrow/impact/fire_arrow_scorch.gdshader")
const SCORCH_COUNT := 16
const BLITZ_TRAIL_COUNT := 6
const BLITZ_TRAIL_LIFE := 0.95
const TAIL_RELEASE_TIME := 0.40
const BARRIER_SEGMENTS := 24
const BARRIER_WALL_THICKNESS := 0.30

var _actor: FireSabretooth
var _ball: MeshInstance3D
var _charge_rays: MeshInstance3D
var _beam: MeshInstance3D
var _beam_head: MeshInstance3D
var _barrier_mesh: MeshInstance3D
var _barrier_body: StaticBody3D
var _barrier_shapes: Array[CollisionShape3D] = []
var _barrier_fading: bool = false
var _barrier_fade_left: float = 0.0
var _barrier_fade_total: float = 0.45
var _barrier_draw: float = 0.0
var _barrier_rise: float = 0.0
var _barrier_cached_radius: float = -1.0
var _barrier_cached_height: float = -1.0
var _barrier_collision_on: bool = false
var _barrier_projectile_blocking: bool = false
var _warning: MeshInstance3D
var _burst: MeshInstance3D
var _flame_crown: MeshInstance3D
var _shockwave: MeshInstance3D
var _afterwave: MeshInstance3D
var _void_seam: MeshInstance3D
var _blitz_tube: MeshInstance3D
var _blitz_trails: Array[MeshInstance3D] = []
var _blitz_trail_ages := PackedFloat32Array()
var _blitz_trail_cursor: int = 0
var _reform_ribbons: MeshInstance3D
var _reform_ripple: MeshInstance3D
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
var _beam_fire_age: float = 0.0
var _current_beam_length: float = 0.0
var _wall_beam_length: float = 0.0
var _tick_left: float = 0.0
var _burst_left: float = 0.0
var _scorch_life: float = 6.0


func _ready() -> void:
	_actor = get_parent() as FireSabretooth
	var sphere := SphereMesh.new()
	sphere.radial_segments = 28
	sphere.rings = 14
	sphere.radius = 1.0
	sphere.height = 2.0
	_ball = _mesh(sphere, 0)
	_charge_rays = _mesh(_charge_rays_mesh(), 0)
	var rays_mat := ShaderMaterial.new()
	rays_mat.shader = CHARGE_RAYS
	_charge_rays.material_override = rays_mat
	_burst = _mesh(sphere, 3)
	_flame_crown = _mesh(sphere, 5)
	var cylinder := CylinderMesh.new()
	cylinder.height = 1.0
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.radial_segments = 24
	cylinder.rings = 16
	_beam = _mesh(cylinder, 1)
	_beam_head = _mesh(sphere, 0)
	(_beam_head.material_override as ShaderMaterial).set_shader_parameter(&"strength", 1.35)
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	_barrier_mesh = _make_barrier_visual()
	_barrier_body = _make_barrier_collider()
	_warning = _ring(false)
	_shockwave = _ring(true)
	_afterwave = _ring(true)
	_void_seam = _blitz_mesh(plane, 0)
	var tube := CylinderMesh.new()
	tube.height = 1.0
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.radial_segments = 24
	tube.rings = 10
	tube.cap_top = false
	tube.cap_bottom = false
	_blitz_tube = _blitz_mesh(tube, 1)
	var trail_mesh := _blitz_trail_mesh()
	for _slot: int in BLITZ_TRAIL_COUNT:
		var trail := _blitz_mesh(trail_mesh, 2)
		_blitz_trails.append(trail)
		_blitz_trail_ages.append(-1.0)
	_reform_ribbons = _blitz_mesh(_reform_ribbons_mesh(), 3)
	_reform_ripple = _blitz_mesh(plane, 4)
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
	_ray.hit_from_inside = false
	_ray.exclude = [_actor.get_rid(), _barrier_body.get_rid()]
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
	for index: int in _blitz_trails.size():
		if _blitz_trail_ages[index] < 0.0:
			continue
		busy = true
		_blitz_trail_ages[index] += delta
		var p := clampf(_blitz_trail_ages[index] / BLITZ_TRAIL_LIFE, 0.0, 1.0)
		(_blitz_trails[index].material_override as ShaderMaterial).set_shader_parameter(&"progress", p)
		if _blitz_trail_ages[index] >= BLITZ_TRAIL_LIFE:
			_blitz_trail_ages[index] = -1.0
			_blitz_trails[index].hide()
	if _burst_left > 0.0:
		busy = true
		_burst_left = maxf(0.0, _burst_left - delta)
		_update_burst(1.0 - _burst_left / maxf(_actor.profile.finale_fade_time, 0.01))
	if _barrier_fading:
		busy = true
		_barrier_fade_left = maxf(0.0, _barrier_fade_left - delta)
		var f := clampf(_barrier_fade_left / maxf(_barrier_fade_total, 0.05), 0.0, 1.0)
		var bmat := _barrier_mesh.material_override as ShaderMaterial
		bmat.set_shader_parameter(&"barrier_fade", f)
		bmat.set_shader_parameter(&"wall_height_t", _barrier_rise * f)
		if f <= 0.0:
			_barrier_fading = false
			_barrier_mesh.hide()
	if not busy:
		set_physics_process(false)


func charge(orb_center: Vector3, progress: float) -> void:
	global_basis = _actor.model.global_basis.orthonormalized()
	_ball.global_position = orb_center
	_ball.scale = Vector3.ONE * maxf(0.02, _actor.profile.beam_ball_radius * progress)
	_ball.show()
	_charge_rays.global_position = orb_center
	_charge_rays.global_basis = Basis.IDENTITY
	var ray_mat := _charge_rays.material_override as ShaderMaterial
	ray_mat.set_shader_parameter(&"progress", progress)
	ray_mat.set_shader_parameter(&"strength", lerpf(0.45, 1.15, progress))
	_charge_rays.show()
	_tail_release = false
	_update_tail_aim(orb_center)
	_set_tail_fold(smoothstep(0.0, 0.7, progress))
	_scorch_life = _actor.profile.scorch_duration
	_beam_fire_age = 0.0
	_current_beam_length = 0.0
	_wall_beam_length = 0.0
	_beam_head.hide()
	_tick_left = 0.0
	_last_mark = Vector3.INF


func current_beam_length() -> float:
	return _current_beam_length


func wall_beam_length() -> float:
	return _wall_beam_length


func beam(orb_center: Vector3, direction: Vector3, delta: float, jaw: Vector3) -> void:
	global_basis = _actor.model.global_basis.orthonormalized()
	_charge_rays.hide()
	var first_shot := _beam_fire_age <= 0.0001
	_beam_fire_age += delta
	_beam_from = orb_center
	_ray.from = Vector3(jaw.x, orb_center.y, jaw.z)
	_ray.to = orb_center + direction * _actor.profile.beam_range
	var contact := get_world_3d().direct_space_state.intersect_ray(_ray)
	var wall_end: Vector3 = contact.position if not contact.is_empty() else _ray.to
	_wall_beam_length = maxf(0.0, (wall_end - orb_center).dot(direction))
	# Cho tia laser bắn vọt nhanh tới tường trong beam_travel_time (0.5s) thay vì hiện đầy tới tường ngay lập tức.
	var travel_dur := maxf(_actor.profile.beam_travel_time, 0.0)
	var raw_t := 1.0 if travel_dur <= 0.001 else clampf(_beam_fire_age / travel_dur, 0.0, 1.0)
	var travel_t := 1.0 - pow(1.0 - raw_t, 1.35)
	var length := _wall_beam_length * travel_t
	_current_beam_length = length
	var reached_wall := raw_t >= 0.999
	_beam_to = wall_end if reached_wall else (orb_center + direction * length)
	var facing := Basis.looking_at(direction, Vector3.UP, true)
	var beam_transform := Transform3D(facing * Basis(Vector3.RIGHT, PI * 0.5), (orb_center + _beam_to) * 0.5)
	var r := _actor.profile.beam_radius
	_beam.global_transform = beam_transform
	_beam.scale = Vector3(r, maxf(length, 0.01), r)
	_beam.visible = length > 0.01
	if first_shot:
		_beam.reset_physics_interpolation()
		_sparks.global_position = orb_center
		_sparks.emission_sphere_radius = r * 0.55
		_sparks.initial_velocity_min = 4.5
		_sparks.initial_velocity_max = 9.5
		_sparks.restart()
	_ball.global_position = orb_center
	_update_tail_aim(orb_center)
	var has_wall_contact := not contact.is_empty() and not (contact.normal as Vector3).is_zero_approx()
	var show_head := length > 0.05 and ((not reached_wall) or has_wall_contact)
	if show_head:
		var was_head := _beam_head.visible
		_beam_head.global_transform = Transform3D(facing, _beam_to)
		var head_len := minf(r * 2.35, maxf(length * 0.45, r * 0.95)) if not reached_wall else (r * 1.12)
		var head_w := (r * 1.32) if not reached_wall else (r * 1.12)
		_beam_head.scale = Vector3(head_w, head_w, head_len)
		_beam_head.show()
		if first_shot or not was_head:
			_beam_head.reset_physics_interpolation()
	else:
		_beam_head.hide()
	var was_impact := _impact.emitting
	var valid_contact := reached_wall and has_wall_contact and length > 0.2
	_impact.emitting = valid_contact
	if valid_contact:
		_impact.global_position = _beam_to
		if not was_impact:
			_impact.reset_physics_interpolation()
		if _last_mark.distance_to(_beam_to) > 0.65:
			_scorch(_beam_to, contact.normal)
		else:
			_mark_ages[(_mark_cursor + SCORCH_COUNT - 1) % SCORCH_COUNT] = 0.0
	_tick_left = maxf(0.0, _tick_left - delta)
	if _tick_left <= 0.0 and length > 0.01:
		_cylinder.radius = r
		_cylinder.height = length
		_query.transform = beam_transform
		var dealt := false
		for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(_query, 32):
			var hurtbox := result.collider as HurtboxComponent
			if hurtbox and _beam_reaches(hurtbox, orb_center.y):
				if hurtbox.receive_hit(DamageInfo.new(_actor.profile.beam_damage, DamageInfo.Type.FIRE, Vector3.ZERO, _actor)):
					dealt = true
		if dealt:
			_tick_left = maxf(_actor.profile.beam_tick, 0.05)
	set_physics_process(true)


func _beam_reaches(hurtbox: HurtboxComponent, height: float) -> bool:
	var previous_end := _ray.to
	_ray.to = Vector3(hurtbox.global_position.x, height, hurtbox.global_position.z)
	var clear := get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()
	_ray.to = previous_end
	return clear


func update_beam_barrier(center: Vector3, elapsed: float, allow_player_exit: bool = false) -> void:
	# Dựng barrier lửa hình tròn từ từ quanh Hổ (vẽ nét vòng tròn 0 -> 360 độ rồi nâng thành lửa cao lên):
	# - Hitbox chặn player (layer 256) bật FULL ngay lập tức từ đầu (trừ khoảnh khắc ngắn đẩy player đang ở sẵn bên trong ra ngoài để không bị nhốt).
	# - Khi hiệu ứng chưa dựng xong (_barrier_rise < 0.99): chỉ bật layer 256 nên cung tên & skill vẫn xuyên qua trúng Hổ.
	# - Khi hiệu ứng đã dựng xong (_barrier_rise >= 0.99): bật thêm layer 1 (world) để mọi đạn/skill (tên, kiếm gió, lốc xoáy...) đập trúng barrier sẽ despawn (vẫn nổ hiệu ứng tại mặt barrier), trong khi tia laser của Hổ đã exclude RID nên bắn xuyên ra bình thường!
	var config := _actor.profile
	var radius := maxf(config.beam_barrier_radius, 2.0)
	var wall_h := maxf(config.beam_barrier_height, 1.2)
	var draw_dur := maxf(config.beam_barrier_draw_time, 0.15)
	var rise_dur := maxf(config.beam_barrier_rise_time, 0.15)
	_sync_barrier_layout(radius, wall_h)
	_barrier_fading = false
	_barrier_draw = clampf(elapsed / draw_dur, 0.0, 1.0)
	var rise_start := draw_dur * 0.72
	_barrier_rise = smoothstep(0.0, 1.0, clampf((elapsed - rise_start) / rise_dur, 0.0, 1.0))
	var floor_pt := Vector3(center.x, center.y + 0.04, center.z)
	_barrier_mesh.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(radius, wall_h, radius)), floor_pt)
	var bmat := _barrier_mesh.material_override as ShaderMaterial
	bmat.set_shader_parameter(&"draw_progress", _barrier_draw)
	bmat.set_shader_parameter(&"wall_height_t", _barrier_rise)
	bmat.set_shader_parameter(&"barrier_fade", 1.0)
	_barrier_mesh.show()
	_barrier_body.global_position = Vector3(center.x, center.y, center.z)
	_barrier_projectile_blocking = _barrier_rise >= 0.99
	var desired_layer := (1 | 256) if _barrier_projectile_blocking else 256
	if _barrier_body.collision_layer != desired_layer:
		_barrier_body.collision_layer = desired_layer
	_set_barrier_collision(not allow_player_exit)


func stop_beam_barrier(immediate: bool = false) -> void:
	_barrier_projectile_blocking = false
	_barrier_body.collision_layer = 256
	_set_barrier_collision(false)
	if immediate or not _barrier_mesh.visible:
		_barrier_fading = false
		_barrier_fade_left = 0.0
		_barrier_draw = 0.0
		_barrier_rise = 0.0
		_barrier_mesh.hide()
		return
	_barrier_fading = true
	_barrier_fade_total = maxf(_actor.profile.beam_barrier_fade_time, 0.08)
	_barrier_fade_left = _barrier_fade_total
	set_physics_process(true)


func is_barrier_blocking() -> bool:
	return _barrier_collision_on


func is_barrier_projectile_blocking() -> bool:
	return _barrier_projectile_blocking


func barrier_center() -> Vector3:
	return _barrier_body.global_position


func barrier_rid() -> RID:
	return _barrier_body.get_rid()


func stop_beam() -> void:
	_ball.hide()
	_charge_rays.hide()
	_beam.hide()
	_beam_head.hide()
	_beam_fire_age = 0.0
	_current_beam_length = 0.0
	_wall_beam_length = 0.0
	_impact.emitting = false
	_tail_release = _tail_fold > 0.0
	stop_beam_barrier(false)


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


func set_tail_portal_clip(active: bool, origin: Vector3 = Vector3.ZERO, normal: Vector3 = Vector3.UP) -> void:
	for tail: MeshInstance3D in _tails:
		var mat := tail.material_override as ShaderMaterial
		mat.set_shader_parameter(&"portal_clip", active)
		mat.set_shader_parameter(&"portal_origin", origin)
		mat.set_shader_parameter(&"portal_normal", normal)


func show_void_seam(at: Vector3, facing: Vector3, progress: float) -> void:
	var dir := facing.slide(Vector3.UP)
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	else:
		dir = dir.normalized()
	_void_seam.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP, true), at + Vector3.UP * 0.035)
	var swell := lerpf(0.75, 1.35, sin(clampf(progress, 0.0, 1.0) * PI))
	_void_seam.scale = Vector3(1.85 * swell, 1.0, 2.85 * swell)
	(_void_seam.material_override as ShaderMaterial).set_shader_parameter(&"progress", clampf(progress, 0.0, 1.0))
	_void_seam.show()


func hide_void_seam() -> void:
	_void_seam.hide()


func show_blitz_lane(start: Vector3, end: Vector3, radius: float, progress: float) -> void:
	var span := end - start
	var length := maxf(span.length(), 0.2)
	var dir := span / length
	var facing := Basis.looking_at(dir, Vector3.UP, true)
	# Trục Y của CylinderMesh hướng theo dir (UV.y = 0 ở đầu vào start -> UV.y = 1 ở đầu ra end).
	var xform := Transform3D(facing * Basis(Vector3.RIGHT, -PI * 0.5), (start + end) * 0.5)
	_blitz_tube.global_transform = xform
	_blitz_tube.scale = Vector3(radius, length, radius)
	_blitz_tube.reset_physics_interpolation()
	(_blitz_tube.material_override as ShaderMaterial).set_shader_parameter(&"progress", clampf(progress, 0.0, 1.0))
	_blitz_tube.show()


func hide_blitz_lane() -> void:
	_blitz_tube.hide()


func spawn_blitz_trail(start: Vector3, end: Vector3, radius: float) -> void:
	var span := end - start
	var length := maxf(span.length(), 0.2)
	var dir := span / length
	var facing := Basis.looking_at(dir, Vector3.UP, true)
	var trail := _blitz_trails[_blitz_trail_cursor]
	trail.global_transform = Transform3D(facing, (start + end) * 0.5)
	trail.scale = Vector3(radius * 1.15, radius * 0.95, length)
	trail.reset_physics_interpolation()
	(trail.material_override as ShaderMaterial).set_shader_parameter(&"progress", 0.0)
	trail.show()
	_blitz_trail_ages[_blitz_trail_cursor] = 0.0
	_blitz_trail_cursor = (_blitz_trail_cursor + 1) % BLITZ_TRAIL_COUNT
	_sparks.global_position = (start + end) * 0.5
	_sparks.emission_sphere_radius = 1.1
	_sparks.initial_velocity_min = 3.2
	_sparks.initial_velocity_max = 6.8
	_sparks.restart()
	set_physics_process(true)


func update_reform(at: Vector3, progress: float) -> void:
	var p := clampf(progress, 0.0, 1.0)
	_reform_ribbons.global_transform = Transform3D(Basis.IDENTITY, at)
	(_reform_ribbons.material_override as ShaderMaterial).set_shader_parameter(&"progress", p)
	_reform_ribbons.visible = p < 0.98
	var ripple_t := clampf((p - 0.65) / 0.35, 0.0, 1.0)
	_reform_ripple.global_transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.04)
	_reform_ripple.scale = Vector3.ONE * lerpf(1.2, 3.6, ripple_t)
	(_reform_ripple.material_override as ShaderMaterial).set_shader_parameter(&"progress", ripple_t)
	_reform_ripple.visible = p >= 0.65


func hide_reform() -> void:
	_reform_ribbons.hide()
	_reform_ripple.hide()


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
	stop_beam_barrier(true)
	_warning.hide()
	_burst.hide()
	_flame_crown.hide()
	_shockwave.hide()
	_afterwave.hide()
	_void_seam.hide()
	_blitz_tube.hide()
	_reform_ribbons.hide()
	_reform_ripple.hide()
	for i: int in _blitz_trails.size():
		_blitz_trail_ages[i] = -1.0
		_blitz_trails[i].hide()
	_burst_left = 0.0
	_sparks.emitting = false
	_vanish.emitting = false
	_burst_ribbons.emitting = false


func _update_burst(progress: float) -> void:
	var radius := _actor.profile.finale_radius
	var core := radius * lerpf(0.14, 0.44, smoothstep(0.0, 0.18, progress))
	_burst.scale = Vector3(core, core * 0.88, core)
	(_burst.material_override as ShaderMaterial).set_shader_parameter(&"progress", smoothstep(0.02, 0.48, progress))
	_burst.visible = progress < 0.48
	var crown := radius * lerpf(0.34, 0.98, smoothstep(0.0, 0.24, progress))
	_flame_crown.scale = Vector3(crown, crown * lerpf(0.28, 0.58, progress), crown)
	(_flame_crown.material_override as ShaderMaterial).set_shader_parameter(&"progress", progress)
	_flame_crown.visible = progress < 0.92
	_shockwave.scale = Vector3.ONE * radius * lerpf(0.28, 1.12, smoothstep(0.0, 0.20, progress))
	(_shockwave.material_override as ShaderMaterial).set_shader_parameter(&"progress", progress)
	_shockwave.visible = progress < 0.62
	var after := clampf((progress - 0.065) * 1.18, 0.0, 1.0)
	_afterwave.scale = Vector3.ONE * radius * lerpf(0.16, 0.90, smoothstep(0.0, 0.48, after))
	(_afterwave.material_override as ShaderMaterial).set_shader_parameter(&"progress", after)
	_afterwave.visible = progress > 0.065 and after < 0.62


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
	var n := normal.normalized()
	var axis := Vector3.RIGHT if absf(n.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK
	var right := axis.cross(n).normalized()
	# Dịch lệch nhỏ theo chỉ số slot + reset nội suy vật lý để tránh vết cháy nháy/bay ngang khi tái dùng slot.
	var offset := 0.055 + float(_mark_cursor % 4) * 0.008
	mark.global_transform = Transform3D(Basis(right, n, right.cross(n)), at + n * offset)
	mark.reset_physics_interpolation()
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


func _make_barrier_visual() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _barrier_ring_mesh()
	node.top_level = true
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 12.0
	var material := ShaderMaterial.new()
	material.shader = FIRE_RING
	material.set_shader_parameter(&"barrier_mode", true)
	material.set_shader_parameter(&"draw_progress", 0.0)
	material.set_shader_parameter(&"wall_height_t", 0.0)
	material.set_shader_parameter(&"barrier_fade", 1.0)
	node.material_override = material
	add_child(node)
	node.hide()
	return node


func _make_barrier_collider() -> StaticBody3D:
	# Tường trụ tròn rỗng (24 đoạn hộp mỏng) đặt trên layer 9 (player_blocker = 256):
	# chặn tuyệt đối player đi bộ / dash, KHÔNG cản tia beam (mask = 1), KHÔNG đẩy và KHÔNG gây sát thương.
	var body := StaticBody3D.new()
	body.name = "BeamBarrierCollider"
	body.top_level = true
	body.collision_layer = 256
	body.collision_mask = 0
	for i: int in BARRIER_SEGMENTS:
		var seg := CollisionShape3D.new()
		seg.name = "Wall_%d" % i
		seg.shape = BoxShape3D.new()
		seg.disabled = true
		body.add_child(seg)
		_barrier_shapes.append(seg)
	add_child(body)
	return body


func _sync_barrier_layout(radius: float, wall_h: float) -> void:
	if is_equal_approx(_barrier_cached_radius, radius) and is_equal_approx(_barrier_cached_height, wall_h):
		return
	_barrier_cached_radius = radius
	_barrier_cached_height = wall_h
	var chord := 2.0 * radius * sin(PI / float(BARRIER_SEGMENTS)) + 0.14
	var box_h := maxf(wall_h, 3.2)
	for i: int in BARRIER_SEGMENTS:
		var ang := (float(i) + 0.5) / float(BARRIER_SEGMENTS) * TAU
		var seg := _barrier_shapes[i]
		(seg.shape as BoxShape3D).size = Vector3(chord, box_h, BARRIER_WALL_THICKNESS)
		var dir_out := Vector3(cos(ang), 0.0, sin(ang))
		var tangent := Vector3(sin(ang), 0.0, -cos(ang))
		seg.transform = Transform3D(Basis(tangent, Vector3.UP, dir_out), dir_out * radius + Vector3.UP * (box_h * 0.5))


func _set_barrier_collision(active: bool) -> void:
	if _barrier_collision_on == active:
		return
	_barrier_collision_on = active
	for seg: CollisionShape3D in _barrier_shapes:
		seg.set_deferred(&"disabled", not active)


func _barrier_ring_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 72
	const QUAD := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
	for layer: int in 2:
		for segment: int in SEGMENTS:
			for corner: Vector2 in QUAD:
				var along := (float(segment) + corner.x) / float(SEGMENTS)
				var angle := along * TAU
				var radius := lerpf(0.92, 1.08, corner.y) if layer == 0 else 1.0
				var height := 0.0 if layer == 0 else corner.y
				surface.set_uv(Vector2(along, corner.y))
				surface.set_uv2(Vector2(float(layer), 0.0))
				surface.add_vertex(Vector3(cos(angle) * radius, height, sin(angle) * radius))
	return surface.commit()


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


func _charge_rays_mesh() -> ArrayMesh:
	# 56 tia sáng mảnh phân bố đều theo cầu xung quanh quả cầu, hút hội tụ vào tâm qua vertex shader kind == 6.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2407
	const COUNT := 56
	const GOLDEN := 2.39996323
	for i: int in COUNT:
		var y := 1.0 - (float(i) + 0.5) / float(COUNT) * 2.0
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var theta := GOLDEN * float(i)
		var dir := Vector3(cos(theta) * r, y, sin(theta) * r).normalized()
		var seed_col := Color(rng.randf(), rng.randf(), rng.randf(), 1.0)
		var corners: Array[Vector2] = [
			Vector2(0.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0),
			Vector2(0.0, -1.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
		]
		for uv: Vector2 in corners:
			surface.set_color(seed_col)
			surface.set_normal(dir)
			surface.set_uv(uv)
			surface.add_vertex(Vector3.ZERO)
	return surface.commit()


func _blitz_mesh(geometry: Mesh, vfx_kind: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = geometry
	node.top_level = true
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = BLITZ
	material.set_shader_parameter(&"vfx_kind", vfx_kind)
	node.material_override = material
	add_child(node)
	node.hide()
	node.extra_cull_margin = 10.0
	return node


func _blitz_trail_mesh() -> ArrayMesh:
	# Hai mặt phẳng chéo dọc đường cào (1 mặt ngang + 1 mặt nghiêng) giúp 3 vệt móng cào & dải lửa đọc rõ ở cả camera chéo lẫn trên cao.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tilt: float in [0.0, 0.52]:
		var cs := cos(tilt)
		var sn := sin(tilt)
		var p0 := Vector3(-cs, -sn, -0.5)
		var p1 := Vector3(cs, sn, -0.5)
		var p2 := Vector3(cs, sn, 0.5)
		var p3 := Vector3(-cs, -sn, 0.5)
		surface.set_uv(Vector2(0.0, 0.0)); surface.add_vertex(p0)
		surface.set_uv(Vector2(0.0, 1.0)); surface.add_vertex(p1)
		surface.set_uv(Vector2(1.0, 1.0)); surface.add_vertex(p2)
		surface.set_uv(Vector2(0.0, 0.0)); surface.add_vertex(p0)
		surface.set_uv(Vector2(1.0, 1.0)); surface.add_vertex(p2)
		surface.set_uv(Vector2(1.0, 0.0)); surface.add_vertex(p3)
	surface.generate_normals()
	return surface.commit()


func _reform_ribbons_mesh() -> ArrayMesh:
	# 10 dải lửa cong xoáy 3D hội tụ vào lõi khi hổ tái hình thành (vertex shader vfx_kind == 3 tính tọa độ xoắn ốc).
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6401
	const RIBBONS := 10
	const SEGS := 14
	for r: int in RIBBONS:
		var seed_col := Color(float(r) / float(RIBBONS) + rng.randf_range(-0.04, 0.04), rng.randf(), rng.randf(), 1.0)
		for s: int in SEGS:
			var u0 := float(s) / float(SEGS)
			var u1 := float(s + 1) / float(SEGS)
			var quad: Array[Vector2] = [
				Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0),
				Vector2(u0, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0),
			]
			for uv: Vector2 in quad:
				surface.set_color(seed_col)
				surface.set_normal(Vector3.UP)
				surface.set_uv(uv)
				surface.add_vertex(Vector3.ZERO)
	return surface.commit()


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
