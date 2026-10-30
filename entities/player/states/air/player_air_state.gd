class_name PlayerAirState
extends PlayerState
## Cơ sở cho các state trên không (Jump, Fall).
## Gom các chuyển state chung ở một chỗ: thêm hành động trên không mới chỉ sửa file này.


func physics_update(delta: float) -> void:
	if not _try_common_transitions():
		_air_update(delta)


## State con ghi đè: trọng lực, điều khiển trên không, chuyển giữa Jump/Fall/tiếp đất
func _air_update(_delta: float) -> void:
	pass


## Trả về true nếu đã chuyển state, state con không xử lý tiếp
func _try_common_transitions() -> bool:
	if player.can_dash():
		state_machine.transition_to(DASH)
		return true
	var skill := player.get_ready_skill()
	if skill:
		state_machine.transition_to(skill.state)
		return true
	return false
