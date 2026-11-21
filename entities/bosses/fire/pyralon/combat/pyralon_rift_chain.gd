class_name PyralonRiftChain
extends Node3D
## Tổ hợp Phase 2 Slam: Vệt chém lửa dựng dọc -> xé tường mở cổng không gian -> bắn xích lửa trói player 2s (0 sát thương) -> kích hoạt toàn bộ lông đỏ cắm tường bay tới player!

enum Stage { OFF, SLASH, PORTAL_OPEN, CHAIN_FIRE, BOUND_HOLD, CHAIN_FADE, PORTAL_CLOSE }

const SHADER := preload("res://entities/bosses/fire/pyralon/combat/pyralon_rift_chain.gdshader")
const PORTAL_CLOSE_TIME := 0.45

var stage: Stage = Stage.OFF
var bound_player: Player

var _field: PyralonField
var _target: Node3D
var _speed: float = 28.0
var _age: float = 0.0

var _slash_pos: Vector3
var _slash_dir: Vector3
var _slash_dist: float = 0.0
var _slash_hits: Dictionary[int, bool] = {}

var _portal_pos: Vector3
var _portal_normal: Vector3
var _portal_open: float = 0.0

var _chain_dir: Vector3
var _chain_tip: Vector3
var _chain_length: float = 0.0
var _feathers_launched: bool = false

var _query := PhysicsShapeQueryParameters3D.new()
var _slash_shape := BoxShape3D.new()
var _chain_shape := BoxShape3D.new()

var _slash_mesh: MeshInstance3D
var _portal_mesh: MeshInstance3D
var _chain_mesh: MeshInstance3D
var _bind_mesh: MeshInstance3D

var _slash_mat: ShaderMaterial
var _portal_mat: ShaderMaterial
var _chain_mat: ShaderMaterial
var _bind_mat: ShaderMaterial

static var _slash_geo: ArrayMesh
static var _portal_geo: QuadMesh
static var _chain_geo: ArrayMesh
static var _bind_geo: ArrayMesh


func _ready() -> void:
	top_level = true
	_field = get_parent() as PyralonField
	_ensure_shared_meshes()

	_slash_mesh = _make_layer(_slash_geo, 0)
	_slash_mat = _slash_mesh.material_override as ShaderMaterial
	_portal_mesh = _make_layer(_portal_geo, 1)
	_portal_mat = _portal_mesh.material_override as ShaderMaterial
	_chain_mesh = _make_layer(_chain_geo, 2)
	_chain_mat = _chain_mesh.material_override as ShaderMaterial
	_bind_mesh = _make_layer(_bind_geo, 3)
	_bind_mat = _bind_mesh.material_override as ShaderMaterial

	_slash_shape.size = Vector3(1.45, 4.4, 2.2)
	_chain_shape.size = Vector3(1.15, 1.50, 1.40)
	_query.collision_mask = 2
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	cancel()


func launch(origin: Vector3, direction: Vector3, target: Node3D, speed: float) -> void:
	cancel()
	var dir := direction.slide(Vector3.UP)
	if dir.length_squared() < 0.0001:
		dir = Vector3.BACK
	_slash_dir = dir.normalized()
	_slash_pos = _field.floor_at(origin)
	_target = target
	_speed = maxf(speed, 4.0)
	_age = 0.0
	_slash_dist = 0.0
	_portal_open = 0.0
	_chain_length = 0.0
	_feathers_launched = false
	_slash_hits.clear()

	var height := _field.profile.vertical_slash_height
	_slash_mesh.scale = Vector3(1.0, height * 0.52, height * 0.52)
	_slash_mat.set_shader_parameter(&"fade_t", 0.0)
	_update_slash_pose()
	_slash_mesh.show()
	stage = Stage.SLASH
	set_physics_process(true)


func cancel() -> void:
	_release_bound_player()
	stage = Stage.OFF
	_target = null
	_feathers_launched = false
	if is_instance_valid(_slash_mesh):
		_slash_mesh.hide()
		_portal_mesh.hide()
		_chain_mesh.hide()
		_bind_mesh.hide()
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_age += delta
	match stage:
		Stage.SLASH:
			_step_slash(delta)
		Stage.PORTAL_OPEN:
			_step_portal_open(delta)
		Stage.CHAIN_FIRE:
			_step_chain_fire(delta)
		Stage.BOUND_HOLD:
			_step_bound_hold(delta)
		Stage.CHAIN_FADE:
			_step_chain_fade(delta)
		Stage.PORTAL_CLOSE:
			_step_portal_close(delta)


