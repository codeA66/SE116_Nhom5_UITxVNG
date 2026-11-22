class_name SabretoothP2Combat
extends Node3D
## Quản lý projectile Blazing Fang Snap (đầu hổ răng kiếm lửa 3D truy đuổi 7s, đẩy được bằng gió E, đụng tường nổ để vệt cháy)
## và hệ thống 3 vết cào uốn cong ngang/dọc + nhánh nứt phụ + khói đá vỡ + khe nứt 30s phun trào mỗi 5s.
## Hoàn toàn dùng pool cố định (0 cấp phát trong vòng lặp nóng) & tự tắt _physics_process khi rảnh.

const SHADER := preload("res://entities/bosses/fire/sabretooth/combat/phase_two/sabretooth_p2_attacks.gdshader")
const FANG_WIND_SCRIPT := preload("res://entities/bosses/fire/sabretooth/combat/phase_two/sabretooth_fang_wind.gd")
const WORLD_MASK := 1 | 256
const FANG_SLOTS := 4
const STAIN_SLOTS := 6
const SWIPE_SLOTS := 6
const FISSURE_SLOTS := 12
const SWIPE_VFX_LIFE := 0.30
const DEBRIS_VFX_LIFE := 0.95
const ERUPT_DURATION := 0.72
const WIND_DRAG := 22.0

var _actor: FireSabretooth

var _fang_nodes: Array[MeshInstance3D] = []
var _fang_winds: Array[SabretoothFangWind] = []
var _fang_active: Array[bool] = []
var _fang_pos: PackedVector3Array = PackedVector3Array()
var _fang_dir: PackedVector3Array = PackedVector3Array()
var _fang_wind_vel: PackedVector3Array = PackedVector3Array()
var _fang_ages: PackedFloat32Array = PackedFloat32Array()
var _fang_targets: Array[Node3D] = []

var _stain_nodes: Array[MeshInstance3D] = []
var _stain_ages: PackedFloat32Array = PackedFloat32Array()
var _stain_cursor: int = 0

var _warn_node: MeshInstance3D
var _warn_mat: ShaderMaterial

var _swipe_nodes: Array[MeshInstance3D] = []
var _debris_nodes: Array[MeshInstance3D] = []
var _swipe_ages: PackedFloat32Array = PackedFloat32Array()
var _debris_ages: PackedFloat32Array = PackedFloat32Array()
var _swipe_cursor: int = 0

var _fissure_nodes: Array[MeshInstance3D] = []
var _erupt_nodes: Array[MeshInstance3D] = []
var _fissure_ages: PackedFloat32Array = PackedFloat32Array()
var _fissure_cycles: PackedFloat32Array = PackedFloat32Array()
var _fissure_centers: PackedVector3Array = PackedVector3Array()
var _fissure_dirs: PackedVector3Array = PackedVector3Array()
var _fissure_sizes: PackedVector2Array = PackedVector2Array()
var _fissure_erupt_hits: Array[Dictionary] = []
var _fissure_cursor: int = 0

var _ray := PhysicsRayQueryParameters3D.new()
var _query := PhysicsShapeQueryParameters3D.new()
var _box := BoxShape3D.new()

static var _plane_mesh: PlaneMesh
static var _quad_mesh: QuadMesh
static var _fang_mesh: ArrayMesh
static var _fang_trail_mesh: ArrayMesh
static var _fang_core_mat: ShaderMaterial
static var _fang_outline_mat: ShaderMaterial
static var _fang_trail_mat: ShaderMaterial
static var _curtain_mesh: ArrayMesh
static var _debris_mesh: ArrayMesh


func _ready() -> void:
	top_level = true
	_actor = get_parent() as FireSabretooth
	_ensure_shared_meshes()

	for i: int in FANG_SLOTS:
		var fnode := MeshInstance3D.new()
		fnode.mesh = _fang_mesh
		fnode.top_level = true
		fnode.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fnode.extra_cull_margin = 16.0
		fnode.set_surface_override_material(0, _fang_core_mat)
		fnode.set_surface_override_material(1, _fang_outline_mat)
		var ftrail := MeshInstance3D.new()
		ftrail.name = "FangTrail"
		ftrail.mesh = _fang_trail_mesh
		ftrail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ftrail.extra_cull_margin = 16.0
		ftrail.material_override = _fang_trail_mat
		fnode.add_child(ftrail)
		add_child(fnode)
		fnode.hide()
		var fwind := SabretoothFangWind.new()
		fwind.name = "FangWind_%d" % i
		fwind.collision_layer = 128
		fwind.collision_mask = 0
		fwind.monitoring = false
		fwind.monitorable = false
		fwind.enabled = false
		fwind.combat = self
		fwind.slot_index = i
		var fshape := CollisionShape3D.new()
		var fsphere := SphereShape3D.new()
		fsphere.radius = 1.25
		fshape.shape = fsphere
		fwind.add_child(fshape)
		fnode.add_child(fwind)
		fwind.owner = _actor
		_fang_nodes.append(fnode)
		_fang_winds.append(fwind)
		_fang_active.append(false)
		_fang_pos.append(Vector3.ZERO)
		_fang_dir.append(Vector3.FORWARD)
		_fang_wind_vel.append(Vector3.ZERO)
		_fang_ages.append(0.0)
		_fang_targets.append(null)

	for _i: int in STAIN_SLOTS:
		_stain_nodes.append(_make_mesh(_quad_mesh, 1))
		_stain_ages.append(-1.0)

	_warn_node = _make_mesh(_plane_mesh, 2)
	_warn_mat = _warn_node.material_override as ShaderMaterial

	for _i: int in SWIPE_SLOTS:
		var sw := _make_mesh(_plane_mesh, 3)
		(sw.material_override as ShaderMaterial).render_priority = 2
		_swipe_nodes.append(sw)
		var db := _make_mesh(_debris_mesh, 6)
		(db.material_override as ShaderMaterial).render_priority = 3
		_debris_nodes.append(db)
		_swipe_ages.append(-1.0)
		_debris_ages.append(-1.0)

	for _i: int in FISSURE_SLOTS:
		var fis := _make_mesh(_plane_mesh, 4)
		(fis.material_override as ShaderMaterial).render_priority = -1
		_fissure_nodes.append(fis)
		var er := _make_mesh(_curtain_mesh, 5)
		(er.material_override as ShaderMaterial).render_priority = 2
		_erupt_nodes.append(er)
		_fissure_ages.append(-1.0)
		_fissure_cycles.append(0.0)
		_fissure_centers.append(Vector3.ZERO)
		_fissure_dirs.append(Vector3.RIGHT)
		_fissure_sizes.append(Vector2.ONE)
		_fissure_erupt_hits.append({})

	_ray.collision_mask = WORLD_MASK
	_ray.hit_from_inside = false
	_ray.exclude = [_actor.get_rid()]
	_query.shape = _box
	_query.collision_mask = 2
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	set_physics_process(false)


func launch_fang_snap(origin: Vector3, direction: Vector3, homing_target: Node3D = null) -> void:
	var dir := direction.slide(Vector3.UP)
	if dir.length_squared() < 0.001:
		dir = _actor.get_facing_direction().slide(Vector3.UP)
	dir = dir.normalized()
	var slot := -1
	for i: int in FANG_SLOTS:
		if not _fang_active[i]:
			slot = i
			break
	if slot < 0:
		slot = 0
	_fang_active[slot] = true
	_fang_pos[slot] = origin
	_fang_dir[slot] = dir
	_fang_wind_vel[slot] = Vector3.ZERO
	_fang_ages[slot] = 0.0
	_fang_targets[slot] = homing_target if homing_target else _actor.target

	var sc := maxf(_actor.profile.fang_snap_scale, 0.85)
	var node := _fang_nodes[slot]
	node.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP, true), origin)
	node.scale = Vector3.ONE * sc
	node.show()
	node.reset_physics_interpolation()

	var fwind := _fang_winds[slot]
	fwind.enabled = true
	fwind.set_deferred(&"monitorable", true)

	CombatFx.spawn_hit(origin, dir, Color("#ff6a18"), 0.95)
	set_physics_process(true)


