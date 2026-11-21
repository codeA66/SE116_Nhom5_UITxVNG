class_name ChanCopperBlock
extends Node3D
## Giữ khối trong cây node của phòng để hồi sinh có thể trả về vị trí cũ.

signal lifted(block: ChanCopperBlock)

@export var carry_offset: Vector3 = Vector3(0.64, 1.28, 0.12)

var _carrier: Node3D
var _home: Transform3D
var _has_free_hands: Callable

@onready var _pickup: InteractableComponent = $Pickup


func _ready() -> void:
	_home = transform
	_pickup.availability_check = _can_pick_up
	_pickup.interacted.connect(_pick_up)
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_carrier):
		reset()
		return
	global_position = _carrier.global_position + carry_offset


func configure(has_free_hands: Callable) -> void:
	_has_free_hands = has_free_hands


func set_interaction_enabled(enabled: bool) -> void:
	_pickup.enabled = enabled


func is_carried_by(actor: Node3D) -> bool:
	return _carrier == actor


func place_at(target: Transform3D) -> void:
	_stop_carrying()
	global_transform = target
	reset_physics_interpolation()


func reset() -> void:
	_stop_carrying()
	transform = _home
	reset_physics_interpolation()


func _can_pick_up(actor: Node3D) -> bool:
	return _carrier == null and _has_free_hands.is_valid() and _has_free_hands.call(actor)


func _pick_up(actor: Node3D) -> void:
	_carrier = actor
	global_position = actor.global_position + carry_offset
	reset_physics_interpolation()
	set_physics_process(true)
	lifted.emit(self)


func _stop_carrying() -> void:
	_carrier = null
	set_physics_process(false)
