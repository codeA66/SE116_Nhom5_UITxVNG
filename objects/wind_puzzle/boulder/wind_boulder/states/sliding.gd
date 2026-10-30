extends WindBoulderState
## Trượt đều tới điểm dừng đã tính trước. Bị thổi lúc đang trượt thì bỏ qua (đi hết đường mới nhận lệnh mới).


func enter(_previous: StringName) -> void:
	boulder.notify_slide_started()


func physics_update(delta: float) -> void:
	var to := boulder.target - boulder.global_position
	var step := boulder.data.slide_speed * delta
	if to.length() <= step:
		boulder.global_position = boulder.target
		boulder.roll_visual(to.length())
		boulder.notify_slide_stopped()
		state_machine.transition_to(IDLE)
		return
	boulder.global_position += boulder.direction * step
	boulder.roll_visual(step)


## Trượt ngang qua ổ thì rơi vào ổ và dừng luôn
func on_seated(socket_position: Vector3) -> void:
	boulder.global_position = Vector3(socket_position.x, boulder.global_position.y, socket_position.z)
	boulder.notify_slide_stopped()
	state_machine.transition_to(SEATED)
