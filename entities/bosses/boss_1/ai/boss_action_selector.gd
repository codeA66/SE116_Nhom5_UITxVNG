class_name BossActionSelector
extends Node
## Một cửa chọn chiêu cho Idle/Chase; chiêu mở rộng đăng ký callable.

const ELIGIBLE_STATES: Array[StringName] = [&"Idle", &"Chase"]

@export var rules: Array[BossActionRule] = []

var _candidates: Array[Callable] = []
var _boss: Boss1


func _ready() -> void:
	_boss = owner as Boss1


func register_candidate(candidate: Callable) -> void:
	if candidate not in _candidates:
		_candidates.append(candidate)


func try_select(include_rules: bool = true) -> bool:
	if _boss.health.is_dead() or not is_instance_valid(_boss.target_player):
		return false
	if _boss.state_machine.current_state.name not in ELIGIBLE_STATES:
		return false
	for candidate: Callable in _candidates:
		if candidate.is_valid() and bool(candidate.call()):
			return true
	if not include_rules:
		return false
	var offset: Vector3 = _boss.target_player.global_position - _boss.global_position
	offset.y = 0.0
	var distance: float = offset.length()
	for rule: BossActionRule in rules:
		if rule.can_select(_boss, distance):
			_boss.state_machine.transition_to(rule.state)
			return true
	return false
