extends State
var lift: Node3D
var _from: float = 0.0
func enter(_previous: StringName) -> void:
	lift = owner as Node3D
	_from = lift.platform.position.y
	lift.elapsed = 0.0
	lift.set_gates(false, false)
	lift.set_physics_process(true)
func physics_update(delta: float) -> void:
	lift.elapsed += delta
	var t: float = clampf(lift.elapsed / maxf(lift.return_time, 0.1), 0.0, 1.0)
	lift.platform.position.y = _from * (1.0 - smoothstep(0.0, 1.0, t))
	if t >= 1.0:
		state_machine.transition_to(&"Idle")
