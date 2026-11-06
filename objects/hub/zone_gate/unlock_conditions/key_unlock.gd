class_name KeyUnlock
extends UnlockCondition
## Cần đã nhặt chìa (KeyPickup có cùng key_id).

@export var key_id: StringName
@export var hint: String = "Cần chìa khóa"


func is_met() -> bool:
	return not key_id.is_empty() and GameState.has_flag(key_id)


func get_hint() -> String:
	return hint
