class_name WindReactiveClock
extends Node
## Một đồng hồ CPU/GPU chung, chỉ thức khi còn hiệu ứng gió cần hồi phục.

const CLOCK_UNIFORM: StringName = &"wind_react_clock"

var current_time: float = 0.0

static var _instance: WindReactiveClock
static var _registered: bool = false
var _deadline: float = 0.0


func _ready() -> void:
	set_process(Time.get_ticks_msec() * 0.001 < _deadline)


func _process(_delta: float) -> void:
	var now: float = Time.get_ticks_msec() * 0.001
	current_time = now
	RenderingServer.global_shader_parameter_set(CLOCK_UNIFORM, now)
	if now >= _deadline:
		set_process(false)


static func ensure_clock(tree: SceneTree) -> WindReactiveClock:
	if is_instance_valid(_instance):
		return _instance
	_instance = WindReactiveClock.new()
	_instance.name = "WindReactiveClock"
	_instance.set_process(false)
	if not _registered:
		RenderingServer.global_shader_parameter_add(CLOCK_UNIFORM, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
		_registered = true
	_instance.current_time = Time.get_ticks_msec() * 0.001
	RenderingServer.global_shader_parameter_set(CLOCK_UNIFORM, _instance.current_time)
	tree.root.add_child.call_deferred(_instance)
	return _instance


static func arm(tree: SceneTree, duration: float) -> float:
	var clock: WindReactiveClock = ensure_clock(tree)
	var now: float = Time.get_ticks_msec() * 0.001
	clock._deadline = maxf(clock._deadline, now + maxf(duration, 0.01))
	clock.current_time = now
	RenderingServer.global_shader_parameter_set(CLOCK_UNIFORM, now)
	clock.set_process(true)
	return now
