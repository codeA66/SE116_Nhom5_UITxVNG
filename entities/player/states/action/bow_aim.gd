extends PlayerState
## Kéo cung (vũ khí phụ): giữ phím aim để kéo, thả để bắn. Đứng yên, xoay người theo chuột
## (đứng nghiêng kiểu cung thủ, góc do Player.bow_stance_degrees quyết định).
## Dash hủy lúc kéo; sau khi nhả dây, phát chờ do player giữ nên không mất khi rời state.
## Rời mặt đất trước khi nhả dây hoặc bị khoá điều khiển thì hủy.

var _bow: BowData
var _elapsed: float = 0.0
var _draw: float = 0.0
var _released: bool = false


func enter(_previous: StringName) -> void:
	_bow = player.get_bow()
	_elapsed = 0.0
	_draw = 0.0
	_released = false
	player.bow_projectile_fired.connect(_on_bow_volley_projectile)
	var aim := player.get_mouse_aim_direction()
	if aim.is_zero_approx():
		aim = player.get_facing_direction()
	player.turn_bow_toward(aim, -1.0, 0.0)
	player.begin_bow_aim()


func exit() -> void:
	player.bow_projectile_fired.disconnect(_on_bow_volley_projectile)
	# Thôi đứng nghiêng: quay mặt về hướng vừa nhắm
	player.face_instantly(player.get_bow_aim_direction())
	player.end_bow_aim()


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	# Hướng 0: chỉ phanh, không xoay theo hướng chạy; xoay do _turn_toward_aim lo
	player.move_toward_direction(Vector3.ZERO, delta)

	if player.can_dash():
		state_machine.transition_to(DASH)
		return
	if not player.is_on_floor():
		state_machine.transition_to(FALL)
		return

	if not player.controls_enabled:
		state_machine.transition_to(IDLE)
		return

	if _released:
		if player.has_pending_bow_shots():
			return
		if _elapsed >= _bow.release_recovery:
			state_machine.transition_to(IDLE if player.get_move_direction().is_zero_approx() else RUN)
		return

	_turn_toward_aim(delta)
	_draw = minf(_elapsed / maxf(_bow.draw_time, 0.0001), 1.0)
	player.set_bow_draw(_draw)
	if not player.is_holding_aim():
		# So với một sai số nhỏ: kéo đầy bị kẹp đúng 1.0 nhưng phép chia thời gian có thể lệch vài ulp
		if _draw >= _bow.min_draw_to_shoot - 0.0001:
			_shoot()
		else:
			# Thả sớm: hủy, không bắn, không tính hồi; báo để VFX hiện khói hủy
			player.notify_bow_draw_cancelled()
			state_machine.transition_to(IDLE if player.get_move_direction().is_zero_approx() else RUN)


func _on_bow_volley_projectile(primary: bool) -> void:
	# Chỉ state đang nhả dây được phát clip cung; Timer không ghi đè clip Dash/Hurt.
	if not primary and _released:
		_elapsed = 0.0
		player.release_bow(false)


func _turn_toward_aim(delta: float) -> void:
	var aim := player.get_mouse_aim_direction()
	if aim.is_zero_approx():
		# Không có chuột (tay cầm, headless): xoay theo phím hướng
		aim = player.get_move_direction()
	player.turn_bow_toward(aim, _bow.aim_turn_speed, delta)


func _shoot() -> void:
	# Bắn theo hướng cung đang chĩa để mũi tên khớp với hình trên màn hình
	player.shoot_bow(_draw)
	player.release_bow()
	_released = true
	_elapsed = 0.0
