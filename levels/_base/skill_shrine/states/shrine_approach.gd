extends SkillShrineState
## Đến gần bệ: phòng tối dần quanh sách, cột năng lượng và đèn rọi mạnh lên, gió bụi trôi về bệ.
## Rời đi thì trả lại; nhặt sách thì sang Ceremony.


func enter(_previous: StringName) -> void:
	shrine.set_presence(shrine.approach_aura, shrine.beam_approach_energy, shrine.glow_approach_energy, true, shrine.approach_time)
	shrine.set_mood(shrine.approach_dim, 0.0, 0.0, shrine.approach_time)
	_listen(shrine.player_exited, _on_player_exited)
	_listen(shrine.ceremony_started, _on_ceremony_started)


func exit() -> void:
	_unlisten(shrine.player_exited, _on_player_exited)
	_unlisten(shrine.ceremony_started, _on_ceremony_started)


func _on_player_exited() -> void:
	state_machine.transition_to(&"Idle")


func _on_ceremony_started() -> void:
	state_machine.transition_to(&"Ceremony")
