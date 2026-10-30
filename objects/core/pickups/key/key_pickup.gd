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


## Vật liệu phủ lên model chìa (chìa màu khác dùng chung model chìa đỏ); để trống = giữ màu model
@export var model_material: Material


func _build_visual(visual_root: Node3D) -> void:
	if model_material == null:
		return
	for mesh: MeshInstance3D in visual_root.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = model_material


func _get_configuration_warnings() -> PackedStringArray:
	if key_id.is_empty():
		return ["Chưa đặt Key Id: ổ khóa sẽ không biết chìa này."]
	return []


func _can_be_picked_by(interactor: Node3D) -> bool:
	return interactor is Player


func _give_to(_interactor: Node3D) -> void:
	GameState.set_flag(key_id)
