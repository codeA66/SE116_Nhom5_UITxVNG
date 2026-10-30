class_name EnemySensor
extends Area3D
## Vùng phát hiện mục tiêu (player) quanh quái. Theo dõi bằng signal vào/ra, không quét mỗi frame.
## Hình cầu bán kính `radius`; mask chỉnh trong scene (mặc định layer player).

signal target_entered(target: Node3D)
signal target_exited(target: Node3D)

@export var radius: float = 7.0:
	set(value):
		radius = maxf(value, 0.1)
		if is_node_ready():
			_apply_radius()

## Mục tiêu đang ở trong vùng (null nếu không có)
var target: Node3D

@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	monitorable = false
	_apply_radius()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _apply_radius() -> void:
	var sphere := _shape.shape as SphereShape3D
	if sphere:
		sphere.radius = radius


func _on_body_entered(body: Node3D) -> void:
	if target == null:
		target = body
		target_entered.emit(body)


func _on_body_exited(body: Node3D) -> void:
	if body == target:
		target = null
		target_exited.emit(body)
