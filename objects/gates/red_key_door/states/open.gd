extends RedKeyDoorState

func enter(_previous: StringName) -> void:
	door.finish_open(true)
