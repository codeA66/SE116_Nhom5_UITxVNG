extends WindLiftState
## Gió tắt: bệ rơi tự do (có giới hạn tốc độ) về điểm dừng dưới, chạm đáy thì rung nhẹ.
## Trụ quạt nạp đầy lại giữa chừng thì gió đẩy bệ lên tiếp.


func enter(_previous: StringName) -> void:
	lift.set_wind(0.0)
	lift.set_gates(false, false)


func physics_update(delta: float) -> void:
	var d := lift.data
	lift.speed = maxf(lift.speed - d.fall_gravity * delta, -d.fall_max_speed)
	lift.set_platform_height(lift.get_platform_height() + lift.speed * delta)
	if lift.get_platform_height() <= lift.get_lower_y() + 0.001:
		if d.landing_trauma > 0.0:
			ScreenShake.add_trauma(d.landing_trauma)
		state_machine.transition_to(LOWERED)


func on_charger_full() -> void:
	lift.speed = 0.0
	state_machine.transition_to(RISING)
