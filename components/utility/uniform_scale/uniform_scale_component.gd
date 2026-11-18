class_name UniformScaleComponent
extends Node
## Nhân tỉ lệ một lần theo scene gốc; tái dùng qua pool không làm kích thước tăng dồn.

signal scale_applied(value: Vector3)

@export var target: Node3D
@export_range(0.01, 10.0, 0.01, "or_greater") var multiplier: float = 1.0:
	set(value):
		multiplier = maxf(value, 0.01)
		if is_node_ready():
			_apply_scale()

var _base_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	if target == null:
		target = get_parent() as Node3D
	assert(target != null)
	_base_scale = target.scale
	_apply_scale()

func get_base_scale() -> Vector3:
	return _base_scale

func _apply_scale() -> void:
	target.scale = _base_scale * multiplier
	scale_applied.emit(target.scale)
