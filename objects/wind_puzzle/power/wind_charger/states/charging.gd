extends ChargerState
## Đèn sáng lần lượt mỗi light_on_interval giây: cho người chơi thời gian bước lên bệ.

var _timer: float = 0.0


func enter(_previous: StringName) -> void:
	_timer = 0.0
	charger.set_rotor_power(1.0)


func physics_update(delta: float) -> void:
	_timer += delta
	if _timer < charger.data.light_on_interval:
		return
	_timer -= charger.data.light_on_interval
	charger.set_lit_count(charger.lit_count + 1)
	if charger.is_full():
		state_machine.transition_to(FULL)