func _step_slash(delta: float) -> void:
	var config := _field.profile
	var max_range := maxf(config.vertical_slash_range, 10.0)
	var step := minf(_speed * delta, max_range - _slash_dist)
	if step <= 0.0:
		_open_portal(_slash_pos, -_slash_dir)
		return
	var next := _slash_pos + _slash_dir * step
	var level := Vector3.UP * 1.15
	# Kiểm tra sát thương player dọc theo đường bay — dù trúng hay trượt vẫn bay thẳng tới tường!
	_query.shape = _slash_shape
	_slash_shape.size = Vector3(1.55, config.vertical_slash_height, maxf(1.6, step + 1.2))
	var slash_basis := Basis.looking_at(_slash_dir, Vector3.UP, true)
	_query.transform = Transform3D(slash_basis, (_slash_pos + next) * 0.5 + Vector3.UP * (config.vertical_slash_height * 0.45))
	for res: Dictionary in get_world_3d().direct_space_state.intersect_shape(_query, 8):
		var hurtbox := res.collider as HurtboxComponent
		if hurtbox == null or _slash_hits.has(hurtbox.get_instance_id()):
			continue
		if _field.wall_between(_slash_pos + level, hurtbox.global_position + Vector3.UP * 0.65).is_empty():
			_slash_hits[hurtbox.get_instance_id()] = true
			_field.hit_damage(hurtbox, config.vertical_slash_damage, _slash_dir, 1.8)

	# Dò va chạm tường để xé vết nứt dọc & mở cổng không gian (chỉ để lại vệt chém dọc, không tạo vệt nứt đất trên đường bay).
	var wall_hit := _field.wall_between(_slash_pos + level, next + _slash_dir * 0.45 + level)
	if not wall_hit.is_empty():
		var hit_pos: Vector3 = wall_hit.position
		var floor_pos := Vector3(hit_pos.x, _field.floor_at(_slash_pos).y, hit_pos.z)
		var wall_normal := (wall_hit.normal as Vector3).slide(Vector3.UP)
		if wall_normal.length_squared() < 0.01:
			wall_normal = -_slash_dir
		else:
			wall_normal = wall_normal.normalized()
		_open_portal(floor_pos, wall_normal)
		return

	_slash_pos = next
	_slash_dist += step
	_update_slash_pose()


func _update_slash_pose() -> void:
	var height := _field.profile.vertical_slash_height
	var center := _slash_pos + Vector3.UP * (height * 0.48)
	var right := _slash_dir.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	# Local +X = _slash_dir (mũi chém), Local +Y = Vector3.UP (đứng dọc), Local +Z = right (hệ thuận tay phải).
	_slash_mesh.global_transform = Transform3D(Basis(_slash_dir, Vector3.UP, right), center)
	_slash_mesh.scale = Vector3(height * 0.52, height * 0.52, 1.0)


func _open_portal(floor_hit: Vector3, wall_normal: Vector3) -> void:
	_slash_mesh.hide()
	var p_size := _field.profile.portal_size
	var p_w := maxf(p_size.x, 0.8)
	var p_h := maxf(p_size.y, 1.2)
	_portal_normal = wall_normal.normalized()
	_portal_pos = floor_hit + Vector3.UP * (p_h * 0.52) + _portal_normal * 0.10
	_portal_open = 0.0
	_age = 0.0
	var right := Vector3.UP.cross(_portal_normal)
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	# _portal_geo có size = (2, 2) nên scale bằng nửa kích thước cổng thực (2.3m x 3.1m vừa vặn mặt tường, hệ thuận tay phải det > 0).
	_portal_mesh.global_transform = Transform3D(Basis(right * (p_w * 0.5), Vector3.UP * (p_h * 0.5), _portal_normal), _portal_pos)
	_portal_mat.set_shader_parameter(&"open_t", 0.05)
	_portal_mesh.show()
	_field.wall_splash(floor_hit, _portal_normal, p_w * 1.15)
	ScreenShake.add_trauma_at(0.35, _portal_pos, 10.0, 26.0)
	stage = Stage.PORTAL_OPEN


