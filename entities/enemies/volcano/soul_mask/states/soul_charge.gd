extends EnemyState
## Tụ lực: dừng lại, hàm há dần, vạch cảnh báo chạy từ miệng theo hướng ngắm. Còn lock_time giây thì khoá
## hướng (player kịp né ngang), hết charge_time thì sang Beam. Bị đánh / thổi ngắt thì huỷ, khép hàm.

var mask: SoulMask
var _elapsed: float = 0.0
var _locked: bool = false
var _finished: bool = false


func _ready() -> void:
	super()
	mask = owner as SoulMask
	assert(mask != null, "SoulCharge chỉ dùng cho SoulMask")


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_locked = false
	_finished = false
	mask.face_instantly(mask.direction_to_target())
	mask.locked_direction = mask.aim_direction()
	mask.begin_charge()
	mask.update_warning(mask.locked_direction)


func exit() -> void:
	if not _finished:
		# Bị ngắt: bỏ chiêu, vẫn tính hồi chiêu để không bắn lại ngay
		mask.stop_beam()
		mask.set_jaw(0.0, mask.soul_data.beam.recover_time)
		mask.start_attack_cooldown()


## Trong lock_time chia thành lock_flashes nhịp sáng / tắt đều nhau
func _flash_on(b: SoulBeamData) -> bool:
	var lock := clampf(b.lock_time, 0.0, b.charge_time)
	if b.lock_flashes <= 0 or lock <= 0.0:
		return false
	var t := clampf((_elapsed - (b.charge_time - lock)) / lock, 0.0, 0.999)
	return int(t * b.lock_flashes * 2.0) % 2 == 0


func physics_update(delta: float) -> void:
	var b := mask.soul_data.beam
	_elapsed += delta
	mask.apply_gravity(delta)
	mask.fly_toward(Vector3.ZERO, delta)
	if not _locked:
		if _elapsed >= b.charge_time - clampf(b.lock_time, 0.0, b.charge_time):
			_locked = true
		else:
			mask.locked_direction = mask.aim_direction()
			mask.face_direction(mask.direction_to_target(), delta)
	if _locked:
		mask.flash_warning(_flash_on(b))
	mask.update_warning(mask.locked_direction)
	if _elapsed >= b.charge_time:
		_finished = true
		state_machine.transition_to(mask.beam_state)
