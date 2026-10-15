class_name PlayerGroundState
extends PlayerState
## Cơ sở cho các state đứng trên đất (Idle, Run).
## Gom các chuyển state chung ở một chỗ: thêm hành động mới (Dash...) chỉ sửa file này.


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_toward_direction(player.get_move_direction(), delta)
	if not _try_common_transitions():
		_ground_update(delta)


## State con ghi đè: chuyển qua lại giữa các state trên đất
func _ground_update(_delta: float) -> void:
	pass


## Trả về true nếu đã chuyển state, state con không xử lý tiếp
func _try_common_transitions() -> bool:
	if Input.is_action_just_pressed("interact") and player.interactor.try_interact():
		return true
	if player.can_attack():
		state_machine.transition_to(ATTACK)
		return true
	if player.can_jump():
		state_machine.transition_to(JUMP)
		return true
	if not player.is_on_floor():
		state_machine.transition_to(FALL)
		return true
	return false
