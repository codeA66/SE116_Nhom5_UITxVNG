extends PlayerState
## Dash: lao nhanh theo hướng input (không có input thì theo hướng đang nhìn).
## Không chịu trọng lực, bất tử trong lúc dash (Player bật i-frames khi bắt đầu).

var _dash: DashData
var _direction: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0
var _terrain_scale: float = 1.0


func enter(_previous: StringName) -> void:
	_dash = player.start_dash()
	var input_direction := player.get_move_direction()
	_direction = player.get_facing_direction() if input_direction.is_zero_approx() else input_direction.normalized()
	_elapsed = 0.0
	_terrain_scale = player.get_terrain_speed()
	player.dash_wind_only = true
	player.face_instantly(_direction)
	player.play_action(_dash.animation, _dash.anim_speed)
	_apply_dash_velocity(1.0)


func exit() -> void:
	player.dash_wind_only = false


func physics_update(delta: float) -> void:
	_elapsed += delta
	if _elapsed < _dash.duration:
		_apply_dash_velocity(_speed_factor())
		return

	_apply_exit_velocity()
	if not player.is_on_floor():
		state_machine.transition_to(FALL)
	elif player.get_move_direction().is_zero_approx():
		state_machine.transition_to(IDLE)
	else:
		state_machine.transition_to(RUN)


func _speed_factor() -> float:
	var t := _elapsed / maxf(_dash.duration, 0.001)
	if t <= _dash.slowdown_start:
		return 1.0
	var k := (t - _dash.slowdown_start) / maxf(1.0 - _dash.slowdown_start, 0.001)
	return lerpf(1.0, _dash.slowdown_end_factor, clampf(k, 0.0, 1.0))


func _apply_dash_velocity(factor: float) -> void:
	_terrain_scale = minf(_terrain_scale, player.get_terrain_speed())
	player.velocity = _direction * _dash.speed * factor * _terrain_scale


func _apply_exit_velocity() -> void:
	var exit_speed := _dash.speed * _dash.end_momentum
	var move := player.get_move_direction()
	if _dash.keep_run_speed and not move.is_zero_approx():
		exit_speed = maxf(exit_speed, player.movement.max_speed * minf(move.length(), 1.0))
	player.velocity = _direction * exit_speed * player.get_terrain_speed()
