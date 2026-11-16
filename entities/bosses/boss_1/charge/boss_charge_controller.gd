class_name BossChargeController
extends Node
## Đăng ký Charge vào bộ chọn chung; giữ API ép chiêu cho debug.

@export var enabled: bool = true
@export var charge: BossCharge
@export var eligible_states: Array[StringName] = [&"Idle", &"Chase"]
@export var debug_force_charge: bool = false:
	set(value):
		debug_force_charge = value
		if value and is_node_ready():
			_try_charge.call_deferred()
@export var debug_log: bool = false

var _boss: Boss1
var _machine: StateMachine

@onready var _cooldown: Timer = $Cooldown

func _ready() -> void:
	_boss = owner as Boss1
	assert(_boss != null and charge != null)
	await _boss.ready
	_machine = _boss.state_machine
	_boss.action_selector.register_candidate(_select_charge)
	_machine.state_changed.connect(_on_state_changed)
	charge.charge_started.connect(_on_charge_started)
	_cooldown.timeout.connect(_try_charge)
	_try_charge.call_deferred()

func request_charge(ignore_chance: bool = false) -> bool:
	if not enabled or not charge.data.enabled or not _cooldown.is_stopped():
		return false
	if _machine == null or _machine.current_state == null or _machine.current_state.name not in eligible_states:
		return false
	if not is_instance_valid(_boss.target_player) or not _boss.is_on_floor():
		return false
	if _boss.health.is_dead() or _boss.current_phase < charge.data.first_phase:
		return false
	if _boss.is_shielded and not charge.data.allow_while_shielded:
		return false
	var offset: Vector3 = _boss.target_player.global_position - _boss.global_position
	offset.y = 0.0
	var distance: float = offset.length()
	if distance < charge.data.minimum_range or distance > charge.data.maximum_range:
		return false
	if not ignore_chance:
		var chance: float = clampf(charge.data.selection_chance, 0.0, 1.0)
		if chance <= 0.0 or (chance < 1.0 and randf() >= chance):
			return false
	_machine.transition_to(charge.name)
	return true

func get_cooldown_remaining() -> float:
	return _cooldown.time_left

func _on_state_changed(_from: StringName, to: StringName) -> void:
	if to in eligible_states:
		_try_charge.call_deferred()

func _on_charge_started(_direction: Vector3) -> void:
	var duration: float = charge.data.get_cooldown(_boss.current_phase)
	if duration > 0.0:
		_cooldown.start(duration)
	if debug_log:
		print("Charge: phase=", _boss.current_phase, " cooldown=", duration)

func _select_charge() -> bool:
	return request_charge(debug_force_charge)

func _try_charge() -> void:
	if enabled and _boss != null and _boss.is_node_ready():
		_boss.action_selector.try_select(false)
