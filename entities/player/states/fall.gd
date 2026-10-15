extends PlayerState


func enter(_previous: StringName) -> void:
	player.play_anim(Player.ANIM_FALL)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_toward_direction(player.get_move_direction(), delta)

	# Vừa rời mép mà còn coyote time thì vẫn được nhảy
	if player.can_jump():
		state_machine.transition_to(JUMP)
	elif player.is_on_floor():
		var moving := not player.get_move_direction().is_zero_approx()
		state_machine.transition_to(RUN if moving else IDLE)
