extends FireToadState
## Rời ngai nhảy xuống chỗ của mình giữa sân rồi bắt đầu đánh. Còn miễn sát thương tới lúc đáp.

## Gầm trước khi nhảy (s)
@export_range(0.0, 3.0, 0.05) var roar_time: float = 0.5
@export_range(0.0, 1.0, 0.01) var land_trauma: float = 0.3


func _run(id: int) -> void:
	toad.set_invulnerable(true)
	# Còn "ngồi" tới lúc rời ngai; không bỏ ở Throne.exit vì Dead cần biết đang ngồi để biến mất tại chỗ
	toad.seated = false
	toad.warm_pools()
	toad.face_player()
	toad.play_clip(&"Spit_Up")
	await wait(roar_time)
	if not still_running(id):
		return
	toad.play_clip(&"Leap_Start")
	toad.vfx.begin_leap()
	await toad.leap_to(toad.home_point(), toad.data.leap_height, toad.data.leap_time)
	if not still_running(id):
		return
	toad.play_clip(&"Leap_Land")
	toad.vfx.platform_land()
	ScreenShake.add_trauma(land_trauma)
	toad.set_invulnerable(false)
	finish(id)
