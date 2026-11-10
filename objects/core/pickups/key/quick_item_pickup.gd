@tool
class_name QuickItemPickup
extends KeyPickup
## Vật phẩm dùng phím (TNT...) nằm trên đất / trong rương: nhặt là có (cờ key_id = owned_flag của vật phẩm),
## và nếu chưa chọn vật phẩm nào để dùng thì tự chọn luôn vật phẩm này (bấm T dùng được ngay).

@export var item: QuickItemData


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if item == null:
		warnings.append("Chưa gán Item (QuickItemData).")
	elif item.owned_flag != key_id:
		warnings.append("Key Id phải trùng owned_flag của vật phẩm (%s)." % item.owned_flag)
	return warnings


func _give_to(interactor: Node3D) -> void:
	super(interactor)
	if GameState.get_selected_item() == null:
		GameState.select_item(item.id)
