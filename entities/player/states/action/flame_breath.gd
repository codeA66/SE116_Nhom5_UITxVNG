extends PlayerState
## Phun lửa (phím Q): đứng lại, quay về hướng chuột / input, bật vùng lửa liên tục trong khoảng active.
## Lửa gây sát thương (1) nhưng không đẩy. Vùng trúng là HitboxComponent "Model/FlameHitbox"; hình ảnh do
## FlameBreathVfx nghe signal của hitbox đó, state không biết gì về VFX.

const HITBOX_PATH := ^"Model/FlameHitbox"

var _data: FlameBreathData
var _hitbox: HitboxComponent
var _elapsed: float = 0.0
var _fired: bool = false


func enter(_previous: StringName) -> void:
	if _hitbox == null:
		_hitbox = player.get_node(HITBOX_PATH) as HitboxComponent
	_data = player.start_skill(FlameBreathData.ID) as FlameBreathData
	_elapsed = 0.0
	_fired = false
	# Nhắm theo chuột như Thổi Gió: thắp lò / đốt dây leo cần chính xác hơn tự nhắm
	var aim := player.get_mouse_aim_direction()
	if aim.is_zero_approx():
		var input_direction := player.get_move_direction()
		var preferred := player.get_facing_direction() if input_direction.is_zero_approx() else input_direction.normalized()
		aim = player.find_attack_direction(preferred)
	player.face_instantly(aim)
	_hitbox.set_reach(_data.reach)
	_hitbox.set_cross_section(_data.width, _data.height)
	player.play_action(_data.animation, _data.anim_speed)


func exit() -> void:
	if _hitbox.is_active():
		_hitbox.deactivate()


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	player.move_toward_direction(Vector3.ZERO, delta)

	var active_end := _data.active_start + _data.active_time
	if not _fired and _elapsed >= _data.active_start:
		_hitbox.activate(_data.attack, _data.active_time)
		_fired = true
	elif _fired and _elapsed >= active_end and _hitbox.is_active():
		_hitbox.deactivate()

	# Phun xong thì được hủy phần thu tay bằng dash
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
