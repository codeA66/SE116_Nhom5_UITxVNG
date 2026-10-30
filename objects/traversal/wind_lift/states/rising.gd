extends WindLiftState
## Gió dưới đế mạnh dần; đủ mạnh (lift_threshold) thì bệ tăng tốc đi lên, gần tới đỉnh thì chậm lại.
## Đèn trụ tắt hết giữa chừng thì bệ sụp xuống.


func enter(_previous: StringName) -> void:
	lift.set_gates(false, false)


func physics_update(delta: float) -> void:
	var d := lift.data
	lift.set_wind(lift.wind + delta / maxf(d.wind_ramp_up_time, 0.001))
	if lift.wind < d.lift_threshold:
		return
	var remaining := lift.get_upper_y() - lift.get_platform_height()
	# Cập êm: giới hạn tốc độ theo quãng còn lại, không thấp hơn một chút để không đứng khựng trước đỉnh
	var cap := d.rise_max_speed * clampf(remaining / maxf(d.rise_arrive_distance, 0.001), 0.25, 1.0)
	lift.speed = minf(lift.speed + d.rise_acceleration * delta, cap)
	lift.set_platform_height(lift.get_platform_height() + lift.speed * delta)
	if lift.get_platform_height() >= lift.get_upper_y() - 0.001:
		state_machine.transition_to(RAISED)


func on_charger_discharged() -> void:
	state_machine.transition_to(FALLING)
