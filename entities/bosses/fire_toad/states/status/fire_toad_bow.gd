extends FireToadState
## Hết máu khi đánh theo hội: không chết mà cúi đầu (choáng), rồi nhảy về ngai ngồi xem. Court quyết định kết thúc
## trận. Không có ngai thì ẩn như Dead.

## Đứng cúi đầu bao lâu trước khi nhảy về ngai (s)
@export_range(0.0, 5.0, 0.05) var bow_time: float = 1.2
@export var bow_clip: StringName = &"Stunned"


func _run(id: int) -> void:
	toad.set_invulnerable(true)
	toad.slam_indicator.hide_indicator()
	toad.dismiss_sentinels()
	toad.play_clip(bow_clip, true)
	var ground := toad.home_point()
	if toad.global_position.y - ground.y > 0.5 and toad.throne == null:
		await toad.fly_to(Vector3(toad.global_position.x, ground.y, toad.global_position.z), 0.5)
	await wait(bow_time)
	if not still_running(id):
		return
	if toad.throne == null:
		state_machine.transition_to(&"Dead")
		return
	toad.play_clip(&"Leap_Start")
	toad.vfx.begin_leap()
	await toad.leap_to(toad.throne.global_position, toad.data.leap_height, toad.data.leap_time)
	if still_running(id):
		toad.play_clip(&"Leap_Land")
		toad.vfx.platform_land()
		state_machine.transition_to(&"Throne")
