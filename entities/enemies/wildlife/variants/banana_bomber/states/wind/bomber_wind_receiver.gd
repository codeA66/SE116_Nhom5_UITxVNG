class_name BomberWindReceiver
extends WindReceiverComponent
## Mỗi lần E trúng là một lượt hất mới, không cộng dồn vận tốc từ lượt cũ.
@export_range(1.0, 2.0, 0.05) var push_multiplier: float = 1.35

func push(impulse: Vector3) -> void:
	if not enabled or _push_immune: return
	_push_velocity = Vector3.ZERO
	super(impulse * push_multiplier)

func launch_duration() -> float:
	return _push_velocity.length() / maxf(push_decay,0.001)

func stop_launch() -> void:
	_push_velocity = Vector3.ZERO
