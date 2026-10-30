extends SkyFerryState
## Bay theo đường tới bến, chậm dần lúc cập.


func enter(_previous: StringName) -> void:
	ferry.speed = 0.0
	ferry.follow(ferry.approach_route, 0.0)
	ferry.set_present(true)
	ferry.notify_called()


func physics_update(delta: float) -> void:
	if ferry.fly(ferry.data.approach_speed, delta):
		state_machine.transition_to(WAITING)
