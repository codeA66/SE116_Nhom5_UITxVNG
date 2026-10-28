class_name BossJumpSlam
extends BossState
## Đòn nhảy vồ và dậm đất sinh sóng chấn diện rộng (Jump Attack).

@export var windup_time: float = 0.8
@export var impact_time: float = 1.75
@export var aoe_radius: float = 3.5

var _timer: float = 0.0
var _slammed: bool = false
var _jump_target: Vector3 = Vector3.ZERO
var _effective_windup: float = 0.8
var _effective_impact: float = 1.75


func enter(_previous: StringName) -> void:
	_timer = 0.0
	_slammed = false
	
	var anim_speed: float = boss.get_current_anim_speed()
	_effective_windup = windup_time / anim_speed
	_effective_impact = impact_time / anim_speed
	
	boss.play_action(&"Jump Attack", anim_speed)
	boss.start_jump_slam_cooldown()
	
	if is_instance_valid(boss.target_player):
		_jump_target = boss.target_player.global_position
	else:
		_jump_target = boss.global_position + boss.get_facing_direction() * 5.0
	
	# Bật vòng tròn chỉ thị cảnh báo AOE màu đỏ tại điểm rơi dự kiến
	boss.show_jump_indicator(_jump_target, aoe_radius, _effective_impact)


func exit() -> void:
	# Đảm bảo tắt vòng chỉ thị nếu bị ngắt chiêu đột ngột
	boss.hide_jump_indicator()


func physics_update(delta: float) -> void:
	_timer += delta
	
	# Pha 1: Lấy đà trên mặt đất (vòng cảnh báo đang nạp dần)
	if _timer < _effective_windup:
		boss.apply_gravity(delta)
		boss.move_toward_direction(Vector3.ZERO, delta)
		if is_instance_valid(boss.target_player):
			_jump_target = boss.target_player.global_position
			boss.show_jump_indicator(_jump_target, aoe_radius, _effective_impact)
			var to_player: Vector3 = _jump_target - boss.global_position
			to_player.y = 0.0
			boss.face_direction(to_player.normalized(), delta)
		return
	
	# Pha 2: Bay trên không về phía mục tiêu
	if _timer >= _effective_windup and _timer < _effective_impact:
		var flight_time: float = maxf(_effective_impact - _timer, 0.05)
		var to_target: Vector3 = _jump_target - boss.global_position
		to_target.y = 0.0
		var horizontal_vel: Vector3 = to_target / flight_time
		boss.velocity.x = horizontal_vel.x
		boss.velocity.z = horizontal_vel.z
		boss.velocity.y = 2.0 # Giữ bay nhẹ trên không
		boss.face_direction(to_target.normalized(), delta)
		return
	
	# Pha 3: Tiếp đất dậm mạnh
	if _timer >= _effective_impact and not _slammed:
		_slammed = true
		boss.velocity = Vector3.ZERO
		boss.hide_jump_indicator()
		boss.trigger_ground_slam()
	
	# Pha 4: Chờ phục hồi sau cú dậm
	boss.apply_gravity(delta)
	boss.move_toward_direction(Vector3.ZERO, delta)
	
	if boss.is_anim_finished():
		state_machine.transition_to(&"Idle")
