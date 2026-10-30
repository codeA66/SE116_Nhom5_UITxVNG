extends EnemyState
## Bị cú thổi trúng: mất kiểm soát, trôi theo lực đẩy (WindReceiver lo phần trôi), không tự đi.
## Hết lực đẩy thì quay lại đuổi. Nhờ vậy thổi được quái xuống vực / vào gai (môi trường là vũ khí).


func enter(_previous: StringName) -> void:
	enemy.hitbox.deactivate()
	enemy.set_telegraph(false)
	enemy.play_action(ANIM_HURT)


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	# Thả vận tốc tự đi về 0 (không chống lại gió)
	var horizontal := Vector3(enemy.velocity.x, 0.0, enemy.velocity.z).move_toward(Vector3.ZERO, enemy.data.knockback_friction * delta)
	enemy.velocity.x = horizontal.x
	enemy.velocity.z = horizontal.z
	if not enemy.wind_receiver.is_being_pushed():
		state_machine.transition_to(enemy.chase_state if enemy.has_target() else IDLE)
