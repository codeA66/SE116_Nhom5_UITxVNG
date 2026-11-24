extends State

enum Phase { RISE, AIM, FLIGHT, DESCEND }

const WORLD_MASK: int = 1
const ENEMY_MASK: int = 4

var _player: Player
var _owner: CharmUltimate
var _data: SkystrikeData
var _visual: SkystrikeVfx
var _phase: Phase = Phase.RISE
var _age: float = 0.0
var _origin: Vector3
var _impact: Vector3
var _impact_normal: Vector3
var _cursor: Vector2 = Vector2.INF
var _aim_valid: bool = false
var _fire_requested: bool = false
var _cancel_requested: bool = false
var _did_land: bool = false
var _forces_before: bool = true
var _controls_before: bool = true
var _descent_from: float = 0.0
var _probe: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _blast: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _sphere: SphereShape3D = SphereShape3D.new()


func configure(player: Player, caster: CharmUltimate) -> void:
	_player = player
	_owner = caster
	_data = caster.data
	_probe.collision_mask = WORLD_MASK
	_blast.collision_mask = ENEMY_MASK
	_blast.collide_with_areas = true
	_blast.collide_with_bodies = false
	_blast.shape = _sphere


func clear_context() -> void:
	_player = null
	_owner = null
	_data = null


func enter(_previous: StringName) -> void:
	_phase = Phase.RISE
	_age = 0.0
	_origin = _player.global_position
	_did_land = false
	_fire_requested = false
	_cancel_requested = false
	_aim_valid = false
	_cursor = Vector2.INF
	_controls_before = _player.controls_enabled
	_forces_before = _player.external_forces_enabled
	_player.set_damage_protection(self, true)
	_player.set_targetability_block(self, true)
	_player.set_controls_enabled(false)
	_player.external_forces_enabled = false
	_player.velocity = Vector3.ZERO
	var cursor_point: Vector3 = _player.project_cursor_to_height(_owner.get_cursor(), _origin.y)
	if cursor_point.is_finite() and cursor_point.distance_squared_to(_origin) > 0.04:
		_player.face_instantly(_origin.direction_to(cursor_point))
	_player.play_action(Player.ANIM_JUMP)
	_visual = _owner.begin_visual()


func exit() -> void:
	_player.velocity = Vector3.ZERO
	_player.external_forces_enabled = _forces_before
	if not _player.health.is_dead():
		_player.set_controls_enabled(_controls_before)
	_player.set_damage_protection(self, false)
	_player.set_targetability_block(self, false)
	_owner.spend_charge()
	_owner.finish_cast(_did_land)
	_visual = null


func physics_update(delta: float) -> void:
	if _cancel_requested and _phase != Phase.DESCEND:
		_begin_descent()
	_age += delta
	match _phase:
		Phase.RISE:
			_rise(delta)
		Phase.AIM:
			_aim(delta)
		Phase.FLIGHT:
			_flight(delta)
		Phase.DESCEND:
			_descend(delta)


func request_fire() -> void:
	_fire_requested = _phase == Phase.AIM


func request_cancel(force: bool = false) -> void:
	_cancel_requested = force or _phase in [Phase.RISE, Phase.AIM]


func _rise(delta: float) -> void:
	var windup: float = maxf(_data.anticipation, 0.0)
	var elapsed: float = maxf(_age - windup, 0.0)
	var lift: float = clampf(elapsed / maxf(_data.rise_time, delta), 0.0, 1.0)
	var covered: float = 1.0 - pow(1.0 - lift, 2.3)
	_drive_to(_origin.y + _data.lift_height * covered, delta)
	_visual.lift(_player.global_position, _player.model.global_basis,
		clampf(_age / maxf(windup, delta), 0.0, 1.0), lift)
	if lift >= 1.0:
		_phase = Phase.AIM
		_age = 0.0
		_player.play_anim(Player.ANIM_FALL)


