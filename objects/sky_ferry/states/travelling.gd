extends SkyFerryState
## Chở khách theo đường bay tới bến mới.


func enter(_previous: StringName) -> void:
	ferry.speed = 0.0
	ferry.follow(ferry.travel_route, 0.0)
	ferry.notify_departed()


func physics_update(delta: float) -> void:
	if ferry.fly(ferry.data.travel_speed, delta):
		state_machine.transition_to(ARRIVED)
