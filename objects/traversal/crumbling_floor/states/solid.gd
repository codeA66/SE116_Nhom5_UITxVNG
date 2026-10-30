extends CrumblingFloorState
## Ô lành, đứng được. Bước lên thì bắt đầu nứt.


func enter(previous: StringName) -> void:
	floor_tile.set_solid(true)
	floor_tile.set_visual_offset(Vector3.ZERO)
	if not previous.is_empty():
		floor_tile.notify_restored()


func on_stepped() -> void:
	state_machine.transition_to(CRACKING)
