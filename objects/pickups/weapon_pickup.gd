@tool
class_name WeaponPickup
extends Pickup
## Vũ khí nằm trên đất. Người chơi bấm tương tác để nhặt; model và tên lấy từ WeaponData.

@export var weapon: WeaponData:
	set(value):
		weapon = value
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	if weapon == null:
		return ["Chưa gán WeaponData: kéo một file vũ khí (ví dụ resources/weapons/sword.tres) vào ô Weapon."]
	return []


func _build_visual(visual_root: Node3D) -> void:
	if weapon.model_scene:
		var model := weapon.model_scene.instantiate() as Node3D
		model.scale = Vector3.ONE * weapon.model_scale
		visual_root.add_child(model)


func _can_be_picked_by(interactor: Node3D) -> bool:
	return interactor.has_method(&"pick_up_weapon")


func _give_to(interactor: Node3D) -> void:
	interactor.call(&"pick_up_weapon", weapon)
