class_name FireVortex
extends Node3D
## Lốc lửa: gắn làm con của hố hút Cung Gió (WindVortex). Trong lúc hố hút, cả hố bốc lửa tới hết thời gian hố khi:
## - có thứ dễ cháy bên trong đang cháy (hoặc bắt lửa giữa chừng), hoặc
## - một nguồn lửa chạm vào chính hố (Q phun lửa, lửa theo gió, nhát cuối Kiếm Lửa, chỗ tên Cung Lửa trúng),
##   kể cả khi trong hố không có gì: hố tự là một vật dễ cháy (SelfBurnable).
## Bốc lửa thì mọi BurnableComponent trong vùng bắt lửa (quái lẫn vật). Không gây sát thương ngay; sát thương đến từ tick cháy.
## Hoàn toàn theo signal: started / stopped của hố, area_entered / exited, ignited của mục tiêu; không chạy mỗi frame.

## Hố bốc lửa (VFX / âm thanh nghe); phát tối đa 1 lần mỗi lần hố hút
signal caught_fire

## Hố hút để bám theo (bán kính, thời gian bật / tắt)
@export var vortex: WindVortex
## Vùng bắt lửa / đốt = bán kính hút x hệ số này. VFX xoáy gió vẽ rộng hơn vùng hút (vầng sáng ~1.25 lần):
## để người chơi phun vào chỗ nhìn thấy xoáy là ăn. Vùng hút quái không đổi.
@export_range(0.5, 3.0, 0.05) var catch_radius_scale: float = 1.25

var _lit: bool = false
## Mục tiêu dễ cháy đang trong hố -> callable đã nối vào signal ignited của nó (để gỡ khi ra / hết hố)
var _inside: Dictionary[BurnableComponent, Callable] = {}

@onready var _detector: Area3D = $Detector
@onready var _detector_shape: CollisionShape3D = $Detector/Shape
@onready var _igniter: IgniterArea = $Igniter
@onready var _igniter_shape: CollisionShape3D = $Igniter/Shape
@onready var _self_burnable: BurnableComponent = $SelfBurnable
@onready var _self_shape: CollisionShape3D = $SelfBurnable/Shape


## Detector chỉ quét layer burnable, nghỉ cho tới khi hố bắt đầu hút; nối signal của hố.
## Vùng nhận lửa của chính hố tắt cho tới khi hố hút (hố nằm trong pool, không được bắt lửa lúc nghỉ)
func _ready() -> void:
	_self_burnable.set_enabled(false)
	_self_burnable.ignited.connect(_on_self_ignited)
	set_process(false)
	set_physics_process(false)
	_detector.collision_layer = 0
	_detector.collision_mask = 0
	_detector.set_collision_mask_value(IgniterArea.BURNABLE_LAYER, true)
	_detector.monitorable = false
	_detector.monitoring = false
	_detector.area_entered.connect(_on_area_entered)
	_detector.area_exited.connect(_on_area_exited)
	if vortex:
		vortex.started.connect(_on_vortex_started)
		vortex.stopped.connect(_on_vortex_stopped)


## Đúng khi hố đang bốc lửa
func is_lit() -> bool:
	return _lit


## Hố bắt đầu hút: vùng dò, vùng đốt và vùng nhận lửa của hố = bán kính hút x catch_radius_scale; bật dò + nhận lửa
func _on_vortex_started(radius: float, _lifetime: float) -> void:
	_reset()
	var r := maxf(radius * catch_radius_scale, 0.01)
	(_detector_shape.shape as SphereShape3D).radius = r
	(_igniter_shape.shape as SphereShape3D).radius = r
	(_self_shape.shape as SphereShape3D).radius = r
	_detector.set_deferred(&"monitoring", true)
	_self_burnable.set_enabled(true)


## Hố thôi hút: tắt dò, tắt lửa, tắt nhận lửa, gỡ mọi signal đã nối
func _on_vortex_stopped() -> void:
	_detector.set_deferred(&"monitoring", false)
	_igniter.deactivate()
	_self_burnable.set_enabled(false)
	_reset()


## Một nguồn lửa chạm vào chính hố (không cần có gì cháy bên trong): hố bốc lửa
func _on_self_ignited() -> void:
	_catch_fire(_self_burnable)


## Thứ dễ cháy vào hố: theo dõi nó bắt lửa; đang cháy sẵn thì hố bốc lửa ngay
func _on_area_entered(area: Area3D) -> void:
	var burnable := area as BurnableComponent
	if burnable == null or _inside.has(burnable):
		return
	var on_ignited := _catch_fire.bind(burnable)
	burnable.ignited.connect(on_ignited)
	_inside[burnable] = on_ignited
	if burnable.is_burning():
		_catch_fire(burnable)


## Thứ dễ cháy ra khỏi hố: thôi theo dõi
func _on_area_exited(area: Area3D) -> void:
	var burnable := area as BurnableComponent
	if burnable == null or not _inside.has(burnable):
		return
	if is_instance_valid(burnable) and burnable.ignited.is_connected(_inside[burnable]):
		burnable.ignited.disconnect(_inside[burnable])
	_inside.erase(burnable)


## Hố bốc lửa (một lần mỗi lần hút): bật vùng lửa tròn, truyền người châm lửa ban đầu
func _catch_fire(from: BurnableComponent) -> void:
	if _lit:
		return
	_lit = true
	_igniter.ignite_source = from.get_source()
	_igniter.activate()
	caught_fire.emit()


## Gỡ signal của mọi thứ đang theo dõi, về trạng thái chưa bốc lửa
func _reset() -> void:
	for burnable: BurnableComponent in _inside:
		if is_instance_valid(burnable) and burnable.ignited.is_connected(_inside[burnable]):
			burnable.ignited.disconnect(_inside[burnable])
	_inside.clear()
	_lit = false
