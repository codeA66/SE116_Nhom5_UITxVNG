extends StatueState
## Chờ: tắt tia. Thấy player (trong tầm, không bị tường che) thì sang ngắm.
## Không còn player trong vùng phát hiện thì tắt _physics_process của tượng tới khi có người vào lại.

@export var next_state: StringName = &"StatueAim"


func enter(_previous: StringName) -> void:
	statue.set_beam(LaserStatue.BeamMode.OFF)
	statue.hide_warning()
	statue.disable_damage()


func physics_update(_delta: float) -> void:
	if not statue.has_target():
		statue.set_physics_process(false)
		return
	if statue.can_see_target():
		state_machine.transition_to(next_state)
