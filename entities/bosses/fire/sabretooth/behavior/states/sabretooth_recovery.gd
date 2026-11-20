extends EnemyState
## Nhịp hồi ngắn ở dáng chờ, không chèn thêm động tác trông như một đòn khác.

var _actor: FireSabretooth
var _remaining: float
var _done: bool


func enter(_previous: StringName) -> void:
	_actor = enemy as FireSabretooth
	_done = false
	_actor.hitbox.deactivate()
	var skill := _actor.recovering_skill
	var phase_one := _actor.is_phase_one() and not _actor.manual_skill
	var bridge := _actor.profile.ready_bridge if phase_one else _actor.profile.bridge_duration
	_actor.motion.play(&"Growling", bridge, true)
	_remaining = bridge if phase_one else maxf(skill.recovery_time, bridge)


func exit() -> void:
	if not _done:
		_actor.finish_attack(false)


func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	_remaining -= delta
	_actor.walk(Vector3.ZERO, 0.0, delta)
	if _remaining > 0.0:
		return
	_done = true
	var manual := _actor.manual_skill
	_actor.circle_side *= -1.0
	state_machine.transition_to(IDLE if manual or _actor.should_give_up_chase() else _actor.chase_state)
	_actor.finish_attack(true)
