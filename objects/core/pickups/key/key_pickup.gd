@tool
class_name KeyPickup
extends Pickup
## Chìa khóa nằm trên bệ: nhặt là có chìa (lưu bằng cờ key_id). Cửa có ổ khóa (RedKeyDoor) cùng key_id mới mở được.
## Mỗi cặp chìa - ổ có key_id riêng nên map có nhiều cặp không lẫn nhau.

## Định danh chìa, ví dụ "level_1.tier2_key"; ổ khóa dùng đúng tên này
@export var key_id: StringName:
	set(value):
		key_id = value
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	if key_id.is_empty():
		return ["Chưa đặt Key Id: ổ khóa sẽ không biết chìa này."]
	return []


func _can_be_picked_by(interactor: Node3D) -> bool:
	return interactor is Player


func _give_to(_interactor: Node3D) -> void:
	GameState.set_flag(key_id)
