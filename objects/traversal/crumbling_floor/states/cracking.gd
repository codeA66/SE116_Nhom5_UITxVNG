extends CrumblingFloorState
## Ô rung mạnh dần trong crack_time giây (báo trước cho người chơi), hết giờ thì rơi.

var _timer: float = 0.0


func enter(_previous: StringName) -> void:
	_timer = 0.0


func physics_update(delta: float) -> void:
	_timer += delta
	var d := floor_tile.data
	var strength := d.shake_amount * clampf(_timer / maxf(d.crack_time, 0.001), 0.3, 1.0)
	# Rung ngẫu nhiên theo trục ngang: nhìn như sắp vỡ mà không đẩy người đứng trên (chỉ dời phần hình)
	floor_tile.set_visual_offset(Vector3(randf_range(-strength, strength), 0.0, randf_range(-strength, strength)))
	if _timer >= d.crack_time:
		state_machine.transition_to(FALLEN)
