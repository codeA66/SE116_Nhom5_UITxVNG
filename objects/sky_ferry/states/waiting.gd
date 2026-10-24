extends SkyFerryState
## Đậu ở bến, mở khe bến, nhấp nhô chờ khách. Đứng vững trên boong đủ board_delay giây thì cất cánh.

var _board_time: float = 0.0


func enter(_previous: StringName) -> void:
	ferry.speed = 0.0
	ferry.follow(ferry.travel_route, 0.0)
	ferry.set_berth_open(true)
	_board_time = 0.0
	ferry.notify_docked()


func exit() -> void:
	ferry.set_berth_open(false)


func physics_update(delta: float) -> void:
	ferry.hover(delta)
	if ferry.has_grounded_passenger():
		_board_time += delta
		if _board_time >= ferry.data.board_delay:
			state_machine.transition_to(TRAVELLING)
	else:
		_board_time = 0.0
