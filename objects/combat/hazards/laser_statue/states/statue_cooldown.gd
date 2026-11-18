extends StatueState
## Nghỉ sau phát bắn: tắt tia, hết cooldown_time thì về chờ (chờ tự quyết ngắm tiếp hay tắt xử lý).

@export var idle_state: StringName = &"StatueIdle"

var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	statue.set_beam(LaserStatue.BeamMode.OFF)


func physics_update(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= statue.data.cooldown_time:
		state_machine.transition_to(idle_state)
