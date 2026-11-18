class_name ChanEncounter
extends Node3D
## Giữ vòng đời hai lượt lính và các vách chia sân.

signal phase_changed(phase: Phase)

enum Phase { INACTIVE, ARENA, FULL_ROOM, CLEARED }

const KEEPER_SCENE: PackedScene = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/chan_keeper/chan_keeper.tscn")

@export var circuit: ChanCircuit
@export var spawn: Marker3D
@export var second_spawn: Marker3D
@export var battle_chase_range: float = 55.0
@export var walls: Array[Node3D] = []
@export var wall_collisions: Array[CollisionShape3D] = []
@export_range(0.05, 5.0, 0.05, "or_greater") var wall_lower_time: float = 0.65
@export var wall_lower_depth: float = 3.1

var phase: Phase = Phase.INACTIVE
var _keeper: ShieldBearer
var _armor: ChanArmorGuard
var _wall_motion: Tween


func start() -> void:
	if phase != Phase.INACTIVE:
		return
	_set_phase(Phase.ARENA)
	_spawn_keeper()


func reset(completed: bool) -> void:
	_clear_keeper()
	_set_walls_lowered(completed, false)
	_set_phase(Phase.CLEARED if completed else Phase.INACTIVE)


func _spawn_keeper() -> void:
	_keeper = KEEPER_SCENE.instantiate() as ShieldBearer
	_armor = _keeper.get_node(^"HurtboxComponent/ForgeArmor") as ChanArmorGuard
	var point: Marker3D = second_spawn if phase == Phase.FULL_ROOM else spawn
	_keeper.position = to_local(point.global_position)
	if phase == Phase.FULL_ROOM:
		var combat_data: EnemyData = _keeper.data.duplicate() as EnemyData
		combat_data.detect_range = battle_chase_range
		combat_data.lose_range = battle_chase_range
		combat_data.leash_range = battle_chase_range
		combat_data.patrol_radius = 0.0
		_keeper.data = combat_data
	_keeper.died.connect(_on_keeper_died, CONNECT_DEFERRED)
	if phase == Phase.ARENA:
		circuit.attach_keeper(_keeper, _armor)
	add_child(_keeper)
	if phase == Phase.FULL_ROOM:
		_armor.break_armor()


func _on_keeper_died(enemy: Enemy) -> void:
	if enemy != _keeper:
		return
	var armor_intact: bool = _armor.enabled
	_clear_keeper()
	if phase == Phase.ARENA:
		if armor_intact:
			_spawn_keeper()
			return
		_set_walls_lowered(true, true)
		_set_phase(Phase.FULL_ROOM)
		_spawn_keeper()
	elif phase == Phase.FULL_ROOM:
		_set_phase(Phase.CLEARED)


func _clear_keeper() -> void:
	circuit.attach_keeper(null, null)
	if is_instance_valid(_keeper):
		_keeper.queue_free()
	_keeper = null
	_armor = null


func _set_phase(next: Phase) -> void:
	if phase != next:
		phase = next
		phase_changed.emit(phase)


func _set_walls_lowered(lowered: bool, animate: bool) -> void:
	if _wall_motion:
		_wall_motion.kill()
	var height: float = -wall_lower_depth if lowered else 0.0
	if not animate:
		for wall: Node3D in walls:
			wall.position.y = height
		for collision: CollisionShape3D in wall_collisions:
			collision.set_deferred(&"disabled", lowered)
		return
	_wall_motion = create_tween().set_parallel()
	for wall: Node3D in walls:
		_wall_motion.tween_property(wall, ^"position:y", height, wall_lower_time).set_trans(Tween.TRANS_QUAD)
	_wall_motion.chain().tween_callback(_disable_walls)


func _disable_walls() -> void:
	for collision: CollisionShape3D in wall_collisions:
		collision.set_deferred(&"disabled", true)