func _step_portal_open(_delta: float) -> void:
	var dur := maxf(_field.profile.portal_open_time, 0.06)
	_portal_open = clampf(_age / dur, 0.0, 1.0)
	_portal_mat.set_shader_parameter(&"open_t", _portal_open)
	if _age >= dur:
		_begin_chain_fire()


func _begin_chain_fire() -> void:
	stage = Stage.CHAIN_FIRE
	_age = 0.0
	var aim_pos := _portal_pos + _portal_normal * 12.0
	if is_instance_valid(_target):
		aim_pos = _target.global_position + Vector3.UP * 0.95
	var start := Vector3(_portal_pos.x, aim_pos.y, _portal_pos.z) + _portal_normal * 0.16
	_portal_pos.y = clampf(aim_pos.y, _portal_pos.y - 1.2, _portal_pos.y + 1.2)
	var delta_vec := (aim_pos - start).slide(Vector3.UP)
	if delta_vec.length_squared() < 0.0025:
		_chain_dir = _portal_normal
	else:
		_chain_dir = delta_vec.normalized()
	_chain_tip = start
	_chain_length = 0.15
	_chain_mat.set_shader_parameter(&"fade_t", 0.0)
	_update_chain_visual(start, _chain_tip)
	_chain_mesh.show()


func _step_chain_fire(delta: float) -> void:
	var config := _field.profile
	var max_range := maxf(config.chain_max_range, 10.0)
	var step := minf(_speed * delta, max_range - _chain_length)
	if step <= 0.0:
		_begin_chain_miss()
		return
	var next_tip := _chain_tip + _chain_dir * step
	var chain_origin := Vector3(_portal_pos.x, _chain_tip.y, _portal_pos.z) + _portal_normal * 0.12

	# 1. Dò chạm hitbox player theo hộp kéo dọc hướng bay để không bao giờ xuyên lọt ở tốc độ cao (0 sát thương, trói tại chỗ 2s!).
	_chain_shape.size = Vector3(1.18, 1.55, maxf(1.10, step + 0.90))
	_query.shape = _chain_shape
	var chain_basis := Basis.looking_at(_chain_dir, Vector3.UP, true)
	_query.transform = Transform3D(chain_basis, (_chain_tip + next_tip) * 0.5)
	for res: Dictionary in get_world_3d().direct_space_state.intersect_shape(_query, 6):
		var collider := res.collider as Node
		var hit_player: Player = null
		if collider is Player:
			hit_player = collider as Player
		elif collider is HurtboxComponent and collider.get_parent() is Player:
			hit_player = collider.get_parent() as Player
		if hit_player and _field.wall_between(_chain_tip, hit_player.global_position + Vector3.UP * 0.8).is_empty():
			_chain_tip = hit_player.global_position + Vector3.UP * 0.90
			_update_chain_visual(chain_origin, _chain_tip)
			_begin_bind(hit_player)
			return

	# 2. Dò chạm tường đối diện -> xích tan biến, cổng từ từ đóng lại VÀ phóng toàn bộ lông đỏ cắm tường!
	if _chain_length > 0.5:
		var wall_hit := _field.wall_between(_chain_tip, next_tip)
		if not wall_hit.is_empty():
			_chain_tip = wall_hit.position
			_update_chain_visual(chain_origin, _chain_tip)
			CombatFx.spawn_hit(_chain_tip, wall_hit.normal, Color("#ff4c26"), 0.72)
			_begin_chain_miss()
			return

	_chain_tip = next_tip
	_chain_length += step
	_update_chain_visual(chain_origin, _chain_tip)


