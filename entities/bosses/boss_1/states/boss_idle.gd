class_name BossIdle
extends BossState
## State nghỉ ngơi và quan sát của Boss. Quyết định đòn đánh tiếp theo.

@export var min_wait_time: float = 0.4
@export var max_wait_time: float = 0.8

var _wait_timer: float = 0.0


func enter(_previous: StringName) -> void:
	boss.play_anim(&"Idle")
	# Giảm dần thời gian nghỉ theo từng Phase để Boss ngày càng hung hãn
	if boss.current_phase == 3:
		_wait_timer = randf_range(0.1, 0.25)
	elif boss.current_phase == 2:
		_wait_timer = randf_range(0.2, 0.5)
	else:
		_wait_timer = randf_range(min_wait_time, max_wait_time)


func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	boss.move_toward_direction(Vector3.ZERO, delta)
	
	var player: Node3D = boss.target_player
	if not is_instance_valid(player):
		return
	
	# Luôn quay mặt nhẹ về phía player khi idle
	var to_player: Vector3 = player.global_position - boss.global_position
	to_player.y = 0.0
	boss.face_direction(to_player.normalized(), delta)
	
	_wait_timer -= delta
	if _wait_timer > 0.0:
		return
	
	var distance: float = to_player.length()
	
	# 1. Nếu đang có khiên bảo vệ, ưu tiên tung cầu lửa để thách thức player
	if boss.is_shielded and boss.can_cast_fireball():
		state_machine.transition_to(&"CastFireball")
		return
	
	# 2. Cận chiến nếu player đang ở gần
	if distance <= boss.data.melee_range and boss.can_melee():
		state_machine.transition_to(&"Melee")
		return
	
	# 3. Nhảy dậm đất nếu player ở cự ly trung bình/xa
	if distance >= boss.data.jump_slam_min_range and distance <= boss.data.jump_slam_max_range and boss.can_jump_slam():
		state_machine.transition_to(&"JumpSlam")
		return
	
	# 4. Tiếp cận người chơi
	state_machine.transition_to(&"Chase")
