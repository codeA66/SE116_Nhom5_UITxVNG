extends EnemyState
## Khép hàm trong recover_time giây (khoảng hở cho player phản công) rồi bay tiếp.

var mask: SoulMask
var _elapsed: float = 0.0


func _ready() -> void:
	super()
	mask = owner as SoulMask
	assert(mask != null, "SoulRecover chỉ dùng cho SoulMask")


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	mask.set_jaw(0.0, mask.soul_data.beam.recover_time)


func physics_update(delta: float) -> void:
	_elapsed += delta
	mask.apply_gravity(delta)
	mask.fly_toward(Vector3.ZERO, delta)
	if _elapsed >= mask.soul_data.beam.recover_time:
		state_machine.transition_to(mask.chase_state if mask.has_target() else IDLE)
