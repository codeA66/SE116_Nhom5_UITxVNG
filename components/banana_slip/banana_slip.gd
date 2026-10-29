class_name BananaSlip
extends Node
## Trượt là trạng thái điều khiển, không phải sát thương hay lực đẩy có thể phanh bằng input.
signal started
signal finished

@export var slide_distance: float = 3.0
@export var slide_duration: float = 0.55
@export_range(0.0, 30.0) var max_pivot_degrees: float = 16.0
@export var pivot_speed: float = 1.4
var active: bool = false
var _actor: Character
var _heading: float = 0.0
var _initial_heading: float = 0.0
var _remaining: float = 0.0
var _distance_left: float = 0.0
var _before: Vector3

func _ready() -> void:
	_actor = get_parent() as Character
	set_process(false)

func begin() -> bool:
	if active or not _actor.is_on_floor(): return false
	var health: HealthComponent = _actor.get_node_or_null(^"HealthComponent") as HealthComponent
	if health != null and health.is_dead(): return false
	var direction: Vector3 = Vector3(_actor.velocity.x, 0.0, _actor.velocity.z)
	if direction.length_squared() < 0.04: direction = _actor.get_facing_direction()
	_initial_heading = atan2(direction.x, direction.z)
	_heading = _initial_heading
	_remaining = maxf(slide_duration, 0.05)
	_distance_left = maxf(slide_distance, 0.05)
	active = true
	_actor.state_machine.transition_to(&"Slip")
	started.emit()
	return true

func integrate(delta: float) -> void:
	_remaining -= delta
	var input: Vector3 = _actor.get_slip_steering()
	if not input.is_zero_approx():
		var offset: float = wrapf(atan2(input.x, input.z) - _initial_heading, -PI, PI)
		var limit: float = deg_to_rad(max_pivot_degrees)
		var desired: float = _initial_heading + clampf(offset, -limit, limit)
		_heading = rotate_toward(_heading, desired, pivot_speed * delta)
	var direction: Vector3 = Vector3(sin(_heading), 0.0, cos(_heading))
	var speed: float = maxf(slide_distance, 0.05) / maxf(slide_duration, 0.05)
	_actor.velocity.x = direction.x * speed
	_actor.velocity.z = direction.z * speed
	_actor.face_direction(direction, delta)
	_before = _actor.global_position

func after_movement() -> void:
	if not active: return
	var traveled: Vector3 = _actor.global_position - _before
	traveled.y = 0.0
	_distance_left -= traveled.length()
	var blocked: bool = false
	var direction: Vector3 = Vector3(sin(_heading), 0.0, cos(_heading))
	for i: int in _actor.get_slide_collision_count():
		var normal: Vector3 = _actor.get_slide_collision(i).get_normal()
		if absf(normal.y) < 0.7 and normal.dot(direction) < -0.15:
			blocked = true
			break
	if blocked or _remaining <= 0.0 or _distance_left <= 0.0:
		stop()
		if _actor.state_machine.current_state.name == &"Slip":
			_actor.state_machine.transition_to(recovery_state())

func stop() -> void:
	if not active: return
	active = false
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
	finished.emit()

func recovery_state() -> StringName:
	return _actor.get_slip_recovery_state()
