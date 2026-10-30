extends Node3D
## Hitbox hình quạt và VFX dùng cùng bán kính, cùng signal bật từng nhát.
const SLASH: PackedScene=preload("res://assets/vfx/enemies/wolf/werewolf/wolf_claw_slash.tscn")
var pool: ObjectPool
var _index: int=0
var _combo: ClawComboSkillData
var _actor: WildEnemy
var _hitbox: HitboxComponent

func _ready() -> void:
	_actor=get_parent() as WildEnemy
	_combo=(_actor.data as WildEnemyData).skills[0] as ClawComboSkillData
	_hitbox=_actor.get_node("Model/Hitbox") as HitboxComponent
	var collision: CollisionShape3D=_hitbox.get_node("CollisionShape3D") as CollisionShape3D
	var shape: ConvexPolygonShape3D=ConvexPolygonShape3D.new()
	var points: PackedVector3Array=PackedVector3Array()
	for height_value: float in [0.0,_combo.hit_height]:
		points.append(Vector3(0,height_value,0))
		for i: int in 15:
			var angle: float=deg_to_rad(_combo.slash_arc_degrees)*(float(i)/14.0-.5)
			points.append(Vector3(sin(angle)*_combo.slash_radius,height_value,cos(angle)*_combo.slash_radius))
	shape.points=points;collision.position=Vector3.ZERO;collision.shape=shape
	pool=ObjectPool.new();pool.scene=SLASH;pool.initial_size=2;add_child(pool)
	_hitbox.activated.connect(_swing)
	_actor.skill_started.connect(_begin)
	_actor.skill_finished.connect(_finish)

func _begin(_skill: EnemySkillData) -> void:
	_index=0

func _finish(_skill: EnemySkillData,completed: bool) -> void:
	if not completed:pool.release_all()

func _swing(attack: AttackData) -> void:
	if attack!=_combo:return
	var slash: WolfClawSlash=pool.acquire() as WolfClawSlash
	slash.play(_actor.model.global_transform,_combo,_index,_hitbox.get_active_duration())
	_index+=1