func apply_fang_wind(slot: int, impulse: Vector3) -> void:
	if slot < 0 or slot >= FANG_SLOTS or not _fang_active[slot]:
		return
	var push_dir := impulse.slide(Vector3.UP)
	if push_dir.length_squared() < 0.001:
		push_dir = -_fang_dir[slot]
	else:
		push_dir = push_dir.normalized()
	var push_mag := maxf(impulse.length() * 1.35, _actor.profile.fang_snap_wind_push)
	_fang_wind_vel[slot] = push_dir * push_mag
	CombatFx.spawn_hit(_fang_pos[slot], push_dir, Color("#9eeeff"), 0.85)


func show_claw_warning(center: Vector3, swipe_dir: Vector3, length: float, width: float, progress: float) -> void:
	var claw_basis := _claw_basis(swipe_dir)
	var floor_pt := floor_at(center)
	_warn_node.global_transform = Transform3D(claw_basis, floor_pt + Vector3.UP * 0.045)
	_warn_node.scale = Vector3(length * 0.5, 1.0, width * 0.5)
	_warn_mat.set_shader_parameter(&"progress", clampf(progress, 0.0, 1.0))
	_warn_node.show()


func hide_claw_warning() -> void:
	_warn_node.hide()


func trigger_claw_swipe(center: Vector3, swipe_dir: Vector3, length: float, width: float) -> void:
	hide_claw_warning()
	var claw_basis := _claw_basis(swipe_dir)
	var floor_pt := floor_at(center)

	_damage_box(floor_pt + Vector3.UP * 0.9, claw_basis, Vector3(length, 1.9, width * 0.95), _actor.profile.cross_claw_swipe_damage, swipe_dir, 2.2)

	var s_idx := _swipe_cursor
	_swipe_cursor = (_swipe_cursor + 1) % SWIPE_SLOTS
	var sw := _swipe_nodes[s_idx]
	sw.global_transform = Transform3D(claw_basis, floor_pt + Vector3.UP * 0.075)
	sw.scale = Vector3(length * 0.52, 1.0, width * 0.52)
	(sw.material_override as ShaderMaterial).set_shader_parameter(&"progress", 0.0)
	sw.show()
	sw.reset_physics_interpolation()
	_swipe_ages[s_idx] = 0.0

	var db := _debris_nodes[s_idx]
	db.global_transform = Transform3D(claw_basis, floor_pt + Vector3.UP * 0.06)
	db.scale = Vector3.ONE
	var db_mat := db.material_override as ShaderMaterial
	db_mat.set_shader_parameter(&"progress", 0.0)
	db_mat.set_shader_parameter(&"zone_half", Vector2(length * 0.5, width * 0.5))
	db.show()
	db.reset_physics_interpolation()
	_debris_ages[s_idx] = 0.0

	var f_idx := _fissure_cursor
	_fissure_cursor = (_fissure_cursor + 1) % FISSURE_SLOTS
	var fis := _fissure_nodes[f_idx]
	var y_lift := 0.032 + float(f_idx % 4) * 0.006
	fis.global_transform = Transform3D(claw_basis, floor_pt + Vector3.UP * y_lift)
	fis.scale = Vector3(length * 0.5, 1.0, width * 0.5)
	var fmat := fis.material_override as ShaderMaterial
	fmat.set_shader_parameter(&"charge", 0.0)
	fmat.set_shader_parameter(&"erupt", 0.0)
	fmat.set_shader_parameter(&"fade", 1.0)
	fis.show()
	fis.reset_physics_interpolation()

	var er := _erupt_nodes[f_idx]
	er.global_transform = Transform3D(claw_basis, floor_pt + Vector3.UP * 0.04)
	er.scale = Vector3(length * 0.5, 3.65, width * 0.5)
	er.hide()
	er.reset_physics_interpolation()

	_fissure_ages[f_idx] = 0.0
	_fissure_cycles[f_idx] = 0.0
	_fissure_centers[f_idx] = floor_pt
	_fissure_dirs[f_idx] = swipe_dir.slide(Vector3.UP).normalized()
	_fissure_sizes[f_idx] = Vector2(length, width)
	_fissure_erupt_hits[f_idx].clear()

	ScreenShake.add_trauma_at(0.46, floor_pt, length, length * 2.6)
	CombatFx.spawn_hit(floor_pt + Vector3.UP * 0.35, Vector3.UP, Color("#ff6216"), 1.05)
	set_physics_process(true)


func cancel() -> void:
	hide_claw_warning()
	for i: int in FANG_SLOTS:
		_deactivate_fang(i)
	for i: int in STAIN_SLOTS:
		_stain_ages[i] = -1.0
		_stain_nodes[i].hide()
	for i: int in SWIPE_SLOTS:
		_swipe_ages[i] = -1.0
		_debris_ages[i] = -1.0
		_swipe_nodes[i].hide()
		_debris_nodes[i].hide()
	for i: int in FISSURE_SLOTS:
		_fissure_ages[i] = -1.0
		_fissure_cycles[i] = 0.0
		_fissure_nodes[i].hide()
		_erupt_nodes[i].hide()
		_fissure_erupt_hits[i].clear()
	set_physics_process(false)


func active_fang_count() -> int:
	var n := 0
	for a: bool in _fang_active:
		if a:
			n += 1
	return n


func active_wall_stain_count() -> int:
	var n := 0
	for age: float in _stain_ages:
		if age >= 0.0:
			n += 1
	return n


func active_fissure_count() -> int:
	var n := 0
	for age: float in _fissure_ages:
		if age >= 0.0:
			n += 1
	return n


func floor_at(point: Vector3) -> Vector3:
	_ray.from = Vector3(point.x, _actor.global_position.y + 6.0, point.z)
	_ray.to = Vector3(point.x, _actor.global_position.y - 3.0, point.z)
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	if not hit.is_empty() and (hit.normal as Vector3).y > 0.55:
		return hit.position as Vector3
	return Vector3(point.x, _actor.global_position.y, point.z)


func _deactivate_fang(slot: int) -> void:
	_fang_active[slot] = false
	_fang_wind_vel[slot] = Vector3.ZERO
	_fang_targets[slot] = null
	_fang_nodes[slot].hide()
	var fwind := _fang_winds[slot]
	fwind.enabled = false
	fwind.set_deferred(&"monitorable", false)


func _physics_process(delta: float) -> void:
	var busy := false
	busy = _step_fangs(delta) or busy
	busy = _step_stains(delta) or busy
	busy = _step_swipes(delta) or busy
	busy = _step_fissures(delta) or busy
	if not busy:
		set_physics_process(false)


