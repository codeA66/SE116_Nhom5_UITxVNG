extends SkyFerryState
## Chưa được gọi: ẩn ở đầu đường bay tới, không va chạm; khe bến đóng.


func enter(_previous: StringName) -> void:
	ferry.speed = 0.0
	ferry.follow(ferry.approach_route, 0.0)
	ferry.set_present(false)
	ferry.set_berth_open(false)


func on_called() -> void:
	state_machine.transition_to(APPROACHING)
