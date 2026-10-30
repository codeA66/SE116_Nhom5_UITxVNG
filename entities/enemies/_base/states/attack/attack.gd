extends EnemyState
## Ra đòn theo 3 pha của AttackData: lấy đà (0 → active_start, nháy báo trước) → đòn (active_start → active_end,
## bật hitbox, lướt tới) → hồi (active_end → duration, đứng yên: khoảng hở cho player phản công).
## Hướng đòn chốt lúc bắt đầu lấy đà, không xoay theo player giữa chừng (để player né được).

var _elapsed: float = 0.0
var _direction: Vector3
var _hit_started: bool = false
var _attack: AttackData


func enter(_previous: StringName) -> void:
	_attack = enemy.data.attack
	_elapsed = 0.0
	_hit_started = false
	_direction = enemy.direction_to_target()
	if _direction.is_zero_approx():
		_direction = enemy.get_facing_direction()
	enemy.face_instantly(_direction)
	enemy.velocity.x = 0.0
	enemy.velocity.z = 0.0
	enemy.set_telegraph(true)
	enemy.play_action(_attack.animation, _attack.anim_speed)


func exit() -> void:
	enemy.set_telegraph(false)
	enemy.hitbox.deactivate()
	enemy.start_attack_cooldown()


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_gravity(delta)

	if _elapsed >= _attack.active_start and not _hit_started:
		_hit_started = true
		enemy.set_telegraph(false)
		enemy.hitbox.activate(_attack)
	if _elapsed >= _attack.active_end and enemy.hitbox.is_active():
		enemy.hitbox.deactivate()

	# Chỉ lướt tới trong pha đòn; pha lấy đà và pha hồi đứng yên
	var in_lunge := _elapsed >= _attack.active_start and _elapsed < _attack.active_start + _attack.lunge_time
	if in_lunge:
		enemy.velocity.x = _direction.x * _attack.lunge_speed
		enemy.velocity.z = _direction.z * _attack.lunge_speed
	else:
		enemy.move_toward_direction(Vector3.ZERO, delta)

	if _elapsed >= _attack.duration:
		state_machine.transition_to(enemy.chase_state if enemy.has_target() else IDLE)
