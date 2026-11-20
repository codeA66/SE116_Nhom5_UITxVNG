extends EnemyState
## Rình theo vòng cung, đổi nhịp chạy và chọn đòn theo góc tương đối với mục tiêu.

var _actor: FireSabretooth
var _decision: float
var _opening: float
var _direction: Vector3
var _speed: float
var _gait: StringName


func enter(previous: StringName) -> void:
	_actor = enemy as FireSabretooth
	_decision = 0.0
	_opening = 0.0 if previous == &"TigerManeuver" else randf_range(_actor.profile.circle_time.x, _actor.profile.circle_time.y) / _actor.pace()
	_direction = Vector3.ZERO
	_speed = 0.0
	_gait = &""


func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	if _actor.should_give_up_chase():
		_actor.forget_target()
		state_machine.transition_to(IDLE)
		return
	_opening -= delta
	_decision -= delta
	if _decision <= 0.0:
		_decision = _actor.profile.decision_interval
		if _decide():
			return
	_actor.walk(_direction, _speed, delta)
	# Khi quay lại mục tiêu trước đòn, dáng hổ hạ thấp và tốc độ giảm dần.
	if _opening <= 0.0 and _actor.distance_to_target() < _actor.profile.trot_distance:
		_actor.face_direction(_actor.direction_to_target(), delta)


func _decide() -> bool:
	var distance := _actor.distance_to_target()
	var toward := _actor.direction_to_target()
	var angle := _actor.target_angle()
	if _try_dodge(toward, distance):
		return true
	if _opening <= _actor.profile.decision_interval and absf(angle) > deg_to_rad(_actor.profile.turn_threshold) and _actor.velocity.length() < 2.6:
		var clip: StringName = &"TurnLeft" if angle > 0.0 else &"45TurnLeft"
		if absf(angle) > deg_to_rad(145.0):
			clip = &"Spin180" if distance < 5.0 else (&"Slow180" if angle > 0.0 else &"180RIght")
		_actor.start_maneuver(clip)
		return true
	if _opening <= 0.0 and absf(angle) < 1.12:
		var skill := _actor.choose_skill()
		if skill and _actor.clear_path(toward, minf(distance - 1.0, 2.8)):
			_actor.begin_skill(skill)
			return true
	_direction = toward
	_speed = _actor.profile.stalk_speed
	var clip: StringName = &"Stalker"
	if distance > _actor.profile.sprint_distance:
		_speed = _actor.movement.max_speed
		clip = &"Run"
	elif distance > _actor.profile.trot_distance:
		_speed = _actor.profile.trot_speed
		clip = &"Trot"
	elif _opening > 0.0 or _actor.attack_cooldown_remaining() > 0.0:
		var tangent := toward.rotated(Vector3.UP, PI * 0.5 * _actor.circle_side)
		var radial := clampf((distance - _actor.profile.circle_radius) * 0.45, -0.75, 0.75)
		_direction = (tangent * 0.8 + toward * radial).normalized()
		if not _actor.clear_path(_direction, 1.1):
			_actor.circle_side *= -1.0
			_direction = -tangent
	if not _actor.clear_path(_direction, 0.65):
		_direction = Vector3.ZERO
		_opening = minf(_opening, 0.10)
	if clip != _gait:
		_actor.motion.play(clip, _actor.profile.bridge_duration, true, true)
		_gait = clip
	return false


func _try_dodge(toward: Vector3, distance: float) -> bool:
	if _actor.dodge_left > 0.0 or distance > _actor.profile.dodge_range:
		return false
	var player := _actor.target as Player
	var threatened := _actor.threat_left > 0.0 or (player and player.hitbox.is_active())
	if not threatened:
		return false
	_actor.dodge_left = _actor.profile.dodge_cooldown
	if randf() > _actor.profile.dodge_chance:
		return false
	_actor.evasion_count += 1
	if _actor.evasion_count % 4 == 0 and _actor.clear_path(-toward, _actor.profile.dodge_distance):
		_actor.start_maneuver(&"180Flip", -toward, _actor.profile.dodge_distance)
		return true
	var direction := (-toward * 0.35 + toward.rotated(Vector3.UP, PI * 0.5)).normalized()
	if _actor.clear_path(direction, _actor.profile.dodge_distance):
		_actor.start_maneuver(&"StartLeft", direction, _actor.profile.dodge_distance)
		return true
	if _actor.clear_path(-toward, 1.1):
		_actor.start_maneuver(&"Backing", -toward, 0.9)
		return true
	_actor.start_maneuver(&"Cowering2" if _actor.health.current_health < _actor.health.max_health / 3 else &"PissedOff2")
	return true
