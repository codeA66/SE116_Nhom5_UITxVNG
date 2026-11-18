extends FireToadState
## Skill 3, Dậm Dung Nham: nhảy lên rồi đáp xuống chỗ player đứng lúc bật nhảy, tạo vũng dung nham đốt player.
## Vòng báo chỗ đáp hiện suốt lúc bay. Dậm slam_count lần rồi nhảy về giữa sân (không tạo dung nham).
## Cuồng loạn: dậm nhiều lần hơn, vũng to và lâu hơn.

## Nghỉ sau mỗi lần đáp (s)
@export_range(0.0, 3.0, 0.05) var land_recover: float = 0.45
@export_range(0.0, 1.0, 0.01) var land_trauma: float = 0.35


func _run(id: int) -> void:
	var skills := toad.skills()
	for i in skills.slam_count:
		if not still_running(id):
			return
		var target := toad.clamp_to_arena(toad.player_position())
		toad.slam_indicator.show_indicator(target, skills.lava_radius, skills.slam_air_time)
		toad.play_clip(&"Slam_Jump")
		toad.vfx.begin_leap()
		await toad.leap_to(target, toad.data.leap_height, skills.slam_air_time)
		toad.slam_indicator.hide_indicator()
		if not still_running(id):
			return
		toad.play_clip(&"Slam_Land")
		toad.vfx.slam_land(target, skills.lava_radius)
		ScreenShake.add_trauma(land_trauma)
		toad.spawn_lava(target, skills.lava_radius, skills.lava_lifetime)
		await wait(land_recover)
	if skills.slam_return_center and still_running(id):
		toad.play_clip(&"Slam_Jump")
		toad.vfx.begin_leap()
		await toad.leap_to(toad.home_point(), toad.data.leap_height, skills.slam_air_time)
		if not still_running(id):
			return
		toad.play_clip(&"Slam_Land")
		await wait(land_recover)
	finish(id)
