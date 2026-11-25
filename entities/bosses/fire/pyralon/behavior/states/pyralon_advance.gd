extends EnemyState

var _bird: Pyralon
var _rest: float
var _rear_wait: float
var _crimson_wait: float = 0.0


func enter(_previous: StringName) -> void:
	_bird = enemy as Pyralon
	_rear_wait = _bird.profile.rear_check_pause if _bird.rear_check_pending else 0.0
	# Khi vừa chạy nhịp chờ không xoay 1s (rear_check_pending) thì chỉ cộng thêm chase_pause (mặc định 0s);
	# còn sau đòn không kiểm tra sau lưng (Xoay chém / Sky Dive) vẫn giữ 1 nhịp chờ tương đương để không nối chiêu tức thì.
	_rest = _bird.profile.chase_pause if _bird.rear_check_pending else maxf(_bird.profile.chase_pause, _bird.profile.rear_check_pause)
	_crimson_wait = 0.0


func physics_update(delta: float) -> void:
	if not _bird.is_previewing():
		_bird.reacquire_target()
	if not _bird.has_target():
		state_machine.transition_to(IDLE)
		return
	_bird.apply_gravity(delta)
	# Dừng đúng 1 nhịp giữ nguyên hướng cũ sau đòn để kiểm tra player có đứng sau lưng không trước khi xoay theo.
	if _bird.rear_check_pending:
		_rear_wait -= delta
		_bird.velocity.x = 0.0
		_bird.velocity.z = 0.0
		_bird.play_anim(ANIM_IDLE)
		if _rear_wait > 0.0:
			return
		_bird.rear_check_pending = false
		if _bird.try_rear_slash():
			return
	# Ở Phase 2, sau đòn có lông đỏ quay lại lượt 2, đứng chờ lông đỏ bay gần xong hết rồi mới ra chiêu AI tiếp theo.
	if _bird.is_phase_two() and _crimson_wait < _bird.profile.crimson_return_wait_max and _bird.field.has_crimson_returning_busy():
		_crimson_wait += delta
		_bird.velocity.x = 0.0
		_bird.velocity.z = 0.0
		_bird.play_anim(ANIM_IDLE)
		return
	_rest = maxf(0.0, _rest - delta)
	if _rest <= 0.0 and _bird.try_next_move():
		return
	if _bird.is_previewing() or _bird.distance_to_target() <= _bird.wildlife.approach_stop_distance:
		_bird.move_toward_direction(Vector3.ZERO, delta)
		_bird.play_anim(ANIM_IDLE)
	else:
		var direction := (_bird.target.global_position - _bird.global_position).slide(Vector3.UP).normalized()
		_bird.move_toward_direction(direction, delta)
		_bird.play_anim(ANIM_RUN)
