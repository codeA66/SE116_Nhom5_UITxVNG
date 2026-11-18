class_name BossActionRule
extends Resource
## Một điều kiện chọn đòn; thứ tự trong selector quyết định ưu tiên.

@export var state: StringName
@export var readiness_method: StringName
@export var minimum_range_property: StringName
@export var maximum_range_property: StringName
@export var requires_shield: bool = false


func can_select(boss: Boss1, distance: float) -> bool:
	if requires_shield and not boss.is_shielded:
		return false
	if not minimum_range_property.is_empty() and distance < float(boss.data.get(minimum_range_property)):
		return false
	if not maximum_range_property.is_empty() and distance > float(boss.data.get(maximum_range_property)):
		return false
	return bool(boss.call(readiness_method))
