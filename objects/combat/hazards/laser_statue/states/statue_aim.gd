extends StatueState
## Ngắm: tâm đường tia bám theo chân player với tốc độ giới hạn (track_speed); đường cảnh báo cắt ngang qua player
## và tia mảnh từ mắt xuống tâm đường chạy theo. Hết aim_time thì khóa; mất dấu player thì về chờ.

@export var lock_state: StringName = &"StatueLock"
@export var idle_state: StringName = &"StatueIdle"

var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	statue.aim_point = statue.get_target_feet()
	statue.set_beam(LaserStatue.BeamMode.AIM)
	_refresh()
	statue.aim_started.emit()


func physics_update(delta: float) -> void:
	if not statue.can_see_target():
		state_machine.transition_to(idle_state)
		return
	statue.track_target(delta)
	_refresh()
	_elapsed += delta
	if _elapsed >= statue.data.aim_time:
		state_machine.transition_to(lock_state)


func _refresh() -> void:
	statue.show_warning(statue.data.warn_color)
	statue.aim_beam_at(statue.aim_point)
