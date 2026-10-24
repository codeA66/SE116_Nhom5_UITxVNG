extends State
var lift: Node3D
func enter(_previous: StringName) -> void:
	lift = owner as Node3D
	lift.set_gates(false, false)
	lift.begin_trip()
func physics_update(delta: float) -> void:
	lift.elapsed += delta
	var t: float = clampf(lift.elapsed / maxf(lift.rise_time, 0.1), 0.0, 1.0)
	lift.platform.position.y = lift.travel_height * smoothstep(0.0, 1.0, t)
	if t >= 1.0 and lift.cinematic_finished:
		state_machine.transition_to(&"Docked")
