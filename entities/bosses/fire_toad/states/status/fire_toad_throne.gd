extends FireToadState
## Ngồi ngai ngoài sân (đánh theo hội): miễn sát thương, quay về phía sân, chờ court gọi engage().
## Cũng là chỗ về sau khi cúi chào (Bow).


func _run(_id: int) -> void:
	toad.seated = true
	toad.set_invulnerable(true)
	# Chỉ hiện trên ngai khi đã đấu xong và quay về cúi chào.
	toad.vfx.arrival.set_model_visible(toad.health.is_dead())
	toad.slam_indicator.hide_indicator()
	toad.trim_pools()
	if toad.throne:
		toad.global_position = toad.throne.global_position
		toad.reset_physics_interpolation()
	var to_arena := toad.home_point() - toad.global_position
	to_arena.y = 0.0
	if to_arena.length_squared() > 0.01:
		toad.face_instantly(to_arena.normalized())
	toad.play_clip(&"Idle", true)
