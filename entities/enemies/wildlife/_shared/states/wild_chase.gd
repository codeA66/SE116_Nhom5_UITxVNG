extends EnemyState
## FSM gốc gọi state này thay Chase; khoảng hồi chiêu áp sát do Watch điều khiển.
var _actor: WildEnemy

func enter(_previous: StringName) -> void:
	_actor = enemy as WildEnemy
	# Decide the next clip in physics_update; a skill may begin immediately.

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
		var approaching: bool = _actor.distance_to_target() > _actor.wildlife.approach_stop_distance
		_actor.move_toward_direction(_actor.direction_to_target() * _actor.wildlife.cooldown_walk_speed_scale if approaching else Vector3.ZERO, delta)
		_actor.face_direction(_actor.direction_to_target(), delta)
		_actor.play_anim(ANIM_WALK if approaching else ANIM_IDLE)
	else:
		_actor.play_anim(ANIM_RUN)
		_actor.move_toward_direction(_actor.direction_to_target(), delta)
