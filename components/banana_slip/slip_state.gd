extends State
## FSM cũ tạm nhường quyền điều khiển: không dash, nhảy, đánh hoặc phanh trong lúc trượt.
var _actor: Character
var _forces_were_enabled: bool = true

func enter(_previous: StringName) -> void:
	_actor = owner as Character
	_forces_were_enabled = _actor.external_forces_enabled
	_actor.external_forces_enabled = false
	_actor.play_slip_animation()

func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	_actor.banana_slip.integrate(delta)

func exit() -> void:
	_actor.external_forces_enabled = _forces_were_enabled
	_actor.banana_slip.stop()
