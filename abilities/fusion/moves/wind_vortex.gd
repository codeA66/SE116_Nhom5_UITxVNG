class_name WindVortex
extends FusionMove
## Hố hút gió: nở tại chỗ mũi tên trúng, hút quái quanh đó về tâm trong một lúc rồi tan. Không gây sát thương
## (sát thương đã có ở mũi tên). Theo dõi quái vào/ra bằng signal; chỉ chạy _physics_process trong lúc còn sống.
## Hình: dải gió có texture xoắn vào tâm, hết thì co lại rồi tan.

signal finished

@export var radius: float = 2.5
@export var lifetime: float = 0.8
## Gia tốc hút về tâm (m/s²); phải lớn hơn push_decay của vật nhận gió thì mới kéo được
@export var pull_accel: float = 34.0
## Trong bán kính này coi như đã tới tâm, thôi hút (không bị kéo qua lại)
@export var hold_radius: float = 0.7
## Lớp vùng nhận gió của nhân vật
@export_flags_3d_physics var receiver_mask: int = 128
## Giữ node thêm bấy nhiêu giây sau khi hố tắt để phần hình co lại chạy hết
@export var linger: float = 0.45

var _left: float = 0.0
var _linger_left: float = 0.0
var _receivers: Array[WindReceiverComponent] = []

@onready var _area: Area3D = $Area
@onready var _shape: CollisionShape3D = $Area/Shape
@onready var _swirl: WindVortexVfx = $Swirl


func _ready() -> void:
	set_as_top_level(true)
	set_physics_process(false)
	_area.monitoring = false
	_area.monitorable = false
	_area.collision_layer = 0
	_area.collision_mask = receiver_mask
	_shape.shape = _shape.shape.duplicate()
	(_shape.shape as SphereShape3D).radius = maxf(radius, 0.01)
	_area.area_entered.connect(_on_receiver_entered)
	_area.area_exited.connect(_on_receiver_exited)


func prepare_shader_warmup() -> void:
	_swirl.prepare_shader_warmup()


## Gốc node đặt ở điểm trúng; nét gió đặt dưới mặt đất ngay dưới tâm
func perform(_user: Character, _attack: AttackData, _direction: Vector3) -> void:
	_left = lifetime
	_linger_left = 0.0
	_receivers.clear()
	_area.monitoring = true
	var ground := global_position
	var query := PhysicsRayQueryParameters3D.create(ground + Vector3.UP * 0.5, ground + Vector3.DOWN * 3.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		ground = hit["position"]
	_swirl.global_position = ground
	_swirl.play(radius)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _left <= 0.0:
		_linger_left -= delta
		if _linger_left <= 0.0:
			set_physics_process(false)
			if finished.get_connections().is_empty():
				queue_free()
			else:
				finished.emit()
		return
	var center := global_position
	for receiver in _receivers:
		if not is_instance_valid(receiver):
			continue
		var offset := center - receiver.global_position
		offset.y = 0.0
		if offset.length() > hold_radius:
			receiver.push(offset.normalized() * pull_accel * delta)
	_left -= delta
	if _left <= 0.0:
		_area.set_deferred(&"monitoring", false)
		_receivers.clear()
		_swirl.stop(linger)
		_linger_left = linger


func pool_released() -> void:
	_left = 0.0
	_linger_left = 0.0
	_receivers.clear()
	_area.set_deferred(&"monitoring", false)
	_swirl.pool_released()
	set_physics_process(false)


func _on_receiver_entered(area: Area3D) -> void:
	var receiver := area as WindReceiverComponent
	# Chỉ hút quái: bỏ qua người bắn và vật nhận gió không phải quái (đá, thuyền, đạn...)
	if receiver and receiver.owner is Enemy and not receiver in _receivers:
		_receivers.append(receiver)


func _on_receiver_exited(area: Area3D) -> void:
	var receiver := area as WindReceiverComponent
	if receiver:
		_receivers.erase(receiver)
