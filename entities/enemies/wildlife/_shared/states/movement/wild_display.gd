extends EnemyState
## Đầu đàn vỗ ngực/gầm một lần mỗi lần phát hiện, các grunt đã nhận tín hiệu tập hợp.
var _actor: WildEnemy
var _remaining: float = 0.0

func enter(_previous: StringName) -> void:
	_actor = enemy as WildEnemy
	_remaining = _actor.begin_alert()

func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	_actor.move_toward_direction(Vector3.ZERO, delta)
	if _actor.should_give_up_chase():
		_actor.forget_target(); state_machine.transition_to(PATROL); return
	_actor.face_direction(_actor.direction_to_target(), delta)
	_remaining -= delta
	if _remaining <= 0.0: state_machine.transition_to(_actor.chase_state)
