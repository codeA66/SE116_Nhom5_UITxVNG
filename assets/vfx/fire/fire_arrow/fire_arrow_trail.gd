class_name FireArrowTrail
extends Node3D
## VFX TẠM: vệt lửa bám theo mũi tên Cung Lửa lúc bay. Tên kết thúc (trúng / hết tầm) thì thôi phát hạt,
## chờ hạt đang bay tàn hết rồi phát finished để trả về object pool.
## Biết tên kết thúc nhờ signal (finished của ArrowProjectile dùng pool, hoặc tree_exiting), không dò mỗi frame;
## _process chỉ để bám vị trí tên trong lúc bay và đếm thời gian tàn.
##
## TRẠNG THÁI (2026-10-31): bản tạm cho thấy tên đang bốc lửa. CHƯA ĐẠT về thẩm mỹ: giao AI VFX làm bản đẹp
## (giữ nguyên start() / finished).

## Hết lượt: pool nối signal này để nhả node về
signal finished

var _projectile: Node3D
var _linger: float = 0.0

@onready var _flames: GPUParticles3D = $Flames


## Đặt theo toạ độ thế giới (pool nằm dưới player), mặc định nghỉ
func _ready() -> void:
	top_level = true
	set_process(false)
	_flames.emitting = false


## Trong lúc bay: bám vị trí tên. Sau khi tên kết thúc: đếm cho hạt tàn hết rồi trả về pool
func _process(delta: float) -> void:
	if _projectile:
		global_position = _projectile.global_position
		return
	_linger -= delta
	if _linger <= 0.0:
		set_process(false)
		finished.emit()


## Gắn vệt lửa vào một mũi tên vừa bắn
func start(projectile: Node3D) -> void:
	_projectile = projectile
	global_position = projectile.global_position
	projectile.tree_exiting.connect(_on_flight_ended, CONNECT_ONE_SHOT)
	# Tên dùng pool không rời cây khi kết thúc, nên nghe cả signal thu hồi của nó
	if projectile.has_signal(&"finished"):
		projectile.connect(&"finished", _on_flight_ended, CONNECT_ONE_SHOT)
	_flames.restart()
	_flames.emitting = true
	set_process(true)


## Pool nhả về giữa chừng: tắt hẳn, gỡ signal còn nối
func pool_released() -> void:
	_disconnect_projectile()
	_projectile = null
	_flames.emitting = false
	set_process(false)


## Tên kết thúc: thôi phát hạt, đợi hạt đang bay tàn hết
func _on_flight_ended() -> void:
	_disconnect_projectile()
	_projectile = null
	_flames.emitting = false
	_linger = _flames.lifetime


## Gỡ signal đang nối với tên (tên dùng pool sẽ được bắn lại, không để nối thừa)
func _disconnect_projectile() -> void:
	if not is_instance_valid(_projectile):
		return
	if _projectile.tree_exiting.is_connected(_on_flight_ended):
		_projectile.tree_exiting.disconnect(_on_flight_ended)
	if _projectile.has_signal(&"finished") and _projectile.is_connected(&"finished", _on_flight_ended):
		_projectile.disconnect(&"finished", _on_flight_ended)
