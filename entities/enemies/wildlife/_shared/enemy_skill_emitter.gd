class_name EnemySkillEmitter
extends Node
## Pool riêng cho mỗi loại phép, không tạo/xoá hiệu ứng liên tục trong giao tranh.
signal hazard_spawned(hazard: EnemyHazard, skill: EnemySkillData)
@export var prewarm_count: int = 2
var pools: Dictionary[PackedScene, ObjectPool] = {}
var _actor: WildEnemy

func _ready() -> void:
	_actor = get_parent() as WildEnemy
	var config: WildEnemyData = _actor.data as WildEnemyData
	for skill: EnemySkillData in config.skills:
		if skill.effect_scene == null or pools.has(skill.effect_scene): continue
		var pool: ObjectPool = ObjectPool.new()
		pool.name = String(skill.skill_id) + "Pool"
		pool.scene = skill.effect_scene
		pool.initial_size = prewarm_count
		pools[skill.effect_scene] = pool
		add_child(pool)

func emit_skill(skill: EnemySkillData, facing: Vector3) -> EnemyHazard:
	var pool: ObjectPool = pools.get(skill.effect_scene)
	if pool == null: return null
	var hazard: EnemyHazard = pool.acquire() as EnemyHazard
	var release: Callable = pool.release.bind(hazard)
	if not hazard.finished.is_connected(release): hazard.finished.connect(release)
	var at: Vector3 = _actor.global_position + facing * skill.effect_forward_offset
	if skill.effect_at_target and _actor.has_target(): at = _actor.target.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 20.0, 257)
	var floor_hit: Dictionary = _actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not floor_hit.is_empty(): at.y = (floor_hit["position"] as Vector3).y
	hazard.start(skill, at, facing)
	hazard_spawned.emit(hazard, skill)
	return hazard

func cancel_all() -> void:
	for pool: ObjectPool in pools.values(): pool.release_all()
