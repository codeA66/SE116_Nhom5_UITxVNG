extends PlayerState
## Thổi gió: đứng lại, quay về hướng input (có soft-lock), bật vùng thổi trong khoảng active.
## Gió không gây sát thương, chỉ đẩy. Dùng được cả trên đất và trên không.

var _data: WindBlastData
var _elapsed: float = 0.0
var _blasted: bool = false


func enter(_previous: StringName) -> void:
	_data = player.start_wind_blast()
	_elapsed = 0.0
	_blasted = false
	var input_direction := player.get_move_direction()
	var preferred := player.get_facing_direction() if input_direction.is_zero_approx() else input_direction.normalized()
	player.face_instantly(player.find_attack_direction(preferred))
	player.wind_blast.begin_charge(_data)
	player.play_action(_data.animation, _data.anim_speed)


func exit() -> void:
	player.wind_blast.deactivate()


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	player.move_toward_direction(Vector3.ZERO, delta)

	var active_end := _data.active_start + _data.active_time
	if not _blasted and _elapsed >= _data.active_start:
		player.wind_blast.activate(_data)
		_blasted = true
	elif _blasted and _elapsed >= active_end and player.wind_blast.is_active():
		player.wind_blast.deactivate()

	# Thổi xong thì được hủy phần thu tay bằng dash
	if _elapsed >= active_end and player.can_dash():
		state_machine.transition_to(DASH)
		return

	if _elapsed >= _data.duration:
		if not player.is_on_floor():
			state_machine.transition_to(FALL)
		elif player.get_move_direction().is_zero_approx():
			state_machine.transition_to(IDLE)
		else:
			state_machine.transition_to(RUN)
