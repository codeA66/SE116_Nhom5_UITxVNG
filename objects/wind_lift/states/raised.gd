extends WindLiftState
## Bệ ở trên. Gió đi theo số đèn còn sáng của trụ: đèn tắt dần thì gió yếu dần.
## Đèn tắt hết thì bệ sụp xuống.


func enter(_previous: StringName) -> void:
	lift.speed = 0.0
	lift.set_platform_height(lift.get_upper_y())
	lift.set_gates(false, true)
	lift.raised.emit()


func physics_update(delta: float) -> void:
	var target := lift.get_charger_level()
	var rate := delta / maxf(lift.data.wind_follow_time, 0.001)
	lift.set_wind(move_toward(lift.wind, target, rate))


func on_charger_discharged() -> void:
	state_machine.transition_to(FALLING)
