class_name GardenKingEncounter
extends Area3D
signal cleared
signal intro_requested
signal approached(player: Player)
signal guard_registered(guard: Enemy)
@export var guards: Array[Enemy] = []
@export var encounter_flag: StringName = &"level_1.monkey_king_defeated"
@export var introduction: CameraCutscene
@export var leader: MonkeyChieftain
@export var interface_layer: CanvasLayer
@export_range(0.1, 15.0, 0.1) var boss_peel_lifetime: float = 2.0
var fighting: bool = false
var started: bool = false
var _alive: int = 0
var _player: Player
var _hidden_layers: Dictionary[CanvasLayer,bool] = {}
var _tracked: Array[Enemy] = []
var _guard_ids: Array[int] = []
var _projectile_pools: Array[ObjectPool] = []
var _leader_defeated: bool = false
var _completed: bool = false

func _ready() -> void:
	_setup.call_deferred()
	body_entered.connect(_entered)

func _setup() -> void:
	if GameState.has_flag(encounter_flag):
		started = true; _completed = true; _leader_defeated = true
		set_deferred("monitoring",false)
		for guard: Enemy in guards:
			if is_instance_valid(guard): guard.queue_free()
		return
	if introduction:
		introduction.camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		introduction.started.connect(_hide_interface)
		introduction.shot_reached.connect(_introduce_leader)
		introduction.finished.connect(_fight)
	for guard: Enemy in guards:
		if not is_instance_valid(guard) or guard.is_dead(): continue
		guard.set_dormant(true); guard.process_mode = Node.PROCESS_MODE_DISABLED
		_track_guard(guard)
	if is_instance_valid(leader): leader.summoner.summoned.connect(_on_summoned)

func _track_guard(guard: Enemy) -> void:
	if not is_instance_valid(guard) or guard in _tracked or guard.is_dead(): return
	_tracked.append(guard); _guard_ids.append(guard.get_instance_id())
	guard_registered.emit(guard)
	guard.died.connect(_died,CONNECT_ONE_SHOT); _alive += 1
	var emitter: EnemyProjectileEmitter = guard.get_node_or_null("ProjectileEmitter") as EnemyProjectileEmitter
	if emitter:
		emitter.peel_lifetime_override = boss_peel_lifetime
		for pool: ObjectPool in emitter.pools.values():
			if pool not in _projectile_pools: _projectile_pools.append(pool)

func _on_summoned(monkeys: Array[MonkeyGrunt]) -> void:
	for monkey: MonkeyGrunt in monkeys:
		if not is_instance_valid(monkey): continue
		if monkey not in guards: guards.append(monkey)
		_track_guard(monkey)
	if _leader_defeated: _defeat_followers.call_deferred()

func _entered(body: Node3D) -> void:
	if started or not body is Player: return
	started = true; _player = body as Player; set_deferred("monitoring",false)
	approached.emit(_player)
	if introduction: intro_requested.emit()
	else: _fight()

func _introduce_leader() -> void:
	if not is_instance_valid(leader) or leader.is_dead(): return
	leader.process_mode = Node.PROCESS_MODE_INHERIT
	leader.face_instantly((_player.global_position-leader.global_position).normalized())
	leader.state_machine.transition_to(&"Introduction")

func _fight() -> void:
	for layer: CanvasLayer in _hidden_layers:
		if is_instance_valid(layer): layer.visible = _hidden_layers[layer]
	_hidden_layers.clear()
	if fighting or _leader_defeated: return
	fighting = true
	if is_instance_valid(leader) and not leader.is_dead():
		leader.complete_introduction()
		leader.state_machine.transition_to(&"Idle")
	for guard: Enemy in guards:
		if is_instance_valid(guard) and not guard.is_dead():
			guard.process_mode = Node.PROCESS_MODE_INHERIT
			guard.set_dormant(false)
			if guard is WildEnemy: (guard as WildEnemy).receive_rally(_player)
			else: guard.target = _player

func _hide_interface() -> void:
	if is_instance_valid(interface_layer):
		_hidden_layers[interface_layer] = interface_layer.visible; interface_layer.hide()
	# HUD chuẩn do CameraCutscene phục hồi; các thẻ item phụ cần giữ trạng thái riêng.
	var hud: Node = _player.get_node_or_null("HUD")
	for layer: CanvasLayer in _player.find_children("*","CanvasLayer",true,false):
		if layer == hud: continue
		_hidden_layers[layer] = layer.visible; layer.hide()

func _died(enemy: Enemy) -> void:
	_alive -= 1
	if enemy == leader:
		_leader_defeated = true; fighting = false
		# Chết theo dây chuyền ngoài callback physics, vẫn đi qua Health/FSM và hủy ngòi nổ bình thường.
		_defeat_followers.call_deferred()
	elif _alive<=0: _complete()

func _defeat_followers() -> void:
	for guard: Enemy in guards:
		if not is_instance_valid(guard) or guard == leader or guard.is_dead(): continue
		guard.process_mode = Node.PROCESS_MODE_INHERIT
		guard.on_lethal_zone_entered()
	# Pool dùng chung toàn map: chỉ hủy chuối thuộc quân của trận boss.
	for pool: ObjectPool in _projectile_pools:
		if not is_instance_valid(pool): continue
		for node: Node in pool.get_active():
			var projectile: EnemyProjectile = node as EnemyProjectile
			if projectile and projectile.source_instance_id in _guard_ids: projectile.cancel()
	if _alive<=0: _complete()

func _complete() -> void:
	if _completed: return
	_completed = true
	GameState.set_flag(encounter_flag); cleared.emit()
