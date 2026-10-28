class_name MonkeyChieftain
extends WildEnemy
## Vỗ ngực là buff 10 giây, hồi 20 giây; các cú vỗ phát sóng âm trong không gian.
@export var battlecry_radius: float = 8.0
@export var battlecry_duration: float = 10.0
@export var battlecry_cooldown: float = 20.0
var _battlecry_left: float = 0.0
var _display_elapsed: float = 0.0
var _buff_applied: bool = false

func alert_pending() -> bool:
	return _battlecry_left <= 0.0 and has_target()

func begin_alert() -> float:
	_battlecry_left = battlecry_cooldown
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
	var displaying: bool = state_machine.current_state != null and state_machine.current_state.name == &"Display" and not is_dead()
	if battle_aura != null: battle_aura.set_chant(displaying)
	if not displaying: return
	_display_elapsed += delta
	if not _buff_applied and _display_elapsed >= 0.85:
		_buff_applied = true
		apply_battle_buff(battlecry_duration)
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			var monkey: MonkeyGrunt = node as MonkeyGrunt
			if monkey != null and global_position.distance_to(monkey.global_position) <= battlecry_radius:
				monkey.apply_battle_buff(battlecry_duration)
