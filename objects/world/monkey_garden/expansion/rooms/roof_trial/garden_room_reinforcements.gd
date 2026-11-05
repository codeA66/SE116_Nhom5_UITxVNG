class_name GardenRoomReinforcements
extends Node
## Sinh một nhóm quái duy nhất khi vào phòng, cùng tham gia điều kiện clear của thử thách.
@export var trigger: Area3D
@export var challenge: RoofGardenChallenge
@export var enemy_scene: PackedScene
@export var spawn_points: Array[Marker3D] = []
var _requested: bool = false

func _ready() -> void:
	trigger.body_entered.connect(_entered)

func _entered(body: Node3D) -> void:
	if _requested or not body is Player or challenge.is_cleared(): return
	_requested = true
	# Tạo collider sau callback vật lý để không thay đổi vùng quét đang flush.
	_spawn.call_deferred()

func _spawn() -> void:
	for index: int in spawn_points.size():
		var point: Marker3D = spawn_points[index]
		if not is_instance_valid(point): continue
		var guard: Enemy = enemy_scene.instantiate() as Enemy
		guard.name = "GroundGuard_" + str(index + 1)
		guard.transform = (get_parent() as Node3D).global_transform.affine_inverse() * point.global_transform
		guard.process_mode = Node.PROCESS_MODE_DISABLED
		get_parent().add_child(guard)
		challenge.register_guard(guard)
