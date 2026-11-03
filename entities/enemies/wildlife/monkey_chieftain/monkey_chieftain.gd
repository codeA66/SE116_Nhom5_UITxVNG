class_name MonkeyChieftain
extends WildEnemy
## Vỗ ngực là buff 10 giây, hồi 20 giây; các cú vỗ phát sóng âm trong không gian.
@export var battlecry_radius: float = 8.0
@export var battlecry_duration: float = 10.0
@export var battlecry_cooldown: float = 20.0
@export var summon_cooldown: float = 20.0
@export var display_minimum_gap: float = 6.0
var _battlecry_left: float = 0.0
var _summon_left: float = 0.0
var _display_gap_left: float = 0.0
var _summoning: bool = false
var _next_summon: bool = false
var _next_boulder: bool = false
var _display_elapsed: float = 0.0
var _buff_applied: bool = false
@onready var summoner: ChieftainSummoner = $Summoner

func choose_skill() -> EnemySkillData:
	var desired: StringName = &"boulder_throw" if _next_boulder else &"leap_claw"
	for skill: EnemySkillData in wildlife.skills:
		if skill.skill_id == desired and skill_ready(skill): return skill
	# Chờ tới tầm nhảy thay vì lặp mãi đòn ném khi đang luân phiên.
	return null

func complete_skill(skill: EnemySkillData, completed: bool, cooldown_started: bool = false) -> void:
	if completed: _next_boulder = skill.skill_id == &"leap_claw"
	super(skill, completed, cooldown_started)

func alert_pending() -> bool:
	return has_target() and _display_gap_left <= 0.0 and (_battlecry_left <= 0.0 or (_summon_left <= 0.0 and summoner.can_summon()))

func begin_alert() -> float:
	_summoning = _summon_left <= 0.0 and summoner.can_summon() and (_next_summon or _battlecry_left > 0.0)
	if _summoning: _summon_left = summon_cooldown
	else: _battlecry_left = battlecry_cooldown
	_next_summon = not _summoning
	_display_gap_left = display_minimum_gap
	_display_elapsed = 0.0
	_buff_applied = false
	if battle_aura == null:
		battle_aura = MonkeyBattleAura.new()
		add_child(battle_aura)
	battle_aura.set_chant(true)
	return super()

func _pre_state_update(delta: float) -> void:
	super(delta)
	_battlecry_left = maxf(_battlecry_left - delta, 0.0)
	_summon_left = maxf(_summon_left - delta, 0.0)
	_display_gap_left = maxf(_display_gap_left - delta, 0.0)
	var displaying: bool = state_machine.current_state != null and state_machine.current_state.name == &"Display" and not is_dead()
	if battle_aura != null: battle_aura.set_chant(displaying)
	if not displaying: return
	_display_elapsed += delta
	if not _buff_applied and _display_elapsed >= 0.85:
		_buff_applied = true
		if _summoning:
			summoner.summon()
			return
		apply_battle_buff(battlecry_duration)
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			var monkey: MonkeyGrunt = node as MonkeyGrunt
			if monkey != null and global_position.distance_to(monkey.global_position) <= battlecry_radius:
				monkey.apply_battle_buff(battlecry_duration)
