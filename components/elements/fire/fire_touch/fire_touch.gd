class_name FireTouch
extends Node3D
## Vùng lửa ngắn hạn đặt ở đâu đốt ở đó (nhát cuối Kiếm Lửa, chỗ tên Cung Lửa trúng...): bật trong một khoảng ngắn,
## mọi BurnableComponent trong vùng bắt lửa, rồi tự phát finished để trả về object pool (không instantiate mỗi lần).
## Hai dạng: sweep() hình hộp (nhát chém) và burst() hình cầu (bùng quanh chỗ trúng). Chỉ làm cháy, không gây sát thương.
## top_level: đặt theo toạ độ thế giới, không đi theo người dùng sau khi đặt.

## Hết lượt: pool nối signal này để nhả node về
signal finished
## Vùng lửa vừa bật (VFX nghe): size = kích thước hộp, hoặc (bán kính, bán kính, bán kính) nếu sphere
signal fired(size: Vector3, sphere: bool)

## Thời gian bật tối thiểu (s): monitoring bật trễ một khung, ngắn hơn thì có thể không kịp dò
@export var min_duration: float = 0.08

var _left: float = 0.0

@onready var _igniter: IgniterArea = $Igniter
@onready var _box: CollisionShape3D = $Igniter/Box
@onready var _sphere: CollisionShape3D = $Igniter/Sphere


## Tách khỏi transform của cha (pool nằm dưới player), mặc định nghỉ
func _ready() -> void:
	top_level = true
	set_physics_process(false)


## Chỉ chạy trong lúc vùng đang bật: hết giờ thì tắt vùng và báo pool
func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_igniter.deactivate()
		set_physics_process(false)
		finished.emit()


## Đúng khi vùng đang bật (chưa trả về pool)
func is_active() -> bool:
	return _left > 0.0


## Vùng lửa hình hộp đặt theo xform (tâm hộp), kích thước size; source = người châm lửa (không tự đốt mình)
func sweep(xform: Transform3D, size: Vector3, duration: float, source: Node) -> void:
	_box.disabled = false
	_sphere.disabled = true
	(_box.shape as BoxShape3D).size = Vector3(maxf(size.x, 0.01), maxf(size.y, 0.01), maxf(size.z, 0.01))
	global_transform = xform
	_start(duration, source)
	fired.emit(size, false)


## Vùng lửa hình cầu bán kính radius quanh origin; source = người châm lửa
func burst(origin: Vector3, radius: float, duration: float, source: Node) -> void:
	_box.disabled = true
	_sphere.disabled = false
	var r := maxf(radius, 0.01)
	(_sphere.shape as SphereShape3D).radius = r
	global_transform = Transform3D(Basis.IDENTITY, origin)
	_start(duration, source)
	fired.emit(Vector3.ONE * r, true)


## Pool nhả về giữa chừng (đổi khu...): tắt hẳn, không phát finished lần nữa
func pool_released() -> void:
	_left = 0.0
	_igniter.deactivate()
	set_physics_process(false)


## Bật vùng; người châm lửa vừa là nguồn tick cháy vừa được loại trừ (player không tự đốt mình)
func _start(duration: float, source: Node) -> void:
	_igniter.exclude_root = source
	_igniter.ignite_source = source
	_left = maxf(duration, min_duration)
	_igniter.activate()
	set_physics_process(true)
