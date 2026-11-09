extends SkillShrineState
## Chờ: cột năng lượng sáng vừa, phòng bình thường. Đã học rồi (nạp save) thì về Dormant ngay.


func enter(_previous: StringName) -> void:
	if shrine.is_learned():
		state_machine.transition_to(&"Dormant")
		return
	shrine.set_presence(shrine.idle_aura, shrine.beam_idle_energy, shrine.glow_idle_energy, false, shrine.approach_time)
	shrine.set_rune_visible(true)
	shrine.set_mood(0.0, 0.0, 0.0, shrine.approach_time)
	_listen(shrine.player_entered, _on_player_entered)


func exit() -> void:
	_unlisten(shrine.player_entered, _on_player_entered)


func _on_player_entered(_player: Player) -> void:
	state_machine.transition_to(&"Approach")
