extends EnemyState
## Lượn vòng quanh player ở bán kính orbit_radius: xa thì lại gần, gần thì lùi ra, đúng khoảng thì bay ngang.
## Luôn quay mặt về player. Đủ điều kiện ra đòn thì chuyển sang tụ lực. Dùng làm chase_state của Đầu Lửa.

var mask: SoulMask
var _sign: float = 1.0
var _switch_left: float = 0.0


func _ready() -> void:
	super()
	mask = owner as SoulMask
	assert(mask != null, "SoulOrbit chỉ dùng cho SoulMask")


func enter(_previous: StringName) -> void:
	_sign = 1.0 if randf() < 0.5 else -1.0
	_pick_switch()
	mask.play_anim(ANIM_IDLE)


func physics_update(delta: float) -> void:
	mask.apply_gravity(delta)
	if mask.should_give_up_chase():
		mask.forget_target()
		state_machine.transition_to(PATROL)
		return
	if mask.can_attack():
		state_machine.transition_to(mask.attack_state)
		return
	var d := mask.soul_data
	var to_target := mask.direction_to_target()
	var distance := mask.distance_to_target()
	_switch_left -= delta
	if _switch_left <= 0.0 or mask.is_on_wall():
		_sign = -_sign
		_pick_switch()
	var tangent := to_target.cross(Vector3.UP) * _sign * d.orbit_speed_scale
	var radial := Vector3.ZERO
	if distance > d.orbit_radius + d.orbit_tolerance:
		radial = to_target
	elif distance < d.orbit_radius - d.orbit_tolerance:
		radial = -to_target
	mask.fly_toward((tangent + radial).limit_length(1.0), delta)
	mask.face_direction(to_target, delta)


func _pick_switch() -> void:
	_switch_left = randf_range(mask.soul_data.orbit_switch_min, mask.soul_data.orbit_switch_max)
