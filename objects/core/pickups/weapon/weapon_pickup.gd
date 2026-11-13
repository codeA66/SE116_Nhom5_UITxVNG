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
		return ["Chưa gán WeaponData: kéo một file vũ khí (ví dụ resources/combat/weapons/sword.tres) vào ô Weapon."]
	return []


func _build_visual(visual_root: Node3D) -> void:
	_update_prompt()
	if weapon.model_scene:
		var model := weapon.model_scene.instantiate() as Node3D
		model.scale = Vector3.ONE * weapon.model_scale
		visual_root.add_child(model)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not Engine.is_editor_hint() and is_node_ready():
		_update_prompt()


func _update_prompt() -> void:
	if weapon != null and is_instance_valid(_interactable):
		_interactable.prompt_text = tr("Nhặt %s") % tr(weapon.display_name)


func _can_be_picked_by(interactor: Node3D) -> bool:
	return interactor.has_method(&"pick_up_weapon")


func _give_to(interactor: Node3D) -> void:
	interactor.call(&"pick_up_weapon", weapon)
