class_name VaneBridge
extends Node3D
## Cầu chong chóng: Wind Blast thổi trúng chong chóng ở trụ giữa thì cả nhịp cầu xoay step_degrees quanh trụ.
## Người đứng trên cầu xoay theo (nhịp cầu là AnimatableBody3D). Dùng làm câu đố nối lối hoặc mở đường tắt.
## Mỗi cầu chỉ nghe chong chóng của chính nó. Hành vi theo FSM dạng node (objects/traversal/vane_bridge/states/).

signal turn_started
signal turn_finished(angle_degrees: float)

@export var data: VaneBridgeData
## Góc xoay ban đầu của nhịp cầu (độ). Đổi để đặt hướng cầu lúc vào khu
@export var start_angle_degrees: float = 0.0
## Cờ lưu "cầu đã được xoay" (đường tắt đã mở thì lần sau vào vẫn mở, cầu xoay sẵn một bước). Để trống = không lưu
@export var persistent_id: StringName

## Góc hiện tại và góc đích của lần xoay (độ), state đọc/ghi
var angle_degrees: float = 0.0
var target_degrees: float = 0.0

@onready var state_machine: StateMachine = $StateMachine
@onready var deck: AnimatableBody3D = $Deck
@onready var _vane: Node3D = $Vane
@onready var _receiver: WindReceiverComponent = $Vane/WindReceiver


func _ready() -> void:
	if data == null:
		push_error("%s thiếu VaneBridgeData, cầu đứng yên" % get_path())
		set_physics_process(false)
		return
	angle_degrees = start_angle_degrees
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		angle_degrees += data.step_degrees
	set_deck_angle(angle_degrees)
	_receiver.pushed.connect(_on_pushed)


func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)


func set_deck_angle(degrees: float) -> void:
	deck.rotation.y = deg_to_rad(degrees)


func spin_vane(radians: float) -> void:
	_vane.rotate_object_local(Vector3.BACK, radians)


func _on_pushed(_impulse: Vector3) -> void:
	(state_machine.current_state as VaneBridgeState).on_blown()


## State gọi khi bắt đầu / xoay xong: signal phát từ chính class khai báo nó
func notify_turn_started() -> void:
	turn_started.emit()


func notify_turn_finished() -> void:
	turn_finished.emit(angle_degrees)
