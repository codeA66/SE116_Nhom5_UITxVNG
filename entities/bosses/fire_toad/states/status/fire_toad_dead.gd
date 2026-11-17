extends FireToadState
## Boss chết: tắt hurtbox (không nhận đòn nữa), chạy clip Death rồi ẩn. Đang bay thì rơi xuống sàn;
## đang ngồi ngai (court kết thúc trận) thì ẩn tại chỗ.

## Thời gian từ lúc chết tới lúc ẩn hẳn (s)
@export_range(0.1, 10.0, 0.1) var vanish_delay: float = 1.5


func _run(id: int) -> void:
	toad.hurtbox.set_deferred(&"monitorable", false)
	toad.slam_indicator.hide_indicator()
	toad.dismiss_sentinels()
	toad.play_clip(&"Death")
	var ground: Vector3 = toad.home_point()
	if toad.seated:
		ground = toad.global_position
	var should_drop: bool = toad.global_position.y - ground.y > 0.5
	var landing_y: float = ground.y if should_drop else toad.global_position.y
	toad.vfx.death(vanish_delay, landing_y)
	if should_drop:
		await toad.fly_to(Vector3(toad.global_position.x, ground.y, toad.global_position.z), 0.5)
	await wait(vanish_delay)
	if still_running(id):
		toad.hide()
		toad.set_physics_process(false)
