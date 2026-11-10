class_name StoneSeed
extends Node3D
## Đạn đá quét đường bay mỗi tick. Chỉ nhận lực từ cú thổi của Foxy.

signal finished(seed: StoneSeed)

const WORLD := 1
const PLAYER := 2
const ENEMY := 4

@export var speed: float = 7.5
## Độ nhạy của viên đá với thay đổi vận tốc do cú thổi.
@export var wind_response: float = 1.5
@export var lifetime: float = 3.0

var _shooter: Node3D
var _velocity: Vector3
var _remaining: float
var _reflected: bool
var _query := PhysicsRayQueryParameters3D.new()

@onready var _receiver: WindReceiverComponent = $WindReceiverComponent
@onready var _dust: MeshInstance3D = $Dust
@onready var _ribbon: Node3D = $Wind


func _ready() -> void:
	top_level = true
	_query.collide_with_areas = true
	_query.hit_from_inside = true
	_receiver.pushed.connect(_reflect)
	set_physics_process(false)


func launch(origin: Vector3, target: Vector3, shooter: Node3D) -> void:
	global_position = origin
	_shooter = shooter
	_velocity = origin.direction_to(target) * maxf(speed, 0.01)
	_remaining = maxf(lifetime, 0.01)
	_reflected = false
	_query.collision_mask = WORLD | PLAYER
	_dust.show()
	_ribbon.hide()
	_face_velocity()
	reset_physics_interpolation()
	set_physics_process(true)
	_receiver.enabled = true
	_receiver.set_deferred(&"monitorable", true)


func pool_released() -> void:
	set_physics_process(false)
	_receiver.enabled = false
	_receiver.set_deferred(&"monitorable", false)
	_shooter = null


func is_reflected() -> bool:
	return _reflected


func _physics_process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		finished.emit(self)
		return
	_query.from = global_position
	_query.to = global_position + _velocity * delta
	var collision := get_world_3d().direct_space_state.intersect_ray(_query)
	if collision.is_empty():
		global_position = _query.to
		return
	var hurtbox := collision.collider as HurtboxComponent
	if hurtbox == null and collision.collider is CharacterBody3D:
		hurtbox = collision.collider.get_node_or_null(^"HurtboxComponent") as HurtboxComponent
	if hurtbox:
		hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3.ZERO, self if _reflected else _shooter))
	finished.emit(self)


func _reflect(impulse: Vector3) -> void:
	if not is_physics_processing() or _reflected or impulse.is_zero_approx():
		return
	# Giữ động lượng ngang của viên đá rồi cộng thay đổi vận tốc do gió.
	var incoming := Vector3(_velocity.x, 0.0, _velocity.z)
	var wind := Vector3(impulse.x, 0.0, impulse.z)
	_velocity = incoming + wind * wind_response
	_reflected = true
	_remaining = maxf(lifetime, 0.01)
	_query.collision_mask = WORLD | ENEMY
	_dust.hide()
	_ribbon.show()
	_face_velocity()


func _face_velocity() -> void:
	if not _velocity.is_zero_approx():
		var up := Vector3.FORWARD if absf(_velocity.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
		look_at(global_position + _velocity, up, true)
