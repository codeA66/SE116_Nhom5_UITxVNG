extends EnemyState
## Giữ khoảng cách [preferred_min, preferred_max] với player: lùi ra khi quá gần, lại gần khi quá xa,
## đúng khoảng thì bay ngang chậm. Quyết định dịch chuyển hay niệm cầu. Dùng làm chase_state của quái pháp sư.

var caster: WispCaster
## +1 / -1: chiều bay ngang
var _strafe_sign: float = 1.0
var _strafe_left: float = 0.0
var _panic_elapsed: float = 0.0
var _no_los_elapsed: float = 0.0


func _ready() -> void:
	super()
	caster = owner as WispCaster
	assert(caster != null, "KeepDistance chỉ dùng cho WispCaster")


func enter(_previous: StringName) -> void:
	_panic_elapsed = 0.0
	_no_los_elapsed = 0.0
	_pick_strafe()
	caster.invalidate_line_of_sight()
	enemy.play_anim(ANIM_IDLE)


func physics_update(delta: float) -> void:
	caster.apply_gravity(delta)
	if caster.should_give_up_chase():
		caster.forget_target()
		state_machine.transition_to(PATROL)
		return

	var data := caster.caster_data
	var distance := caster.distance_to_target()
	var has_los := caster.has_line_of_sight()
	_panic_elapsed = _panic_elapsed + delta if distance < data.panic_distance else 0.0
	_no_los_elapsed = _no_los_elapsed + delta if not has_los else 0.0

	var wants_teleport := caster.wants_teleport() or _panic_elapsed >= data.panic_time or _no_los_elapsed >= data.no_los_time
	if wants_teleport and caster.can_teleport():
		state_machine.transition_to(caster.teleport_state)
		return
	if has_los and caster.can_cast() and caster.can_attack():
		state_machine.transition_to(caster.attack_state)
		return

	var to_target := caster.direction_to_target()
	caster.fly_toward(_desired_direction(distance, to_target, delta), delta)
	# Luôn quay mặt về player, kể cả khi đang lùi
	caster.face_direction(to_target, delta)


func _desired_direction(distance: float, to_target: Vector3, delta: float) -> Vector3:
	var data := caster.caster_data
	if distance < data.preferred_min:
		return -to_target
	if distance > data.preferred_max:
		return to_target
	_strafe_left -= delta
	# Đổi chiều theo thời gian, hoặc khi đụng tường / rào
	if _strafe_left <= 0.0 or caster.is_on_wall():
		_strafe_sign = -_strafe_sign
		_strafe_left = randf_range(data.strafe_switch_min, data.strafe_switch_max)
	return to_target.cross(Vector3.UP) * _strafe_sign * data.strafe_speed_scale


func _pick_strafe() -> void:
	var data := caster.caster_data
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	_strafe_left = randf_range(data.strafe_switch_min, data.strafe_switch_max)
