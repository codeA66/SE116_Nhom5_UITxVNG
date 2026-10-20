extends ChargerState
## Đèn tắt dần mỗi light_off_interval giây, cánh quạt chậm lại theo. Tắt hết thì báo discharged.
## Thổi trúng lúc đang tắt thì nạp tiếp từ số đèn còn sáng.

var _timer: float = 0.0


func enter(_previous: StringName) -> void:
	_timer = 0.0


func physics_update(delta: float) -> void:
	_timer += delta
	if _timer < charger.data.light_off_interval:
		return
	_timer -= charger.data.light_off_interval
	charger.set_lit_count(charger.lit_count - 1)
	charger.set_rotor_power(charger.get_level())
	if charger.lit_count == 0:
		charger.discharged.emit()
		state_machine.transition_to(IDLE)


func on_blown() -> void:
	state_machine.transition_to(CHARGING)
