class_name GardenIntroChallenge
extends Node3D
signal cleared
signal guards_defeated
@export var guards: Array[Enemy] = []
@export var gates: Array[GardenLiftGate] = []
@export var reward: OfferingBanana
@export var guide: GardenTotemGuide
@export var pedestals: Array[OfferingPedestal] = []
var enemies_cleared: bool = false
var completed: bool = false
var _alive: int
var _picked_up: bool = false

func _ready() -> void:
	_initialize.call_deferred()

func _initialize() -> void:
	_alive = guards.size()
	for guard: Enemy in guards: guard.died.connect(_guard_died)
	guide.read_completed.connect(_try_finish)
	reward.interaction.interacted.connect(_picked_up_reward)
	for pedestal: OfferingPedestal in pedestals: pedestal.activated.connect(_try_finish)
	guide.set_enabled(false); reward.set_available(false)
	for gate: GardenLiftGate in gates: gate.set_locked(self,true)
	if _alive == 0: _all_defeated()

func is_cleared() -> bool:
	return completed

func _guard_died(_enemy: Enemy) -> void:
	_alive -= 1
	if _alive == 0: _all_defeated.call_deferred()

func _all_defeated() -> void:
	if enemies_cleared: return
	enemies_cleared = true; guards_defeated.emit(); GardenRewards.offering(reward)

func _picked_up_reward(_actor: Node3D) -> void:
	# Offering nhận F trước callback này, nên có thể xác nhận đã mang thật sự.
	if not enemies_cleared or reward.location != OfferingBanana.Location.CARRIED: return
	_picked_up = true; guide.set_enabled(true)

func _try_finish() -> void:
	if completed or not enemies_cleared or not _picked_up or not guide.has_been_read: return
	var offered: bool = false
	for pedestal: OfferingPedestal in pedestals:
		if pedestal.item == reward: offered = true; break
	if not offered: return
	completed = true
	for gate: GardenLiftGate in gates: gate.set_locked(self,false)
	cleared.emit()
