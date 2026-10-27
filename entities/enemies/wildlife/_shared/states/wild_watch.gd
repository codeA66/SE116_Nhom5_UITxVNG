extends EnemyState
## Hồi chiêu vẫn áp sát: đi chậm khi gần, chạy khi player đã xa.
var _actor: WildEnemy

func enter(_previous: StringName) -> void:
	_actor = enemy as WildEnemy
	_actor.play_anim(ANIM_IDLE)

func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	if _actor.should_give_up_chase():
		_actor.forget_target(); state_machine.transition_to(PATROL); return
	var distance: float = _actor.distance_to_target()
	var config: WildEnemyData = _actor.wildlife
	if config.advance_on_cooldown and distance > config.approach_stop_distance:
		var running: bool = distance > config.cooldown_run_distance
		_actor.play_anim(ANIM_RUN if running else ANIM_WALK)
		_actor.move_toward_direction(_actor.direction_to_target() * (1.0 if running else config.cooldown_walk_speed_scale), delta)
	else:
		_actor.play_anim(ANIM_IDLE)
		_actor.move_toward_direction(Vector3.ZERO, delta)
	_actor.face_direction(_actor.direction_to_target(), delta)
	if _actor.attack_cooldown_remaining() <= 0.0:
		state_machine.transition_to(_actor.chase_state)