func _step_fangs(delta: float) -> bool:
	var any := false
	var config := _actor.profile
	var chase_speed := maxf(config.fang_snap_speed, 1.5)
	var life_max := maxf(config.fang_snap_homing_duration, 0.5)
	var turn_rate := maxf(config.fang_snap_turn_rate, 0.5)
	var sc := maxf(config.fang_snap_scale, 0.85)

	for i: int in FANG_SLOTS:
		if not _fang_active[i]:
			continue
		any = true
		_fang_ages[i] += delta
		if _fang_ages[i] >= life_max:
			CombatFx.spawn_hit(_fang_pos[i], Vector3.UP, Color("#ff6e1a"), 0.85)
			_deactivate_fang(i)
			continue

		var cur := _fang_pos[i]
		var dir := _fang_dir[i]
		var wind := _fang_wind_vel[i]
		var tgt := _fang_targets[i]
		if not is_instance_valid(tgt):
			tgt = _actor.target
			_fang_targets[i] = tgt

		# Khi chưa bị luồng gió E lấn át, liên tục rẽ mượt truy đuổi vị trí player (có quán tính nên ngoặt gấp sát tường sẽ lao vào tường!).
		var wind_len := wind.length()
		if is_instance_valid(tgt) and wind_len < chase_speed * 0.85:
			var desired := (tgt.global_position - cur).slide(Vector3.UP)
			if desired.length_squared() > 0.04:
				desired = desired.normalized()
				var cur_ang := atan2(dir.x, dir.z)
				var des_ang := atan2(desired.x, desired.z)
				var new_ang := rotate_toward(cur_ang, des_ang, turn_rate * delta)
				dir = Vector3(sin(new_ang), 0.0, cos(new_ang)).normalized()
				_fang_dir[i] = dir

		var move_vel := dir * chase_speed + wind
		wind = wind.move_toward(Vector3.ZERO, WIND_DRAG * delta)
		_fang_wind_vel[i] = wind

		var step_vec := move_vel * delta
		var step_len := step_vec.length()
		var move_dir := (step_vec / step_len) if step_len > 0.0001 else dir
		var next := cur + step_vec

		# Kiểm tra va chạm tường (do quá trớn hoặc bị player thổi gió E đập vào tường) -> nổ & để lại vệt cháy tường rồi biến mất!
		_ray.from = cur
		_ray.to = next + move_dir * (0.65 * sc * 0.65)
		var wall := get_world_3d().direct_space_state.intersect_ray(_ray)
		if not wall.is_empty():
			var hit_pos: Vector3 = wall.position
			var wall_n := (wall.normal as Vector3).slide(Vector3.UP)
			if wall_n.length_squared() < 0.01:
				wall_n = -move_dir
			else:
				wall_n = wall_n.normalized()
			_spawn_wall_stain(hit_pos, wall_n)
			_deactivate_fang(i)
			continue

		# Kiểm tra va chạm với player -> gây sát thương, nổ lửa và biến mất ngay!
		var fang_basis := Basis.looking_at(dir, Vector3.UP, true)
		_box.size = Vector3(1.12 * sc, 1.35 * sc, maxf(1.25 * sc, step_len + 0.85))
		_query.transform = Transform3D(fang_basis, (cur + next) * 0.5)
		var hit_player := false
		for res: Dictionary in get_world_3d().direct_space_state.intersect_shape(_query, 8):
			var hurtbox := res.collider as HurtboxComponent
			if hurtbox == null:
				continue
			hurtbox.receive_hit(DamageInfo.new(config.fang_snap_damage, DamageInfo.Type.FIRE, move_dir * 2.6, _actor))
			CombatFx.spawn_hit(next, move_dir, Color("#ff6e1a"), 1.25)
			ScreenShake.add_trauma_at(0.36, next, 8.0, 20.0)
			hit_player = true
			break
		if hit_player:
			_deactivate_fang(i)
			continue

		_fang_pos[i] = next
		var bob := sin(_fang_ages[i] * 7.5) * 0.09
		var fade_val := 1.0 - smoothstep(life_max - 0.38, life_max, _fang_ages[i])
		var pop_in := smoothstep(0.0, 0.12, _fang_ages[i])
		var cur_sc := sc * (0.20 + 0.80 * pop_in) * (0.12 + 0.88 * fade_val)
		var node := _fang_nodes[i]
		node.global_transform = Transform3D(fang_basis, next + Vector3.UP * bob)
		node.scale = Vector3.ONE * cur_sc
	return any


func _spawn_wall_stain(hit_pos: Vector3, wall_normal: Vector3) -> void:
	var idx := _stain_cursor
	_stain_cursor = (_stain_cursor + 1) % STAIN_SLOTS
	var right := wall_normal.cross(Vector3.UP)
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var anchor := hit_pos + wall_normal * (0.14 + float(idx % 3) * 0.012)
	var node := _stain_nodes[idx]
	node.global_transform = Transform3D(Basis(right * 2.9, Vector3.UP * 2.9, wall_normal), anchor)
	var smat := node.material_override as ShaderMaterial
	smat.render_priority = 2
	smat.set_shader_parameter(&"progress", 0.0)
	node.show()
	node.reset_physics_interpolation()
	_stain_ages[idx] = 0.0
	CombatFx.spawn_hit(anchor, wall_normal, Color("#ff761a"), 1.35)
	ScreenShake.add_trauma_at(0.38, anchor, 9.0, 24.0)


func _step_stains(delta: float) -> bool:
	var any := false
	var life := maxf(_actor.profile.fang_snap_wall_stain_time, 0.5)
	for i: int in STAIN_SLOTS:
		if _stain_ages[i] < 0.0:
			continue
		any = true
		_stain_ages[i] += delta
		var p := clampf(_stain_ages[i] / life, 0.0, 1.0)
		(_stain_nodes[i].material_override as ShaderMaterial).set_shader_parameter(&"progress", p)
		if p >= 1.0:
			_stain_ages[i] = -1.0
			_stain_nodes[i].hide()
	return any


func _step_swipes(delta: float) -> bool:
	var any := false
	for i: int in SWIPE_SLOTS:
		if _swipe_ages[i] >= 0.0:
			any = true
			_swipe_ages[i] += delta
			var p := clampf(_swipe_ages[i] / SWIPE_VFX_LIFE, 0.0, 1.0)
			(_swipe_nodes[i].material_override as ShaderMaterial).set_shader_parameter(&"progress", p)
			if p >= 1.0:
				_swipe_ages[i] = -1.0
				_swipe_nodes[i].hide()
		if _debris_ages[i] >= 0.0:
			any = true
			_debris_ages[i] += delta
			var dp := clampf(_debris_ages[i] / DEBRIS_VFX_LIFE, 0.0, 1.0)
			(_debris_nodes[i].material_override as ShaderMaterial).set_shader_parameter(&"progress", dp)
			if dp >= 1.0:
				_debris_ages[i] = -1.0
				_debris_nodes[i].hide()
	return any


func _step_fissures(delta: float) -> bool:
	var any := false
	var config := _actor.profile
	var max_life := maxf(config.cross_claw_fissure_duration, 2.0)
	var interval := maxf(config.cross_claw_erupt_interval, 0.65)
	var erupt_dur := minf(ERUPT_DURATION, interval * 0.42)
	var charge_dur := maxf(interval - erupt_dur, 0.25)

	for i: int in FISSURE_SLOTS:
		if _fissure_ages[i] < 0.0:
			continue
		any = true
		_fissure_ages[i] += delta
		if _fissure_ages[i] >= max_life:
			_fissure_ages[i] = -1.0
			_fissure_nodes[i].hide()
			_erupt_nodes[i].hide()
			_fissure_erupt_hits[i].clear()
			continue

		var fade_val := 1.0 - smoothstep(max_life - 1.4, max_life, _fissure_ages[i])
		var prev_cycle := _fissure_cycles[i]
		_fissure_cycles[i] = fposmod(prev_cycle + delta, interval)
		if _fissure_cycles[i] < prev_cycle:
			_fissure_erupt_hits[i].clear()

		var cyc := _fissure_cycles[i]
		var fmat := _fissure_nodes[i].material_override as ShaderMaterial
		var er := _erupt_nodes[i]
		var emat := er.material_override as ShaderMaterial
		fmat.set_shader_parameter(&"fade", fade_val)

		if cyc < charge_dur:
			var ch_t := clampf(cyc / charge_dur, 0.0, 1.0)
			fmat.set_shader_parameter(&"charge", ch_t)
			fmat.set_shader_parameter(&"erupt", 0.0)
			er.hide()
		else:
			var er_t := clampf((cyc - charge_dur) / erupt_dur, 0.0, 1.0)
			fmat.set_shader_parameter(&"charge", 1.0)
			fmat.set_shader_parameter(&"erupt", 1.0 - er_t)
			emat.set_shader_parameter(&"erupt", er_t)
			emat.set_shader_parameter(&"fade", fade_val)
			er.show()
			if er_t <= 0.65:
				var claw_basis := _claw_basis(_fissure_dirs[i])
				var sz := _fissure_sizes[i]
				var half_w := sz.y * 0.5
				# Thu gọn hitbox phun trào thành 3 dải hẹp bám sát 3 khe lửa cong hiển thị (không đánh hụt ngoài lửa!).
				var lane_specs := [
					Vector3(0.14 * half_w, sz.x * 0.78, maxf(sz.y * 0.16, 0.42)),
					Vector3(0.62 * half_w, sz.x * 0.64, maxf(sz.y * 0.12, 0.34)),
					Vector3(-0.38 * half_w, sz.x * 0.64, maxf(sz.y * 0.12, 0.34)),
				]
				for lane: Vector3 in lane_specs:
					var lane_center := _fissure_centers[i] + claw_basis.z * lane.x + Vector3.UP * 0.92
					_damage_box_unique(
						lane_center,
						claw_basis,
						Vector3(lane.y, 1.85, lane.z),
						config.cross_claw_erupt_damage,
						Vector3.UP,
						1.4,
						_fissure_erupt_hits[i]
					)
	return any


