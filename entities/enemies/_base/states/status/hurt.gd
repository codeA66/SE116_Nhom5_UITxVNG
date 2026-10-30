extends EnemyState
## Trúng đòn: khựng một lúc, bị đẩy lùi, ngắt đòn đang ra. Hết khựng thì đuổi tiếp.

var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	var knockback := enemy.last_hit.knockback if enemy.last_hit else Vector3.ZERO
	enemy.velocity.x = knockback.x
	enemy.velocity.z = knockback.z
	if not knockback.is_zero_approx():
		enemy.face_instantly(-knockback)
	enemy.play_action(ANIM_HURT)


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_gravity(delta)
	var horizontal := Vector3(enemy.velocity.x, 0.0, enemy.velocity.z).move_toward(Vector3.ZERO, enemy.data.knockback_friction * delta)
	enemy.velocity.x = horizontal.x
	enemy.velocity.z = horizontal.z
	if _elapsed >= enemy.data.stun_time:
		state_machine.transition_to(enemy.chase_state if enemy.has_target() else IDLE)
