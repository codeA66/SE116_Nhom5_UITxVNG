class_name BossIdle
extends BossState
## State nghỉ ngơi và quan sát của Boss. Quyết định đòn đánh tiếp theo.

@export_group("Timing")
@export var min_wait_time: float = 0.4
@export var max_wait_time: float = 0.8

@export_group("Turn In Place")
## Góc lệch tối thiểu (độ) giữa hướng nhìn và Player để Boss bước chân xoay người
@export var turn_threshold_degrees: float = 35.0
## Góc lệch (độ) khi đã đối diện Player để dừng bước và chuyển mượt về Idle
@export var turn_aligned_degrees: float = 12.0

var _wait_timer: float = 0.0
var _is_turning: bool = false


func enter(_previous: StringName) -> void:
	_is_turning = false
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
	
	# Luôn quay mặt về phía player khi idle; bước chân nếu góc lệch lớn để không bị trượt đơ
	var to_player: Vector3 = player.global_position - boss.global_position
	to_player.y = 0.0
	if not to_player.is_zero_approx():
		var target_angle := atan2(to_player.x, to_player.z)
		var angle_diff := absf(wrapf(target_angle - boss.model.rotation.y, -PI, PI))
		
		if not _is_turning and angle_diff > deg_to_rad(turn_threshold_degrees):
			_is_turning = true
			boss.play_anim(&"Walk")
		elif _is_turning and angle_diff <= deg_to_rad(turn_aligned_degrees):
			_is_turning = false
			boss.play_anim(&"Idle")
		
		boss.face_direction(to_player.normalized(), delta)
	
	_wait_timer -= delta
	if _wait_timer > 0.0:
		return
	
	
	if boss.action_selector.try_select():
		return
	
	# 5. Tiếp cận người chơi
	state_machine.transition_to(&"Chase")
