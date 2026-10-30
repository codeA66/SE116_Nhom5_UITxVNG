extends RedKeyDoorState

var _elapsed: float = 0.0

func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	door.begin_insert()
	door.set_physics_process(true)

func physics_update(delta: float) -> void:
	_elapsed += delta
	door.update_insert(clampf(_elapsed / door.insert_time, 0.0, 1.0))
	if _elapsed >= door.insert_time:
		state_machine.transition_to(&"Dissolving")
