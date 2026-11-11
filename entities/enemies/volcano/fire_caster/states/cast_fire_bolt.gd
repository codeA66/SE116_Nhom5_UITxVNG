extends EnemyState
## Niệm cầu lửa: đứng lại, cầu trên tay phình to + đèn cam sáng dần (báo trước). Tới aim_lock_time hướng ngắm
## còn xoay theo player, sau đó khoá (player kịp né ngang); tới active_start bắn một quả theo hướng đã khoá,
## rồi đứng yên tới hết duration (khoảng hở cho player). Mốc thời gian lấy từ EnemyData.attack.
## Bị đánh / thổi gió giữa chừng thì state khác chen vào: exit() huỷ niệm, không bắn.

var caster: FireCaster
var _attack: AttackData
var _elapsed: float = 0.0
var _locked: bool = false
var _fired: bool = false
var _locked_direction: Vector3 = Vector3.FORWARD


func _ready() -> void:
	super()
	caster = owner as FireCaster
	assert(caster != null, "CastFireBolt chỉ dùng cho FireCaster")


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
		caster.fire_bolt(_locked_direction)
	if _elapsed >= _attack.duration:
		state_machine.transition_to(caster.chase_state if caster.has_target() else IDLE)
