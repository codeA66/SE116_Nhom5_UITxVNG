class_name ChanConductor
extends Node3D
## Hai tay đẩy đi theo khối. Tiếp điểm chỉ khép khi khối đã đứng yên ở nấc đúng.

@export var rail_axis: Vector3 = Vector3.RIGHT
@export_range(0.1, 12.0, 0.05, "or_greater") var step_distance: float = 1.45
@export_range(-1, 1) var initial_step: int = 1
@export var handle_distance: float = 1.1

var _step: int
var _step_vector: Vector3
var _data: ChanPuzzleData
var _enabled: bool = false
var _moving: bool = false
var _slide: Tween

@onready var _block: AnimatableBody3D = $Block
@onready var _negative: InteractableComponent = $Block/Negative
@onready var _positive: InteractableComponent = $Block/Positive
@onready var _rail: MeshInstance3D = $Rail


func _ready() -> void:
	var direction: Vector3 = rail_axis.normalized()
	_step_vector = direction * step_distance
	_rail.rotation.y = atan2(-direction.z, direction.x)
	_rail.scale.x = step_distance
	_negative.position = -direction * handle_distance + Vector3.UP * _negative.position.y
	_positive.position = direction * handle_distance + Vector3.UP * _positive.position.y
	_negative.availability_check = _can_push.bind(1)
	_positive.availability_check = _can_push.bind(-1)
	_negative.interacted.connect(_push.bind(1))
	_positive.interacted.connect(_push.bind(-1))
	reset()


func configure(data: ChanPuzzleData) -> void:
	_data = data


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func reset() -> void:
	if _slide:
		_slide.kill()
	_moving = false
	_step = clampi(initial_step, -1, 1)
	_block.position = _step_vector * _step


func closes_circuit() -> bool:
	return not _moving and _step == 0


func get_selected_port() -> int:
	return 0 if _moving else _step + 2


func _can_push(actor: Node3D, direction: int) -> bool:
	return actor is Player and _enabled and not _moving and absi(_step + direction) <= 1


func _push(_actor: Node3D, direction: int) -> void:
	_step += direction
	_moving = true
	_slide = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_slide.tween_property(_block, ^"position", _step_vector * _step, _data.slide_time)
	_slide.tween_callback(_finish_slide)


func _finish_slide() -> void:
	_moving = false
