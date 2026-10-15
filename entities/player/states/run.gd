extends PlayerGroundState


func enter(_previous: StringName) -> void:
	player.play_anim(Player.ANIM_RUN)


func _ground_update(_delta: float) -> void:
	if player.get_move_direction().is_zero_approx():
		state_machine.transition_to(IDLE)
