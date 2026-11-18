class_name ChanCircuit
extends Node3D
## Dòng điện dừng tại ổ đầu tiên chưa nối. Mỗi ổ có nhóm mesh phát sáng riêng.

signal powered
signal unpowered

@export var contacts: Array[ChanConductor] = []
@export var live_sections: Array[Node3D] = []
@export var electric_strip: Area3D

var _powered: bool = false
var _armored_guard: ChanArmorGuard
var _keeper: ShieldBearer
var _keeper_on_strip: bool = false

@onready var _timer: Timer = $PowerTime


func _ready() -> void:
	_timer.timeout.connect(_clear)
	if electric_strip:
		electric_strip.body_entered.connect(_on_body_entered)
		electric_strip.body_exited.connect(_on_body_exited)
	_clear()


func attach_keeper(keeper: ShieldBearer, armor: ChanArmorGuard) -> void:
	_keeper = keeper
	_armored_guard = armor
	_keeper_on_strip = false


func pulse(duration: float) -> void:
	var reaches_end: bool = _trace_pulse()
	_timer.start(maxf(duration, 0.01))
	_set_powered(reaches_end)
	_try_break_armor()


func stop() -> void:
	_timer.stop()
	_clear()


func _trace_pulse() -> bool:
	var reaches_end: bool = true
	for index: int in live_sections.size():
		live_sections[index].visible = reaches_end
		if index < contacts.size() and not contacts[index].closes_circuit():
			reaches_end = false
	return reaches_end


func _clear() -> void:
	_hide_tracks()
	_set_powered(false)


func _hide_tracks() -> void:
	for section: Node3D in live_sections:
		section.hide()


func _set_powered(value: bool) -> void:
	if _powered == value:
		return
	_powered = value
	if value:
		powered.emit()
	else:
		unpowered.emit()


func _on_body_entered(body: Node3D) -> void:
	if body == _keeper:
		_keeper_on_strip = true
		_try_break_armor()


func _on_body_exited(body: Node3D) -> void:
	if body == _keeper:
		_keeper_on_strip = false


func _try_break_armor() -> void:
	if _powered and _keeper_on_strip and is_instance_valid(_armored_guard):
		_armored_guard.break_armor()
