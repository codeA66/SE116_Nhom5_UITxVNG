class_name RoofGardenChallenge
extends Node3D
signal cleared
@export var guards: Array[RoofBananaGrunt] = []
@export var reward: OfferingBanana
@export var item: BananaItemPickup
@export_range(0.0, 10.0, 0.1) var reward_delay: float = 2.2
var started: bool = false
var completed: bool = false
var _alive: int = 0

func _ready() -> void:
	_setup.call_deferred()

func _setup() -> void:
	reward.set_available(false)
	for guard: RoofBananaGrunt in guards:
		guard.set_dormant(true)
		guard.died.connect(_guard_died)
		_alive += 1

func is_cleared() -> bool:
	return completed

func begin(player: Player) -> void:
	if started or completed: return
	started = true
	for guard: RoofBananaGrunt in guards:
		if is_instance_valid(guard) and not guard.is_dead():
			guard.set_dormant(false); guard.receive_rally(player)
	_check()

func _guard_died(_guard: Enemy) -> void:
	_alive -= 1; _check()

func _check() -> void:
	if not started or completed or _alive>0: return
	completed = true
	GardenRewards.offering(reward); item.reveal()
	get_tree().create_timer(reward_delay,false).timeout.connect(func() -> void: cleared.emit())
