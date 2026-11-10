class_name ChieftainBoulderEmitter
extends Node3D
## Đá giữ ở giữa hai lòng bàn tay, rời tay đúng marker; đạn tiếp tục sống khi người ném chết.

signal boulder_released(volley: BoulderVolley)
const VOLLEY: PackedScene = preload("res://objects/combat/projectiles/chieftain_boulder/boulder_volley.tscn")
var _actor: WildEnemy
var _skeleton: Skeleton3D
var _left: int
var _right: int
var _held: MeshInstance3D
var _pool: ObjectPool
var _volley: BoulderVolley
var _skill: BoulderThrowSkillData

func _ready() -> void:
	_actor = get_parent() as WildEnemy
	_skeleton = _actor.get_node("Model/Visual/Rig").find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_left = _skeleton.find_bone("CATRigLArmPalm")
	_right = _skeleton.find_bone("CATRigRArmPalm001")
	_held = BoulderVolley.stone()
	add_child(_held)
	_held.hide()
	var world: Node = _actor
	while world.get_parent() != get_tree().root and world.get_parent() != null: world = world.get_parent()
	_pool = world.get_node_or_null("ChieftainBoulderPool") as ObjectPool
	if _pool == null:
		_pool = ObjectPool.new()
		_pool.name = "ChieftainBoulderPool"
		_pool.scene = VOLLEY
		_pool.initial_size = 2
		world.add_child.call_deferred(_pool)
	set_process(false)

func prepare(skill: BoulderThrowSkillData) -> void:
	_skill = skill
	_volley = _pool.acquire() as BoulderVolley
	if not _volley.finished.is_connected(_pool.release): _volley.finished.connect(_pool.release)
	_volley.prepare(skill, target_position(), _actor)
	_held.scale = Vector3.ONE * skill.rock_radius
	_held.show()
	set_process(true)
	_process(0.0)

func track_target() -> void:
	if _volley != null: _volley.aim(target_position())

func target_position() -> Vector3:
	var at: Vector3 = _actor.target.global_position if _actor.has_target() else _actor.global_position + _actor.get_facing_direction() * 6.0
	var ground: Dictionary = _actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3, at - Vector3.UP * 15, 257))
	return ground.position if not ground.is_empty() else at

func release_boulder() -> void:
	if _volley == null: return
	_process(0.0)
	_volley.launch(_held.global_position)
	boulder_released.emit(_volley)
	_volley = null
	_held.hide()
	set_process(false)

func cancel() -> void:
	_held.hide()
	set_process(false)
	if _volley != null:
		_pool.release(_volley)
		_volley = null

func _process(_delta: float) -> void:
	var a: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(_left).origin
	var b: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(_right).origin
	_held.global_position = (a + b) * 0.5
