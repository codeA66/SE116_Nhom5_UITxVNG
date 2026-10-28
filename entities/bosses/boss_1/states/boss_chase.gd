class_name BossChase
extends BossState
## State di chuyển tiếp cận người chơi của Boss.

@export var max_chase_duration: float = 3.5

var _chase_timer: float = 0.0


func enter(_previous: StringName) -> void:
	boss.play_anim(&"Walk")
	_chase_timer = max_chase_duration


func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	
	var player: Node3D = boss.target_player
	if not is_instance_valid(player):
		state_machine.transition_to(&"Idle")
		return
	
	var to_player: Vector3 = player.global_position - boss.global_position
	to_player.y = 0.0
	var distance: float = to_player.length()
	var direction: Vector3 = to_player.normalized()
	
	# Cập nhật tốc độ di chuyển theo Phase
	var current_speed: float = boss.get_current_walk_speed()
	boss.movement.max_speed = current_speed
	boss.move_toward_direction(direction, delta)
	
	_chase_timer -= delta
	
	# Nếu đang có khiên bảo vệ, sẵn sàng tung cầu lửa
	if boss.is_shielded and boss.can_cast_fireball():
		state_machine.transition_to(&"CastFireball")
		return
	
	# Đã vào cự ly cận chiến
	if distance <= boss.data.melee_range and boss.can_melee():
		state_machine.transition_to(&"Melee")
		return
	
	# Ở tầm nhảy dậm đất
	if distance >= boss.data.jump_slam_min_range and distance <= boss.data.jump_slam_max_range and boss.can_jump_slam():
		state_machine.transition_to(&"JumpSlam")
		return
	
	# Hết thời gian rượt đuổi -> tạm dừng Idle đổi nhịp
	if _chase_timer <= 0.0:
		state_machine.transition_to(&"Idle")