func _damage_box(center: Vector3, box_basis: Basis, size: Vector3, damage: int, dir: Vector3, kb: float) -> void:
	var hit_ids: Dictionary[int, bool] = {}
	_damage_box_unique(center, box_basis, size, damage, dir, kb, hit_ids)


func _damage_box_unique(
	center: Vector3,
	box_basis: Basis,
	size: Vector3,
	damage: int,
	dir: Vector3,
	kb: float,
	hit_ids: Dictionary
) -> void:
	_box.size = size
	_query.transform = Transform3D(box_basis, center)
	for res: Dictionary in get_world_3d().direct_space_state.intersect_shape(_query, 10):
		var hurtbox := res.collider as HurtboxComponent
		if hurtbox == null or hit_ids.has(hurtbox.get_instance_id()):
			continue
		hit_ids[hurtbox.get_instance_id()] = true
		hurtbox.receive_hit(DamageInfo.new(damage, DamageInfo.Type.FIRE, dir.normalized() * kb, _actor))


func _claw_basis(swipe_dir: Vector3) -> Basis:
	var x_axis := swipe_dir.slide(Vector3.UP)
	if x_axis.length_squared() < 0.001:
		x_axis = Vector3.RIGHT
	else:
		x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(Vector3.UP).normalized()
	return Basis(x_axis, Vector3.UP, z_axis)


func _make_mesh(geometry: Mesh, kind_id: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = geometry
	node.top_level = true
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 16.0
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"kind", kind_id)
	node.material_override = mat
	add_child(node)
	node.hide()
	return node


static func _ensure_shared_meshes() -> void:
	if _plane_mesh != null:
		return
	_plane_mesh = PlaneMesh.new()
	_plane_mesh.size = Vector2(2.0, 2.0)
	_quad_mesh = QuadMesh.new()
	_quad_mesh.size = Vector2(2.0, 2.0)
	_build_fang_materials()
	_fang_mesh = _build_fang_jaw_mesh()
	_fang_trail_mesh = _build_fang_trail_mesh()
	_curtain_mesh = _build_erupt_curtain_mesh()
	_debris_mesh = _build_claw_debris_mesh()


static func _build_fang_materials() -> void:
	# Hàm trên & hàm dưới răng nanh lửa cách điệu (KHÔNG nguyên đầu hổ, KHÔNG thanh ống nối giả):
	# - Surface 0 (_fang_core_mat): từng chiếc răng hình thoi cong sắc bén phát quang cam-vàng rực rỡ, gốc thuôn mềm kiểu ngọn lửa.
	# - Surface 1 (_fang_outline_mat): viền đỏ thẫm siêu mảnh tách từng chiếc răng sắc gọn.
	# - Trail (_fang_trail_mat): quầng lửa hồng-cam mềm ôm gốc chân răng + dải lửa uốn lượn rực đỏ-cam-vàng & tàn lửa sắc nét phía sau!
	var core_sh := Shader.new()
	core_sh.code = """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, shadows_disabled;

varying vec2 v_uv;
varying vec4 v_col;
varying vec3 v_nrm;
varying vec3 v_pos;
varying float v_snap;

void vertex() {
	v_uv = UV;
	v_col = COLOR;
	vec3 pos = VERTEX;
	vec3 nrm = NORMAL;
	// Nhịp đớp hàm uy lực: há rộng khoe rõ 2 hàng nanh lửa -> ngoạm nhanh sát lại (không đâm chồng chéo nhau) rồi bật mở!
	float cycle = 0.5 + 0.5 * sin(TIME * 6.8);
	float snap = pow(cycle, 2.0);
	float jaw_sign = (COLOR.g > 0.5) ? 1.0 : -1.0;
	float ang = mix(-0.02, 0.16, snap) * jaw_sign;
	vec3 pivot = vec3(0.0, jaw_sign * 0.34, -0.45);
	vec3 rel = pos - pivot;
	float cs = cos(ang);
	float sn = sin(ang);
	vec3 rpos = vec3(rel.x, rel.y * cs - rel.z * sn, rel.y * sn + rel.z * cs) + pivot;
	vec3 rnrm = vec3(nrm.x, nrm.y * cs - nrm.z * sn, nrm.y * sn + nrm.z * cs);
	rpos.y += jaw_sign * mix(-0.03, 0.08, snap);
	VERTEX = rpos;
	NORMAL = rnrm;
	v_pos = rpos;
	v_nrm = rnrm;
	v_snap = snap;
}

void fragment() {
	vec3 n = normalize(v_nrm);
	vec3 v_dir = normalize((INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz - (MODEL_MATRIX * vec4(v_pos, 1.0)).xyz);
	vec3 w_nrm = normalize(mat3(MODEL_MATRIX) * n);
	float ndl = dot(n, normalize(vec3(0.22, 0.88, 0.42))) * 0.5 + 0.5;
	float fres = 1.0 - clamp(abs(dot(w_nrm, v_dir)), 0.0, 1.0);

	vec3 ember_root = vec3(0.84, 0.14, 0.02);
	vec3 fiery_orange = vec3(1.0, 0.42, 0.06);
	vec3 warm_peach = vec3(1.0, 0.72, 0.28);
	vec3 hot_gold = vec3(1.0, 0.90, 0.56);
	vec3 hot_tip = vec3(1.0, 0.97, 0.86);

	// Răng nanh hình giọt lửa/thoi sắc: gốc đỏ-cam cháy rực -> thân cam đào óng -> mũi vàng kem rực sáng!
	float t_tip = clamp(v_uv.y, 0.0, 1.0);
	float shimmer = 0.5 + 0.5 * sin(t_tip * 9.0 - TIME * 12.0 + v_col.b * 6.283);
	float facet = mix(0.86, 1.08, smoothstep(0.24, 0.78, ndl));
	vec3 col = mix(ember_root, fiery_orange, smoothstep(0.04, 0.34, t_tip));
	col = mix(col, warm_peach, smoothstep(0.28, 0.66, t_tip));
	col = mix(col, hot_gold, smoothstep(0.60, 0.90, t_tip));
	col = mix(col, hot_tip, smoothstep(0.82, 1.0, t_tip) * (0.68 + 0.32 * v_snap));
	col *= facet;
	col += vec3(0.35, 0.14, 0.02) * pow(fres, 1.8);
	float em = mix(0.45, 0.92, t_tip) + shimmer * 0.12 + (1.0 - v_snap) * 0.16;

	ALBEDO = col;
	EMISSION = col * em;
}
"""
	_fang_core_mat = ShaderMaterial.new()
	_fang_core_mat.shader = core_sh

	var out_sh := Shader.new()
	out_sh.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always, shadows_disabled;

void vertex() {
	vec3 pos = VERTEX;
	vec3 nrm = NORMAL;
	float cycle = 0.5 + 0.5 * sin(TIME * 6.8);
	float snap = pow(cycle, 2.0);
	float jaw_sign = (COLOR.g > 0.5) ? 1.0 : -1.0;
	float ang = mix(-0.02, 0.16, snap) * jaw_sign;
	vec3 pivot = vec3(0.0, jaw_sign * 0.34, -0.45);
	vec3 rel = pos - pivot;
	float cs = cos(ang);
	float sn = sin(ang);
	vec3 rpos = vec3(rel.x, rel.y * cs - rel.z * sn, rel.y * sn + rel.z * cs) + pivot;
	vec3 rnrm = vec3(nrm.x, nrm.y * cs - nrm.z * sn, nrm.y * sn + nrm.z * cs);
	rpos.y += jaw_sign * mix(-0.03, 0.08, snap);
	rpos += normalize(rnrm) * (0.013 * COLOR.a);
	VERTEX = rpos;
}

