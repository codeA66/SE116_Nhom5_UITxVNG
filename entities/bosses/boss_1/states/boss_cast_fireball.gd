class_name BossCastFireball
extends BossState
## State tụ chưởng và phóng Cầu Lửa (Cast_Fireball).

@export var shoot_time: float = 1.45

var _timer: float = 0.0
var _fired: bool = false


func enter(_previous: StringName) -> void:
	_timer = 0.0
	_fired = false
	boss.play_anim(&"Cast_Fireball")
	boss.start_fireball_cooldown()


func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	boss.move_toward_direction(Vector3.ZERO, delta)
	
	_timer += delta
	
	# Trước khi phóng: quay theo người chơi
	if not _fired and is_instance_valid(boss.target_player):
		var to_player: Vector3 = boss.target_player.global_position - boss.global_position
		to_player.y = 0.0
		boss.face_direction(to_player.normalized(), delta)
	
	# Đúng thời điểm chưởng: phóng cầu lửa
	if _timer >= shoot_time and not _fired:
		_fired = true
		boss.spawn_fireball()
	
	if boss.is_anim_finished():
		state_machine.transition_to(&"Idle")
