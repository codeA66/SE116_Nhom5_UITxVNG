class_name WildSkillAttack
extends EnemyState
## Cùng một đồng hồ cho pose, root motion vật lý, active frames và hiệu ứng.
var _actor: WildEnemy
var _skill: EnemySkillData
var _elapsed: float = 0.0
var _facing: Vector3
var _hit_started: bool = false
var _effect_started: bool = false
var _completed: bool = false
var _effect: EnemyHazard

func enter(_previous: StringName) -> void:
	_actor = enemy as WildEnemy
	_skill = _actor.pending_skill
	assert(_skill != null)
	_elapsed = 0.0; _hit_started = false; _effect_started = false; _completed = false; _effect = null
	_facing = _actor.direction_to_target()
	if _facing.is_zero_approx(): _facing = _actor.get_facing_direction()
	_actor.face_instantly(_facing)
	_actor.velocity.x = 0.0; _actor.velocity.z = 0.0
	_actor.set_telegraph(true)
	_actor.play_action(_skill.animation, _skill.anim_speed, 0.05)
	_actor.skill_started.emit(_skill)
	if _skill.effect_on_start: _spawn_effect()

func exit() -> void:
	_actor.set_telegraph(false)
	_actor.hitbox.deactivate()
	_actor.velocity.x = 0.0; _actor.velocity.z = 0.0
	if not _completed and is_instance_valid(_effect): _effect.cancel()
	_actor.complete_skill(_skill, _completed)

func physics_update(delta: float) -> void:
	var previous: float = _elapsed
	_elapsed += delta
	_actor.apply_gravity(delta)
	_update_aim(previous, delta)
	if _elapsed >= _skill.windup_end:
		_actor.set_telegraph(false)
		if not _effect_started and not _skill.effect_after_animation and _skill.effect_scene != null: _spawn_effect()
	if _skill.melee_enabled and _elapsed >= _skill.active_start and not _hit_started:
		_hit_started = true
		_actor.hitbox.activate(_skill, _skill.active_end - _skill.active_start)
	if _elapsed >= _skill.active_end and _actor.hitbox.is_active(): _actor.hitbox.deactivate()
	_apply_motion(previous, delta)
	if _elapsed >= _skill.duration:
		_completed = true
		if _skill.effect_after_animation: _spawn_effect()
		state_machine.transition_to(&"Watch" if _actor.data.attack_cooldown > 0.0 else _actor.chase_state)

func _spawn_effect() -> void:
	_effect_started = true
	if _skill.effect_scene == null: return
	_effect = _actor.emitter.emit_skill(_skill, _facing)

func _update_aim(previous: float, delta: float) -> void:
	if _skill.track_during_windup and previous < _skill.windup_end and _actor.has_target():
		_actor.face_direction(_actor.direction_to_target(), delta)
		_facing = _actor.get_facing_direction()

func _apply_motion(previous: float, delta: float) -> void:
	var advance: float = _actor.root_offset(_skill, _elapsed) - _actor.root_offset(_skill, previous)
	_actor.velocity.x = _facing.x * advance / maxf(delta, 0.0001)
	_actor.velocity.z = _facing.z * advance / maxf(delta, 0.0001)
