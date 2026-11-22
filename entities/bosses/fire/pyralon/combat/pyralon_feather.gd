class_name PyralonFeather
extends Node3D
## Lông vàng mang quán tính riêng; lông trắng quét hết quãng bay để không xuyên player.

enum Mode {
	OFF,
	ORBIT,
	WHITE,
	DEFLECTED,
	DROP,
	HOVER,
	QUEUED,
	CHASE,
	DOMINO_WAIT,
	WARNING,
	CRIMSON_WALL_FLY,
	CRIMSON_WALL_STUCK,
	CRIMSON_GROUND_FLY,
	CRIMSON_GROUND_STUCK,
	CRIMSON_LIFT,
	CRIMSON_REFIRE,
}

const FIRE := preload("res://entities/bosses/fire/pyralon/combat/pyralon_fire.gdshader")

static var _white_mesh: ArrayMesh
static var _crimson_mesh: ArrayMesh
static var _gold_mesh: ArrayMesh
static var _trail_mesh: ArrayMesh
static var _aura_mesh: ArrayMesh
static var _floor_plane: PlaneMesh
static var _shadow_disc: ArrayMesh
static var _white_material: StandardMaterial3D
static var _crimson_material: StandardMaterial3D
static var _crimson_hot_material: StandardMaterial3D
static var _gold_idle_material: StandardMaterial3D
static var _gold_hot_material: StandardMaterial3D
static var _trail_material: ShaderMaterial
static var _crimson_trail_material: ShaderMaterial
static var _shadow_material: StandardMaterial3D

var mode: Mode = Mode.OFF
var _field: PyralonField
var _target: Node3D
var _data: PyralonData
var _velocity: Vector3
var _wind: Vector3
var _origin: Vector3
var _goal: Vector3
var _base: Vector3
var _floor_y: float
var _last_floor_sample: Vector3
var _age: float
var _lifetime: float
var _deadline: float
var _warning_duration: float = 0.50
var _domino_delay: float = 0.0
var _drop_time: float
var _tumble: float
var _queued: bool
var _gold: bool
var _crimson: bool
var _stick_normal: Vector3 = Vector3.UP
var _saved_flight_speed: float = 0.0
var _pending_wall_relaunch: bool = false
var _pending_ground_uproot: bool = false
var _uproot_delay: float = 0.0
var _uproot_start: Vector3 = Vector3.ZERO
var _uproot_lift_h: float = 1.55
var _uproot_lift_time: float = 0.34
var _phase: float
var _wall := PhysicsRayQueryParameters3D.new()
var _fire_mat: ShaderMaterial
var _ring_mat: ShaderMaterial

@onready var _visual: Node3D = $Visual
@onready var _blade: MeshInstance3D = $Visual/Blade
@onready var _trail: MeshInstance3D = $Visual/Trail
@onready var _halo: MeshInstance3D = $Fire
@onready var _ring: MeshInstance3D = $FloorRing
@onready var _shadow: MeshInstance3D = $FloorShadow
@onready var _sweep: ShapeCast3D = $Sweep
@onready var _receiver: WindReceiverComponent = $WindReceiver


func _ready() -> void:
	top_level = true
	_ensure_shared_assets()
	_blade.mesh = _white_mesh
	_trail.mesh = _trail_mesh
	_trail.material_override = _trail_material

	_halo.mesh = _aura_mesh
	_fire_mat = ShaderMaterial.new()
	_fire_mat.shader = FIRE
	_fire_mat.set_shader_parameter(&"kind", 0)
	_halo.material_override = _fire_mat

	_ring.mesh = _floor_plane
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = FIRE
	_ring_mat.set_shader_parameter(&"kind", 1)
	_ring.material_override = _ring_mat

	_shadow.mesh = _shadow_disc
	_shadow.material_override = _shadow_material
	_shadow.scale = Vector3(0.34, 1.0, 0.34)

	_wall.collision_mask = 1 | 256
	pool_released()


func pool_released() -> void:
	mode = Mode.OFF
	_target = null
	_trail.visible = false
	_halo.visible = false
	_ring.visible = false
	_shadow.visible = false
	_set_wind_enabled(false)
	set_physics_process(false)