func _begin_bind(player: Player) -> void:
	bound_player = player
	bound_player.set_root_locked(self, true)
	stage = Stage.BOUND_HOLD
	_age = 0.0
	_bind_mesh.global_position = bound_player.global_position + Vector3.UP * 0.82
	_bind_mesh.scale = Vector3(0.68, 0.95, 0.68)
	_bind_mat.set_shader_parameter(&"open_t", 1.0)
	_bind_mat.set_shader_parameter(&"fade_t", 0.0)
	_bind_mesh.show()
	CombatFx.spawn_hit(_bind_mesh.global_position, Vector3.UP, Color("#ff3b1c"), 0.85)
	ScreenShake.add_trauma_at(0.28, _bind_mesh.global_position, 8.0, 18.0)
	_trigger_wall_feathers()


func _step_bound_hold(delta: float) -> void:
	var bind_dur := maxf(_field.profile.chain_bind_duration, 0.1)
	if is_instance_valid(bound_player):
		var bind_center := bound_player.global_position + Vector3.UP * 0.82
		_bind_mesh.global_position = bind_center
		_bind_mesh.rotate_y(delta * 2.4)
		var chain_origin := Vector3(_portal_pos.x, bind_center.y, _portal_pos.z) + _portal_normal * 0.12
		_update_chain_visual(chain_origin, bind_center)
	if _age >= bind_dur:
		_release_bound_player()
		stage = Stage.CHAIN_FADE
		_age = 0.0


func _begin_chain_miss() -> void:
	stage = Stage.CHAIN_FADE
	_age = 0.0
	_trigger_wall_feathers()


func _step_chain_fade(_delta: float) -> void:
	var fade_dur := maxf(_field.profile.chain_fade_time, 0.12)
	var t := clampf(_age / fade_dur, 0.0, 1.0)
	_chain_mat.set_shader_parameter(&"fade_t", t)
	if _bind_mesh.visible:
		_bind_mat.set_shader_parameter(&"fade_t", t)
	_portal_open = lerpf(1.0, 0.45, t)
	_portal_mat.set_shader_parameter(&"open_t", _portal_open)
	if t >= 1.0:
		_chain_mesh.hide()
		_bind_mesh.hide()
		stage = Stage.PORTAL_CLOSE
		_age = 0.0


func _step_portal_close(_delta: float) -> void:
	var t := clampf(_age / PORTAL_CLOSE_TIME, 0.0, 1.0)
	_portal_mat.set_shader_parameter(&"open_t", lerpf(0.45, 0.0, t))
	if t >= 1.0:
		cancel()


func _trigger_wall_feathers() -> void:
	if _feathers_launched:
		return
	_feathers_launched = true
	_field.launch_wall_crimson_feathers()


func _release_bound_player() -> void:
	if is_instance_valid(bound_player):
		bound_player.set_root_locked(self, false)
	bound_player = null


func _update_chain_visual(start: Vector3, end_pt: Vector3) -> void:
	var span := end_pt - start
	var dist := maxf(span.length(), 0.05)
	var dir := span / dist
	var up := Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.94 else Vector3.UP
	var right := up.cross(dir).normalized()
	var z_axis := right.cross(dir).normalized()
	# Local +Y chạy dọc từ start (0) tới end_pt (1) theo hệ trục thuận tay phải.
	_chain_mesh.global_transform = Transform3D(Basis(right, dir, z_axis), start)
	_chain_mesh.scale = Vector3(1.0, dist, 1.0)
	_chain_mat.set_shader_parameter(&"chain_len", dist)


func _make_layer(mesh_data: Mesh, kind_id: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh_data
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 16.0
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"kind", kind_id)
	node.material_override = mat
	add_child(node)
	return node


static func _ensure_shared_meshes() -> void:
	if _slash_geo != null:
		return
	_slash_geo = _build_vertical_slash_mesh()
	_portal_geo = QuadMesh.new()
	_portal_geo.size = Vector2(2.0, 2.0)
	_chain_geo = _build_chain_mesh()
	_bind_geo = _build_bind_coil_mesh()


static func _build_vertical_slash_mesh() -> ArrayMesh:
	# 3 lát phẳng đứng chéo nhẹ (0°, +14°, -14°) giúp vệt chém lửa dọc có độ dày rõ nét từ camera nhìn chéo trên cao.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offsets := [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.22), Vector3(0.0, 0.0, -0.22)]
	var widths := [1.0, 0.86, 0.86]
	for i: int in offsets.size():
		var off: Vector3 = offsets[i]
		var s: float = widths[i]
		_quad(
			st,
			Vector3(-s, s, 0.0) + off,
			Vector3(s, s, 0.0) + off,
			Vector3(s, -s, 0.0) + off,
			Vector3(-s, -s, 0.0) + off,
			Color.WHITE
		)
	st.generate_normals()
	return st.commit()


