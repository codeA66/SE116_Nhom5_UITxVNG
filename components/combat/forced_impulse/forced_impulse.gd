class_name ForcedImpulse
extends Node
## Lực nổ dịch chuyển qua va chạm, độc lập với trạng thái tấn công và miễn đẩy từ buff.
@export var deceleration: float = 24.0
var _body: CharacterBody3D
var _velocity: Vector3

static func push(body: CharacterBody3D, impulse: Vector3) -> void:
	var component: ForcedImpulse = body.get_node_or_null("ExplosionImpulse") as ForcedImpulse
	if component == null:
		component = ForcedImpulse.new()
		component.name = "ExplosionImpulse"
		body.add_child(component)
	component._body = body
	component._velocity = impulse
	component.set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_body): set_physics_process(false); return
	var hit: KinematicCollision3D = _body.move_and_collide(_velocity * delta)
	if hit: _velocity = _velocity.slide(hit.get_normal())
	_velocity = _velocity.move_toward(Vector3.ZERO, deceleration*delta)
	if _velocity.length_squared() < 0.01: set_physics_process(false)