func setup(field: PyralonField, target: Node3D, at: Vector3, gold: bool, crimson: bool = false) -> void:
	_field = field
	_data = field.profile
	_target = target
	_gold = gold
	_crimson = crimson and not gold
	_age = 0.0
	_lifetime = 0.0
	_tumble = 0.0
	_queued = false
	_pending_wall_relaunch = false
	_pending_ground_uproot = false
	_uproot_delay = 0.0
	_saved_flight_speed = 0.0
	_stick_normal = Vector3.UP
	_phase = randf() * TAU
	_velocity = Vector3.ZERO
	_wind = Vector3.ZERO
	_floor_y = field.floor_at(at).y
	_last_floor_sample = at
	global_transform = Transform3D(Basis.IDENTITY, at)
	_visual.rotation = Vector3.ZERO
	_visual.scale = Vector3.ONE * (1.04 if gold else (1.50 if _crimson else 1.38))
	_blade.mesh = _gold_mesh if gold else (_crimson_mesh if _crimson else _white_mesh)
	_blade.material_override = _gold_idle_material if gold else (_crimson_material if _crimson else _white_material)
	_trail.material_override = _crimson_trail_material if _crimson else _trail_material
	_trail.visible = false
	_halo.visible = gold
	_halo.position = Vector3(0.0, 0.24, 0.0)
	_halo.scale = Vector3(0.95, 0.92, 0.95)
	_fire_mat.set_shader_parameter(&"heat", 0.0)
	_ring.visible = false
	var ring_radius := _data.gold_blast_radius / 0.90
	_ring.scale = Vector3(ring_radius, 1.0, ring_radius)
	_ring_mat.set_shader_parameter(&"heat", 0.0)
	_shadow.visible = gold
	_sync_floor_markers()
	_sweep.clear_exceptions()
	_sweep.add_exception(field.actor)
	_set_wind_enabled(false)
	reset_physics_interpolation()


func orbit(at: Vector3, direction: Vector3) -> void:
	mode = Mode.ORBIT
	global_position = at
	_trail.visible = false
	_orient(direction)


func fire(direction: Vector3, speed: float) -> void:
	mode = Mode.WHITE
	_age = 0.0
	_velocity = direction.normalized() * speed
	_trail.visible = true
	_orient(direction)
	_set_wind_enabled(true)
	set_physics_process(true)


func fire_crimson_wall(direction: Vector3, speed: float) -> void:
	mode = Mode.CRIMSON_WALL_FLY
	_age = 0.0
	_saved_flight_speed = maxf(speed, 1.0)
	_velocity = direction.normalized() * _saved_flight_speed
	_trail.visible = true
	_orient(direction)
	_set_wind_enabled(true)
	set_physics_process(true)


func fire_crimson_ground(direction: Vector3, speed: float) -> void:
	mode = Mode.CRIMSON_GROUND_FLY
	_age = 0.0
	_saved_flight_speed = maxf(speed, 1.0)
	_velocity = direction.normalized() * _saved_flight_speed
	_trail.visible = true
	_orient(direction)
	_set_wind_enabled(true)
	set_physics_process(true)


func launch_from_wall(speed_override: float = 0.0) -> void:
	if mode == Mode.CRIMSON_WALL_FLY:
		_pending_wall_relaunch = true
		if speed_override > 0.1:
			_saved_flight_speed = speed_override
		return
	if mode != Mode.CRIMSON_WALL_STUCK:
		return
	_pending_wall_relaunch = false
	var speed := speed_override if speed_override > 0.1 else maxf(_saved_flight_speed, 6.0)
	# Nhích nhẹ khỏi bề mặt tường để ShapeCast không tự đâm ngược lại chính mặt tường đang cắm.
	global_position += _stick_normal * 0.30
	var aim_dir := _stick_normal
	if is_instance_valid(_target):
		var to_player := (_target.global_position + Vector3.UP * 0.72) - global_position
		if to_player.length_squared() > 0.0025:
			aim_dir = to_player.normalized()
	mode = Mode.CRIMSON_REFIRE
	_age = 0.0
	_velocity = aim_dir * speed
	_blade.material_override = _crimson_hot_material
	_trail.visible = true
	_orient(aim_dir)
	_set_wind_enabled(true)
	set_physics_process(true)
	CombatFx.spawn_hit(global_position, _stick_normal, Color("#ff3042"), 0.36)


func begin_ground_uproot(delay: float, lift_height: float, lift_time: float, speed_override: float = 0.0) -> void:
	_uproot_delay = maxf(delay, 0.0)
	_uproot_lift_h = maxf(lift_height, 0.35)
	_uproot_lift_time = maxf(lift_time, 0.08)
	if speed_override > 0.1:
		_saved_flight_speed = speed_override
	if mode == Mode.CRIMSON_GROUND_FLY:
		_pending_ground_uproot = true
		return
	if mode != Mode.CRIMSON_GROUND_STUCK:
		return
	_pending_ground_uproot = false
	_uproot_start = global_position
	mode = Mode.CRIMSON_LIFT
	_age = 0.0
	_set_wind_enabled(true)
	set_physics_process(true)


