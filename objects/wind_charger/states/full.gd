extends ChargerState
## Đủ đèn: báo fully_charged, giữ hold_time giây. Thổi thêm thì giữ lại từ đầu.

var _timer: float = 0.0


func enter(_previous: StringName) -> void:
	_timer = 0.0
	charger.notify_fully_charged()


func physics_update(delta: float) -> void:
	_timer += delta
	if _timer >= charger.data.hold_time:
		state_machine.transition_to(DRAINING)


func on_blown() -> void:
	_timer = 0.0
