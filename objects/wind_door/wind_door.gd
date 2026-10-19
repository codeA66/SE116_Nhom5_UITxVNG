class_name WindDoor
extends StaticBody3D
## Cửa mở khi tất cả công tắc đã kích hoạt.

signal opened
signal closed

@export var switch_paths: Array[NodePath] = []
@export var persistent_id: StringName
@export var permanent: bool = false
@export var required_flag: StringName

var is_open: bool = false
var _switches: Array[WindTurbineSwitch] = []
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _visual: MeshInstance3D = $MeshInstance3D
@onready var _light: OmniLight3D = $SignalLamp


func _ready() -> void:
	for switch_path in switch_paths:
		var wind_switch: WindTurbineSwitch = get_node_or_null(switch_path) as WindTurbineSwitch
		if wind_switch == null:
			push_error("WindDoor: không tìm thấy công tắc " + str(switch_path))
			continue
		_switches.append(wind_switch)
		wind_switch.activated.connect(_refresh)
		wind_switch.deactivated.connect(_refresh)
	GameState.progress_changed.connect(_refresh)
	_set_open(permanent and not persistent_id.is_empty() and GameState.has_flag(persistent_id))
	_refresh()


func _refresh() -> void:
	if is_open and permanent:
		return
	if not required_flag.is_empty() and not GameState.has_flag(required_flag):
		_set_open(false)
		return
	if _switches.is_empty():
		return
	for wind_switch in _switches:
		if not wind_switch.is_active():
			_set_open(false)
			return
	_set_open(true)


func _set_open(value: bool) -> void:
	if is_open == value:
		return
	is_open = value
	_collision.set_deferred(&"disabled", value)
	_visual.visible = not value
	_light.visible = value
	if value:
		if permanent and not persistent_id.is_empty():
			GameState.set_flag(persistent_id)
		opened.emit()
	else:
		closed.emit()