func drop(at: Vector3, landing: Vector3) -> void:
	mode = Mode.DROP
	_origin = at
	_goal = landing
	_floor_y = landing.y - _data.gold_hover_height
	_last_floor_sample = landing
	_drop_time = clampf(_origin.distance_to(_goal) / 13.0, 0.40, 1.35)
	_sync_floor_markers()
	_set_wind_enabled(true)
	set_physics_process(true)


func gold_position() -> Vector3:
	return _goal if mode == Mode.DROP else _base


func reserve() -> void:
	_queued = true
	if mode == Mode.HOVER:
		mode = Mode.QUEUED


func available_for_command() -> bool:
	return _gold and mode in [Mode.DROP, Mode.HOVER, Mode.QUEUED]


func chase() -> void:
	if mode == Mode.DROP:
		_base = global_position
	_floor_y = _field.floor_at(_base).y
	_last_floor_sample = _base
	_base.y = _floor_y + _data.gold_hover_height
	mode = Mode.CHASE
	_age = 0.0
	_deadline = _data.gold_chase_time
	_warning_duration = _data.gold_warning_time
	_blade.material_override = _gold_hot_material
	_fire_mat.set_shader_parameter(&"heat", 0.48)
	_field.command_feather_flash(global_position)


func trigger_domino(delay: float, warn_time: float) -> void:
	# Kích hoạt hàng đợi nổ domino theo bán kính từ boss ra ngoài (Resonance Slam Phase 2).
	if not _gold or mode in [Mode.OFF, Mode.WARNING]:
		return
	if mode == Mode.DROP:
		_base = global_position
	_floor_y = _field.floor_at(_base).y
	_last_floor_sample = _base
	_base.y = _floor_y + _data.gold_hover_height
	_domino_delay = maxf(delay, 0.0)
	_warning_duration = maxf(warn_time, 0.08)
	_age = 0.0
	_blade.material_override = _gold_hot_material
	if _domino_delay <= 0.01:
		mode = Mode.WARNING
		_deadline = _warning_duration
		_field.command_feather_flash(global_position)
	else:
		mode = Mode.DOMINO_WAIT
		_fire_mat.set_shader_parameter(&"heat", 0.34)


func on_blast(impulse: Vector3) -> void:
	# Lông đỏ Phase 2 vẫn bị thổi bật đi bởi chiêu E gió giống lông trắng (kể cả lúc đang bứng lên hoặc bay đợt 2).
	if mode in [Mode.WHITE, Mode.CRIMSON_WALL_FLY, Mode.CRIMSON_GROUND_FLY, Mode.CRIMSON_LIFT, Mode.CRIMSON_REFIRE]:
		mode = Mode.DEFLECTED
		_age = 0.0
		_trail.visible = false
		_velocity = impulse * 0.65 + Vector3.UP * 11.5
		_orient(_velocity)
		_field.white_deflect(global_position, _velocity)
		_set_wind_enabled(false)
	elif _gold and mode != Mode.OFF:
		_wind += impulse
		_wind = _wind.limit_length(15.0)


func _physics_process(delta: float) -> void:
	_age += delta
	match mode:
		Mode.WHITE:
			_step_white(delta)
		Mode.CRIMSON_WALL_FLY, Mode.CRIMSON_GROUND_FLY, Mode.CRIMSON_REFIRE:
			_step_crimson_fly(delta)
		Mode.CRIMSON_LIFT:
			_step_crimson_lift(delta)
		Mode.DEFLECTED:
			global_position += _velocity * delta
			_velocity.y += 6.0 * delta
			_visual.rotate_y(16.0 * delta)
			if _age >= 0.40:
				_field.recycle(self)
		Mode.DROP:
			_step_drop(delta)
		Mode.HOVER, Mode.QUEUED, Mode.CHASE, Mode.DOMINO_WAIT, Mode.WARNING:
			_step_gold(delta)


func _step_crimson_fly(delta: float) -> void:
	var movement := _velocity * delta
	_sweep.target_position = movement
	_sweep.force_shapecast_update()
	if _sweep.is_colliding():
		var at := _sweep.get_collision_point(0)
		var normal := _sweep.get_collision_normal(0)
		var collider := _sweep.get_collider(0) as Node
		var hurtbox := collider as HurtboxComponent
		if hurtbox == null and collider is Player:
			hurtbox = (collider as Player).get_node(^"HurtboxComponent") as HurtboxComponent
		if hurtbox:
			_field.hit_feather(hurtbox, _velocity.normalized())
			_field.recycle(self)
			return
		if mode == Mode.CRIMSON_REFIRE:
			# Lượt bay thứ 2 chạm sàn/tường -> cháy rụi thành tro giống lông trắng rồi trả pool.
			_field.white_impact(at, normal, _velocity.normalized(), true)
			_field.recycle(self)
			return
		# Lượt bay đầu của lông đỏ Phase 2: cắm chặt giữ nguyên trên tường (Slam) hoặc trên sàn (Barrage), không tự biến mất!
		global_position = at + normal * 0.04
		_stick_normal = normal
		_orient(_velocity.normalized())
		_trail.visible = false
		_set_wind_enabled(false)
		CombatFx.spawn_hit(at, normal, Color("#ff2434"), 0.36)
		if mode == Mode.CRIMSON_WALL_FLY:
			mode = Mode.CRIMSON_WALL_STUCK
			_age = 0.0
			set_physics_process(false)
			if _pending_wall_relaunch:
				launch_from_wall()
		else:
			mode = Mode.CRIMSON_GROUND_STUCK
			_age = 0.0
			set_physics_process(false)
			if _pending_ground_uproot:
				begin_ground_uproot(_uproot_delay, _uproot_lift_h, _uproot_lift_time)
	elif _age >= _data.crimson_flight_lifetime:
		_field.recycle(self)
	else:
		global_position += movement