static func _build_chain_mesh() -> ArrayMesh:
	# Lõi xích 2 mặt chữ X (COLOR.a = 0.0) + ống vỏ lửa bao bọc quanh xích (COLOR.a = 1.0), kéo dọc Y = 0..1.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var core_c := Color(0.5, 0.5, 0.5, 0.0)
	var hw := 0.14
	_quad(st, Vector3(-hw, 1.0, 0.0), Vector3(hw, 1.0, 0.0), Vector3(hw, 0.0, 0.0), Vector3(-hw, 0.0, 0.0), core_c)
	_quad(st, Vector3(0.0, 1.0, -hw), Vector3(0.0, 1.0, hw), Vector3(0.0, 0.0, hw), Vector3(0.0, 0.0, -hw), core_c)

	# Ống vỏ lửa 6 mặt chạy dọc thân xích (8 đốt theo Y để sóng lửa uốn mềm).
	const SIDES := 6
	const RINGS := 8
	var r := 0.26
	for r_i: int in RINGS:
		var v0 := float(r_i) / float(RINGS)
		var v1 := float(r_i + 1) / float(RINGS)
		for s_i: int in SIDES:
			var u0 := float(s_i) / float(SIDES)
			var u1 := float(s_i + 1) / float(SIDES)
			var a0 := u0 * TAU
			var a1 := u1 * TAU
			var p00 := Vector3(cos(a0) * r, v0, sin(a0) * r)
			var p10 := Vector3(cos(a1) * r, v0, sin(a1) * r)
			var p11 := Vector3(cos(a1) * r, v1, sin(a1) * r)
			var p01 := Vector3(cos(a0) * r, v1, sin(a0) * r)
			var sc := Color(u0, v0, 0.5, 1.0)
			_tri_uv(st, p00, p10, p11, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), sc)
			_tri_uv(st, p00, p11, p01, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1), sc)
	st.generate_normals()
	return st.commit()


static func _build_bind_coil_mesh() -> ArrayMesh:
	# 3 vòng xích lửa nghiêng đan chéo quấn quanh người player khi bị trói.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGS := 16
	var heights := [-0.42, 0.0, 0.42]
	var tilts := [0.22, -0.18, 0.26]
	for band: int in 3:
		var y_base: float = heights[band]
		var tilt: float = tilts[band]
		var rad := 1.0 + float(band % 2) * 0.12
		var bh := 0.15
		for i: int in SEGS:
			var u0 := float(i) / float(SEGS)
			var u1 := float(i + 1) / float(SEGS)
			var a0 := u0 * TAU
			var a1 := u1 * TAU
			var y0 := y_base + sin(a0 + float(band)) * tilt
			var y1 := y_base + sin(a1 + float(band)) * tilt
			var b0 := Vector3(cos(a0) * rad, y0 - bh, sin(a0) * rad)
			var b1 := Vector3(cos(a1) * rad, y1 - bh, sin(a1) * rad)
			var t1 := Vector3(cos(a1) * rad, y1 + bh, sin(a1) * rad)
			var t0 := Vector3(cos(a0) * rad, y0 + bh, sin(a0) * rad)
			_tri_uv(st, b0, b1, t1, Vector2(u0, 1.0), Vector2(u1, 1.0), Vector2(u1, 0.0), Color.WHITE)
			_tri_uv(st, b0, t1, t0, Vector2(u0, 1.0), Vector2(u1, 0.0), Vector2(u0, 0.0), Color.WHITE)
	st.generate_normals()
	return st.commit()


static func _quad(st: SurfaceTool, tl: Vector3, top_r: Vector3, br: Vector3, bl: Vector3, col: Color) -> void:
	_tri_uv(st, tl, top_r, br, Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), col)
	_tri_uv(st, tl, br, bl, Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0), col)


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
