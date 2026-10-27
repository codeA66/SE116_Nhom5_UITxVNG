extends EnemyState
## Không đuổi hoặc đánh trong khoảng hồi chung của khỉ, chỉ quay nhìn player.
var _actor: WildEnemy

func enter(_previous: StringName) -> void:
	_actor = enemy as WildEnemy
	_actor.play_anim(ANIM_IDLE)

func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	_actor.move_toward_direction(Vector3.ZERO, delta)
	if _actor.should_give_up_chase():
		_actor.forget_target(); state_machine.transition_to(PATROL); return
	_actor.face_direction(_actor.direction_to_target(), delta)
	if _actor.attack_cooldown_remaining() <= 0.0:
		state_machine.transition_to(_actor.chase_state)
