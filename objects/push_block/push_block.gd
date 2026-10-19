class_name WindPushBlock
extends CharacterBody3D
## Mỗi cú thổi đẩy bệ đúng một ô nếu đường đi trống.

signal entered_switch

@export var cell_size: float = 1.0
@export var slide_seconds: float = 0.2
@export var switch_path: NodePath
@export var persistent_id: StringName

var is_on_switch: bool = false
var _moving: bool = false
var _destination: Vector3
var _remaining: float = 0.0
@onready var _receiver: WindReceiverComponent = $WindReceiver


func _ready() -> void:
	set_physics_process(false)
	_receiver.pushed.connect(_on_pushed)
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		is_on_switch = true


func _physics_process(delta: float) -> void:
	var offset: Vector3 = _destination - global_position
	if offset.length() <= 0.01:
		global_position = _destination
		_moving = false
		set_physics_process(false)
		_check_switch()
		return
	var step: Vector3 = offset.normalized() * cell_size * delta / maxf(slide_seconds, 0.01)
	var collision: KinematicCollision3D = move_and_collide(step.limit_length(offset.length()))
	if collision != null:
		_moving = false
		set_physics_process(false)
	else:
		_remaining -= delta
		if _remaining <= 0.0:
			global_position = _destination
			_moving = false
			set_physics_process(false)
			_check_switch()


func _on_pushed(impulse: Vector3) -> void:
	if _moving or is_on_switch or cell_size <= 0.0:
		return
	var axis: Vector3 = Vector3.RIGHT if absf(impulse.x) >= absf(impulse.z) else Vector3.BACK
	var signed_axis: Vector3 = axis * signf(impulse.dot(axis))
	var motion: Vector3 = signed_axis * cell_size
	if test_move(global_transform, motion):
		return
	_destination = global_position + motion
	_remaining = maxf(slide_seconds, 0.01)
	_moving = true
	set_physics_process(true)


func _check_switch() -> void:
	if switch_path.is_empty():
		return
	var floor_switch: Node3D = get_node_or_null(switch_path) as Node3D
	if floor_switch == null or global_position.distance_to(floor_switch.global_position) > cell_size * 0.5:
		return
	is_on_switch = true
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	entered_switch.emit()
