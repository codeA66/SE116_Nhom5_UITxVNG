@tool
class_name AbilityPickup
extends Pickup
## Sách kỹ năng nằm trên đất: nhặt là mở khóa kỹ năng. Đổi kỹ năng bằng cách gán file .tres khác.

@export var ability: AbilityData:
	set(value):
		ability = value
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	if ability == null:
		return ["Chưa gán AbilityData: kéo một file kỹ năng (ví dụ abilities/wind_blast/wind_blast.tres) vào ô Ability."]
	return []


func _can_be_picked_by(interactor: Node3D) -> bool:
	return interactor.has_method(&"unlock_ability")


func _give_to(interactor: Node3D) -> void:
	interactor.call(&"unlock_ability", ability)
