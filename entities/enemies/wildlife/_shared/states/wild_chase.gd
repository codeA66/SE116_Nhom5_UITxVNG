extends EnemyState
## FSM gốc gọi state này thay Chase; khoảng hồi chiêu là một state đứng xoay riêng.
var _actor: WildEnemy

func enter(_previous: StringName) -> void:
	_actor = enemy as WildEnemy
	_actor.play_anim(ANIM_RUN)

func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	if _actor.should_give_up_chase():
		_actor.forget_target(); state_machine.transition_to(PATROL); return
	if _actor.alert_pending():
		state_machine.transition_to(&"Display"); return
	if _actor.attack_cooldown_remaining() > 0.0:
		state_machine.transition_to(&"Watch"); return
	var skill: EnemySkillData = _actor.choose_skill()
	if skill != null:
		_actor.begin_skill(skill); return
	if _actor.distance_to_target() <= _actor.data.attack_range:
		_actor.move_toward_direction(Vector3.ZERO, delta)
		_actor.face_direction(_actor.direction_to_target(), delta)
		_actor.play_anim(ANIM_IDLE)
	else:
		_actor.play_anim(ANIM_RUN)
		_actor.move_toward_direction(_actor.direction_to_target(), delta)
