class_name WindReactiveWindmill
extends WindReactiveProp
## Cánh quay theo tốc độ nền, xung gió và gió liên tục.

signal spin_changed(speed: float)

@export var rotor_name: StringName = &"Windmill_Rotor"
@export var base_spin_speed: float = 0.0

var _spin_speed: float = 0.0
var _hold_strength: float = 0.0
var _rotor: Node3D


func _setup_visual() -> void:
	_rotor = _find_named(_model, rotor_name)
	_spin_speed = base_spin_speed
	set_process(base_spin_speed > 0.0)


func _process(delta: float) -> void:
	var previous: float = _spin_speed
	var wanted: float = base_spin_speed + _hold_strength * data.windmill_boost
	_spin_speed = move_toward(_spin_speed, wanted, data.windmill_decay * delta)
	if _rotor != null:
		_rotor.rotate_z(_spin_speed * delta)
	if not is_equal_approx(previous, _spin_speed):
		spin_changed.emit(_spin_speed)
	if base_spin_speed <= 0.0 and _hold_strength <= 0.0 and is_zero_approx(_spin_speed):
		set_process(false)


func get_spin_speed() -> float:
	return _spin_speed


func _on_reacted(_direction: Vector3, strength: float) -> void:
	var normalized: float = clampf(strength / maxf(data.full_strength, 0.01), 0.0, 2.0)
	_spin_speed = maxf(_spin_speed, base_spin_speed + normalized * data.windmill_boost)
	spin_changed.emit(_spin_speed)
	set_process(true)


func _on_wind_changed(_direction: Vector3, strength: float) -> void:
	_hold_strength = clampf(strength / maxf(data.full_strength, 0.01), 0.0, 2.0)
	if _hold_strength > 0.0:
		set_process(true)


func _find_named(node: Node, wanted: StringName) -> Node3D:
	if node.name == wanted and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found: Node3D = _find_named(child, wanted)
		if found != null:
			return found
	return null
