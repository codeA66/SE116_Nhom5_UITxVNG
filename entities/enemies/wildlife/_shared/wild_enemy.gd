class_name WildEnemy
extends Enemy
## Dùng Enemy/Character/FSM gốc; chỉ bổ sung chọn đòn và animation cho rig mới.
signal engaged(player: Node3D)
signal skill_started(skill: EnemySkillData)
signal skill_finished(skill: EnemySkillData, completed: bool)

var wildlife: WildEnemyData
var pending_skill: EnemySkillData
var _cooldowns: Dictionary[StringName, float] = {}
var _alert_done: bool = false
var _announced: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var emitter: EnemySkillEmitter = $SkillEmitter

func _ready() -> void:
	wildlife = data as WildEnemyData
	assert(wildlife != null)
	_rng.randomize()
	for skill: EnemySkillData in wildlife.skills:
		_cooldowns[skill.skill_id] = 0.0
	super()
	sensor.target_entered.connect(_announce_target)
	died.connect(_cancel_effects)
	play_anim(&"Idle")

func _pre_state_update(delta: float) -> void:
	super(delta)
	for skill: EnemySkillData in wildlife.skills:
		_cooldowns[skill.skill_id] = maxf(_cooldowns[skill.skill_id] - delta, 0.0)

func play_anim(clip: StringName) -> void:
	super(_map_animation(clip))

func play_action(clip: StringName, speed: float = 1.0, blend: float = -1.0) -> void:
	super(_map_animation(clip), speed, blend)

func animation_player() -> AnimationPlayer:
	return _anim

func alert_pending() -> bool:
	return not _alert_done and not wildlife.alert_animation.is_empty()

func begin_alert() -> float:
	_alert_done = true
	play_action(wildlife.alert_animation, 1.0, 0.08)
	return _anim.get_animation(wildlife.alert_animation).length

func choose_skill() -> EnemySkillData:
	for skill: EnemySkillData in wildlife.skills:
		if skill_ready(skill): return skill
	return null

func choose_random_skill() -> EnemySkillData:
	var selected: EnemySkillData
	var count: int = 0
	for skill: EnemySkillData in wildlife.skills:
		if not skill_ready(skill): continue
		count += 1
		if _rng.randi_range(1, count) == 1: selected = skill
	return selected

func skill_ready(skill: EnemySkillData) -> bool:
	var distance: float = distance_to_target()
	return has_target() and _attack_cooldown_left <= 0.0 and skill_cooldown(skill.skill_id) <= 0.0 and distance >= skill.minimum_range and distance <= skill.maximum_range

func skill_cooldown(id: StringName) -> float:
	return _cooldowns.get(id, 0.0)

func attack_cooldown_remaining() -> float:
	return _attack_cooldown_left

func begin_skill(skill: EnemySkillData) -> void:
	pending_skill = skill
	state_machine.transition_to(skill.state)

func complete_skill(skill: EnemySkillData, completed: bool) -> void:
	_cooldowns[skill.skill_id] = maxf(0.0, skill.cooldown)
	start_attack_cooldown()
	skill_finished.emit(skill, completed)
	pending_skill = null

func root_offset(skill: EnemySkillData, elapsed: float) -> float:
	var clip: Animation = _anim.get_animation(skill.animation)
	var motion: Curve = clip.get_meta(&"root_forward_curve", null) as Curve
	if motion == null: return 0.0
	return motion.sample(clampf(elapsed * skill.anim_speed / maxf(clip.length, 0.001), 0.0, 1.0)) * wildlife.model_scale

func receive_rally(player: Node3D) -> void:
	if is_dead() or not is_instance_valid(player): return
	target = player
	_announce_target(player)

func forget_target() -> void:
	super()
	_alert_done = false
	_announced = false

func reacquire_target() -> void:
	# Signal rời Area có thể đến sau một physics frame: không nhận lại mục tiêu đã xa.
	if has_target():
		if should_give_up_chase(): forget_target()
		return
	var candidate: Node3D = sensor.target
	if not is_instance_valid(candidate) or is_dead(): return
	var offset: Vector3 = candidate.global_position - global_position
	offset.y = 0.0
	if offset.length() <= data.detect_range and distance_from_home() <= data.leash_range:
		target = candidate
		_announce_target(candidate)

func should_give_up_chase() -> bool:
	if target is Player and (target as Player).health.is_dead(): return true
	return super()

func _announce_target(player: Node3D) -> void:
	if _announced or is_dead(): return
	_announced = true
	engaged.emit(player)

func _cancel_effects(_enemy: Enemy) -> void:
	emitter.cancel_all()

func _map_animation(clip: StringName) -> StringName:
	if wildlife == null: return clip
	if clip == &"Idle": return wildlife.idle_animation
	if clip == &"Walk": return wildlife.walk_animation
	if clip == &"Run": return wildlife.run_animation
	if clip == &"Hurt": return wildlife.hurt_animation
	if clip == &"Death": return wildlife.death_animation
	return clip