func _step_crimson_lift(_delta: float) -> void:
	if _age < _uproot_delay:
		return
	var lift_t := clampf((_age - _uproot_delay) / maxf(_uproot_lift_time, 0.06), 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - lift_t, 2.2)
	var peak := _uproot_start + _stick_normal * 0.25 + Vector3.UP * _uproot_lift_h
	global_position = _uproot_start.lerp(peak, ease_out)
	_blade.material_override = _crimson_hot_material
	var aim_dir := Vector3.FORWARD
	if is_instance_valid(_target):
		var to_target := (_target.global_position + Vector3.UP * 0.68) - global_position
		if to_target.length_squared() > 0.0025:
			aim_dir = to_target.normalized()
	_orient(aim_dir)
	if lift_t >= 1.0:
		mode = Mode.CRIMSON_REFIRE
		_age = 0.0
		_velocity = aim_dir * maxf(_saved_flight_speed, 6.0)
		_trail.visible = true
		_set_wind_enabled(true)
		CombatFx.spawn_hit(global_position, aim_dir, Color("#ff3842"), 0.34)


func _step_white(delta: float) -> void:
	var movement := _velocity * delta
	_sweep.target_position = movement
	_sweep.force_shapecast_update()
	if _sweep.is_colliding():
		var at := _sweep.get_collision_point(0)
		var collider := _sweep.get_collider(0) as Node
		var hurtbox := collider as HurtboxComponent
		if hurtbox == null and collider is Player:
			hurtbox = (collider as Player).get_node(^"HurtboxComponent") as HurtboxComponent
		if hurtbox:
			_field.hit_feather(hurtbox, _velocity.normalized())
		else:
			_field.white_impact(at, _sweep.get_collision_normal(0), _velocity.normalized())
		_field.recycle(self)
	elif _age >= 2.8:
		_field.recycle(self)
	else:
		global_position += movement


func _step_drop(delta: float) -> void:
	var t := clampf(_age / _drop_time, 0.0, 1.0)
	_goal = _shove(_goal, _wind * delta)
	var wind_speed := _wind.length()
	_tumble += (1.2 + wind_speed * 0.75) * delta
	_wind = _wind.move_toward(Vector3.ZERO, 19.0 * delta)
	var next := _origin.lerp(_goal, t) + Vector3.UP * sin(t * PI) * 0.85
	var move := next - global_position
	global_position = _shove(global_position, move)
	_visual.rotation = Vector3(1.12 + 0.35 * sin(_tumble * 2.2), _phase + _tumble * 1.8, move.x * 0.55)
	_sync_floor_markers()
	if t >= 1.0:
		_base = global_position
		_floor_y = _field.floor_at(_base).y
		_last_floor_sample = _base
		_base.y = _floor_y + _data.gold_hover_height
		mode = Mode.QUEUED if _queued else Mode.HOVER


