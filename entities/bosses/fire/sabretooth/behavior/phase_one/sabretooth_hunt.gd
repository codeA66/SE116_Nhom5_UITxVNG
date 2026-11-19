extends EnemyState
## Đồng hồ chung cho nhịp xoay và áp sát; hết giờ vẫn đuổi nếu chưa có đòn đủ tầm.

var _actor: FireSabretooth
var _gait: StringName
var _decision: float
var _direction: Vector3
var _speed: float


func enter(_previous: StringName) -> void:
	_actor = enemy as FireSabretooth
	_gait = &""
	_decision = 0.0
	_direction = Vector3.ZERO
	_speed = 0.0


func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	if _actor.should_give_up_chase():
		_actor.forget_target()
		state_machine.transition_to(IDLE)
		return
	if _actor.phase_one_turn_pending:
		state_machine.transition_to(&"TigerPhaseOneTurn")
		return
	if _actor.phase_one_reaction_pending:
		state_machine.transition_to(&"TigerPhaseOneReaction")
		return
	if _actor.phase_one_prepared and _actor.phase_one_can_prepare():
		var skill := _actor.select_phase_one_skill()
		if skill:
			_actor.phase_one_prepared = false
			_actor.begin_skill(skill)
			return
	if not _actor.phase_one_prepared and _actor.phase_one_wait <= 0.0 and _actor.phase_one_can_prepare():
		_actor.velocity.x = 0.0
		_actor.velocity.z = 0.0
		state_machine.transition_to(&"TigerPhaseOneWarning")
		return
	_decision -= delta
	if _decision <= 0.0:
		_decision = _actor.profile.decision_interval
		var distance := _actor.distance_to_target()
		_speed = _actor.profile.stalk_speed
		var clip: StringName = &"Stalker"
		var run_limit := _actor.profile.run_distance + (-_actor.profile.gait_hysteresis if _gait == &"Run" else _actor.profile.gait_hysteresis)
		if distance > run_limit:
			_speed = _actor.movement.max_speed
			clip = &"Run"
		elif distance <= _actor.profile.stalk_stop_distance:
			_speed = 0.0
			clip = &"Growling"
		if not _actor.clear_path(_direction, 0.35):
			_speed = 0.0
		if clip != _gait:
			_actor.motion.play(clip, _actor.profile.bridge_duration, true, clip != &"Growling")
			_gait = clip
	_direction = _actor.direction_to_target()
	_actor.walk(_direction if _speed > 0.0 else Vector3.ZERO, _speed, delta)
	if _speed <= 0.0:
		_actor.face_direction(_actor.direction_to_target(), delta)
