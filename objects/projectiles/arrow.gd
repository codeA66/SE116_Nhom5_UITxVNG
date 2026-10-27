class_name ArrowProjectile
extends Node3D
## Tên bay thẳng theo +Z. Quét cả đoạn đường mỗi physics frame để không xuyên vật mỏng.

## Tên trúng thứ gì đó (quái hoặc tường) tại position: buff nguyên tố của cung nghe signal này
signal impacted(position: Vector3, direction: Vector3)

@export_flags_3d_physics var collision_mask: int = 5 # world + enemy

var _attack: AttackData
var _velocity: Vector3
var _remaining: float
var _source: Node3D
var _previous_position: Vector3


func _ready() -> void:
	add_to_group(&"arrows")
	set_physics_process(false)


func launch(attack: AttackData, speed: float, lifetime: float, direction: Vector3, source: Node3D, origin: Vector3) -> void:
	_attack = attack
	_velocity = direction.normalized() * speed
	_remaining = lifetime
	_source = source
	_previous_position = origin
	look_at(global_position + direction, Vector3.UP, true)
	reset_physics_interpolation()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var next := global_position + _velocity * minf(delta, _remaining)
	var query := PhysicsRayQueryParameters3D.create(_previous_position, next, collision_mask)
	query.collide_with_areas = true
	query.hit_from_inside = true
	if is_instance_valid(_source) and _source is CollisionObject3D:
		query.exclude = [(_source as CollisionObject3D).get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var collider := result["collider"] as Node
		var hurtbox := collider as HurtboxComponent
		if hurtbox == null and collider:
			hurtbox = collider.get_node_or_null(^"HurtboxComponent") as HurtboxComponent
		if hurtbox:
			var source: Node = _source if is_instance_valid(_source) else null
			hurtbox.receive_hit(DamageInfo.new(_attack.damage, _attack.damage_type, _velocity.normalized() * _attack.knockback, source))
		# Lùi một chút khỏi điểm trúng để vật nở ra (hố hút) không lọt vào trong tường
		impacted.emit((result["position"] as Vector3) - _velocity.normalized() * 0.3, _velocity.normalized())
		queue_free()
		return
	global_position = next
	_previous_position = next
	_remaining -= delta
	if _remaining <= 0.0:
		queue_free()
