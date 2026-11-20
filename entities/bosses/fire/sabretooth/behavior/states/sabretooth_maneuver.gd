extends EnemyState
## Hướng thật quay theo clip, bước né dùng va chạm và điểm đáp đã kiểm tra.

var _actor: FireSabretooth
var _yaw: float
var _duration: float
var _travelling: bool


func enter(_previous: StringName) -> void:
	_actor = enemy as FireSabretooth
	_yaw = _actor.model.rotation.y
	_duration = _actor.motion.play(_actor.maneuver_clip, _actor.profile.bridge_duration)
	_travelling = _actor.maneuver_distance > 0.0


func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	var time := _actor.motion.elapsed()
	_actor.set_body_yaw(_yaw + _actor.motion.yaw_at(time))
	var velocity := Vector3.ZERO
	if _travelling and time > 0.05 and time < _duration - _actor.profile.bridge_duration - 0.13:
		velocity = _actor.maneuver_direction * _actor.maneuver_distance / maxf(0.2, _duration - _actor.profile.bridge_duration - 0.18)
	_actor.velocity.x = velocity.x
	_actor.velocity.z = velocity.z
	if _actor.motion.finished():
		state_machine.transition_to(IDLE if _actor.should_give_up_chase() else _actor.chase_state)


func exit() -> void:
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
