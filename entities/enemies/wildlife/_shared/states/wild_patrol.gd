extends EnemyState
## Đi tuần giới hạn quanh điểm spawn; có timeout để không kẹt mãi ở tường.
var _actor: WildEnemy
var _point: Vector3
var _elapsed: float = 0.0

func enter(previous: StringName) -> void:
	_actor = enemy as WildEnemy
	_elapsed = 0.0
	var radius: float = maxf(0.0, _actor.data.patrol_radius)
	if previous == _actor.chase_state or _actor.distance_from_home() > radius:
		_point = _actor.home_position
	else:
		var angle: float = randf() * TAU
		_point = _actor.home_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(radius * 0.3, radius)
	_actor.play_anim(ANIM_WALK)

func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	if _check_target(): return
	var offset: Vector3 = _point - _actor.global_position
	offset.y = 0.0
	_elapsed += delta
	if offset.length() < maxf(0.05, _actor.wildlife.patrol_arrive_distance) or _elapsed > maxf(0.1, _actor.wildlife.patrol_timeout):
		state_machine.transition_to(IDLE); return
	_actor.move_toward_direction(offset.normalized() * _actor.data.patrol_speed_scale, delta)
