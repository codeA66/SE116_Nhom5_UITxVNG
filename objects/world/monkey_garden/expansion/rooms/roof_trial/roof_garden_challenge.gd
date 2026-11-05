class_name RoofGardenChallenge
extends Node3D
signal cleared
@export var guards: Array[Enemy] = []
@export var reward: OfferingBanana
@export var item: BananaItemPickup
@export_range(0.0, 10.0, 0.1) var reward_delay: float = 2.2
var started: bool = false
var completed: bool = false
var _alive: int = 0
var _player: Player
var _tracked: Array[Enemy] = []

func _ready() -> void:
	_setup.call_deferred()

func _setup() -> void:
	reward.set_available(false)
	for guard: Enemy in guards:
		_track_guard(guard)

func register_guard(guard: Enemy) -> void:
	if not is_instance_valid(guard) or completed: return
	if guard not in guards: guards.append(guard)
	_track_guard(guard)
	if started: _wake_guard(guard)

func is_cleared() -> bool:
	return completed

func begin(player: Player) -> void:
	if started or completed: return
	started = true
	_player = player
	for guard: Enemy in guards:
		_wake_guard(guard)
	_check()

func _track_guard(guard: Enemy) -> void:
	if not is_instance_valid(guard) or guard in _tracked or guard.is_dead(): return
	_tracked.append(guard)
	guard.set_dormant(true)
	guard.process_mode = Node.PROCESS_MODE_DISABLED
	guard.died.connect(_guard_died)
	_alive += 1

func _wake_guard(guard: Enemy) -> void:
	if not is_instance_valid(guard) or guard.is_dead(): return
	guard.process_mode = Node.PROCESS_MODE_INHERIT
	guard.set_dormant(false)
	if guard is WildEnemy: (guard as WildEnemy).receive_rally(_player)
	else: guard.target = _player

func _guard_died(_guard: Enemy) -> void:
	_alive -= 1; _check()

func _check() -> void:
	if not started or completed or _alive>0: return
	completed = true
	GardenRewards.offering(reward); item.reveal()
	get_tree().create_timer(reward_delay,false).timeout.connect(func() -> void: cleared.emit())
