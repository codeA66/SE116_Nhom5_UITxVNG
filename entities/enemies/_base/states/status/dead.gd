extends EnemyState
## Chết: tắt đòn đánh, nhận đòn, chịu gió và va chạm với player; nằm lại một lúc rồi biến mất.


var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	enemy.forget_target()
	enemy.set_telegraph(false)
	enemy.hitbox.deactivate()
	enemy.hurtbox.set_deferred(&"monitorable", false)
	enemy.sensor.set_deferred(&"monitoring", false)
	if enemy.wind_receiver:
		enemy.wind_receiver.enabled = false
	# Không chặn đường player nữa, nhưng vẫn đứng trên sàn
	enemy.set_deferred(&"collision_layer", 0)
	enemy.play_action(ANIM_DEATH)


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_gravity(delta)
	enemy.move_toward_direction(Vector3.ZERO, delta)
	if _elapsed >= enemy.data.corpse_time:
		enemy.queue_free()
