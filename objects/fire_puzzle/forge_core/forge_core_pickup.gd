@tool
class_name ForgeCorePickup
extends Pickup
## Lõi lò (tier 2 map Lửa): bấm tương tác để nhặt, lưu cờ persistent_id. Ống dẫn (ForgeConduit) cùng cờ ở Hub bừng sáng;
## đủ ba ống thì cửa sang mini-boss mở. Mỗi lõi một cờ riêng nên ba nhánh làm theo thứ tự nào cũng được.

signal collected


func _can_be_picked_by(interactor: Node3D) -> bool:
	return interactor is Player


func _give_to(_interactor: Node3D) -> void:
	collected.emit()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if persistent_id.is_empty():
		warnings.append("Chưa đặt persistent_id (cờ lõi): ống dẫn cùng cờ không bao giờ sáng")
	return warnings
