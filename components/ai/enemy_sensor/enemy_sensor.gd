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
var _observed_player: Player

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
	var player: Player = body as Player
	if player and player != _observed_player:
		_disconnect_observer()
		_observed_player = player
		_observed_player.targetability_changed.connect(_on_player_targetability_changed)
	if player and not player.is_targetable():
		return
	if target == null:
		target = body
		target_entered.emit(body)


func _on_body_exited(body: Node3D) -> void:
	if body == _observed_player:
		_disconnect_observer()
	if body == target:
		target = null
		target_exited.emit(body)


func _on_player_targetability_changed(targetable: bool) -> void:
	if targetable and monitoring and target == null and is_instance_valid(_observed_player):
		target = _observed_player
		target_entered.emit(target)
	elif not targetable and target == _observed_player:
		target = null
		target_exited.emit(_observed_player)


func _disconnect_observer() -> void:
	if is_instance_valid(_observed_player):
		_observed_player.targetability_changed.disconnect(_on_player_targetability_changed)
	_observed_player = null
