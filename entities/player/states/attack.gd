extends PlayerState
## Combo đánh thường. Dữ liệu từng đòn lấy từ player.get_weapon().combo (AttackData).

var _combo_index: int = 0
var _elapsed: float = 0.0
var _attack: AttackData
var _lunge_direction: Vector3 = Vector3.ZERO
var _hitbox_used: bool = false
var _weapon: WeaponData
## Khoảng bật hitbox của đòn hiện tại (giây thực), lấy từ marker animation nếu có
var _active_start: float = 0.0
var _active_end: float = 0.0


func enter(_previous: StringName) -> void:
	_combo_index = 0
	_start_attack()


func exit() -> void:
	player.hitbox.deactivate()


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	_apply_lunge(delta)
	_update_hitbox()

	# Animation cancel: từ cancel_start được hủy phần thu đòn bằng dash
	if _elapsed >= _attack.cancel_start and player.can_dash():
		state_machine.transition_to(DASH)
		return

	# Attack buffer nằm ở Player: bấm sớm trong lúc đòn chưa xong vẫn được ghi nhận
	var has_next := _combo_index < _weapon.combo.size() - 1
	if has_next and _elapsed >= _attack.combo_window_start and player.can_attack():
		_combo_index += 1
		_start_attack()
		return

	if _elapsed >= _attack.duration:
		var moving := not player.get_move_direction().is_zero_approx()
		state_machine.transition_to(RUN if moving else IDLE)


func _start_attack() -> void:
	player.consume_attack_input()
	player.hitbox.deactivate()
	_weapon = player.get_weapon()
	_attack = _weapon.combo[_combo_index]
	if not _weapon.is_ranged():
		player.hitbox.set_reach(_weapon.attack_range)
	_elapsed = 0.0
	_hitbox_used = false

	var input_direction := player.get_move_direction()
	var preferred := player.get_facing_direction() if input_direction.is_zero_approx() else input_direction.normalized()
	_lunge_direction = player.find_attack_direction(preferred)
	player.face_instantly(_lunge_direction)
	player.play_action(_attack.animation, _attack.anim_speed, _attack.blend_in)
	_resolve_active_window()


## Marker nằm trong thời gian clip: chia anim_speed ra giây thực. Thiếu marker thì dùng số trong AttackData
func _resolve_active_window() -> void:
	_active_start = _attack.active_start
	_active_end = _attack.active_end
	var speed := maxf(_attack.anim_speed, 0.001)
	var start_mark := player.get_action_marker_time(_attack.animation, _attack.hit_start_marker)
	var end_mark := player.get_action_marker_time(_attack.animation, _attack.hit_end_marker)
	if start_mark >= 0.0 and end_mark > start_mark:
		_active_start = start_mark / speed
		_active_end = end_mark / speed


func _apply_lunge(delta: float) -> void:
	if _elapsed < _attack.lunge_time:
		player.velocity.x = _lunge_direction.x * _attack.lunge_speed
		player.velocity.z = _lunge_direction.z * _attack.lunge_speed
	elif _attack.lunge_stop:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
	else:
		player.move_toward_direction(Vector3.ZERO, delta)


func _update_hitbox() -> void:
	if _weapon.is_ranged():
		# Kiểm tra >= thay vì một cửa sổ hẹp: FPS thấp vẫn chỉ phóng đúng một tên.
		if not _hitbox_used and _elapsed >= _active_start:
			player.shoot_arrow(_weapon, _attack, _lunge_direction)
			_hitbox_used = true
		return
	var in_window := _elapsed >= _active_start and _elapsed < _active_end
	if in_window and not _hitbox_used:
		player.hitbox.activate(_attack, _active_end - _active_start)
		_hitbox_used = true
	elif not in_window and player.hitbox.is_active():
		player.hitbox.deactivate()
