class_name ChanSocket
extends Node3D
## Tiếp điểm sáng khi khối đã khớp với ổ.

signal connection_changed

var _block: ChanCopperBlock
var _find_held_block: Callable

@onready var _insert: InteractableComponent = $Insert
@onready var _seat: Marker3D = $Seat
@onready var _connected: Node3D = $Connected
@onready var _latch: Node3D = $Latch
@onready var _pulse: Node3D = $Pulse
@onready var _break: Node3D = $Break


func _ready() -> void:
	_insert.availability_check = _can_insert
	_insert.interacted.connect(_insert_block)


func configure(find_held_block: Callable) -> void:
	_find_held_block = find_held_block


func has_block() -> bool:
	return is_instance_valid(_block)


func set_interaction_enabled(enabled: bool) -> void:
	_insert.enabled = enabled


func lock() -> void:
	_latch.visible = has_block()


func show_trace(reached: bool, blocked: bool) -> void:
	_pulse.visible = reached and not blocked
	_break.visible = blocked


func reset() -> void:
	if has_block():
		_block.lifted.disconnect(_on_block_lifted)
	_block = null
	_connected.hide()
	_latch.hide()
	show_trace(false, false)


func _can_insert(actor: Node3D) -> bool:
	return not has_block() and _find_held_block.is_valid() and _find_held_block.call(actor) != null


func _insert_block(actor: Node3D) -> void:
	_block = _find_held_block.call(actor) as ChanCopperBlock
	_block.place_at(_seat.global_transform)
	_block.lifted.connect(_on_block_lifted, CONNECT_ONE_SHOT)
	_connected.show()
	connection_changed.emit()


func _on_block_lifted(_lifted: ChanCopperBlock) -> void:
	_block = null
	_connected.hide()
	connection_changed.emit()
