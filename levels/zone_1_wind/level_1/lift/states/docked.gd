extends State
var lift: Node3D
func enter(_previous: StringName) -> void:
	lift = owner as Node3D
	lift.set_gates(false, true)
	lift.notify_arrived()
func physics_update(_delta: float) -> void:
	var player := lift.rider as Player
	if not is_instance_valid(player):
		lift.release_trip()
		state_machine.transition_to(&"Returning")
		return
	var offset: Vector3 = player.global_position - lift.platform.global_position
	if player.is_on_floor() and Vector2(offset.x, offset.z).length() > lift.clear_radius:
		lift.release_trip()
		state_machine.transition_to(&"Returning")
