class_name BossCooldowns
extends Node
## Timer chỉ chạy khi đang hồi chiêu; thêm chiêu bằng node Timer mới.

var _timers: Dictionary[StringName, Timer] = {}


func _ready() -> void:
	for child: Node in get_children():
		if child is Timer:
			_timers[child.name] = child as Timer


func is_ready(action: StringName) -> bool:
	return _timers[action].is_stopped()


func start_cooldown(action: StringName, duration: float) -> void:
	if duration > 0.0:
		_timers[action].start(duration)
	else:
		_timers[action].stop()


func stop_all() -> void:
	for timer: Timer in _timers.values():
		timer.stop()