void fragment() {
	ALBEDO = vec3(0.42, 0.05, 0.015);
	EMISSION = vec3(0.24, 0.03, 0.008);
}
"""
	_fang_outline_mat = ShaderMaterial.new()
	_fang_outline_mat.shader = out_sh

	var trail_sh := Shader.new()
	trail_sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

varying vec2 v_uv;
varying vec4 v_col;

float h21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm2(vec2 p) {
	return 0.56 * vn(p) + 0.29 * vn(p * 2.2 + vec2(9.1, 5.7)) + 0.15 * vn(p * 4.5 - vec2(4.2, 13.8));
}

void vertex() {
	v_uv = UV;
	v_col = COLOR;
	vec3 pos = VERTEX;
	float along = clamp(UV.y, 0.0, 1.0);
	float sway = along * along;
	if (COLOR.r < 0.35) {
		// Dải lửa uốn sóng dữ dội phía sau hai cung hàm (cả biên dọc lẫn biên ngang đều uốn lượn mềm mại như ngọn lửa thật).
		float ph = COLOR.b * 6.283185;
		float wave_w = smoothstep(0.05, 0.95, along);
		pos.x += sin(TIME * 12.0 - along * 7.2 + ph + UV.x * 3.14) * 0.15 * sway;
		pos.y += (cos(TIME * 10.2 - along * 6.0 + ph) * 0.09 + sin(TIME * 13.5 - along * 9.5 + UV.x * 5.0) * 0.055) * wave_w;
	} else if (COLOR.r < 0.70) {
		// Quầng sương lửa mềm tỏa quanh gốc răng hàm trên / hàm dưới (đồng bộ nhịp đớp hàm!).
		float cycle = 0.5 + 0.5 * sin(TIME * 6.8);
		float snap = pow(cycle, 2.0);
		float jaw_sign = (COLOR.g > 0.5) ? 1.0 : -1.0;
		pos.y += jaw_sign * mix(-0.03, 0.08, snap);
	} else {
		// Tàn lửa kim cương nhỏ gọn lướt nhanh dọc theo vệt đuôi phía sau.
		float seed = COLOR.g;
		float t_sp = fract(TIME * mix(1.45, 2.45, seed) + COLOR.b);
		float z_off = mix(-0.08, -3.25, t_sp);
		float ang = seed * 6.283185 + t_sp * 4.8;
		float rad = mix(0.48, 0.08, t_sp) + sin(t_sp * 10.0 + seed * 5.0) * 0.07;
		float sc = sin(t_sp * 3.14159) * mix(0.50, 0.95, fract(seed * 7.1));
		pos = pos * sc + vec3(cos(ang) * rad, sin(ang) * rad * 0.72, z_off);
	}
	VERTEX = pos;
}

void fragment() {
	vec3 dark_crimson = vec3(0.58, 0.02, 0.008);
	vec3 crimson = vec3(0.92, 0.10, 0.015);
	vec3 fiery_orange = vec3(1.0, 0.34, 0.025);
	vec3 bright_gold = vec3(1.0, 0.76, 0.16);
	vec3 white_hot = vec3(1.0, 0.96, 0.78);
	float alpha;
	vec3 col;
	float em;

	if (v_col.r < 0.35) {
		// Dải lửa đỏ-cam rực rỡ uốn lưỡi lửa rõ nét (không nhạt xanh vàng trên nền trời!).
		float along = clamp(v_uv.y, 0.0, 1.0);
		float across = abs(v_uv.x * 2.0 - 1.0);
		float n1 = fbm2(vec2(v_uv.x * 5.2 + v_col.b * 3.7, along * 4.2 - TIME * 7.2));
		float n2 = fbm2(vec2(v_uv.x * 10.4 - n1 * 1.1, along * 7.5 - TIME * 10.8));
		float warp_x = across + (n1 - 0.5) * (0.48 + along * 0.35);
		float tongue_len = mix(0.55, 1.08, n1 * 0.65 + n2 * 0.35) * (1.0 - across * 0.52);
		float length_cut = 1.0 - smoothstep(tongue_len - 0.24, tongue_len + 0.04, along);
		float side_cut = 1.0 - smoothstep(0.24, 0.88, warp_x);
		float wisps = smoothstep(0.16 + along * 0.36, 0.56 + along * 0.24, n1 * 0.55 + n2 * 0.45 + (1.0 - along) * 0.38);
		float root_in = smoothstep(0.0, 0.16, along);
		alpha = clamp(side_cut * length_cut * wisps * root_in * v_col.a, 0.0, 0.92);
		float heat = clamp((1.0 - along * 0.72) * 0.68 + (1.0 - across) * 0.28 + (n2 - 0.45) * 0.35, 0.0, 1.0);
		col = mix(dark_crimson, crimson, smoothstep(0.05, 0.32, heat));
		col = mix(col, fiery_orange, smoothstep(0.28, 0.62, heat));
		col = mix(col, bright_gold, smoothstep(0.60, 0.88, heat));
		col = mix(col, white_hot, smoothstep(0.88, 1.0, heat) * (1.0 - along));
		em = mix(0.85, 1.55, heat);
	} else if (v_col.r < 0.70) {
		// Quầng lửa mềm rực đỏ-cam tỏa quanh chân răng (tái tạo vầng sáng mờ ảo ở đỉnh & đáy ảnh mẫu!).
		float n_g = fbm2(vec2(v_uv.x * 7.0, v_uv.y * 3.5 - TIME * 6.0));
		float y_env = sin(clamp(v_uv.y, 0.0, 1.0) * 3.14159);
		float x_env = smoothstep(0.0, 0.14, v_uv.x) * (1.0 - smoothstep(0.86, 1.0, v_uv.x));
		alpha = clamp(pow(y_env, 1.4) * x_env * (0.55 + 0.45 * n_g) * 0.72, 0.0, 0.72);
		col = mix(crimson, fiery_orange, y_env * 0.75 + n_g * 0.25);
		col = mix(col, bright_gold, pow(y_env, 2.2) * 0.55);
		em = 1.25;
	} else {
		// Tàn lửa kim cương sắc nét cam-vàng rực (không đốm bầu dục mờ nhạt!).
		vec2 p = v_uv * 2.0 - 1.0;
		float diamond = abs(p.x) * 1.15 + abs(p.y) * 0.85;
		alpha = (1.0 - smoothstep(0.20, 0.92, diamond)) * 0.95;
		col = mix(fiery_orange, white_hot, 1.0 - smoothstep(0.0, 0.68, diamond));
		em = 1.55;
	}

	if (alpha <= 0.015) {
		discard;
	}
	ALBEDO = col;
	EMISSION = col * em;
	ALPHA = alpha;
}
"""
	_fang_trail_mat = ShaderMaterial.new()
	_fang_trail_mat.shader = trail_sh
	_fang_trail_mat.render_priority = 1


