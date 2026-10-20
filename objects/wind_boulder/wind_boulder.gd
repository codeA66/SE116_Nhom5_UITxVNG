class_name WindBoulder
extends AnimatableBody3D
## Đá trượt gió: Wind Blast thổi trúng thì đá trượt thẳng theo một trong 4 hướng chính (gần hướng thổi nhất)
## cho tới khi vướng vật chặn, giống câu đố trượt băng. Đá nằm vào ổ (BoulderSocket) thì bị khoá lại.
## Hành vi theo FSM dạng node (objects/wind_boulder/states/).

signal slide_started(direction: Vector3)
signal slide_stopped

@export var data: WindBoulderData

## Điểm dừng của lần trượt hiện tại (state đọc)
var target: Vector3
var direction: Vector3 = Vector3.ZERO

var _shape: SphereShape3D
var _start_position: Vector3

@onready var state_machine: StateMachine = $StateMachine
@onready var _receiver: WindReceiverComponent = $WindReceiver
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	if data == null:
		push_error("%s thiếu WindBoulderData, đá đứng yên" % get_path())
		set_physics_process(false)
		return
	sync_to_physics = false
	_start_position = global_position
	_shape = SphereShape3D.new()
	_shape.radius = data.radius
	($CollisionShape3D as CollisionShape3D).shape = _shape
	($CollisionShape3D as CollisionShape3D).position.y = data.radius
	_visual.position.y = data.radius
	_visual.scale = Vector3.ONE * data.radius
	# Vùng nhận gió to hơn viên đá một chút để cú thổi trúng dễ
	var receive := SphereShape3D.new()
	receive.radius = data.radius + 0.3
	var receive_shape := _receiver.get_node("CollisionShape3D") as CollisionShape3D
	receive_shape.shape = receive
	receive_shape.position.y = data.radius
	_receiver.pushed.connect(_on_pushed)


func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)


## Hướng chính (±X hoặc ±Z thế giới) gần hướng thổi nhất; trả về 0 nếu thổi gần như thẳng đứng
static func cardinal_of(impulse: Vector3) -> Vector3:
	var flat := Vector3(impulse.x, 0.0, impulse.z)
	if flat.length() < 0.001:
		return Vector3.ZERO
	if absf(flat.x) >= absf(flat.z):
		return Vector3(signf(flat.x), 0.0, 0.0)
	return Vector3(0.0, 0.0, signf(flat.z))


## Tính điểm dừng: quét hình cầu dọc hướng trượt tới vật chặn đầu tiên
func plan_slide(dir: Vector3) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _shape
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * (data.radius + 0.05))
	params.motion = dir * data.max_slide_distance
	params.collision_mask = data.blocking_mask
	params.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.cast_motion(params)
	var travel := data.max_slide_distance * result[0]
	travel = maxf(travel - data.stop_margin, 0.0)
	if travel < 0.05:
		return false
	direction = dir
	target = global_position + dir * travel
	return true


## Lăn phần hình theo quãng vừa đi (chỉ là hình, va chạm là hình cầu nên không cần xoay)
func roll_visual(distance: float) -> void:
	var axis := Vector3.UP.cross(direction)
	if axis.length() > 0.001:
		_visual.rotate(axis.normalized(), distance / maxf(data.radius, 0.01))


## Về chỗ ban đầu nếu chưa vào ổ. Trả về true nếu đá đã được dời về
func reset_to_start() -> bool:
	var state := String(state_machine.current_state.name)
	if state == WindBoulderState.SEATED or global_position.is_equal_approx(_start_position):
		return false
	global_position = _start_position
	if state != WindBoulderState.IDLE:
		state_machine.transition_to(WindBoulderState.IDLE)
	return true


func _on_pushed(impulse: Vector3) -> void:
	(state_machine.current_state as WindBoulderState).on_blown(cardinal_of(impulse))


## State gọi khi bắt đầu / dừng trượt: signal phát từ chính class khai báo nó
func notify_slide_started() -> void:
	slide_started.emit(direction)


func notify_slide_stopped() -> void:
	slide_stopped.emit()
