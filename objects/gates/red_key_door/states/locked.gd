extends RedKeyDoorState

func enter(_previous: StringName) -> void:
	door.set_physics_process(false)
	if door.was_opened():
		door.finish_open(false)
	else:
		door.interaction.enabled = true

func interact() -> void:
	if door.is_open:
		return
	if not door.has_key():
		door.deny()
		return
	state_machine.transition_to(&"Inserting")
