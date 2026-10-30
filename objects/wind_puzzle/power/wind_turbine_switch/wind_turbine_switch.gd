class_name WindTurbineSwitch
extends Node3D
## Cối xay kích hoạt khi đủ tốc độ quay trong một khoảng thời gian.

signal activated
signal deactivated

@export var windmill_path: NodePath = ^"Windmill"
@export var spin_threshold: float = 1.0
@export var activation_seconds: float = 0.2
@export var permanent: bool = false
@export var persistent_id: StringName

var active: bool = false
var _elapsed: float = 0.0
@onready var _windmill: WindReactiveWindmill = get_node(windmill_path) as WindReactiveWindmill
@onready var _lamp: OmniLight3D = $SignalLamp


func _ready() -> void:
	set_process(false)
	active = permanent and not persistent_id.is_empty() and GameState.has_flag(persistent_id)
	_lamp.visible = active
	_windmill.spin_changed.connect(_on_spin_changed)
	if active:
		activated.emit()


func _process(delta: float) -> void:
	if _windmill.get_spin_speed() < spin_threshold:
		_elapsed = 0.0
		if active and not permanent:
			_set_active(false)
		set_process(false)
		return
	if not active:
		_elapsed += delta
		if _elapsed >= activation_seconds:
			_set_active(true)
			if permanent:
				set_process(false)


func is_active() -> bool:
	return active


func _on_spin_changed(speed: float) -> void:
	if active and permanent:
		return
	if speed >= spin_threshold:
		if activation_seconds <= 0.0:
			_set_active(true)
		else:
			set_process(true)
	elif active and not permanent:
		_set_active(false)
		_elapsed = 0.0
		set_process(false)


func _set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	_lamp.visible = value
	if value:
		if permanent and not persistent_id.is_empty():
			GameState.set_flag(persistent_id)
		activated.emit()
	else:
		deactivated.emit()
