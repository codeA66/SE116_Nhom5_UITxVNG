extends PlayerState
## Combo đánh thường. Dữ liệu từng đòn lấy từ player.get_weapon().combo (AttackData).

var _combo_index: int = 0
var _elapsed: float = 0.0
var _attack: AttackData
var _lunge_direction: Vector3 = Vector3.ZERO
var _hitbox_used: bool = false


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
	var has_next := _combo_index < player.get_weapon().combo.size() - 1
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
	var weapon := player.get_weapon()
	_attack = weapon.combo[_combo_index]
	player.hitbox.set_reach(weapon.attack_range)
	_elapsed = 0.0
	_hitbox_used = false

	var input_direction := player.get_move_direction()
	var preferred := player.get_facing_direction() if input_direction.is_zero_approx() else input_direction.normalized()
	_lunge_direction = player.find_attack_direction(preferred)
	player.face_instantly(_lunge_direction)
	player.play_action(_attack.animation, _attack.anim_speed)


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
	var in_window := _elapsed >= _attack.active_start and _elapsed < _attack.active_end
	if in_window and not _hitbox_used:
		player.hitbox.activate(_attack)
		_hitbox_used = true
	elif not in_window and player.hitbox.is_active():
		player.hitbox.deactivate()
