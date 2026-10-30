extends PlayerState
## Bị đánh: choáng ngắn, bị đẩy lùi, không điều khiển được. Bất tử do HurtboxComponent lo.
## Input bấm trong lúc choáng vẫn nằm trong buffer, hết choáng là ra đòn / nhảy ngay.

@export var stun_time: float = 0.3
## Độ hãm knockback (m/s mỗi giây)
@export var knockback_friction: float = 30.0

var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	var knockback := player.last_hit.knockback if player.last_hit else Vector3.ZERO
	player.velocity.x = knockback.x
	player.velocity.z = knockback.z
	# Quay mặt về phía bị đánh tới
	player.face_instantly(-knockback)
	player.play_action(Player.ANIM_HURT)


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z).move_toward(Vector3.ZERO, knockback_friction * delta)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z

	if _elapsed < stun_time:
		return
	if not player.is_on_floor():
		state_machine.transition_to(FALL)
	elif player.get_move_direction().is_zero_approx():
		state_machine.transition_to(IDLE)
	else:
		state_machine.transition_to(RUN)
