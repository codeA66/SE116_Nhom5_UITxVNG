@tool
class_name WeaponSlot
extends Control
## Một ô hình thoi: xám khi chưa nhặt, viền xanh sáng khi đang sử dụng.

@export var slot: WeaponData.Slot = WeaponData.Slot.SWORD
@export var accent_color := Color("7be9ff")

var selected: bool = false
var owned: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	refresh()


func refresh() -> void:
	owned = GameState.get_weapon_in_slot(slot) != null
	var equipped := GameState.get_weapon()
	selected = equipped != null and equipped.slot == slot
	$Icon.modulate = Color.WHITE if owned else Color(0.46, 0.56, 0.62, 0.42)
	$Key.modulate = accent_color if selected else Color("91a4b3")
	$Status.text = "ĐANG DÙNG" if selected else ("ĐÃ NHẶT" if owned else "CHƯA NHẶT")
	$Status.modulate = accent_color if selected else Color("91a4b3")
	queue_redraw()


func _draw() -> void:
	var center := Vector2(size.x * 0.5, 48)
	var radius := 43.0
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	if selected:
		for width: float in [14.0, 9.0, 5.0]:
			draw_polyline(outline, Color(accent_color, 0.07), width, true)
	draw_colored_polygon(points, Color("173545") if selected else Color(0.035, 0.065, 0.10, 0.88))
	draw_polyline(outline, accent_color if selected else Color("4d6376"), 2.0, true)
	if selected:
		draw_circle(center + Vector2(0, 34), 2.0, accent_color, true, -1, true)
