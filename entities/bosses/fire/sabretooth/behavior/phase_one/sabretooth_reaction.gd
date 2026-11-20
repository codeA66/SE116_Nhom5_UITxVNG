extends EnemyState
## Một phản ứng mỗi nhịp, lùi lấy khoảng cách rồi báo đòn; không kéo dài timer khi trúng thêm.

var _actor: FireSabretooth
var _backing: bool
var _remaining: float
var _backward: Vector3


func enter(_previous: StringName) -> void:
	_actor = enemy as FireSabretooth
	_actor.phase_one_reaction_pending = false
	_actor.phase_one_reaction_used = true
	_actor.phase_one_prepared = false
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
	_backing = false
	var clips := _actor.profile.reaction_clips
	_actor.motion.play(clips[randi_range(0, clips.size() - 1)], _actor.profile.bridge_duration)


func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	if _actor.should_give_up_chase():
		state_machine.transition_to(IDLE)
		return
	if not _backing:
		if _actor.motion.finished():
			_backing = true
			_backward = -_actor.get_facing_direction()
			_remaining = _actor.profile.backup_distance / maxf(_actor.profile.backup_speed, 0.1)
			_actor.motion.play(&"BackUp", _actor.profile.bridge_duration, true)
			_actor.animation_player().speed_scale = _actor.profile.backup_playback
		return
	_remaining -= delta
	if _remaining > 0.0 and _actor.clear_path(_backward, 0.35):
		_actor.walk(_backward, _actor.profile.backup_speed, delta, true)
		return
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
	_actor.phase_one_wait = 0.0
	state_machine.transition_to(&"TigerPhaseOneWarning")
