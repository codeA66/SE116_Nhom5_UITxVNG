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
## Mốc (giây trong đòn) bắt đầu bật lùi vì chém trúng; < 0 = đòn này chưa trúng
var _recoil_start: float = -1.0

## Nhớ nhát kế sau khi rời đòn: đang đi mà đòn bị hủy để chạy thì bấm tiếp vẫn nối combo
@onready var _combo: ComboTracker = $ComboTracker


func enter(_previous: StringName) -> void:
	_combo_index = _combo.peek_index(player.get_weapon().combo.size())
	player.hitbox.hit.connect(_on_hit)
	_start_attack()


func exit() -> void:
	player.hitbox.deactivate()
	player.hitbox.hit.disconnect(_on_hit)
	_combo.start_grace()


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	_apply_movement(delta)
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

	var moving := not player.get_move_direction().is_zero_approx()
	# Giữ hướng đi (và không có lệnh chém đang chờ) thì bỏ phần thu đòn để chạy tiếp.
	# Lệnh chém đang chờ thì giữ nhịp đòn như lúc đứng yên, để vừa đi vừa chém không ra đòn nhanh hơn.
	# Không hủy trước khi hết active: đặt mốc quá sớm cũng không mất đòn
	var move_cancel_at := maxf(_attack.move_cancel_start, _active_end)
	var move_cancel := _attack.move_cancel_start >= 0.0 and _elapsed >= move_cancel_at and moving and not player.can_attack()
	if move_cancel or _elapsed >= _attack.duration:
		state_machine.transition_to(RUN if moving else IDLE)


func _start_attack() -> void:
	player.consume_attack_input()
	player.hitbox.deactivate()
	_weapon = player.get_weapon()
	_attack = _weapon.combo[_combo_index]
	_combo.mark_started(_combo_index, _weapon.combo.size())
	if not _weapon.is_ranged():
		player.hitbox.set_reach(_weapon.attack_range)
	_elapsed = 0.0
	_hitbox_used = false
	_recoil_start = -1.0

	# Chém theo con trỏ chuột giống Wind Blast; không có chuột (tay cầm, headless) thì theo phím + soft-lock
	_lunge_direction = player.get_mouse_aim_direction()
	if _lunge_direction.is_zero_approx():
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


func _apply_movement(delta: float) -> void:
	if _recoil_start >= 0.0:
		var recoil_t := (_elapsed - _recoil_start) / maxf(_attack.self_recoil_time, 0.001)
		_set_horizontal_velocity(-_lunge_direction * _attack.self_recoil_speed * maxf(1.0 - recoil_t, 0.0))
	elif _elapsed < _attack.lunge_time:
		_set_horizontal_velocity(_lunge_direction * _attack.lunge_speed)
	elif _attack.lunge_stop:
		# Phanh đều về 0 thay vì đứng khựng ngay: dừng gọn mà không bị giật
		var brake := 0.0
		if _attack.lunge_brake_time > 0.0:
			brake = clampf(1.0 - (_elapsed - _attack.lunge_time) / _attack.lunge_brake_time, 0.0, 1.0)
		_set_horizontal_velocity(_lunge_direction * _attack.lunge_speed * brake)
	else:
		player.move_toward_direction(Vector3.ZERO, delta)


func _set_horizontal_velocity(horizontal: Vector3) -> void:
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z


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


func _on_hit(_target: HurtboxComponent) -> void:
	# Trúng nhiều mục tiêu trong một nhát chỉ bật lùi một lần
	if _attack.self_recoil_speed > 0.0 and _recoil_start < 0.0:
		_recoil_start = _elapsed