static func _build_fang_jaw_mesh() -> ArrayMesh:
	# Dựng CHỈ HAI HÀNG RĂNG NANH LỬA CÁCH ĐIỆU HÌNH THOI CONG SẮC BÉN (KHÔNG đầu hổ, KHÔNG thanh ống nối giả!):
	# - Mỗi chiếc răng thuôn nhọn mềm ở cả đỉnh gốc (tạo hình ngọn lửa/thoi giống ảnh mẫu) lẫn mũi nanh cong sắc lẹm!
	var core_st := SurfaceTool.new()
	core_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var out_st := SurfaceTool.new()
	out_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. HÀNG RĂNG HÀM TRÊN (10 răng: 4 răng cửa hình thoi lửa + 2 nanh cận + 2 NANH KIẾM KHỔNG LỒ cong vuốt + 2 răng hàm sau).
	var upper_teeth: Array = [
		[-0.16, 0.58, 0.56, 0.30, Vector2(0.068, 0.048), -0.02, 0.11],
		[ 0.16, 0.58, 0.56, 0.30, Vector2(0.068, 0.048), -0.02, 0.19],
		[-0.41, 0.60, 0.55, 0.35, Vector2(0.074, 0.052), -0.03, 0.27],
		[ 0.41, 0.60, 0.55, 0.35, Vector2(0.074, 0.052), -0.03, 0.35],
		[-0.66, 0.62, 0.53, 0.46, Vector2(0.084, 0.062), -0.05, 0.46],
		[ 0.66, 0.62, 0.53, 0.46, Vector2(0.084, 0.062), -0.05, 0.54],
		# CẶP NANH KIẾM CHÍNH: dài uy lực, cong vuốt tinh tế tạo cá tính riêng cho Hổ Răng Kiếm!
		[-0.93, 0.65, 0.50, 0.76, Vector2(0.106, 0.082), -0.11, 0.68],
		[ 0.93, 0.65, 0.50, 0.76, Vector2(0.106, 0.082), -0.11, 0.76],
		[-1.22, 0.63, 0.46, 0.36, Vector2(0.072, 0.055), -0.04, 0.85],
		[ 1.22, 0.63, 0.46, 0.36, Vector2(0.072, 0.055), -0.04, 0.93],
	]
	for spec: Array in upper_teeth:
		var th: float = spec[0]
		var rx_arch: float = spec[1]
		var rz_arch: float = spec[2]
		var t_len: float = spec[3]
		var rad0: Vector2 = spec[4]
		var sweep_z: float = spec[5]
		var seed_v: float = spec[6]
		var u_norm := clampf(absf(th) / 1.22, 0.0, 1.0)
		var root_pt := Vector3(sin(th) * rx_arch, 0.48 + 0.07 * (1.0 - u_norm * u_norm), cos(th) * rz_arch + 0.08)
		var inward_x := -signf(th) * 0.045 * (t_len / 0.55)
		# Dáng thoi lửa: đỉnh gốc thuôn gọn (0.20) -> phình chắc ở 28% -> vuốt nhọn sắc lẹm về mũi (0.01)!
		var pts: Array[Vector3] = [
			root_pt + Vector3(0.0, 0.12, 0.0),
			root_pt + Vector3(inward_x * 0.12, -t_len * 0.16, 0.03),
			root_pt + Vector3(inward_x * 0.45, -t_len * 0.55, sweep_z * 0.38 + 0.02),
			root_pt + Vector3(inward_x * 0.85, -t_len * 0.84, sweep_z * 0.78),
			root_pt + Vector3(inward_x, -t_len, sweep_z),
		]
		var rads: Array[Vector2] = [
			rad0 * 0.22,
			rad0 * 1.08,
			rad0 * 0.84,
			rad0 * 0.38,
			Vector2(0.010, 0.010),
		]
		_add_curve_tube(core_st, out_st, pts, rads, 8, Color(0.12, 1.0, seed_v, 0.85))

	# 2. HÀNG RĂNG HÀM DƯỚI (8 răng hình thoi lửa sắc gọn chĩa cong lên đối xứng hàm trên).
	var lower_teeth: Array = [
		[-0.16, 0.52, 0.50, 0.28, Vector2(0.064, 0.046), -0.01, 0.14],
		[ 0.16, 0.52, 0.50, 0.28, Vector2(0.064, 0.046), -0.01, 0.22],
		[-0.44, 0.54, 0.49, 0.32, Vector2(0.068, 0.050), -0.02, 0.33],
		[ 0.44, 0.54, 0.49, 0.32, Vector2(0.068, 0.050), -0.02, 0.41],
		[-0.74, 0.56, 0.47, 0.48, Vector2(0.084, 0.064), -0.05, 0.58],
		[ 0.74, 0.56, 0.47, 0.48, Vector2(0.084, 0.064), -0.05, 0.66],
		[-1.08, 0.55, 0.43, 0.31, Vector2(0.066, 0.050), -0.04, 0.81],
		[ 1.08, 0.55, 0.43, 0.31, Vector2(0.066, 0.050), -0.04, 0.89],
	]
	for spec: Array in lower_teeth:
		var th: float = spec[0]
		var rx_arch: float = spec[1]
		var rz_arch: float = spec[2]
		var t_len: float = spec[3]
		var rad0: Vector2 = spec[4]
		var sweep_z: float = spec[5]
		var seed_v: float = spec[6]
		var u_norm := clampf(absf(th) / 1.22, 0.0, 1.0)
		var root_pt := Vector3(sin(th) * rx_arch, -0.46 - 0.05 * (1.0 - u_norm * u_norm), cos(th) * rz_arch + 0.06)
		var inward_x := -signf(th) * 0.035 * (t_len / 0.45)
		var pts: Array[Vector3] = [
			root_pt + Vector3(0.0, -0.10, 0.0),
			root_pt + Vector3(inward_x * 0.12, t_len * 0.18, 0.025),
			root_pt + Vector3(inward_x * 0.45, t_len * 0.56, sweep_z * 0.38 + 0.015),
			root_pt + Vector3(inward_x * 0.85, t_len * 0.84, sweep_z * 0.78),
			root_pt + Vector3(inward_x, t_len, sweep_z),
		]
		var rads: Array[Vector2] = [
			rad0 * 0.22,
			rad0 * 1.06,
			rad0 * 0.82,
			rad0 * 0.36,
			Vector2(0.010, 0.010),
		]
		_add_curve_tube(core_st, out_st, pts, rads, 8, Color(0.12, 0.0, seed_v, 0.85))

	var mesh := ArrayMesh.new()
	core_st.commit(mesh)
	out_st.commit(mesh)
	return mesh


