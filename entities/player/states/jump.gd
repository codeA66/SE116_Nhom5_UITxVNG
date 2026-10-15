extends PlayerState


func enter(_previous: StringName) -> void:
	player.jump()
	player.play_anim(Player.ANIM_JUMP)


func physics_update(delta: float) -> void:
	if Input.is_action_just_released("jump"):
		player.cut_jump()
	player.apply_gravity(delta)
	player.move_toward_direction(player.get_move_direction(), delta)

	if player.velocity.y <= 0.0:
		state_machine.transition_to(FALL)
