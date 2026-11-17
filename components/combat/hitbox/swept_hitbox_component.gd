class_name SweptHitboxComponent
extends HitboxComponent
## Quét đoạn đã đi trong khung vật lý để không bỏ sót hurtbox khi lao nhanh.

@export_flags_3d_physics var obstruction_mask: int = 1
@export var knockback_along_forward: bool = true

var _previous_position: Vector3 = Vector3.ZERO

@onready var _sweep: ShapeCast3D = $Sweep
@onready var _obstruction: RayCast3D = $Obstruction

func _ready() -> void:
	super._ready()
	_shape.shape = _shape.shape.duplicate() as Shape3D
	_sweep.shape = _shape.shape
	_sweep.transform = _shape.transform
	_sweep.collision_mask = collision_mask
	process_physics_priority = 100
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	if not is_active():
		return
	_sweep.target_position = _sweep.to_local(_previous_position)
	_sweep.force_shapecast_update()
	for index: int in _sweep.get_collision_count():
		var area: Area3D = _sweep.get_collider(index) as Area3D
		if area != null:
			_on_area_entered(area)
	_previous_position = _sweep.global_position

func activate(data: AttackData, duration: float = -1.0) -> void:
	_previous_position = _sweep.global_position
	super.activate(data, duration)
	set_physics_process(true)

func deactivate() -> void:
	super.deactivate()
	set_physics_process(false)

func configure_box(size: Vector3, center: Vector3) -> void:
	var box: BoxShape3D = _shape.shape as BoxShape3D
	assert(box != null)
	box.size = size.max(Vector3.ONE * MIN_DEPTH)
	_shape.position = center
	_sweep.transform = _shape.transform

func get_box_size() -> Vector3:
	return (_shape.shape as BoxShape3D).size

func _can_hit(hurtbox: HurtboxComponent) -> bool:
	var center: Vector3 = hurtbox.global_position
	var shape: CollisionShape3D = hurtbox.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null:
		center = shape.global_position
	var origin: Vector3 = (owner as Node3D).global_position if owner is Node3D else global_position
	origin.y = center.y
	_obstruction.global_position = origin
	_obstruction.target_position = _obstruction.to_local(center)
	_obstruction.collision_mask = obstruction_mask
	_obstruction.force_raycast_update()
	return not _obstruction.is_colliding()

func _get_hit_direction(hurtbox: HurtboxComponent) -> Vector3:
	if not knockback_along_forward:
		return super._get_hit_direction(hurtbox)
	var direction: Vector3 = global_basis.z
	direction.y = 0.0
	return direction.normalized()
