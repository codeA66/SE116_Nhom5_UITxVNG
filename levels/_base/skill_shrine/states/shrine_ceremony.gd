extends SkillShrineState
## Đang nhận kỹ năng: chuyển quyền điều khiển cột gió cho các pha trình diễn.
## Chuỗi trình diễn tự lo tối màn và bảng; xong thì sang Spent.


func enter(_previous: StringName) -> void:
	shrine.set_rune_visible(false)
	if shrine.acquire_data.continuous_energy:
		shrine.set_lights(shrine.beam_ceremony_energy, shrine.glow_ceremony_energy, shrine.ceremony_light_time)
	else:
		shrine.set_presence(0.0, shrine.beam_approach_energy, shrine.glow_approach_energy, false, 0.4)
	_listen(shrine.ceremony_finished, _on_finished)


func exit() -> void:
	_unlisten(shrine.ceremony_finished, _on_finished)


func _on_finished() -> void:
	state_machine.transition_to(&"Spent")
