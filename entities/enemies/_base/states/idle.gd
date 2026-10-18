extends EnemyState
## Đứng chờ một lúc rồi đi tuần (nếu có bán kính tuần). Thấy mục tiêu thì đuổi.

var _wait_left: float = 0.0


func enter(_previous: StringName) -> void:
	_wait_left = randf_range(enemy.data.patrol_wait_min, enemy.data.patrol_wait_max)
	enemy.play_anim(ANIM_IDLE)


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.move_toward_direction(Vector3.ZERO, delta)
	if _check_target():
		return
	_wait_left -= delta
	if _wait_left <= 0.0 and enemy.data.patrol_radius > 0.0:
		state_machine.transition_to(PATROL)
