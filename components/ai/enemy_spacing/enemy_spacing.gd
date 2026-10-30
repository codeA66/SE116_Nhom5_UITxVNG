class_name EnemySpacing
extends Area3D
## Va chạm cứng chặn chồng người; hướng tránh nhẹ giúp quái đi vòng đồng đội phía trước.
@export var separation_radius: float = 1.25:
	set(value):
		separation_radius = maxf(value, 0.05)
		if is_node_ready(): _apply_radius()
@export var separation_strength: float = 0.9
var _body: CharacterBody3D
var _neighbors: Dictionary[int, CharacterBody3D] = {}

func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	_apply_radius()
	monitorable = false
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)

func steer(direction: Vector3) -> Vector3:
	if direction.is_zero_approx(): return direction
	var preferred: Vector3 = direction.normalized()
	var correction: Vector3 = Vector3.ZERO
	for id: int in _neighbors:
		var other: CharacterBody3D = _neighbors[id]
		if not is_instance_valid(other): continue
		var away: Vector3 = _body.global_position - other.global_position
		away.y = 0.0
		var distance: float = away.length()
		if distance < 0.001 or distance >= separation_radius: continue
		var weight: float = 1.0 - distance / separation_radius
		correction += away / distance * weight
		if preferred.dot(-away / distance) > 0.6:
			var side: float = 1.0 if _body.get_instance_id() < other.get_instance_id() else -1.0
			correction += Vector3(preferred.z, 0, -preferred.x) * weight * side
	return (preferred + correction * separation_strength).normalized() * minf(direction.length(), 1.0)

func _on_entered(body: Node3D) -> void:
	if body != _body and body is CharacterBody3D: _neighbors[body.get_instance_id()] = body as CharacterBody3D

func _on_exited(body: Node3D) -> void:
	_neighbors.erase(body.get_instance_id())

func _apply_radius() -> void:
	var shape: SphereShape3D = ($CollisionShape3D as CollisionShape3D).shape as SphereShape3D
	shape.radius = separation_radius
