@tool
class_name WeaponSkillSlot
extends SkillSlot
## Ô vũ khí: rỗng khi chưa nhặt vũ khí ở ô này; sáng khi dùng được. Chỉ nổi lên (phóng to) khi đang dùng,
## theo active_states. Đang ghép nguyên tố thì có chấm màu nguyên tố ở góc ô.

@export var slot: WeaponData.Slot = WeaponData.Slot.SWORD
## Vũ khí phụ (cung): không cần chọn, có là dùng được nên luôn sáng khi đã sở hữu
@export var always_ready: bool = false

@export_group("Element Badge")
## Vị trí chấm nguyên tố so với tâm ô, tính theo bán kính (mặc định ở mũi phải)
@export var element_badge_anchor: Vector2 = Vector2(0.62, 0.0)
@export var element_badge_radius: float = 6.0
@export var element_badge_ring: float = 2.0
@export var element_badge_ring_color := Color(0.03, 0.05, 0.08, 1.0)


func is_available() -> bool:
	return GameState.get_weapon_in_slot(slot) != null


func is_ready() -> bool:
	return always_ready or _is_equipped()


func _is_equipped() -> bool:
	var equipped := GameState.get_weapon()
	return equipped != null and equipped.slot == slot


func _draw_extra(center: Vector2) -> void:
	if Engine.is_editor_hint():
		return
	var element := GameState.get_fused_element(slot)
	if element == null:
		return
	var badge := center + element_badge_anchor * radius
	draw_circle(badge, element_badge_radius + element_badge_ring, element_badge_ring_color, true, -1.0, true)
	draw_circle(badge, element_badge_radius, element.color, true, -1.0, true)
