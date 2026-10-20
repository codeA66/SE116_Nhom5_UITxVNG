extends WindLiftState
## Bệ nằm ở điểm dừng dưới, gió lặng. Trụ quạt đầy thì bắt đầu lên.


func enter(previous: StringName) -> void:
	lift.speed = 0.0
	lift.set_wind(0.0)
	lift.set_platform_height(lift.get_lower_y())
	lift.set_gates(true, false)
	if not previous.is_empty():
		lift.lowered.emit()


func on_charger_full() -> void:
	state_machine.transition_to(RISING)
