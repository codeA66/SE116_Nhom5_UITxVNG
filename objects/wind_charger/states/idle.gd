extends ChargerState
## Tắt hết đèn, cánh quạt dừng. Thổi trúng thì bắt đầu nạp.


func enter(_previous: StringName) -> void:
	charger.set_lit_count(0)
	charger.set_rotor_power(0.0)


func on_blown() -> void:
	state_machine.transition_to(CHARGING)
