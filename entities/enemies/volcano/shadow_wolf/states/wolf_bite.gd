extends EnemyState
## Cắn liên hoàn (attack_state của Sói): tối đa bite_combo cú, mỗi cú theo mốc của EnemyData.attack
## (lấy đà có nháy báo trước -> hitbox bật -> hồi). Giữa các cú quay lại theo player; player ra khỏi tầm
## hoặc giơ lửa thì dừng chuỗi. Bị đánh thì Hurt / Flee chen vào: chuỗi bị ngắt.

signal bite(index: int)

var wolf: ShadowWolf
var bites_done: int = 0
var _attack: AttackData
var _elapsed: float = 0.0
var _hit_started: bool = false
var _direction: Vector3 = Vector3.FORWARD


func _ready() -> void:
	super()
	wolf = owner as ShadowWolf
	assert(wolf != null, "WolfBite chỉ dùng cho ShadowWolf")


func enter(_previous: StringName) -> void:
	_attack = wolf.data.attack
	bites_done = 0
	wolf.fade_to(0.0, 0.1)
	_start_bite()


func exit() -> void:
	wolf.set_telegraph(false)
	wolf.hitbox.deactivate()
	wolf.start_attack_cooldown()


func physics_update(delta: float) -> void:
	_elapsed += delta
	wolf.apply_gravity(delta)
	if _elapsed >= _attack.active_start and not _hit_started:
		_hit_started = true
		wolf.set_telegraph(false)
		wolf.hitbox.activate(_attack)
		bite.emit(bites_done)
	if _elapsed >= _attack.active_end and wolf.hitbox.is_active():
		wolf.hitbox.deactivate()
	var lunge := _elapsed >= _attack.active_start and _elapsed < _attack.active_start + _attack.lunge_time
	if lunge:
		wolf.velocity.x = _direction.x * _attack.lunge_speed
		wolf.velocity.z = _direction.z * _attack.lunge_speed
	else:
		wolf.move_toward_direction(Vector3.ZERO, delta)
	if _elapsed < _attack.duration:
		return
	bites_done += 1
	var keep_going := bites_done < wolf.wolf_data.bite_combo and wolf.has_target() \
			and wolf.distance_to_target() <= wolf.wolf_data.bite_range + 0.6 and not wolf.is_target_lit()
	if keep_going:
		_start_bite()
	else:
		state_machine.transition_to(wolf.chase_state if wolf.has_target() else IDLE)


func _start_bite() -> void:
	_elapsed = 0.0
	_hit_started = false
	_direction = wolf.direction_to_target()
	if _direction.is_zero_approx():
		_direction = wolf.get_facing_direction()
	wolf.face_instantly(_direction)
	wolf.velocity.x = 0.0
	wolf.velocity.z = 0.0
	wolf.set_telegraph(true)
	wolf.play_action(_attack.animation, _attack.anim_speed)
