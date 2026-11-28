class_name ChanCircuit
extends Node3D
## Dòng điện dừng tại ổ đầu tiên chưa nối. Mỗi ổ có nhóm mesh phát sáng riêng.

signal powered
signal unpowered

@export var sockets: Array[ChanSocket] = []
@export var blocks: Array[ChanCopperBlock] = []
@export var live_sections: Array[Node3D] = []

var _powered: bool = false
var _carried: ChanCopperBlock

@onready var _timer: Timer = $PowerTime


func _ready() -> void:
	for block: ChanCopperBlock in blocks:
		block.configure(_has_free_hands)
		block.lifted.connect(_on_block_lifted)
	for socket: ChanSocket in sockets:
		socket.configure(_held_block)
		socket.connection_changed.connect(stop)
	_timer.timeout.connect(_clear)
	_clear()


func set_interaction_enabled(enabled: bool) -> void:
	for block: ChanCopperBlock in blocks:
		block.set_interaction_enabled(enabled)
	for socket: ChanSocket in sockets:
		socket.set_interaction_enabled(enabled)


func lock() -> void:
	set_interaction_enabled(false)
	for socket: ChanSocket in sockets:
		socket.lock()


func reset() -> void:
	stop()
	_carried = null
	for socket: ChanSocket in sockets:
		socket.reset()
	for block: ChanCopperBlock in blocks:
		block.reset()


func return_carried_block(actor: Node3D) -> void:
	var block: ChanCopperBlock = _held_block(actor)
	if block != null:
		block.reset()
		_carried = null


func pulse(duration: float) -> void:
	var reaches_end: bool = _trace_pulse()
	_timer.start(maxf(duration, 0.01))
	_set_powered(reaches_end)


func stop() -> void:
	_timer.stop()
	_clear()


func _trace_pulse() -> bool:
	_clear_socket_traces()
	var reaches_end: bool = true
	for index: int in live_sections.size():
		live_sections[index].visible = reaches_end
		if reaches_end and index < sockets.size():
			var socket: ChanSocket = sockets[index]
			reaches_end = socket.has_block()
			socket.show_trace(reaches_end, not reaches_end)
	return reaches_end


func _clear() -> void:
	_hide_tracks()
	_set_powered(false)


func _hide_tracks() -> void:
	_clear_socket_traces()
	for section: Node3D in live_sections:
		section.hide()


func _clear_socket_traces() -> void:
	for socket: ChanSocket in sockets:
		socket.show_trace(false, false)


func _held_block(actor: Node3D) -> ChanCopperBlock:
	if is_instance_valid(_carried) and _carried.is_carried_by(actor):
		return _carried
	return null


func _has_free_hands(actor: Node3D) -> bool:
	return actor is Player and _held_block(actor) == null


func _on_block_lifted(block: ChanCopperBlock) -> void:
	_carried = block


func _set_powered(value: bool) -> void:
	if _powered == value:
		return
	_powered = value
	if value:
		powered.emit()
	else:
		unpowered.emit()
