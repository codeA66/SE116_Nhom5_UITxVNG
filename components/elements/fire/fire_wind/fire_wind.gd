class_name FireWind
extends Node3D
## Lửa theo vết gió: gắn cạnh vùng gió của cú thổi (WindBlastArea). Lúc gió bật, nếu trong vết gió có thứ đang cháy
## (quái, hình nộm, thùng, kể cả thứ đứng yên không bị gió đẩy) thì phần vết gió từ vật cháy gần người thổi nhất
## trở đi (xuôi gió) tới cuối tầm thành lửa: mọi thứ dễ cháy trong đó bắt lửa. Phần giữa người thổi và vật cháy không có lửa.
## Không sửa code thổi gió: chỉ nghe blast_started / blast_stopped. Hoàn toàn theo signal, chỉ chạy _physics_process
## trong lúc đếm extra_time sau khi gió tắt.

## Vết lửa bật hoặc kéo dài (VFX / âm thanh nghe). start, length tính theo trục +Z của node (hướng gió), width = bề rộng gió
signal fired(start: float, length: float, width: float)

## Vùng gió để bám theo (Model/WindBlastArea)
@export var wind_area: WindBlastArea
@export var data: FireWindData

var _blowing: bool = false
## Mốc z (theo node này) nơi vết lửa bắt đầu; INF = chưa có vật cháy
var _start: float = INF
var _off_left: float = 0.0
var _wind_shape: CollisionShape3D

@onready var _detector: Area3D = $Detector
@onready var _detector_shape: CollisionShape3D = $Detector/Shape
@onready var _igniter: IgniterArea = $Igniter
@onready var _igniter_shape: CollisionShape3D = $Igniter/Shape


## Dò chỉ quét layer burnable, dùng chung hình hộp với vùng gió; vết lửa không làm mới thứ đang cháy sẵn
func _ready() -> void:
	set_physics_process(false)
	_detector.collision_layer = 0
	_detector.collision_mask = 0
	_detector.set_collision_mask_value(IgniterArea.BURNABLE_LAYER, true)
	_detector.monitorable = false
	_detector.monitoring = false
	_detector.area_entered.connect(_on_area_entered)
	_igniter.skip_burning = true
	if wind_area == null:
		return
	_wind_shape = wind_area.get_node("CollisionShape3D") as CollisionShape3D
	# Dùng chung resource: cú thổi đổi kích thước theo dữ liệu kỹ năng thì vùng dò đổi theo
	_detector_shape.shape = _wind_shape.shape
	wind_area.blast_started.connect(_on_blast_started)
	wind_area.blast_stopped.connect(_on_blast_stopped)


## Chỉ chạy sau khi gió tắt: đếm extra_time rồi tắt vết lửa
func _physics_process(delta: float) -> void:
	_off_left -= delta
	if _off_left <= 0.0:
		_igniter.deactivate()
		set_physics_process(false)


## Gió bật: chép vị trí / hình vùng gió (state đã đặt tầm, bề rộng), bật dò
func _on_blast_started(_wind: WindBlastData) -> void:
	set_physics_process(false)
	_igniter.deactivate()
	global_transform = wind_area.global_transform
	_detector_shape.transform = _wind_shape.transform
	_start = INF
	_blowing = true
	_detector.set_deferred(&"monitoring", true)


## Gió tắt: thôi dò; vết lửa giữ thêm extra_time rồi tắt
func _on_blast_stopped() -> void:
	_blowing = false
	_detector.set_deferred(&"monitoring", false)
	if not _igniter.is_active():
		return
	_off_left = data.extra_time if data else 0.0
	set_physics_process(true)


## Thứ dễ cháy trong vết gió: đang cháy thì vết lửa bắt đầu (hoặc kéo dài về phía người thổi) từ chỗ nó
func _on_area_entered(area: Area3D) -> void:
	var burnable := area as BurnableComponent
	if not _blowing or burnable == null or not burnable.is_burning() or _is_own(burnable):
		return
	_extend_from(burnable)


## Đặt vết lửa từ vị trí vật cháy (chiếu lên trục gió) tới cuối tầm; vật cháy gần người thổi hơn thì kéo dài vết
func _extend_from(burnable: BurnableComponent) -> void:
	var z := maxf(to_local(burnable.global_position).z, 0.0)
	if z >= _start:
		return
	var wind_box := _wind_shape.shape as BoxShape3D
	var reach_end := _wind_shape.position.z + wind_box.size.z * 0.5
	var length := reach_end - z
	if length <= 0.01:
		return
	_start = z
	var box := _igniter_shape.shape as BoxShape3D
	box.size = Vector3(wind_box.size.x, wind_box.size.y, length)
	_igniter_shape.position = Vector3(_wind_shape.position.x, _wind_shape.position.y, z + length * 0.5)
	if not _igniter.is_active():
		_igniter.ignite_source = burnable.get_source()
		_igniter.activate()
	fired.emit(z, length, wind_box.size.x)


## Đúng khi vật thuộc chính thực thể đang thổi (sau này player có BurnableComponent thì không tự dẫn lửa từ mình)
func _is_own(burnable: BurnableComponent) -> bool:
	# Theo chuỗi owner, không theo cây node: hố hút Cung Gió nằm trong pool dưới Player vẫn phải bắt lửa được
	return IgniterArea.belongs_to(burnable, owner)
