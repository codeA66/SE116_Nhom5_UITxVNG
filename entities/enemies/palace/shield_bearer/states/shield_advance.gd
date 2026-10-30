extends ShieldBearerState
## Tiến chậm tới mục tiêu (thay Chase), dừng ở khoảng cách ưa thích. Khiên luôn giơ.
## Hết hồi chiêu và mục tiêu trong tầm thì đập khiên. Quay người chậm nên player vòng ra sườn / sau được.


func enter(_previous: StringName) -> void:
	enemy.play_anim(ANIM_WALK)


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	if enemy.should_give_up_chase():
		enemy.forget_target()
		state_machine.transition_to(PATROL)
		return
	if enemy.can_attack():
		state_machine.transition_to(enemy.attack_state)
		return
	var direction := enemy.direction_to_target()
	# Không dừng xa hơn tầm đánh, kẻo đứng yên mãi ngoài tầm (preferred_distance > attack_range)
	var stop_distance := minf(bearer.shield_data().preferred_distance, enemy.data.attack_range)
	if enemy.distance_to_target() <= stop_distance:
		enemy.move_toward_direction(Vector3.ZERO, delta)
		enemy.face_direction(direction, delta)
		return
	enemy.move_toward_direction(direction, delta)
