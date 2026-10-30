extends WindBoulderState
## Đá đứng yên. Bị thổi thì tính điểm dừng rồi trượt.


func on_blown(dir: Vector3) -> void:
	if dir == Vector3.ZERO:
		return
	if boulder.plan_slide(dir):
		state_machine.transition_to(SLIDING)


func on_seated(socket_position: Vector3) -> void:
	boulder.global_position = Vector3(socket_position.x, boulder.global_position.y, socket_position.z)
	state_machine.transition_to(SEATED)
