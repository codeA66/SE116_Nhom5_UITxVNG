class_name TrapGardenChallenge
extends Node3D
signal cleared
@export var reward: OfferingBanana
@export var item: BananaItemPickup
@export var seals: Array[GardenSwitch] = []
@export var hazards: Array[GardenTimedSpikes] = []
@export var guards: Array[RoofBananaGrunt] = []
@export var moving_seals: Array[ShiftingGardenSeal] = []
@export var wind_ambush: GardenWindAmbush
var started: bool = false
var completed: bool = false
var _guard_ids: Array[int] = []
var _projectile_pools: Array[ObjectPool] = []

func _ready() -> void:
	_setup.call_deferred()

func _setup() -> void:
	reward.set_available(false)
	for seal: GardenSwitch in seals: seal.activated.connect(_check); seal.interaction.enabled = false
	for guard: RoofBananaGrunt in guards:
		guard.set_dormant(true); _guard_ids.append(guard.get_instance_id())
		for pool: ObjectPool in (guard.get_node("ProjectileEmitter") as EnemyProjectileEmitter).pools.values():
			if pool not in _projectile_pools: _projectile_pools.append(pool)

func is_cleared() -> bool:
	return completed

func begin(actor: Player) -> void:
	if started: return
	started = true
	for seal: GardenSwitch in seals: seal.interaction.enabled = true
	for hazard: GardenTimedSpikes in hazards: hazard.set_enabled(true)
	for guard: RoofBananaGrunt in guards:
		if is_instance_valid(guard) and not guard.is_dead(): guard.set_dormant(false); guard.receive_rally(actor)
	for mover: ShiftingGardenSeal in moving_seals: mover.begin()
	if wind_ambush: wind_ambush.begin(actor)

func _check() -> void:
	if not started or completed: return
	for seal: GardenSwitch in seals:
		if not seal.is_active(): return
	completed = true
	for mover: ShiftingGardenSeal in moving_seals: mover.stop()
	if wind_ambush: wind_ambush.stop()
	for pool: ObjectPool in _projectile_pools:
		for node: Node in pool.get_active():
			var projectile: EnemyProjectile = node as EnemyProjectile
			if projectile and projectile.source_instance_id in _guard_ids: projectile.cancel()
	for node: Node in get_parent().get_children():
		if node is EnemyProjectile: (node as EnemyProjectile).cancel()
	for hazard: GardenTimedSpikes in hazards: hazard.set_enabled(false)
	for guard: RoofBananaGrunt in guards:
		if is_instance_valid(guard) and not guard.is_dead(): guard.disable()
	GardenRewards.offering(reward); item.reveal()
	get_tree().create_timer(2.2,false).timeout.connect(func() -> void: cleared.emit())
