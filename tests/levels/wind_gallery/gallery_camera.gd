extends Camera3D
## Camera kiểm tra asset, không thay camera hoặc input của scene gameplay.

@export var orbit_sensitivity: float = 0.008
@export var minimum_distance: float = 2.0
@export var maximum_distance: float = 180.0

var orbit_enabled: bool = true
var _target: Vector3 = Vector3.UP
var _distance: float = 12.0
var _yaw: float = 0.55
var _pitch: float = 0.6


func frame_bounds(bounds: AABB) -> void:
	orbit_enabled = true
	fov = 40.0
	_target = bounds.get_center()
	_distance = clampf(bounds.size.length() * 1.65 + 3.0, 6.0, maximum_distance)
	_yaw = 0.55
	_pitch = 0.6
	_update_orbit()
	make_current()


func game_view(anchor: Vector3) -> void:
	orbit_enabled = false
	fov = 30.0
	global_position = anchor + Vector3(0.0, 24.51, 20.57)
	rotation_degrees = Vector3(-50.0, 0.0, 0.0)
	make_current()


func _unhandled_input(event: InputEvent) -> void:
	if not orbit_enabled or not current:
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_yaw -= motion.relative.x * orbit_sensitivity
			_pitch = clampf(_pitch + motion.relative.y * orbit_sensitivity, 0.08, 1.45)
			_update_orbit()
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(minimum_distance, _distance * 0.88)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(maximum_distance, _distance / 0.88)
		_update_orbit()


func _update_orbit() -> void:
	position = _target + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	look_at(_target)