func _step_gold(delta: float) -> void:
	if mode == Mode.HOVER:
		_lifetime += delta
		if _lifetime >= _data.gold_lifetime:
			_field.recycle(self)
			return
	var to_target := Vector3.INF
	if is_instance_valid(_target):
		to_target = _target.global_position - _base
	var near := absf(to_target.y) <= 1.65 and to_target.slide(Vector3.UP).length_squared() <= _data.gold_trigger_range ** 2.0
	if mode == Mode.HOVER and near:
		mode = Mode.WARNING
		_age = 0.0
		_warning_duration = _data.gold_hover_warning_time
		_deadline = _warning_duration
		_blade.material_override = _gold_hot_material
	elif mode == Mode.CHASE and near:
		mode = Mode.WARNING
		_warning_duration = _data.gold_warning_time
		_deadline = minf(_deadline, _age + _warning_duration)
		_blade.material_override = _gold_hot_material

	var drift := Vector3(sin(_age * 1.5 + _phase), 0.0, cos(_age * 1.8 + _phase)) * 0.28
	if mode == Mode.CHASE and to_target.is_finite():
		var chase_spd := _data.gold_chase_speed * (_data.p2_gold_chase_mult if _field.is_phase_two() else 1.0)
		drift += to_target.slide(Vector3.UP).normalized() * chase_spd
	_base = _shove(_base, (drift + _wind) * delta)
	var wind_speed := _wind.length()
	if wind_speed > 0.2:
		_tumble += wind_speed * 0.95 * delta
	_wind = _wind.move_toward(Vector3.ZERO, 19.0 * delta)
	if _base.slide(Vector3.UP).distance_squared_to(_last_floor_sample.slide(Vector3.UP)) >= 0.45:
		_floor_y = _field.floor_at(_base).y
		_last_floor_sample = _base
		_base.y = _floor_y + _data.gold_hover_height
	global_position = _base + Vector3.UP * (sin(_age * 3.4 + _phase) * 0.13)

	# Lông vàng lơ lửng hơi nghiêng để lộ silhouette cánh rõ ở camera cao, lộn mạnh khi gặp gió E.
	var wind_tumble := clampf(wind_speed / 10.0, 0.0, 1.0)
	var pitch := 1.18 + 0.18 * sin(_age * 2.5 + _phase) + sin(_tumble * 3.2) * 0.85 * wind_tumble
	var yaw := _phase + _age * 0.95 + _tumble * 1.25
	var roll := 0.22 * sin(_age * 3.1) + cos(_tumble * 2.6) * 0.75 * wind_tumble
	_visual.rotation = Vector3(pitch, yaw, roll)

	if mode == Mode.DOMINO_WAIT:
		var wait_ratio := clampf(_age / maxf(_domino_delay, 0.01), 0.0, 1.0)
		_fire_mat.set_shader_parameter(&"heat", lerpf(0.28, 0.62, wait_ratio))
		if _age >= _domino_delay:
			mode = Mode.WARNING
			_age = 0.0
			_deadline = _warning_duration
			_field.command_feather_flash(global_position)
	var in_warning := mode == Mode.WARNING
	_ring.visible = in_warning
	if mode in [Mode.WARNING, Mode.CHASE]:
		var remaining := maxf(0.0, _deadline - _age)
		var warning := 1.0 - clampf(remaining / maxf(_warning_duration, 0.01), 0.0, 1.0)
		var heat_val := lerpf(0.36, 0.56, warning) if mode == Mode.CHASE else lerpf(0.62, 1.0, warning)
		_fire_mat.set_shader_parameter(&"heat", heat_val)
		if in_warning:
			_ring_mat.set_shader_parameter(&"heat", warning)
			_halo.scale = Vector3.ONE * lerpf(1.0, 1.28, warning)
		if _age >= _deadline:
			_field.explode_gold(global_position)
			_field.recycle(self)
	elif mode == Mode.DOMINO_WAIT:
		pass
	elif mode == Mode.QUEUED:
		_fire_mat.set_shader_parameter(&"heat", 0.22)
	else:
		_fire_mat.set_shader_parameter(&"heat", 0.08)

	_sync_floor_markers()


func _sync_floor_markers() -> void:
	var floor_offset := _floor_y - global_position.y
	_shadow.position = Vector3(0.0, floor_offset + 0.022, 0.0)
	_ring.position = Vector3(0.0, floor_offset + 0.035, 0.0)


func _shove(at: Vector3, movement: Vector3) -> Vector3:
	if movement.is_zero_approx():
		return at
	_wall.from = at
	_wall.to = at + movement
	var wall := get_world_3d().direct_space_state.intersect_ray(_wall)
	if wall.is_empty():
		return _wall.to
	var normal: Vector3 = wall.normal
	_wind = _wind.slide(normal)
	return wall.position + normal * 0.05


func _set_wind_enabled(active: bool) -> void:
	_receiver.enabled = active
	_receiver.set_deferred(&"monitorable", active)


func _orient(direction: Vector3) -> void:
	if direction.is_zero_approx():
		return
	var up := Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.95 else Vector3.UP
	_visual.global_basis = Basis.looking_at(direction, up, true) * _visual.scale.x
	_visual.rotate_object_local(Vector3.RIGHT, PI * 0.5)


