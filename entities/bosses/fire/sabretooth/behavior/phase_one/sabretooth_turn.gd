extends EnemyState
## Chơi clip quay theo góc phù hợp trước khi cho phép bước áp sát hoặc phản ứng trúng đòn.

var _actor: FireSabretooth
var _yaw: float
var _angle: float
var _short: float


func enter(_previous: StringName) -> void:
	_actor = enemy as FireSabretooth
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
	_yaw = _actor.model.rotation.y
	_short = 0.0
	var angle := _actor.target_angle()
	var clip := _actor.pick_turn_clip(angle)
	if absf(angle) <= deg_to_rad(_actor.profile.turn_snap_angle) or clip.is_empty():
		_short = _actor.profile.ready_bridge
		_actor.motion.play(&"Growling", _short, true)
		return
	_angle = angle
	_actor.motion.play(clip, _actor.profile.bridge_duration)


func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	if _actor.should_give_up_chase():
		state_machine.transition_to(IDLE)
		return
	if _short > 0.0:
		_short = maxf(0.0, _short - delta)
		if _short > 0.0:
			return
	else:
		var progress := _actor.motion.elapsed() / maxf(_actor.motion.content_length(), 0.001)
		_actor.set_body_yaw(_yaw + _angle * smoothstep(0.0, 1.0, progress))
		if not _actor.motion.finished():
			return
	_actor.phase_one_turn_pending = false
	state_machine.transition_to(_actor.chase_state)
