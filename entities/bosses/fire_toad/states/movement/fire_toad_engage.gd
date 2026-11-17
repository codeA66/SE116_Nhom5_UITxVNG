extends FireToadState
## Giữ miễn sát thương trong đoạn xuất hiện để trận chỉ bắt đầu khi cóc đứng trên sân.

@export_group("Khe nứt")
@export_range(0.05, 2.0, 0.01) var crack_time: float = 0.23
@export_range(0.05, 2.0, 0.01) var reveal_time: float = 0.55
@export_range(0.05, 2.0, 0.01) var close_time: float = 0.24
@export_group("Tiếp đất")
@export_range(0.1, 8.0, 0.1) var drop_height: float = 2.45
@export_range(0.05, 2.0, 0.01) var drop_time: float = 0.46
@export_range(0.0, 1.0, 0.01) var land_trauma: float = 0.3

var _entrance: Tween


func exit() -> void:
	super()
	if _entrance != null:
		_entrance.kill()
		_entrance = null
	toad.vfx.arrival.stop()
	toad.vfx.arrival.set_model_visible(true)


func _run(id: int) -> void:
	toad.set_invulnerable(true)
	toad.seated = false
	toad.warm_pools()
	var landing: Vector3 = toad.home_point()
	toad.teleport(landing + Vector3.UP * drop_height)
	toad.face_player()
	toad.play_clip(&"Idle", true)
	toad.vfx.arrival.begin(toad.global_position)

	# Dùng một timeline để khe khép hẳn trước khi bắt đầu rơi.
	_entrance = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_entrance.tween_method(toad.vfx.arrival.draw_crack, 0.0, 1.0, crack_time)
	_entrance.tween_method(toad.vfx.arrival.draw_reveal, 0.0, 1.0, reveal_time)
	_entrance.tween_method(toad.vfx.arrival.draw_close, 0.0, 1.0, close_time)
	_entrance.tween_callback(_start_drop)
	_entrance.tween_property(toad, ^"global_position", landing, drop_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_entrance.tween_callback(_land.bind(id, landing))


func _start_drop() -> void:
	toad.vfx.arrival.stop()
	toad.play_clip(&"Leap_Air", true)


func _land(id: int, landing: Vector3) -> void:
	_entrance = null
	toad.play_clip(&"Leap_Land")
	toad.vfx.arrival_land(landing)
	ScreenShake.add_trauma(land_trauma)
	toad.set_invulnerable(false)
	finish(id)