static func _build_fang_trail_mesh() -> ArrayMesh:
	# Quầng lửa chân răng mềm (COLOR.r = 0.5) + dải lửa đỏ-cam uốn lượn phía sau (COLOR.r = 0.15) + tàn lửa kim cương (COLOR.r = 0.85)!
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 0. Quầng sương lửa cong mềm tỏa quanh chân răng hàm trên & hàm dưới (thay hoàn toàn thanh ống cứng!).
	const GLOW_SEGS := 14
	for jaw_i: int in 2:
		var y_c := 0.50 if jaw_i == 0 else -0.48
		var rx_g := 0.65 if jaw_i == 0 else 0.57
		var rz_g := 0.55 if jaw_i == 0 else 0.49
		var band_h := 0.24 if jaw_i == 0 else -0.22
		var g_col := Color(0.52, 1.0 if jaw_i == 0 else 0.0, 0.2, 1.0)
		for s: int in GLOW_SEGS:
			var u0 := float(s) / float(GLOW_SEGS)
			var u1 := float(s + 1) / float(GLOW_SEGS)
			var th0 := lerpf(-1.32, 1.32, u0)
			var th1 := lerpf(-1.32, 1.32, u1)
			var p0 := Vector3(sin(th0) * rx_g, y_c, cos(th0) * rz_g + 0.06)
			var p1 := Vector3(sin(th1) * rx_g, y_c, cos(th1) * rz_g + 0.06)
			_tri_uv(st, p0 - Vector3(0.0, band_h * 0.45, 0.0), p1 - Vector3(0.0, band_h * 0.45, 0.0), p1 + Vector3(0.0, band_h, -0.08), Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), g_col)
			_tri_uv(st, p0 - Vector3(0.0, band_h * 0.45, 0.0), p1 + Vector3(0.0, band_h, -0.08), p0 + Vector3(0.0, band_h, -0.08), Vector2(u0, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0), g_col)

	# 1. Dải lửa vòm trên & vòm dưới chảy dài rực lửa phía sau cung hàm.
	const LEN_SEGS := 16
	const ARC_SEGS := 10
	for jaw_i: int in 2:
		var y_base := 0.42 if jaw_i == 0 else -0.38
		var len_z := 3.25 if jaw_i == 0 else 2.75
		var w_start := 0.74 if jaw_i == 0 else 0.62
		var arch_h := 0.24 if jaw_i == 0 else -0.20
		var phase := 0.15 if jaw_i == 0 else 0.65
		var col := Color(0.15, float(jaw_i), phase, 0.92 if jaw_i == 0 else 0.82)
		for l: int in LEN_SEGS:
			var v0 := float(l) / float(LEN_SEGS)
			var v1 := float(l + 1) / float(LEN_SEGS)
			var z0 := lerpf(0.24, -len_z, v0)
			var z1 := lerpf(0.24, -len_z, v1)
			var r0 := lerpf(w_start, 0.08, pow(v0, 0.65))
			var r1 := lerpf(w_start, 0.08, pow(v1, 0.65))
			var y0 := y_base * pow(maxf(0.0, 1.0 - v0), 1.35)
			var y1 := y_base * pow(maxf(0.0, 1.0 - v1), 1.35)
			for a: int in ARC_SEGS:
				var u0 := float(a) / float(ARC_SEGS)
				var u1 := float(a + 1) / float(ARC_SEGS)
				var x00 := lerpf(-1.0, 1.0, u0)
				var x10 := lerpf(-1.0, 1.0, u1)
				var p00 := Vector3(x00 * r0, y0 + (1.0 - x00 * x00) * arch_h * (1.0 - v0 * 0.72), z0)
				var p10 := Vector3(x10 * r0, y0 + (1.0 - x10 * x10) * arch_h * (1.0 - v0 * 0.72), z0)
				var p11 := Vector3(x10 * r1, y1 + (1.0 - x10 * x10) * arch_h * (1.0 - v1 * 0.72), z1)
				var p01 := Vector3(x00 * r1, y1 + (1.0 - x00 * x00) * arch_h * (1.0 - v1 * 0.72), z1)
				_tri_uv(st, p00, p10, p11, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), col)
				_tri_uv(st, p00, p11, p01, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1), col)

	# 2. Hai dải lửa xoắn hai bên sườn nanh kiếm (uốn lượn dọc đuôi tạo chiều sâu 3D mềm mại).
	for side: float in [-1.0, 1.0]:
		var col_s := Color(0.20, 0.5, 0.35 if side > 0.0 else 0.82, 0.88)
		for l: int in LEN_SEGS:
			var v0 := float(l) / float(LEN_SEGS)
			var v1 := float(l + 1) / float(LEN_SEGS)
			var z0 := lerpf(0.28, -3.40, v0)
			var z1 := lerpf(0.28, -3.40, v1)
			var cx0 := side * lerpf(0.64, 0.06, pow(v0, 0.74))
			var cx1 := side * lerpf(0.64, 0.06, pow(v1, 0.74))
			var twist0 := v0 * 2.8 * side
			var twist1 := v1 * 2.8 * side
			var hw0 := lerpf(0.36, 0.06, v0)
			var hw1 := lerpf(0.36, 0.06, v1)
			var off0 := Vector3(sin(twist0) * hw0 * 0.55, cos(twist0) * hw0, 0.0)
			var off1 := Vector3(sin(twist1) * hw1 * 0.55, cos(twist1) * hw1, 0.0)
			var p00 := Vector3(cx0, 0.02, z0) - off0
			var p10 := Vector3(cx0, 0.02, z0) + off0
			var p11 := Vector3(cx1, 0.02, z1) + off1
			var p01 := Vector3(cx1, 0.02, z1) - off1
			_tri_uv(st, p00, p10, p11, Vector2(0.0, v0), Vector2(1.0, v0), Vector2(1.0, v1), col_s)
			_tri_uv(st, p00, p11, p01, Vector2(0.0, v0), Vector2(1.0, v1), Vector2(0.0, v1), col_s)

	# 3. 20 tàn lửa hình thoi nhỏ gọn sắc nét trôi mượt dọc theo đuôi lửa.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5207
	for _i: int in 20:
		var sp_col := Color(0.85, rng.randf(), rng.randf(), 1.0)
		var sx := rng.randf_range(0.026, 0.052)
		var sz := rng.randf_range(0.075, 0.145)
		_tri_uv(st, Vector3(-sx, 0.0, -sz), Vector3(sx, 0.0, -sz), Vector3(sx, 0.0, sz), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), sp_col)
		_tri_uv(st, Vector3(-sx, 0.0, -sz), Vector3(sx, 0.0, sz), Vector3(-sx, 0.0, sz), Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0), sp_col)
		_tri_uv(st, Vector3(0.0, -sx, -sz), Vector3(0.0, sx, -sz), Vector3(0.0, sx, sz), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), sp_col)
		_tri_uv(st, Vector3(0.0, -sx, -sz), Vector3(0.0, sx, sz), Vector3(0.0, -sx, sz), Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0), sp_col)

	st.generate_normals()
	return st.commit()


static func _add_curve_tube(
	core_st: SurfaceTool,
	out_st: SurfaceTool,
	pts: Array[Vector3],
	rads: Array[Vector2],
	segs: int,
	col: Color
) -> void:
	# Dùng khung Bishop (parallel transport) liên tục dọc theo đường cong -> tuyệt đối không bao giờ lật trục 90 độ hay thắt nút!
	var rings: Array = []
	var count := pts.size()
	var prev_r := Vector3.ZERO
	for i: int in count:
		var tangent: Vector3
		if i == 0:
			tangent = (pts[1] - pts[0]).normalized()
		elif i == count - 1:
			tangent = (pts[i] - pts[i - 1]).normalized()
		else:
			tangent = (pts[i + 1] - pts[i - 1]).normalized()
		var r_axis: Vector3
		if i == 0:
			var ref := Vector3.RIGHT if absf(tangent.dot(Vector3.RIGHT)) < 0.85 else Vector3.UP
			r_axis = (ref - tangent * ref.dot(tangent)).normalized()
		else:
			r_axis = (prev_r - tangent * prev_r.dot(tangent))
			if r_axis.length_squared() < 0.0001:
				r_axis = prev_r
			else:
				r_axis = r_axis.normalized()
		prev_r = r_axis
		var u_axis := tangent.cross(r_axis).normalized()
		var v_coord := float(i) / float(maxi(count - 1, 1))
		rings.append([pts[i], r_axis, u_axis, rads[i].x, rads[i].y, v_coord, col])
	_add_loft(core_st, out_st, rings, segs)


static func _add_loft(core_st: SurfaceTool, out_st: SurfaceTool, rings: Array, segs: int) -> void:
	var n_rings := rings.size()
	if n_rings < 2:
		return
	var ring_pts: Array = []
	var ring_nrms: Array = []
	for r: int in n_rings:
		var spec: Array = rings[r]
		var center: Vector3 = spec[0]
		var r_ax: Vector3 = spec[1]
		var u_ax: Vector3 = spec[2]
		var rx: float = spec[3]
		var ry: float = spec[4]
		var pts_r: PackedVector3Array = PackedVector3Array()
		var nrms_r: PackedVector3Array = PackedVector3Array()
		for k: int in segs:
			var ang := TAU * float(k) / float(segs)
			var cs := cos(ang)
			var sn := sin(ang)
			pts_r.append(center + r_ax * (cs * rx) + u_ax * (sn * ry))
			nrms_r.append((r_ax * (cs / maxf(rx, 0.004)) + u_ax * (sn / maxf(ry, 0.004))).normalized())
		ring_pts.append(pts_r)
		ring_nrms.append(nrms_r)

	for r: int in n_rings - 1:
		var p0: PackedVector3Array = ring_pts[r]
		var p1: PackedVector3Array = ring_pts[r + 1]
		var n0: PackedVector3Array = ring_nrms[r]
		var n1: PackedVector3Array = ring_nrms[r + 1]
		var v0: float = rings[r][5]
		var v1: float = rings[r + 1][5]
		var c0: Color = rings[r][6]
		var c1: Color = rings[r + 1][6]
		for k: int in segs:
			var kn := (k + 1) % segs
			var u0 := float(k) / float(segs)
			var u1 := float(k + 1) / float(segs)
			var hint := (n0[k] + n0[kn] + n1[kn] + n1[k]).normalized()
			_emit_smooth_tri(core_st, out_st, p0[k], p0[kn], p1[kn], n0[k], n0[kn], n1[kn], Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), c0, c0, c1, hint)
			_emit_smooth_tri(core_st, out_st, p0[k], p1[kn], p1[k], n0[k], n1[kn], n1[k], Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1), c0, c1, c1, hint)

	# Đóng kín nắp tròn ở 2 đầu ống để khối 100% đặc kín từ mọi góc nhìn.
	var start_c: Vector3 = rings[0][0]
	var next_c: Vector3 = rings[1][0]
	var start_dir: Vector3 = (start_c - next_c).normalized()
	var start_col: Color = rings[0][6]
	var sp: PackedVector3Array = ring_pts[0]
	var sn_arr: PackedVector3Array = ring_nrms[0]
	for k: int in segs:
		var kn := (k + 1) % segs
		_emit_smooth_tri(core_st, out_st, start_c, sp[k], sp[kn], start_dir, sn_arr[k], sn_arr[kn], Vector2(0.5, 0.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0), start_col, start_col, start_col, start_dir)

	var end_c: Vector3 = rings[n_rings - 1][0]
	var prev_c: Vector3 = rings[n_rings - 2][0]
	var end_dir: Vector3 = (end_c - prev_c).normalized()
	var end_col: Color = rings[n_rings - 1][6]
	var ep: PackedVector3Array = ring_pts[n_rings - 1]
	var en_arr: PackedVector3Array = ring_nrms[n_rings - 1]
	for k: int in segs:
		var kn := (k + 1) % segs
		_emit_smooth_tri(core_st, out_st, end_c, ep[k], ep[kn], end_dir, en_arr[k], en_arr[kn], Vector2(0.5, 1.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0), end_col, end_col, end_col, end_dir)


