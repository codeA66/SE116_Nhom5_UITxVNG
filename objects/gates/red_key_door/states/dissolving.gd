extends RedKeyDoorState

var _elapsed: float = 0.0

func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	door.begin_dissolve()

func physics_update(delta: float) -> void:
	_elapsed += delta
	door.update_dissolve(clampf(_elapsed / door.dissolve_time, 0.0, 1.0))
	if _elapsed >= door.dissolve_time:
		state_machine.transition_to(&"Open")
