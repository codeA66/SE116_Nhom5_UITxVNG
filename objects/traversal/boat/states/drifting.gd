extends BoatState
## Bị thổi từ bờ: buồm giương ngắn, trôi thêm một đoạn rồi dừng giữa đường.

var _distance_left: float = 0.0


func enter(_previous: StringName) -> void:
	_distance_left = boat.data.shore_push_distance
	boat.raise_sail()


func physics_update(delta: float) -> void:
	var data := boat.data
	# Chậm dần về cuối đoạn trôi
	var target := data.shore_push_speed * clampf(_distance_left / maxf(data.shore_push_distance * 0.5, 0.01), 0.2, 1.0)
	boat.speed = move_toward(boat.speed, target, data.acceleration * delta)
	var step := minf(boat.speed * delta, _distance_left)
	boat.advance(step)
	_distance_left -= step
	if boat.get_remaining_distance() <= 0.0:
		state_machine.transition_to(ARRIVED)
	elif _distance_left <= 0.0:
		boat.lower_sail()
		state_machine.transition_to(DOCKED)


## Đang trôi mà người trên thuyền thổi tiếp thì chạy hết tuyến
func on_tailwind(from_on_board: bool) -> void:
	if from_on_board:
		state_machine.transition_to(SAILING)
