extends State
## Chá»‰ khá»Ÿi hÃ nh khi cÃ¡o Ä‘á»©ng vá»¯ng trong vÃ¹ng giá»¯a bá»‡.
var lift: Node3D
func enter(_previous: StringName) -> void:
	lift = owner as Node3D
	lift.platform.position.y = 0.0
	lift.get_node("Platform/WindColumn").visible = false
	lift.set_gates(true, false)
	lift.set_physics_process(is_instance_valid(lift.candidate))
func physics_update(_delta: float) -> void:
	if not lift.required_flag.is_empty() and not GameState.has_flag(lift.required_flag):
		return
	var player := lift.candidate as Player
	if not is_instance_valid(player) or not player.controls_enabled or not player.is_on_floor():
		return
	var offset: Vector3 = player.global_position - lift.platform.global_position
	if Vector2(offset.x, offset.z).length() <= lift.boarding_radius and absf(offset.y) < 0.25:
		state_machine.transition_to(&"Rising")
