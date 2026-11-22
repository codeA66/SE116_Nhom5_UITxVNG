class_name ChanEncounter
extends Node3D
## Giữ vòng đời hai đợt quái và các vách chia sân.

signal phase_changed(phase: Phase)

enum Phase { INACTIVE, ARENA, FULL_ROOM, CLEARED }

@export var arena_wave: Dictionary[NodePath, PackedScene] = {}
@export var full_room_wave: Dictionary[NodePath, PackedScene] = {}
@export var battle_chase_range: float = 55.0
@export var walls: Array[Node3D] = []
@export var wall_collisions: Array[CollisionShape3D] = []
@export_range(0.05, 5.0, 0.05, "or_greater") var wall_lower_time: float = 0.65
@export var wall_lower_depth: float = 3.1

var phase: Phase = Phase.INACTIVE
var _player: Player
var _alive: Array[Enemy] = []
var _web_patches: Array[WebPatch] = []
var _wall_motion: Tween

@onready var _enemies: Node3D = $Enemies


func start(player: Player) -> void:
	if phase != Phase.INACTIVE:
		return
	_player = player
	_set_phase(Phase.ARENA)
	_spawn_wave(arena_wave)


func reset(completed: bool) -> void:
	_player = null
	_alive.clear()
	for enemy: Node in _enemies.get_children():
		enemy.queue_free()
	_clear_web_patches()
	_set_walls_lowered(completed, false)
	_set_phase(Phase.CLEARED if completed else Phase.INACTIVE)


func _spawn_wave(wave: Dictionary[NodePath, PackedScene]) -> void:
	for marker_path: NodePath in wave:
		var marker: Marker3D = get_node(marker_path) as Marker3D
		var enemy: Enemy = wave[marker_path].instantiate() as Enemy
		enemy.transform = _enemies.global_transform.affine_inverse() * marker.global_transform
		if phase == Phase.FULL_ROOM:
			_configure_full_room_chase(enemy)
		enemy.died.connect(_on_enemy_died, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
		_alive.append(enemy)
		_enemies.add_child(enemy)
		enemy.target = _player
		var spider: FireSpider = enemy as FireSpider
		if spider != null:
			spider.web_fired.connect(_on_web_fired)


func _configure_full_room_chase(enemy: Enemy) -> void:
	var combat_data: EnemyData = enemy.data.duplicate() as EnemyData
	combat_data.detect_range = battle_chase_range
	combat_data.lose_range = battle_chase_range
	combat_data.leash_range = battle_chase_range
	combat_data.patrol_radius = 0.0
	enemy.data = combat_data


func _on_enemy_died(enemy: Enemy) -> void:
	if not _alive.has(enemy):
		return
	_alive.erase(enemy)
	if not _alive.is_empty():
		return
	if phase == Phase.ARENA:
		_set_walls_lowered(true, true)
	elif phase == Phase.FULL_ROOM:
		_set_phase(Phase.CLEARED)
		_clear_web_patches()


func _on_web_fired(bolt: WebBolt) -> void:
	if not bolt.landed.is_connected(_on_web_landed):
		bolt.landed.connect(_on_web_landed, CONNECT_ONE_SHOT)


func _on_web_landed(patch: WebPatch, _on_player: bool) -> void:
	if _alive.is_empty():
		patch.queue_free()
		return
	_web_patches.append(patch)
	patch.tree_exiting.connect(_forget_web_patch.bind(patch), CONNECT_ONE_SHOT)


func _forget_web_patch(patch: WebPatch) -> void:
	_web_patches.erase(patch)


func _clear_web_patches() -> void:
	# Mảng tơ chỉ chứa đạn của quái trong trận này.
	for patch: WebPatch in _web_patches:
		patch.queue_free()


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
	_wall_motion.chain().tween_callback(_start_full_room)


func _start_full_room() -> void:
	if not is_instance_valid(_player) or _player.health.is_dead():
		return
	for collision: CollisionShape3D in wall_collisions:
		collision.set_deferred(&"disabled", true)
	_set_phase(Phase.FULL_ROOM)
	_spawn_wave(full_room_wave)
