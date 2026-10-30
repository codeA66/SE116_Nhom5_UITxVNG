extends VaneBridgeState
## Cầu đứng yên. Thổi trúng chong chóng thì xoay thêm một bước.


func on_blown() -> void:
	bridge.target_degrees = bridge.angle_degrees + bridge.data.step_degrees
	state_machine.transition_to(TURNING)
