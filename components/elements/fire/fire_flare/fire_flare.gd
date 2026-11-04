class_name FireFlare
extends Node3D
## Bùng lửa phụt theo hướng gió từ sau lưng vật đang cháy (FireWind gọi khi gió thổi trúng vật cháy).
## Gameplay dùng lại script FireTouch (vùng hộp đốt thứ dễ cháy, không gây sát thương trực tiếp) nhưng không lồng
## fire_touch.tscn: vòng lửa VFX kèm theo đó không dùng tới và lồng vào pool thì báo lỗi material khi bị xoá.
## Igniter bỏ qua thứ đang cháy (skip_burning), như vết lửa theo gió, nếu không thổi liên tục sẽ giữ vật cháy mãi.
## Dùng object pool: hình chạy xong (dài hơn vùng đốt) mới phát finished, để pool không ẩn node giữa lúc lửa còn tàn.

## Hết lượt: pool nối signal này để nhả node về
signal finished

var _left: float = 0.0

@onready var _touch: FireTouch = $Touch
@onready var _vfx: FireFlareVfx = $Vfx


## Đặt theo toạ độ thế giới (pool nằm dưới player), mặc định nghỉ
func _ready() -> void:
	top_level = true
	set_process(false)


## Đếm tới khi hình tàn hết rồi trả về pool
func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		set_process(false)
		finished.emit()


## Phụt lửa: origin = đầu vùng phụt (sau lưng vật), direction = hướng gió (nằm ngang), size = (rộng, cao, dài)
func play(origin: Vector3, direction: Vector3, size: Vector3, duration: float, source: Node) -> void:
	global_transform = Transform3D(Basis.looking_at(-direction, Vector3.UP), origin)
	# Tâm hộp nằm giữa chiều dài, hộp quay theo hướng gió nên +Z là hướng phụt
	var center := global_transform * Vector3(0.0, 0.0, size.z * 0.5)
	_touch.sweep(Transform3D(global_basis, center), size, duration, source)
	_left = maxf(duration, _vfx.play(size))
	set_process(true)


## Pool nhả về giữa chừng (đổi khu...): tắt hẳn vùng đốt và hình
func pool_released() -> void:
	_left = 0.0
	set_process(false)
	if is_node_ready():
		_touch.pool_released()
		_vfx.stop()