static func _ensure_shared_assets() -> void:
	if _white_mesh != null:
		return
	_white_mesh = _build_eagle_feather_mesh(false)
	_crimson_mesh = _build_eagle_feather_mesh(true)
	_gold_mesh = _build_feather_mesh(true)
	_trail_mesh = _build_trail_mesh()
	_aura_mesh = _build_aura_mesh()

	_floor_plane = PlaneMesh.new()
	_floor_plane.size = Vector2(2.0, 2.0)
	_shadow_disc = _build_shadow_disc()

	_white_material = _blade_material(Color("#ffe9c8"), 0.42)
	_crimson_material = _blade_material(Color("#b80604"), 1.15)
	_crimson_hot_material = _blade_material(Color("#e61208"), 1.65)
	_gold_idle_material = _blade_material(Color("#ff9618"), 0.36)
	_gold_hot_material = _blade_material(Color("#ffcf42"), 1.05)

	_trail_material = ShaderMaterial.new()
	_trail_material.shader = FIRE
	_trail_material.set_shader_parameter(&"kind", 7)
	_trail_material.set_shader_parameter(&"heat", 0.0)

	_crimson_trail_material = ShaderMaterial.new()
	_crimson_trail_material.shader = FIRE
	_crimson_trail_material.set_shader_parameter(&"kind", 7)
	_crimson_trail_material.set_shader_parameter(&"heat", 1.0)

	_shadow_material = StandardMaterial3D.new()
	_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shadow_material.albedo_color = Color(0.04, 0.02, 0.02, 0.18)


