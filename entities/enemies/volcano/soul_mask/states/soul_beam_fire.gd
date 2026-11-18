extends EnemyState
## Bắn tia theo hướng đã khoá trong fire_time giây, đứng yên. Hết thì sang Recover.
## Bị đánh / thổi ngắt thì tia tắt ngay (exit luôn tắt tia).

var mask: SoulMask
var _elapsed: float = 0.0
var _done: bool = false


func _ready() -> void:
	super()
	mask = owner as SoulMask
	assert(mask != null, "SoulBeamFire chỉ dùng cho SoulMask")


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_done = false
	mask.face_instantly(Vector3(mask.locked_direction.x, 0.0, mask.locked_direction.z))
	mask.fire_beam(mask.locked_direction)


func exit() -> void:
	mask.stop_beam()
	# Bị ngắt giữa chừng (không qua Recover): tự khép hàm
	if not _done:
		mask.set_jaw(0.0, mask.soul_data.beam.recover_time)
	mask.start_attack_cooldown()


func physics_update(delta: float) -> void:
	_elapsed += delta
	mask.apply_gravity(delta)
	mask.fly_toward(Vector3.ZERO, delta)
	if _elapsed >= mask.soul_data.beam.fire_time:
		_done = true
		state_machine.transition_to(mask.recover_state)
