class_name EnemyProjectileEmitter
extends Node
## Pool đạn độc lập với hazard: vỏ chuối đã ném vẫn tồn tại khi người ném chết.
signal projectile_fired(projectile: EnemyProjectile)
@export var pool_size: int = 3
@export var max_live_projectiles: int = 32
var pools: Dictionary[PackedScene, ObjectPool] = {}
var _held: Dictionary[ProjectileSkillData, Node3D] = {}
var _sockets: Dictionary[ProjectileSkillData, BoneAttachment3D] = {}
var _knives: Array[MeshInstance3D] = []
var _actor: WildEnemy
var _cast_visual: Node3D

func _ready() -> void:
	_actor = get_parent() as WildEnemy
	# Pool thuộc scene thế giới, không nằm dưới enemy sẽ bị xóa sau khi chết.
	var world: Node = _actor
	while world.get_parent() != get_tree().root and world.get_parent() != null:
		world = world.get_parent()
	var registry: Dictionary = world.get_meta(&"enemy_throwable_pools", {})
	world.set_meta(&"enemy_throwable_pools", registry)
	var skeleton: Skeleton3D
	var model: Node3D = _actor.get_node(^"Model") as Node3D
	for child: Node in model.find_children("*", "Skeleton3D", true, false): skeleton = child as Skeleton3D
	for mesh: Node in model.find_children("*knife*", "MeshInstance3D", true, false): _knives.append(mesh as MeshInstance3D)
	for skill: EnemySkillData in (_actor.data as WildEnemyData).skills:
		var ranged: ProjectileSkillData = skill as ProjectileSkillData
		if ranged == null: continue
		if not pools.has(ranged.projectile_scene):
			var pool: ObjectPool = registry.get(ranged.projectile_scene) as ObjectPool
			if pool == null:
				pool = ObjectPool.new()
				pool.name = &"EnemyThrowablePool"
				pool.scene = ranged.projectile_scene
				pool.initial_size = pool_size
				registry[ranged.projectile_scene] = pool
				world.add_child.call_deferred(pool)
			pools[ranged.projectile_scene] = pool
		if not ranged.hand_bone.is_empty() and skeleton != null:
			var socket: BoneAttachment3D = BoneAttachment3D.new()
			socket.bone_name = ranged.hand_bone
			skeleton.add_child(socket)
			_sockets[ranged] = socket
			if ranged.held_visual_scene == null: continue
			var held: Node3D = ranged.held_visual_scene.instantiate() as Node3D
			socket.add_child(held)
			held.scale = Vector3.ONE * ranged.held_scale
			held.visible = false
			_held[ranged] = held

func prepare_cast(skill: ProjectileSkillData) -> void:
	_cast_visual = _held.get(skill)
	if _cast_visual != null:
		_cast_visual.scale = Vector3.ONE * skill.held_scale / _cast_visual.get_parent_node_3d().global_basis.get_scale().abs()
		_cast_visual.visible = true
		for knife: MeshInstance3D in _knives: knife.visible = false

func finish_cast() -> void:
	if _cast_visual != null: _cast_visual.visible = false
	_cast_visual = null
	for knife: MeshInstance3D in _knives: knife.visible = true

func launch(skill: ProjectileSkillData, facing: Vector3) -> EnemyProjectile:
	var pool: ObjectPool = pools[skill.projectile_scene]
	if pool.get_active_count() >= max_live_projectiles: pool.release(pool.get_oldest_active())
	var projectile: EnemyProjectile = pool.acquire() as EnemyProjectile
	if not projectile.finished.is_connected(pool.release): projectile.finished.connect(pool.release)
	var at: Vector3 = _actor.global_position + Vector3.UP * skill.launch_height + facing * skill.launch_forward
	var socket: BoneAttachment3D = _sockets.get(skill)
	if socket != null: at = socket.global_position
	if _cast_visual != null:
		at = _cast_visual.global_position
		_cast_visual.visible = false
	var direction: Vector3 = facing
	if _actor.has_target():
		var target_at: Vector3 = _actor.target.global_position + Vector3.UP * 0.95
		direction = (target_at - at).normalized()
	projectile.launch(skill, at, direction, _actor, _actor.target)
	projectile_fired.emit(projectile)
	return projectile
