extends FireToadState
## Phase 2: bay lên trên giữa sân, liên tục thả cầu lửa rơi vào chỗ player trong hover_duration rồi hạ xuống.
## Lúc bay miễn sát thương hoàn toàn (kể cả tên): player chỉ né, chờ boss đáp xuống.


func _run(id: int) -> void:
	var data := toad.data
	var ground := toad.home_point()
	toad.set_invulnerable(true)
	toad.play_clip(&"Hover_Start")
	toad.vfx.begin_hover()
	await toad.fly_to(ground + Vector3.UP * data.hover_height, data.hover_rise_time)
	toad.play_clip(&"Hover", true)
	var elapsed := 0.0
	var drop_clock := 0.0
	while elapsed < data.hover_duration:
		if not still_running(id):
			return
		toad.face_player()
		await toad.get_tree().physics_frame
		var delta := toad.get_physics_process_delta_time()
		elapsed += delta
		drop_clock += delta
		if drop_clock >= data.hover_drop_interval:
			drop_clock = 0.0
			var skills := toad.skills()
			toad.drop_fireball(toad.clamp_to_arena(toad.player_position()), skills.rain_warn_time, skills.rain_radius)
	if not still_running(id):
		return
	toad.play_clip(&"Hover_End")
	await toad.fly_to(ground, data.hover_rise_time)
	if still_running(id):
		toad.vfx.end_hover(ground)
	ScreenShake.add_trauma(0.3)
	toad.set_invulnerable(false)
	finish(id)


## Bị chuyển state giữa lúc bay (chết...) cũng bỏ miễn sát thương
func exit() -> void:
	super()
	toad.set_invulnerable(false)