static func _emit_smooth_tri(
	core_st: SurfaceTool,
	out_st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	na: Vector3,
	nb: Vector3,
	nc: Vector3,
	ua: Vector2,
	ub: Vector2,
	uc: Vector2,
	ca: Color,
	cb: Color,
	cc: Color,
	outward_hint: Vector3
) -> void:
	# Đảm bảo mặt trước theo chuẩn clockwise của Godot (pháp tuyến (c - a) x (b - a) hướng ra ngoài!).
	var flip := (c - a).cross(b - a).dot(outward_hint) < 0.0
	var pb := c if flip else b
	var pc := b if flip else c
	var n_b := nc if flip else nb
	var n_c := nb if flip else nc
	var u_b := uc if flip else ub
	var u_c := ub if flip else uc
	var c_b := cc if flip else cb
	var c_c := cb if flip else cc

	core_st.set_normal(na)
	core_st.set_color(ca)
	core_st.set_uv(ua)
	core_st.add_vertex(a)
	core_st.set_normal(n_b)
	core_st.set_color(c_b)
	core_st.set_uv(u_b)
	core_st.add_vertex(pb)
	core_st.set_normal(n_c)
	core_st.set_color(c_c)
	core_st.set_uv(u_c)
	core_st.add_vertex(pc)

	if ca.a > 0.01 or c_b.a > 0.01 or c_c.a > 0.01:
		out_st.set_normal(na)
		out_st.set_color(ca)
		out_st.add_vertex(a)
		out_st.set_normal(n_b)
		out_st.set_color(c_b)
		out_st.add_vertex(pb)
		out_st.set_normal(n_c)
		out_st.set_color(c_c)
		out_st.add_vertex(pc)


static func _build_erupt_curtain_mesh() -> ArrayMesh:
	# Dựng 3 dải lửa phun trào UỐN CONG khớp đúng đường cong 3 vết cào trên sàn (gồm lớp lửa nhọn + lớp khói núi lửa đen bốc phía trên giống Panel 4!).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lanes := [
		Vector3(0.0, 0.96, 1.0),
		Vector3(0.50, 0.80, 0.0),
		Vector3(-0.50, 0.80, 0.0),
	]
	const SEGS := 6
	for lane: Vector3 in lanes:
		var z_base := lane.x
		var half_len := lane.y
		var is_center := lane.z
		var fan_z := 0.26 if is_center > 0.5 else 0.18
		for sgn: float in [-1.0, 1.0]:
			# Lớp lửa nhọn phun xòe hình quạt (COLOR.b = 0.0).
			var col_fire := Color(is_center, 0.5 + 0.35 * sgn, 0.0, 1.0)
			for s: int in SEGS:
				var u0 := float(s) / float(SEGS)
				var u1 := float(s + 1) / float(SEGS)
				var x0 := lerpf(-half_len, half_len, u0)
				var x1 := lerpf(-half_len, half_len, u1)
				var arc0 := 0.19 * (1.0 - x0 * x0) * (1.0 if is_center > 0.5 else 0.84)
				var arc1 := 0.19 * (1.0 - x1 * x1) * (1.0 if is_center > 0.5 else 0.84)
				var bl := Vector3(x0, 0.0, z_base + arc0 - fan_z * 0.25 * sgn)
				var br := Vector3(x1, 0.0, z_base + arc1 - fan_z * 0.25 * sgn)
				var top_r := Vector3(x1, 0.92, z_base + arc1 + fan_z * sgn)
				var tl := Vector3(x0, 0.92, z_base + arc0 + fan_z * sgn)
				_tri_uv(st, bl, br, top_r, Vector2(u0, 1.0), Vector2(u1, 1.0), Vector2(u1, 0.0), col_fire)
				_tri_uv(st, bl, top_r, tl, Vector2(u0, 1.0), Vector2(u1, 0.0), Vector2(u0, 0.0), col_fire)
		# Lớp khói núi lửa đen cuộn bốc trên đỉnh ngọn lửa (COLOR.b = 1.0).
		var col_smoke := Color(is_center, 0.35 + z_base * 0.4, 1.0, 1.0)
		for s: int in SEGS:
			var u0 := float(s) / float(SEGS)
			var u1 := float(s + 1) / float(SEGS)
			var x0 := lerpf(-half_len, half_len, u0)
			var x1 := lerpf(-half_len, half_len, u1)
			var arc0 := 0.19 * (1.0 - x0 * x0) * (1.0 if is_center > 0.5 else 0.84)
			var arc1 := 0.19 * (1.0 - x1 * x1) * (1.0 if is_center > 0.5 else 0.84)
			var bl := Vector3(x0, 0.34, z_base + arc0)
			var br := Vector3(x1, 0.34, z_base + arc1)
			var top_r := Vector3(x1, 1.30, z_base + arc1 + 0.20)
			var tl := Vector3(x0, 1.30, z_base + arc0 + 0.20)
			_tri_uv(st, bl, br, top_r, Vector2(u0, 1.0), Vector2(u1, 1.0), Vector2(u1, 0.0), col_smoke)
			_tri_uv(st, bl, top_r, tl, Vector2(u0, 1.0), Vector2(u1, 0.0), Vector2(u0, 0.0), col_smoke)
	st.generate_normals()
	return st.commit()


static func _build_claw_debris_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9417
	for _i: int in 32:
		var col := Color(rng.randf(), rng.randf(), rng.randf(), 0.0)
		var sx := rng.randf_range(0.09, 0.21)
		var sy := rng.randf_range(0.07, 0.16)
		var sz := rng.randf_range(0.09, 0.20)
		_octa(st, sx, sy, sz, col)
	for _i: int in 24:
		var col := Color(rng.randf(), rng.randf(), rng.randf(), 1.0)
		var r := rng.randf_range(0.40, 0.72)
		var bl := Vector3(-r, -r, 0.0)
		var br := Vector3(r, -r, 0.0)
		var top_r := Vector3(r, r, 0.0)
		var tl := Vector3(-r, r, 0.0)
		_tri_uv(st, bl, br, top_r, Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), col)
		_tri_uv(st, bl, top_r, tl, Vector2(0.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0), col)
	st.generate_normals()
	return st.commit()


static func _octa(st: SurfaceTool, sx: float, sy: float, sz: float, col: Color) -> void:
	var px := Vector3(sx, 0.0, 0.0)
	var nx := Vector3(-sx, 0.0, 0.0)
	var py := Vector3(0.0, sy, 0.0)
	var ny := Vector3(0.0, -sy * 0.78, 0.0)
	var pz := Vector3(0.0, 0.0, sz)
	var nz := Vector3(0.0, 0.0, -sz)
	_tri_uv(st, px, py, pz, Vector2.ZERO, Vector2.UP, Vector2.RIGHT, col)
	_tri_uv(st, pz, py, nx, Vector2.ZERO, Vector2.UP, Vector2.RIGHT, col)
	_tri_uv(st, nx, py, nz, Vector2.ZERO, Vector2.UP, Vector2.RIGHT, col)
	_tri_uv(st, nz, py, px, Vector2.ZERO, Vector2.UP, Vector2.RIGHT, col)
	_tri_uv(st, px, pz, ny, Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, col)
	_tri_uv(st, pz, nx, ny, Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, col)
	_tri_uv(st, nx, nz, ny, Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, col)
	_tri_uv(st, nz, px, ny, Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, col)


static func _tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, col: Color) -> void:
	st.set_color(col)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_color(col)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_color(col)
	st.set_uv(uc)
	st.add_vertex(c)
