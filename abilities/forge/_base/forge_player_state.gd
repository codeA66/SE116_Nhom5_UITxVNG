class_name ForgePlayerState
extends PlayerState
## State của kỹ năng lò rèn: được ForgeSkillInstaller tạo lúc chạy nên owner không phải Player
## (PlayerState gốc lấy player từ owner). Ở đây lấy player qua owner của StateMachine cha.


func _ready() -> void:
	var machine := get_parent()
	player = (machine.owner if machine else null) as Player
	assert(player != null, "ForgePlayerState phải nằm dưới StateMachine của Player")


## Hết chiêu: về Fall / Idle / Run theo tình trạng hiện tại
func finish() -> void:
	if not player.is_on_floor():
		state_machine.transition_to(FALL)
	elif player.get_move_direction().is_zero_approx():
		state_machine.transition_to(IDLE)
	else:
		state_machine.transition_to(RUN)


## Hướng ra chiêu: chuột (có chuột) -> phím di chuyển -> hướng đang nhìn
func get_cast_direction() -> Vector3:
	var aim := player.get_mouse_aim_direction()
	if not aim.is_zero_approx():
		return aim.normalized()
	var input_direction := player.get_move_direction()
	if not input_direction.is_zero_approx():
		return input_direction.normalized()
	return player.get_facing_direction()
