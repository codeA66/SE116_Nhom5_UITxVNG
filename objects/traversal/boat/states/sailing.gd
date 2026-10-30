extends BoatState
## Buồm giương, chạy hết tuyến tới bến cuối rồi cập bến.


func enter(_previous: StringName) -> void:
	boat.raise_sail()


func physics_update(delta: float) -> void:
	var data := boat.data
	var remaining := boat.get_remaining_distance()
	var target := data.sail_speed
	# Giảm tốc dần khi gần bến cuối để cập bến êm
	if remaining < data.arrive_distance:
		target = maxf(data.sail_speed * remaining / maxf(data.arrive_distance, 0.01), data.min_arrive_speed)
	boat.speed = move_toward(boat.speed, target, data.acceleration * delta)
	boat.advance(boat.speed * delta)
	if boat.get_remaining_distance() <= 0.0:
		state_machine.transition_to(ARRIVED)
