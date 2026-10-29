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
var _returning_home: bool = false
var _battle_buff_left: float = 0.0
var _base_move_speed: float = 0.0
var battle_aura: MonkeyBattleAura

@onready var emitter: EnemySkillEmitter = $SkillEmitter

func _ready() -> void:
	wildlife = data as WildEnemyData
	assert(wildlife != null)
	_rng.randomize()
	for skill: EnemySkillData in wildlife.skills:
		_cooldowns[skill.skill_id] = 0.0
	super()
	# Runtime movement belongs to this actor; buffs must not edit shared .tres data.
	movement = movement.duplicate(true) as MovementStats
	_base_move_speed = movement.max_speed
	sensor.target_entered.connect(_announce_target)
	died.connect(_cancel_effects)
	play_anim(&"Idle")

func _pre_state_update(delta: float) -> void:
	super(delta)
	for skill: EnemySkillData in wildlife.skills:
		_cooldowns[skill.skill_id] = maxf(_cooldowns[skill.skill_id] - delta, 0.0)
	if _battle_buff_left > 0.0:
		_battle_buff_left = maxf(_battle_buff_left - delta, 0.0)
		if _battle_buff_left <= 0.0:
			movement.max_speed = _base_move_speed
			if wind_receiver != null: wind_receiver.set_push_immunity(false)
			if battle_aura != null: battle_aura.set_buff(false)

func play_anim(clip: StringName) -> void:
	_anim.speed_scale = 1.12 if battle_buff_active() and clip in [&"Walk", &"Run"] else 1.0
	super(_map_animation(clip))

func play_action(clip: StringName, speed: float = 1.0, blend: float = -1.0) -> void:
	_anim.speed_scale = 1.0
	super(_map_animation(clip), speed, blend)

func battle_buff_active() -> bool:
	return _battle_buff_left > 0.0

func resists_knockback() -> bool:
	return battle_buff_active()

func battle_attack_scale() -> float:
	return 1.12 if battle_buff_active() else 1.0

func apply_battle_buff(duration: float = 10.0) -> void:
	if is_dead(): return
	_battle_buff_left = maxf(duration, 0.0)
	movement.max_speed = _base_move_speed * 1.12
	if wind_receiver != null: wind_receiver.set_push_immunity(true)
	if battle_aura == null:
		battle_aura = MonkeyBattleAura.new()
		add_child(battle_aura)
	battle_aura.set_buff(true)

func start_attack_cooldown() -> void:
	super()
	if battle_buff_active(): _attack_cooldown_left *= 0.88

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
	return has_target() and (not skill.use_attack_cooldown or _attack_cooldown_left <= 0.0) and skill_cooldown(skill.skill_id) <= 0.0 and distance >= skill.minimum_range and distance <= skill.maximum_range

func skill_cooldown(id: StringName) -> float:
	return _cooldowns.get(id, 0.0)

func attack_cooldown_remaining() -> float:
	return _attack_cooldown_left

func begin_skill(skill: EnemySkillData) -> void:
	pending_skill = skill
	state_machine.transition_to(skill.state)

func start_skill_cooldown(skill: EnemySkillData) -> void:
	var scale: float = 0.88 if skill.cooldown_affected_by_buff and battle_buff_active() else 1.0
	_cooldowns[skill.skill_id] = maxf(0.0, skill.cooldown) * scale

func complete_skill(skill: EnemySkillData, completed: bool, cooldown_started: bool = false) -> void:
	if not cooldown_started: start_skill_cooldown(skill)
	if skill.use_attack_cooldown: start_attack_cooldown()
	skill_finished.emit(skill, completed)
	pending_skill = null

func root_offset(skill: EnemySkillData, elapsed: float) -> float:
	var clip: Animation = _anim.get_animation(skill.animation)
	if not clip.has_meta(&"root_forward_curve"): return 0.0
	var motion: Curve = clip.get_meta(&"root_forward_curve", null) as Curve
	if motion == null: return 0.0
	return motion.sample(clampf(elapsed * skill.anim_speed / maxf(clip.length, 0.001), 0.0, 1.0)) * wildlife.model_scale

func receive_rally(player: Node3D) -> void:
	if is_dead() or not is_instance_valid(player) or _returning_home: return
	target = player
	_announce_target(player)

func forget_target() -> void:
	_returning_home = distance_from_home() > data.patrol_radius + 0.5
	super()
	_alert_done = false
	_announced = false

func reacquire_target() -> void:
	var candidate: Node3D = sensor.target
	var nearby: bool = false
	if is_instance_valid(candidate):
		var toward: Vector3 = candidate.global_position - global_position
		toward.y = 0.0
		nearby = toward.length() <= wildlife.close_defense_range
	if _returning_home:
		if distance_from_home() > data.patrol_radius + 0.2 and not nearby: return
		_returning_home = false
	# Signal rời Area có thể đến sau một physics frame: không nhận lại mục tiêu đã xa.
	if has_target():
		if should_give_up_chase(): forget_target()
		return
	if not is_instance_valid(candidate) or is_dead(): return
	var offset: Vector3 = candidate.global_position - global_position
	offset.y = 0.0
	if offset.length() <= data.detect_range and (distance_from_home() <= data.leash_range or nearby):
		target = candidate
		_announce_target(candidate)

func should_give_up_chase() -> bool:
	if not has_target(): return true
	if target is Player and (target as Player).health.is_dead(): return true
	var distance: float = distance_to_target()
	return distance > data.lose_range or (distance_from_home() > data.leash_range and distance > wildlife.close_defense_range)

func _announce_target(player: Node3D) -> void:
	if _announced or is_dead(): return
	_announced = true
	engaged.emit(player)

func _on_target_entered(body: Node3D) -> void:
	if not _returning_home: super(body)

func _cancel_effects(_enemy: Enemy) -> void:
	emitter.cancel_all()
	_battle_buff_left = 0.0
	if wind_receiver != null: wind_receiver.set_push_immunity(false)
	if battle_aura != null: battle_aura.hide()

func _map_animation(clip: StringName) -> StringName:
	if wildlife == null: return clip
	if clip == &"Idle": return wildlife.idle_animation
	if clip == &"Walk": return wildlife.walk_animation
	if clip == &"Run": return wildlife.run_animation
	if clip == &"Hurt": return wildlife.hurt_animation
	if clip == &"Death": return wildlife.death_animation
	return clip