static func _blade_material(glow: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = glow
	material.emission_energy_multiplier = energy
	return material


static func _build_eagle_feather_mesh(crimson: bool) -> ArrayMesh:
	# Lông vũ đại bàng thuôn dài (trắng ngà cho Phase 1; đỏ thẫm rực phát sáng cho Phase 2).
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ivory := Color("#e61810") if crimson else Color("#fffcf2")
	var cream := Color("#ad080a") if crimson else Color("#f1f3f6")
	var barb_grey := Color("#6b0406") if crimson else Color("#c6cdd7")
	var vein_grey := Color("#2f0203") if crimson else Color("#838b98")
	var quill_base := Color("#450305") if crimson else Color("#b6bcc6")

	# Cuống lông trụ mảnh nhô ra phía gốc (-0.64 -> -0.32).
	var qb_l := Vector3(-0.014, -0.64, 0.0)
	var qb_r := Vector3(0.014, -0.64, 0.0)
	var qt_l := Vector3(-0.018, -0.30, -0.014)
	var qt_r := Vector3(0.018, -0.30, -0.014)
	var qm_b := Vector3(0.0, -0.64, -0.016)
	var qm_t := Vector3(0.0, -0.30, -0.026)
	_tri(surface, qb_l, qm_b, qm_t, quill_base, vein_grey, vein_grey)
	_tri(surface, qb_l, qm_t, qt_l, quill_base, vein_grey, quill_base)
	_tri(surface, qm_b, qb_r, qt_r, vein_grey, quill_base, quill_base)
	_tri(surface, qm_b, qt_r, qm_t, vein_grey, quill_base, vein_grey)

	# Trục sống lông (rachis) gồ mảnh chạy dọc thân hơi uốn cong tự nhiên tới mũi nhọn (+0.62).
	var s0 := Vector3(0.0, -0.30, -0.026)
	var s1 := Vector3(-0.002, -0.08, -0.036)
	var s2 := Vector3(0.002, 0.14, -0.038)
	var s3 := Vector3(0.010, 0.36, -0.032)
	var s4 := Vector3(0.024, 0.50, -0.020)
	var tip := Vector3(0.042, 0.64, -0.008)

	# Dải sống gân xám hẹp chạy nổi chính giữa.
	var sr := [s0, s1, s2, s3, s4, tip]
	var rw := [0.018, 0.016, 0.014, 0.011, 0.008, 0.003]
	for i: int in sr.size() - 1:
		var a: Vector3 = sr[i]
		var b: Vector3 = sr[i + 1]
		var wa: float = rw[i]
		var wb: float = rw[i + 1]
		_tri(surface, a + Vector3(-wa, 0.0, 0.010), a, b, barb_grey, vein_grey, vein_grey)
		_tri(surface, a + Vector3(-wa, 0.0, 0.010), b, b + Vector3(-wb, 0.0, 0.010), barb_grey, vein_grey, barb_grey)
		_tri(surface, a, a + Vector3(wa, 0.0, 0.010), b + Vector3(wb, 0.0, 0.010), vein_grey, barb_grey, barb_grey)
		_tri(surface, a, b + Vector3(wb, 0.0, 0.010), b, vein_grey, barb_grey, vein_grey)

	# Phiến lông trái (rộng hơn nhẹ, 3 khía tách tơ lông chéo kiểu lông cánh đại bàng).
	var l0 := Vector3(-0.068, -0.24, 0.004)
	var l1 := Vector3(-0.142, -0.06, 0.006)
	var l_n1 := Vector3(-0.088, 0.00, 0.0)
	var l2 := Vector3(-0.165, 0.10, 0.006)
	var l3 := Vector3(-0.156, 0.24, 0.005)
	var l_n2 := Vector3(-0.092, 0.28, -0.002)
	var l4 := Vector3(-0.132, 0.37, 0.004)
	var l5 := Vector3(-0.078, 0.51, 0.002)
	var l_n3 := Vector3(-0.036, 0.54, -0.002)
	var l6 := Vector3(-0.044, 0.58, 0.0)

	_tri(surface, s0, l0, s1, vein_grey, barb_grey, vein_grey)
	_tri(surface, l0, l1, s1, barb_grey, ivory, vein_grey)
	_tri(surface, l1, l_n1, s1, ivory, barb_grey, vein_grey)
	_tri(surface, s1, l_n1, s2, vein_grey, barb_grey, vein_grey)
	_tri(surface, l_n1, l2, s2, barb_grey, ivory, vein_grey)
	_tri(surface, l2, l3, s2, ivory, cream, vein_grey)
	_tri(surface, l3, l_n2, s2, cream, barb_grey, vein_grey)
	_tri(surface, s2, l_n2, s3, vein_grey, barb_grey, vein_grey)
	_tri(surface, l_n2, l4, s3, barb_grey, ivory, vein_grey)
	_tri(surface, l4, l5, s3, ivory, ivory, vein_grey)
	_tri(surface, s3, l5, s4, vein_grey, cream, vein_grey)
	_tri(surface, l5, l_n3, s4, cream, barb_grey, vein_grey)
	_tri(surface, s4, l_n3, tip, vein_grey, barb_grey, ivory)
	_tri(surface, l_n3, l6, tip, barb_grey, ivory, ivory)

	# Phiến lông phải (hẹp và sắc hơn — bất đối xứng tự nhiên như lông bay thật, 2 khía tơ lông).
	var r0 := Vector3(0.056, -0.22, 0.004)
	var r1 := Vector3(0.118, -0.02, 0.006)
	var r2 := Vector3(0.138, 0.16, 0.005)
	var r_n1 := Vector3(0.082, 0.20, -0.002)
	var r3 := Vector3(0.124, 0.30, 0.004)
	var r4 := Vector3(0.104, 0.43, 0.002)
	var r_n2 := Vector3(0.068, 0.46, -0.002)
	var r5 := Vector3(0.082, 0.54, 0.0)

	_tri(surface, s0, s1, r0, vein_grey, vein_grey, barb_grey)
	_tri(surface, s1, r1, r0, vein_grey, cream, barb_grey)
	_tri(surface, s1, s2, r1, vein_grey, vein_grey, cream)
	_tri(surface, s2, r2, r1, vein_grey, ivory, cream)
	_tri(surface, s2, r_n1, r2, vein_grey, barb_grey, ivory)
	_tri(surface, s2, s3, r_n1, vein_grey, vein_grey, barb_grey)
	_tri(surface, s3, r3, r_n1, vein_grey, ivory, barb_grey)
	_tri(surface, s3, r4, r3, vein_grey, cream, ivory)
	_tri(surface, s3, s4, r4, vein_grey, vein_grey, cream)
	_tri(surface, s4, r_n2, r4, vein_grey, barb_grey, cream)
	_tri(surface, s4, r5, r_n2, vein_grey, ivory, barb_grey)
	_tri(surface, s4, tip, r5, vein_grey, ivory, ivory)

	surface.generate_normals()
	return surface.commit()


static func _build_feather_mesh(gold: bool) -> ArrayMesh:
	# Lông chim low-poly có sống gân, khía tách cánh rõ silhouette ở góc camera chơi.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var edge_c := Color("#ffe564") if gold else Color("#fffaf0")
	var vane_c := Color("#ff9f1c") if gold else Color("#eceff4")
	var shade_c := Color("#d95b0c") if gold else Color("#ccd3dc")
	var quill_c := Color("#6b2606") if gold else Color("#79808c")

	# Trục sống lông từ cuống (-Y) tới mũi cong nhẹ (+Y). Mặt trên hướng -Z để đối diện camera khi bay.
	var q0 := Vector3(-0.02, -0.46, 0.0)
	var q1 := Vector3(-0.01, -0.18, -0.05)
	var q2 := Vector3(0.01, 0.14, -0.06)
	var q3 := Vector3(0.05, 0.50, -0.02)

	# Cánh trái có 1 khía tách gọn gần phần giữa.
	var l0 := Vector3(-0.08, -0.26, 0.01)
	var l1 := Vector3(-0.20, -0.04, 0.01)
	var l_notch := Vector3(-0.10, 0.07, -0.01)
	var l2 := Vector3(-0.22, 0.20, 0.01)
	var l3 := Vector3(-0.11, 0.38, 0.01)

	# Cánh phải cong gọn có khía nhẹ gần phần trên.
	var r0 := Vector3(0.07, -0.24, 0.01)
	var r1 := Vector3(0.19, -0.01, 0.01)
	var r2 := Vector3(0.20, 0.22, 0.01)
	var r_notch := Vector3(0.11, 0.28, -0.01)
	var r3 := Vector3(0.15, 0.39, 0.01)

	# Nửa cánh trái (sáng hơn để tạo tương phản mặt phẳng low-poly).
	_tri(surface, q0, l0, q1, quill_c, vane_c, quill_c)
	_tri(surface, l0, l1, q1, vane_c, edge_c, quill_c)
	_tri(surface, l1, l_notch, q1, edge_c, quill_c, quill_c)
	_tri(surface, q1, l_notch, q2, quill_c, quill_c, quill_c)
	_tri(surface, l_notch, l2, q2, quill_c, edge_c, quill_c)
	_tri(surface, l2, l3, q2, edge_c, edge_c, quill_c)
	_tri(surface, l3, q3, q2, edge_c, edge_c, quill_c)

	# Nửa cánh phải (đậm hơn một bậc tạo chiều sâu).
	_tri(surface, q0, q1, r0, quill_c, quill_c, shade_c)
	_tri(surface, q1, r1, r0, quill_c, vane_c, shade_c)
	_tri(surface, q1, q2, r1, quill_c, quill_c, vane_c)
	_tri(surface, q2, r2, r1, quill_c, edge_c, vane_c)
	_tri(surface, q2, r_notch, r2, quill_c, quill_c, edge_c)
	_tri(surface, q2, r3, r_notch, quill_c, edge_c, quill_c)
	_tri(surface, q2, q3, r3, quill_c, edge_c, edge_c)

	surface.generate_normals()
	return surface.commit()


static func _build_trail_mesh() -> ArrayMesh:
	# Dải vệt sáng thuôn dài hai mặt cắt chéo dọc trục -Y phía sau cuống lông trắng.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y_start := -0.52
	var y_end := -2.65
	var half_w := 0.22
	# Mặt 1 nằm ngang (XY) rõ từ camera trên cao.
	_quad_uv(
		surface,
		Vector3(-half_w, y_start, 0.0),
		Vector3(half_w, y_start, 0.0),
		Vector3(half_w, y_end, 0.0),
		Vector3(-half_w, y_end, 0.0)
	)
	# Mặt 2 cắt chéo (ZY) giữ độ rõ từ góc nghiêng.
	_quad_uv(
		surface,
		Vector3(0.0, y_start, -half_w),
		Vector3(0.0, y_start, half_w),
		Vector3(0.0, y_end, half_w),
		Vector3(0.0, y_end, -half_w)
	)
	surface.generate_normals()
	return surface.commit()


static func _build_aura_mesh() -> ArrayMesh:
	# Hai mặt đứng cắt vuông góc quanh lông vàng để ngọn lửa luôn bốc lên trời từ mọi góc nhìn.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := 0.62
	var hh := 0.62
	_quad_uv(surface, Vector3(-hw, hh, 0.0), Vector3(hw, hh, 0.0), Vector3(hw, -hh, 0.0), Vector3(-hw, -hh, 0.0))
	_quad_uv(surface, Vector3(0.0, hh, -hw), Vector3(0.0, hh, hw), Vector3(0.0, -hh, hw), Vector3(0.0, -hh, -hw))
	surface.generate_normals()
	return surface.commit()


static func _build_shadow_disc() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES := 10
	for i: int in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * ((i + 1) % SIDES) / SIDES
		surface.add_vertex(Vector3.ZERO)
		surface.add_vertex(Vector3(cos(a0), 0.0, sin(a0)))
		surface.add_vertex(Vector3(cos(a1), 0.0, sin(a1)))
	surface.generate_normals()
	return surface.commit()


static func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	surface.set_color(ca)
	surface.add_vertex(a)
	surface.set_color(cb)
	surface.add_vertex(b)
	surface.set_color(cc)
	surface.add_vertex(c)


static func _quad_uv(surface: SurfaceTool, tl: Vector3, top_r: Vector3, br: Vector3, bl: Vector3) -> void:
	surface.set_uv(Vector2(0.0, 0.0))
	surface.add_vertex(tl)
	surface.set_uv(Vector2(1.0, 0.0))
	surface.add_vertex(top_r)
	surface.set_uv(Vector2(1.0, 1.0))
	surface.add_vertex(br)
	surface.set_uv(Vector2(0.0, 0.0))
	surface.add_vertex(tl)
	surface.set_uv(Vector2(1.0, 1.0))
	surface.add_vertex(br)
	surface.set_uv(Vector2(0.0, 1.0))
	surface.add_vertex(bl)
