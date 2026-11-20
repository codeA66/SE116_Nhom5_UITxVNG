extends EnemyState

var _bird: Pyralon
var _rest: float


func enter(_previous: StringName) -> void:
	_bird = enemy as Pyralon
	_rest = _bird.profile.chase_pause


func physics_update(delta: float) -> void:
	if not _bird.is_previewing():
		_bird.reacquire_target()
	if not _bird.has_target():
		state_machine.transition_to(IDLE)
		return
	_rest = maxf(0.0, _rest - delta)
	if _rest <= 0.0 and _bird.try_next_move():
		return
	_bird.apply_gravity(delta)
	if _bird.is_previewing() or _bird.distance_to_target() <= _bird.wildlife.approach_stop_distance:
		_bird.move_toward_direction(Vector3.ZERO, delta)
		_bird.play_anim(ANIM_IDLE)
	else:
		var direction := (_bird.target.global_position - _bird.global_position).slide(Vector3.UP).normalized()
		_bird.move_toward_direction(direction, delta)
		_bird.play_anim(ANIM_RUN)
