extends PlayerState
## Dash: lao nhanh theo hướng input (không có input thì theo hướng đang nhìn).
## Không chịu trọng lực, bất tử trong lúc dash (Player bật i-frames khi bắt đầu).

var _dash: DashData
var _direction: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_dash = player.start_dash()
	var input_direction := player.get_move_direction()
	_direction = player.get_facing_direction() if input_direction.is_zero_approx() else input_direction.normalized()
	_elapsed = 0.0
	# Dash xuyên qua gió
	player.external_forces_enabled = false
	player.face_instantly(_direction)
	player.play_action(_dash.animation, _dash.anim_speed)
	_apply_dash_velocity(1.0)


func exit() -> void:
	player.external_forces_enabled = true


func physics_update(delta: float) -> void:
	_elapsed += delta
	if _elapsed < _dash.duration:
		_apply_dash_velocity(1.0)
		return

	_apply_dash_velocity(_dash.end_momentum)
	if not player.is_on_floor():
		state_machine.transition_to(FALL)
	elif player.get_move_direction().is_zero_approx():
		state_machine.transition_to(IDLE)
	else:
		state_machine.transition_to(RUN)


func _apply_dash_velocity(factor: float) -> void:
	player.velocity = _direction * _dash.speed * factor
