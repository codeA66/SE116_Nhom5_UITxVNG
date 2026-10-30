extends ShieldBearerState
## Vừa chặn một đòn: khựng tại chỗ một lúc (khiên rung), bị đẩy lùi nhẹ rồi quay lại đuổi.
## Không đổi hướng trong lúc khựng, không phản đòn: đánh khiên không phạt thêm.

var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	enemy.play_action(ANIM_GUARD_BLOCK)


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_gravity(delta)
	# Hãm lực đẩy lùi do chặn đòn (bearer đã cộng vào velocity trước khi vào state)
	var horizontal := Vector3(enemy.velocity.x, 0.0, enemy.velocity.z).move_toward(Vector3.ZERO, enemy.data.knockback_friction * delta)
	enemy.velocity.x = horizontal.x
	enemy.velocity.z = horizontal.z
	if _elapsed >= bearer.shield_data().block_react_time:
		_leave_to_default()
