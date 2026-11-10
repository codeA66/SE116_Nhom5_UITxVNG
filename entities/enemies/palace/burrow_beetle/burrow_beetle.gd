class_name BurrowBeetle
extends Enemy
## Bọ canh một chỗ. State điều khiển lúc trồi, bắn và chui xuống.

signal seed_fired(seed: StoneSeed)

@export var burrow_distance: float = 5.0
@export var rise_distance: float = 6.5
## Khung 14 của clip Attack, tính từ khung 1 ở 30 fps.
@export var shot_time: float = 0.433333

var _muzzle_index: int
var _skeleton: Skeleton3D

@onready var pool: ObjectPool = $SeedPool
@onready var _skin: Node3D = $Model/Visual/BeetleSkin


func _ready() -> void:
	_anim = _skin.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_skeleton = _skin.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_muzzle_index = _skeleton.find_bone(&"Muzzle")
	assert(_muzzle_index >= 0, "Bọ Đất thiếu xương Muzzle")
	_anim.get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
	super()
	wind_receiver.enabled = false
	wind_receiver.monitorable = false
	wind_receiver.monitoring = false
	died.connect(_on_beetle_died)


func clip_length(clip: StringName) -> float:
	return _anim.get_animation(clip).length


func resists_knockback() -> bool:
	return true


## Character xoay Model theo góc cục bộ, còn hướng tới mục tiêu là hướng thế giới.
func face_direction(direction: Vector3, delta: float) -> void:
	super(global_basis.inverse() * direction, delta)


func face_instantly(direction: Vector3) -> void:
	super(global_basis.inverse() * direction)


func get_facing_direction() -> Vector3:
	return (global_basis * super()).normalized()


func set_exposed(exposed: bool) -> void:
	hurtbox.invulnerable = not exposed
	hurtbox.set_deferred(&"collision_layer", 4 if exposed else 0)
	set_deferred(&"collision_layer", 4 if exposed else 0)


func fire_seed() -> void:
	if not has_target():
		return
	var spawn := _skeleton.to_global(_skeleton.get_bone_global_pose(_muzzle_index).origin)
	var projectile := pool.acquire() as StoneSeed
	if not projectile.finished.is_connected(pool.release):
		projectile.finished.connect(pool.release)
	projectile.launch(spawn, target.global_position + Vector3.UP * 0.75, self)
	seed_fired.emit(projectile)


func _on_beetle_died(_enemy: Enemy) -> void:
	pool.release_all()