func _aim(delta: float) -> void:
	_drive_to(_origin.y + _data.lift_height, delta)
	if _cursor != _owner.get_cursor() or _fire_requested:
		_cursor = _owner.get_cursor()
		_aim_valid = _measure_target(_cursor)
		if _aim_valid:
			var facing: Vector3 = _impact - _origin
			facing.y = 0.0
			if not facing.is_zero_approx():
				_player.face_instantly(facing)
	_visual.aim(_player.global_position, _player.model.global_basis, _impact,
		_impact_normal, _data.radius, _aim_valid, _age, 1.0 - _age / maxf(_data.aim_time, delta))
	if _fire_requested:
		_fire_requested = false
		if _aim_valid:
			_fire()
			return
	if _age >= maxf(_data.aim_time, delta):
		_begin_descent()


func _fire() -> void:
	_phase = Phase.FLIGHT
	_age = 0.0
	_owner.spend_charge()
	_visual.release_shot(_player.global_position, _impact, _impact_normal, _data.radius, _data.flight_time)


func _flight(delta: float) -> void:
	_drive_to(_origin.y + _data.lift_height, delta)
	if _age < _data.flight_time:
		_visual.advance_flight(_data.flight_time - _age)
		return
	_apply_impact()
	_visual.burst(_impact, _impact_normal, _data.radius)
	_begin_descent()


func _begin_descent() -> void:
	_phase = Phase.DESCEND
	_age = 0.0
	_descent_from = maxf(_player.global_position.y - _origin.y, 0.0)
	if _owner.get_charge() != 0:
		_owner.spend_charge()
	_visual.begin_descent()


func _descend(delta: float) -> void:
	var progress: float = clampf(_age / maxf(_data.descent_time, delta), 0.0, 1.0)
	_drive_to(_origin.y + _descent_from * (1.0 - progress * progress), delta)
	if progress >= 1.0:
		# Chừa một nhịp vật lý để kiểm tra sàn thật khi bệ ở chỗ cất cánh đã rơi.
		_player.velocity.y = minf(_player.velocity.y, -0.25)
	_visual.descend(_player.global_position, _player.model.global_basis, progress)
	if _player.is_on_floor() and (progress > 0.3 or _descent_from <= 0.05):
		_did_land = true
		state_machine.transition_to(PlayerState.IDLE)
	elif progress >= 1.0 and _age > _data.descent_time + delta * 2.0:
		state_machine.transition_to(PlayerState.FALL)


func _drive_to(height: float, delta: float) -> void:
	var offset: Vector3 = Vector3(_origin.x, height, _origin.z) - _player.global_position
	_player.velocity = offset / maxf(delta, 0.001)


func _measure_target(cursor: Vector2) -> bool:
	var on_plane: Vector3 = _player.project_cursor_to_height(cursor, _origin.y)
	if not on_plane.is_finite():
		return false
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	_probe.from = on_plane + Vector3.UP * _data.floor_probe_above
	_probe.to = on_plane - Vector3.UP * _data.floor_probe_below
	var floor_hit: Dictionary = space.intersect_ray(_probe)
	if floor_hit.is_empty():
		return false
	var normal: Vector3 = floor_hit["normal"]
	if normal.y < 0.5:
		return false
	var point: Vector3 = floor_hit["position"]
	_probe.from = _player.global_position + Vector3.UP * 0.65
	_probe.to = point + normal * 0.07
	if not space.intersect_ray(_probe).is_empty():
		return false
	_impact = point
	_impact_normal = normal
	return true


func _apply_impact() -> void:
	_sphere.radius = maxf(_data.radius, 0.01)
	_blast.transform = Transform3D(Basis.IDENTITY, _impact)
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var touched: Dictionary[Character, bool] = {}
	for result: Dictionary in space.intersect_shape(_blast, 128):
		var hurtbox: HurtboxComponent = result["collider"] as HurtboxComponent
		var enemy: Character = hurtbox.owner as Character if hurtbox else null
		if enemy == null or touched.has(enemy):
			continue
		touched[enemy] = true
		var info: DamageInfo = DamageInfo.new(_data.damage, DamageInfo.Type.PHYSICAL, Vector3.ZERO, _player)
		info.set_contact(hurtbox.global_position, Vector3.DOWN)
		hurtbox.receive_hit(info)
