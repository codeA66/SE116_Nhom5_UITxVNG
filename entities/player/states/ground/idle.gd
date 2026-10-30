extends PlayerGroundState


func enter(_previous: StringName) -> void:
	player.play_anim(Player.ANIM_IDLE)


func _ground_update(_delta: float) -> void:
	if not player.get_move_direction().is_zero_approx():
		state_machine.transition_to(RUN)
