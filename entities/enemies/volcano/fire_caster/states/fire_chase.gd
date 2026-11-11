extends EnemyState
## Quỷ Xương Lửa đuổi theo player: đi thẳng tới player, vào tầm stop_distance và có đường bắn thì đứng lại;
## hết hồi chiêu thì chuyển sang niệm. Bị tường / cột che thì đuổi tiếp tới khi thấy. Không lùi, không đi ngang.
## Dùng làm chase_state của FireCaster.

var caster: FireCaster


func _ready() -> void:
	super()
	caster = owner as FireCaster
	assert(caster != null, "FireChase chỉ dùng cho FireCaster")


func enter(_previous: StringName) -> void:
	caster.invalidate_line_of_sight()
	caster.play_anim(ANIM_WALK)


func physics_update(delta: float) -> void:
	caster.apply_gravity(delta)
	if caster.should_give_up_chase():
		caster.forget_target()
		state_machine.transition_to(PATROL)
		return
	var has_los := caster.has_line_of_sight()
	if has_los and caster.can_attack():
		state_machine.transition_to(caster.attack_state)
		return
	var to_target := caster.direction_to_target()
	var in_range := caster.distance_to_target() <= caster.caster_data.stop_distance
	var desired := Vector3.ZERO if in_range and has_los else to_target
	caster.move_toward_direction(desired, delta)
	caster.play_anim(ANIM_IDLE if desired.is_zero_approx() else ANIM_WALK)
	caster.face_direction(to_target, delta)
