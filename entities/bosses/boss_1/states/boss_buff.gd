class_name BossBuff
extends BossState
## State gồng nộ và kích hoạt Khiên Bất Hoại ở mốc 50% và 20% HP.

func enter(_previous: StringName) -> void:
	boss.play_anim(&"Buff")
	boss.activate_invulnerable_shield()
	
	var shake: Node = boss.get_node_or_null(^"/root/ScreenShake")
	if shake and shake.has_method(&"add_trauma"):
		shake.add_trauma(0.4)


func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	boss.move_toward_direction(Vector3.ZERO, delta)
	
	if is_instance_valid(boss.target_player):
		var to_player: Vector3 = boss.target_player.global_position - boss.global_position
		to_player.y = 0.0
		boss.face_direction(to_player.normalized(), delta)
	
	if boss.is_anim_finished():
		# Sau khi gồng khiên, lập tức tụ cầu lửa tấn công
		state_machine.transition_to(&"CastFireball")
