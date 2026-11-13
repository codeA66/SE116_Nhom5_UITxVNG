class_name WindTornado
extends Node3D
## Cơn lốc của kỹ năng Lốc xoáy: chạy thẳng theo hướng thả, hút quái trong tầm về tâm, quẹt trúng quái ở gần tâm,
## đẩy vật nhận gió khác (thuyền, cối xay, đạn) như cú Thổi gió; đi hết quãng đường (hoặc gặp tường) thì nổ.
## Theo dõi vật vào / ra bằng signal; chỉ chạy _physics_process trong lúc còn sống. Dùng qua ObjectPool.

signal finished
signal launched(data: WindTornadoData)
signal burst(position: Vector3)

## Lớp vùng nhận gió của nhân vật / vật thể
@export_flags_3d_physics var receiver_mask: int = 128

var _data: WindTornadoData
var _user: Node
var _direction: Vector3 = Vector3.FORWARD
var _travelled: float = 0.0
var _alive: bool = false
var _linger_left: float = 0.0
var _receivers: Array[WindReceiverComponent] = []
## Vật đã bị quẹt / đẩy trong cơn lốc này (mỗi vật một lần)
var _touched: Array[WindReceiverComponent] = []
var _wall_query: PhysicsRayQueryParameters3D

@onready var _area: Area3D = $Area
@onready var _shape: CollisionShape3D = $Area/Shape
@onready var _visual: WindTornadoVfx = $WindTornadoVfx


func _ready() -> void:
	set_as_top_level(true)
	set_physics_process(false)
	_area.monitoring = false
	_area.monitorable = false
	_area.collision_layer = 0
	_area.collision_mask = receiver_mask
	_shape.shape = _shape.shape.duplicate()
	_area.area_entered.connect(_on_receiver_entered)
	_area.area_exited.connect(_on_receiver_exited)
	_wall_query = PhysicsRayQueryParameters3D.new()


func is_alive() -> bool:
	return _alive


## Thả lốc tại start, chạy theo direction (ngang). user không bị lốc của chính mình tác động
func launch(user: Node, data: WindTornadoData, start: Vector3, direction: Vector3) -> void:
	_user = user
	_data = data
	direction.y = 0.0
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector3.FORWARD
	_travelled = 0.0
	_linger_left = 0.0
	_receivers.clear()
	_touched.clear()
	global_position = start
	(_shape.shape as SphereShape3D).radius = maxf(maxf(data.pull_radius, data.burst_radius), 0.01)
	_wall_query.collision_mask = data.wall_mask
	_area.set_deferred(&"monitoring", true)
	_alive = true
	reset_physics_interpolation()
	launched.emit(data)
	set_physics_process(true)


func pool_released() -> void:
	_alive = false
	_linger_left = 0.0
	_receivers.clear()
	_touched.clear()
	_user = null
	if is_node_ready():
		_area.set_deferred(&"monitoring", false)
		_visual.pool_released()
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _alive:
		_linger_left -= delta
		if _linger_left <= 0.0:
			set_physics_process(false)
			if finished.get_connections().is_empty():
				queue_free()
			else:
				finished.emit()
		return
	var step := minf(_data.travel_speed * delta, _data.travel_distance - _travelled)
	var blocked := _data.stops_at_walls and _hits_wall(step)
	if not blocked:
		global_position += _direction * step
		_travelled += step
	_affect_receivers(delta)
	if blocked or step <= 0.0 or _travelled >= _data.travel_distance:
		_explode()


func _hits_wall(step: float) -> bool:
	# Dò ở tầm ngực để bậc thềm thấp không chặn lốc
	var from := global_position + Vector3.UP * 0.8
	_wall_query.from = from
	_wall_query.to = from + _direction * (step + 0.3)
	return not get_world_3d().direct_space_state.intersect_ray(_wall_query).is_empty()


func _affect_receivers(delta: float) -> void:
	var center := global_position
	for receiver in _receivers:
		if not is_instance_valid(receiver):
			continue
		var offset := center - receiver.global_position
		offset.y = 0.0
		var distance := offset.length()
		var is_enemy := receiver.owner is Enemy
		# Chỉ hút quái: vật giải đố (thuyền, đạn, đá) không bị kéo lệch khỏi chỗ của nó
		if is_enemy and distance <= _data.pull_radius and distance > _data.hold_radius:
			receiver.push(offset / distance * _data.pull_accel * delta)
		if distance <= _data.contact_radius and not receiver in _touched:
			_touched.append(receiver)
			if not is_enemy:
				receiver.push(_direction * _data.object_push_speed)
			_damage(receiver, _data.contact_damage, _direction)


func _explode() -> void:
	_alive = false
	_linger_left = _data.linger
	var center := global_position
	for receiver in _receivers:
		if not is_instance_valid(receiver):
			continue
		var offset := receiver.global_position - center
		offset.y = 0.0
		var distance := offset.length()
		if distance > _data.burst_radius:
			continue
		# Vật đứng đúng tâm thì hất theo hướng lốc chạy
		var away := offset / distance if distance > 0.05 else _direction
		receiver.push(away * _data.burst_push_speed)
		_damage(receiver, _data.burst_damage, away)
	_receivers.clear()
	_area.set_deferred(&"monitoring", false)
	burst.emit(center)


## Thứ có máu mất máu (sát thương gió); vật chỉ nhận gió thì bỏ qua. Lực đẩy do bộ nhận gió lo nên không kèm knockback
func _damage(receiver: WindReceiverComponent, amount: int, direction: Vector3) -> void:
	if amount <= 0 or receiver.owner == null:
		return
	var hurtbox := receiver.owner.get_node_or_null(^"HurtboxComponent") as HurtboxComponent
	if hurtbox == null:
		return
	var info := DamageInfo.new(amount, DamageInfo.Type.WIND, Vector3.ZERO, _user)
	info.direction = direction
	# Cú nổ là đòn riêng: không để khoảng bất tử của cú quẹt ngay trước đó nuốt mất
	info.ignores_invincibility = true
	hurtbox.receive_hit(info)


func _on_receiver_entered(area: Area3D) -> void:
	var receiver := area as WindReceiverComponent
	if receiver and receiver.owner != _user and not receiver in _receivers:
		_receivers.append(receiver)


func _on_receiver_exited(area: Area3D) -> void:
	var receiver := area as WindReceiverComponent
	if receiver:
		_receivers.erase(receiver)
