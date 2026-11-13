@tool
class_name ItemPickup
extends Pickup
## Vật phẩm đếm theo số lượng nằm trên đất (Ấn Gió, vật liệu nâng cấp...): nhặt là cộng vào túi (trang Vật phẩm của Tab).
## Thêm loại vật phẩm mới chỉ cần đổi ô Item. Vật phẩm theo cờ (chìa khóa, TNT) dùng KeyPickup / QuickItemPickup.

@export var item: ItemData:
	set(value):
		item = value
		update_configuration_warnings()
@export_range(1, 99) var amount: int = 1
@export var beam_color: Color = Color("a6e0ef")
## Cỡ biểu tượng vật phẩm lơ lửng (m)
@export var icon_size: float = 0.7


func _build_visual(visual_root: Node3D) -> void:
	LootItemBeam.attach_to(visual_root.get_parent() as Node3D, beam_color).show()
	if item.icon == null:
		return
	var sprite := Sprite3D.new()
	sprite.texture = item.icon
	sprite.pixel_size = icon_size / maxf(float(item.icon.get_height()), 1.0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual_root.add_child(sprite)


func _get_configuration_warnings() -> PackedStringArray:
	if item == null:
		return ["Chưa gán ItemData vào ô Item."]
	if not item.owned_flag.is_empty():
		return ["Vật phẩm này tính theo cờ (owned_flag): dùng KeyPickup / QuickItemPickup."]
	return []


func _can_be_picked_by(interactor: Node3D) -> bool:
	return interactor is Player


func _give_to(_interactor: Node3D) -> void:
	GameState.add_item(item, amount)
