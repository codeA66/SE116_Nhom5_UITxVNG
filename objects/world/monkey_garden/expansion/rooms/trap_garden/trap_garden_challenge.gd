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
	_resolve_moving_seals()
	reward.set_available(false)
	for seal: GardenSwitch in seals:
		if is_instance_valid(seal): seal.activated.connect(_check); seal.interaction.enabled = false
	for guard: RoofBananaGrunt in guards:
		if not is_instance_valid(guard): continue
		guard.set_dormant(true); _guard_ids.append(guard.get_instance_id())
		for pool: ObjectPool in (guard.get_node("ProjectileEmitter") as EnemyProjectileEmitter).pools.values():
			if pool not in _projectile_pools: _projectile_pools.append(pool)

func is_cleared() -> bool:
	return completed

func begin(actor: Player) -> void:
	if started: return
	started = true
	for seal: GardenSwitch in seals:
		if is_instance_valid(seal): seal.interaction.enabled = true
	for hazard: GardenTimedSpikes in hazards:
		if is_instance_valid(hazard): hazard.set_enabled(true)
	for guard: RoofBananaGrunt in guards:
		if is_instance_valid(guard) and not guard.is_dead(): guard.set_dormant(false); guard.receive_rally(actor)
	for mover: ShiftingGardenSeal in moving_seals:
		if is_instance_valid(mover): mover.begin()
	if is_instance_valid(wind_ambush): wind_ambush.begin(actor)

func _check() -> void:
	if not started or completed or seals.is_empty(): return
	for seal: GardenSwitch in seals:
		if not is_instance_valid(seal) or not seal.is_active(): return
	completed = true
	for mover: ShiftingGardenSeal in moving_seals:
		if is_instance_valid(mover): mover.stop()
	if is_instance_valid(wind_ambush): wind_ambush.stop()
	for pool: ObjectPool in _projectile_pools:
		for node: Node in pool.get_active():
			var projectile: EnemyProjectile = node as EnemyProjectile
			if projectile and projectile.source_instance_id in _guard_ids: projectile.cancel()
	for node: Node in get_parent().get_children():
		if node is EnemyProjectile: (node as EnemyProjectile).cancel()
	for hazard: GardenTimedSpikes in hazards:
		if is_instance_valid(hazard): hazard.set_enabled(false)
	for guard: RoofBananaGrunt in guards:
		if is_instance_valid(guard) and not guard.is_dead(): guard.disable()
	GardenRewards.offering(reward); item.reveal()
	get_tree().create_timer(2.2,false).timeout.connect(func() -> void: cleared.emit())

func _resolve_moving_seals() -> void:
	# Editor có thể làm mất tham chiếu khi reload script: khôi phục theo bia mà mỗi component quản lý.
	var candidates: Array[ShiftingGardenSeal] = []
	for mover: ShiftingGardenSeal in moving_seals:
		if is_instance_valid(mover) and mover not in candidates: candidates.append(mover)
	for child: Node in get_parent().get_children():
		var mover: ShiftingGardenSeal = child as ShiftingGardenSeal
		if is_instance_valid(mover) and mover not in candidates: candidates.append(mover)
	moving_seals.clear()
	for seal: GardenSwitch in seals:
		if not is_instance_valid(seal): continue
		for mover: ShiftingGardenSeal in candidates:
			if mover.seal == seal:
				moving_seals.append(mover)
				break
