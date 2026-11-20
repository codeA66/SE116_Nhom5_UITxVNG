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
signal dissipated

var _data: WindBlastData
var _active: bool = false
var _already_pushed: Array[WindReceiverComponent] = []

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _magma_selector: WindBlastTargetSelector = $MagmaSelector


func _ready() -> void:
	monitorable = false
	monitoring = false
	area_entered.connect(_on_area_entered)
	_magma_selector.selected.connect(_on_magma_selected)


func is_active() -> bool:
	return _active


func begin_charge(data: WindBlastData) -> void:
	charge_started.emit(data)


func activate(data: WindBlastData) -> void:
	_data = data
	_already_pushed.clear()
	_magma_selector.begin()
	_active = true
	# Shape là local_to_scene nên đổi kích thước không ảnh hưởng instance khác
	var box := _shape.shape as BoxShape3D
	box.size = Vector3(data.width, data.height, data.reach)
	_shape.position.z = data.reach * 0.5
	set_deferred(&"monitoring", true)
	blast_started.emit(data)


func deactivate() -> void:
	_active = false
	_magma_selector.cancel()
	set_deferred(&"monitoring", false)
	blast_stopped.emit()


func _on_area_entered(area: Area3D) -> void:
	var receiver := area as WindReceiverComponent
	# Bỏ qua bộ nhận gió của chính người thổi
	if not _active or receiver == null or receiver.owner == owner or receiver in _already_pushed:
		return

	var direction := global_basis.z
	direction.y = 0.0
	var f_norm := direction.normalized() if not direction.is_zero_approx() else Vector3.FORWARD

	if _magma_selector.handles(receiver):
		_magma_selector.offer(receiver)
		return

	_already_pushed.append(receiver)
	receiver.push_from_blast(f_norm * _data.push_speed, global_position, _data.width * 0.5)
	_hit_owner(receiver, f_norm)
	pushed.emit(receiver)


func _on_magma_selected(receiver: WindReceiverComponent) -> void:
	if not _active or receiver in _already_pushed:
		return
	var direction: Vector3 = global_basis.z
	direction.y = 0.0
	direction = direction.normalized() if not direction.is_zero_approx() else Vector3.FORWARD
	_already_pushed.append(receiver)
	receiver.push(direction * _data.push_speed)
	pushed.emit(receiver)
	dissipated.emit()
	deactivate()


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
