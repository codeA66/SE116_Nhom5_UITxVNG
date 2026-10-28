extends EnemyState
## Hồi chiêu vẫn áp sát: đi chậm khi gần, chạy khi player đã xa.
var _actor: WildEnemy
var _approaching: bool = false
var _running: bool = false

func enter(_previous: StringName) -> void:
	_actor = enemy as WildEnemy
	_approaching = _actor.distance_to_target() > _actor.wildlife.approach_stop_distance
	_running = _actor.distance_to_target() > _actor.wildlife.cooldown_run_distance

func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	if _actor.should_give_up_chase():
		_actor.forget_target(); state_machine.transition_to(PATROL); return
	if _actor.attack_cooldown_remaining() <= 0.0:
		state_machine.transition_to(_actor.chase_state); return
	var distance: float = _actor.distance_to_target()
	var config: WildEnemyData = _actor.wildlife
	if _approaching and distance < config.approach_stop_distance: _approaching = false
	elif not _approaching and distance > config.approach_stop_distance + 0.25: _approaching = true
	if _running and distance < config.cooldown_run_distance - 0.4: _running = false
	elif not _running and distance > config.cooldown_run_distance + 0.4: _running = true
	if config.advance_on_cooldown and _approaching:
		_actor.play_anim(ANIM_RUN if _running else ANIM_WALK)
		_actor.move_toward_direction(_actor.direction_to_target() * (1.0 if _running else config.cooldown_walk_speed_scale), delta)
	else:
		_actor.play_anim(ANIM_IDLE)
		_actor.move_toward_direction(Vector3.ZERO, delta)
	_actor.face_direction(_actor.direction_to_target(), delta)
