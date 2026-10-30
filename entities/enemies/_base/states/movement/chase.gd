extends EnemyState
## Đuổi theo mục tiêu. Vào tầm đánh và hết hồi chiêu thì ra đòn; mục tiêu ra quá xa hoặc bị kéo quá xa nhà thì bỏ đuổi.


func enter(_previous: StringName) -> void:
	enemy.play_anim(ANIM_RUN)


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	if enemy.should_give_up_chase():
		enemy.forget_target()
		state_machine.transition_to(PATROL)
		return
	if enemy.can_attack():
		state_machine.transition_to(enemy.attack_state)
		return
	# Trong tầm nhưng còn hồi chiêu: đứng lại, quay mặt về mục tiêu (khoảng hở cho player)
	if enemy.distance_to_target() <= enemy.data.attack_range:
		enemy.move_toward_direction(Vector3.ZERO, delta)
		enemy.face_direction(enemy.direction_to_target(), delta)
		return
	enemy.move_toward_direction(enemy.direction_to_target(), delta)
