class_name WindBlastArea
extends Area3D
## Vùng gió của kỹ năng thổi: đẩy mọi WindReceiverComponent trong vùng theo hướng nhân vật đang nhìn,
## và gây sát thương (WindBlastData.damage) cho chủ của bộ nhận gió nếu có HurtboxComponent.
## Mặc định tắt, state bật trong lúc thổi. Mỗi lần thổi, một vật chỉ bị đẩy một lần.
## Thứ gì muốn phản ứng với gió (quái, thuyền, lửa...) chỉ cần có WindReceiverComponent.

signal pushed(receiver: WindReceiverComponent)
signal charge_started(data: WindBlastData)
signal blast_started(data: WindBlastData)
signal blast_stopped

var _data: WindBlastData
var _active: bool = false
var _already_pushed: Array[WindReceiverComponent] = []

@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	monitorable = false
	monitoring = false
	area_entered.connect(_on_area_entered)


func is_active() -> bool:
	return _active


func begin_charge(data: WindBlastData) -> void:
	charge_started.emit(data)


func activate(data: WindBlastData) -> void:
	_data = data
	_already_pushed.clear()
	_active = true
	# Shape là local_to_scene nên đổi kích thước không ảnh hưởng instance khác
	var box := _shape.shape as BoxShape3D
	box.size = Vector3(data.width, data.height, data.reach)
	_shape.position.z = data.reach * 0.5
	set_deferred(&"monitoring", true)
	blast_started.emit(data)


func deactivate() -> void:
	_active = false
	set_deferred(&"monitoring", false)
	blast_stopped.emit()


func _on_area_entered(area: Area3D) -> void:
	var receiver := area as WindReceiverComponent
	# Bỏ qua bộ nhận gió của chính người thổi
	if not _active or receiver == null or receiver.owner == owner or receiver in _already_pushed:
		return
	_already_pushed.append(receiver)
	# Đẩy thẳng theo hướng thổi (không tỏa ra từ người thổi) để giải đố dễ đoán hướng
	var direction := global_basis.z
	direction.y = 0.0
	receiver.push(direction.normalized() * _data.push_speed)
	_hit_owner(receiver, direction.normalized())
	pushed.emit(receiver)


## Thứ có máu (quái, hình nộm) mất máu; vật chỉ nhận gió (thuyền, lửa, đồ giải đố) bỏ qua.
## Không truyền knockback: lực đẩy đã do bộ nhận gió lo, tránh đẩy hai lần
func _hit_owner(receiver: WindReceiverComponent, direction: Vector3) -> void:
	if _data.damage <= 0 or receiver.owner == null:
		return
	var hurtbox := receiver.owner.get_node_or_null(^"HurtboxComponent") as HurtboxComponent
	if hurtbox == null:
		return
	var info := DamageInfo.new(_data.damage, DamageInfo.Type.PHYSICAL, Vector3.ZERO, owner)
	info.direction = direction
	hurtbox.receive_hit(info)
