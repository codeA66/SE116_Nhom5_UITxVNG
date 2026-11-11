class_name FireCyclone
extends Node3D
## Cột lốc lửa của kỹ năng Lốc Lửa: một hố hút gió (WindVortex) được châm lửa ngay khi nở (FireVortex con của nó),
## rồi trôi thẳng theo hướng phóng. Gặp tường thì đứng lại xoáy tại chỗ tới hết giờ. Dùng với ObjectPool.
## Chỉ chạy _physics_process khi đang trôi.

## Lốc tan hẳn: pool nghe để thu lại
signal finished
## Lốc chạm tường, thôi trôi
signal blocked

## Lớp tường / sàn chặn lốc
@export_flags_3d_physics var wall_mask: int = 1
## Độ cao tia dò tường tính từ chân lốc
@export var probe_height: float = 0.6
## Dò trước bấy nhiêu mét để lốc không lún vào tường
@export var probe_margin: float = 0.4

var _direction: Vector3 = Vector3.ZERO
var _speed: float = 0.0
var _query: PhysicsRayQueryParameters3D

@onready var _vortex: WindVortex = $Vortex
@onready var _fire: FireVortex = $Vortex/FireVortex
@onready var _self_burnable: BurnableComponent = $Vortex/FireVortex/SelfBurnable


func _ready() -> void:
	set_physics_process(false)
	_vortex.finished.connect(finished.emit)
	# Hố thôi hút (hết giờ) thì thôi trôi: phần hình co lại tại chỗ
	_vortex.stopped.connect(set_physics_process.bind(false))
	_query = PhysicsRayQueryParameters3D.new()
	_query.collision_mask = wall_mask


## Nở lốc tại origin, châm lửa, trôi theo direction (ngang) với speed m/s trong lifetime giây
func launch(user: Character, origin: Vector3, direction: Vector3, speed: float, lifetime: float) -> void:
	_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	_speed = speed
	_vortex.lifetime = lifetime
	_vortex.global_position = origin
	_vortex.perform(user, null, _direction)
	# Hố vừa bật vùng nhận lửa trong perform (signal started): châm luôn để lốc cháy từ đầu
	_self_burnable.ignite(user)
	set_physics_process(_speed > 0.0 and not _direction.is_zero_approx())


func is_lit() -> bool:
	return _fire.is_lit()


func get_vortex_position() -> Vector3:
	return _vortex.global_position


func pool_released() -> void:
	set_physics_process(false)
	_vortex.pool_released()


func _physics_process(delta: float) -> void:
	var from := _vortex.global_position + Vector3.UP * probe_height
	var step := _direction * _speed * delta
	_query.from = from
	_query.to = from + step + _direction * probe_margin
	if not get_world_3d().direct_space_state.intersect_ray(_query).is_empty():
		set_physics_process(false)
		blocked.emit()
		return
	_vortex.global_position += step
