extends EnemyState
## Niệm cầu: 0 → aim_lock_time hướng ngắm còn xoay theo player; sau đó khoá hướng (player kịp né ngang);
## tới active_start thì bắn một quả theo hướng đã khoá; rồi đứng yên tới hết duration (khoảng hở cho player).
## Mốc thời gian và sát thương lấy từ EnemyData.attack. Bị đánh / thổi ngắt giữa chừng thì không bắn.

var caster: WispCaster
var _attack: AttackData
var _elapsed: float = 0.0
var _locked: bool = false
var _fired: bool = false
var _locked_direction: Vector3 = Vector3.FORWARD


func _ready() -> void:
	super()
	caster = owner as WispCaster
	assert(caster != null, "CastOrb chỉ dùng cho WispCaster")


func enter(_previous: StringName) -> void:
	_attack = caster.data.attack
	_elapsed = 0.0
	_locked = false
	_fired = false
	caster.face_instantly(caster.direction_to_target())
	caster.set_telegraph(true)
	caster.begin_charge(_attack.active_start)
	caster.play_action(_attack.animation, _attack.anim_speed)


func exit() -> void:
	caster.set_telegraph(false)
	# Bị ngắt khi chưa bắn: huỷ quả đang niệm
	caster.cancel_charge()
	caster.start_attack_cooldown()


func physics_update(delta: float) -> void:
	_elapsed += delta
	caster.apply_gravity(delta)
	caster.move_toward_direction(Vector3.ZERO, delta)

	if not _locked:
		if _elapsed >= minf(caster.caster_data.aim_lock_time, _attack.active_start):
			_locked = true
			_locked_direction = caster.aim_direction()
			caster.face_instantly(_locked_direction)
		else:
			caster.face_direction(caster.direction_to_target(), delta)

	if not _fired and _elapsed >= _attack.active_start:
		_fired = true
		caster.set_telegraph(false)
		caster.cancel_charge()
		caster.fire_orb(_locked_direction)
		caster.notify_cast()

	if _elapsed >= _attack.duration:
		state_machine.transition_to(caster.chase_state if caster.has_target() else IDLE)
