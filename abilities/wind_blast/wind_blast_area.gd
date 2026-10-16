class_name WindBlastArea
extends Area3D
## Vùng gió của kỹ năng thổi: đẩy mọi WindReceiverComponent trong vùng theo hướng nhân vật đang nhìn.
## Mặc định tắt, state bật trong lúc thổi. Mỗi lần thổi, một vật chỉ bị đẩy một lần.
## Thứ gì muốn phản ứng với gió (quái, thuyền, lửa...) chỉ cần có WindReceiverComponent.

signal pushed(receiver: WindReceiverComponent)

## Hạt bay chậm nhất bằng tỉ lệ này so với hạt nhanh nhất, cho luồng gió không đều
const PARTICLE_SPEED_SPREAD := 0.7

var _data: WindBlastData
var _active: bool = false
var _already_pushed: Array[WindReceiverComponent] = []

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _particles: CPUParticles3D = $Particles
@onready var _sound: AudioStreamPlayer3D = $Sound


func _ready() -> void:
	monitorable = false
	monitoring = false
	area_entered.connect(_on_area_entered)


func is_active() -> bool:
	return _active


func activate(data: WindBlastData) -> void:
	_data = data
	_already_pushed.clear()
	_active = true
	# Shape là local_to_scene nên đổi kích thước không ảnh hưởng instance khác
	var box := _shape.shape as BoxShape3D
	box.size = Vector3(data.width, data.height, data.reach)
	_shape.position.z = data.reach * 0.5
	# Hạt bay vừa hết tầm thổi trong đúng thời gian sống
	var particle_speed := data.reach / _particles.lifetime
	_particles.initial_velocity_max = particle_speed
	_particles.initial_velocity_min = particle_speed * PARTICLE_SPEED_SPREAD
	_particles.restart()
	if _sound.stream:
		_sound.play()
	set_deferred(&"monitoring", true)


func deactivate() -> void:
	_active = false
	set_deferred(&"monitoring", false)


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
	pushed.emit(receiver)
