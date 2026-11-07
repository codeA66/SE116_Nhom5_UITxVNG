@tool
class_name WeaponSkillSlot
extends "res://ui/hud/skills/slots/skill_slot.gd"
## Huy hiệu đọc từ fusion khi có signal, không gọi GameState trong mỗi frame vẽ.
@export var slot: WeaponData.Slot = WeaponData.Slot.SWORD
@export var always_ready: bool = false
var _element: ElementData
## Điều kiện sở hữu tách khỏi hình dạng ô.
func is_available() -> bool:
	return GameState.get_weapon_in_slot(slot) != null
## Cung có thể sẵn sàng dù vũ khí chính vẫn là kiếm.
func is_ready() -> bool:
	var equipped: WeaponData = GameState.get_weapon()
	return always_ready or (equipped != null and equipped.slot == slot)
## Cache màu/huy hiệu sau signal, không truy vấn fusion khi cooldown đang vẽ.
func refresh() -> void:
	if not Engine.is_editor_hint(): _element = GameState.get_fused_element(slot)
	super.refresh()
## Dấu nguyên tố nhỏ, không tranh silhouette với glyph vũ khí.
func _draw_extra(center: Vector2) -> void:
	if _element == null: return
	var badge: Vector2 = center+style.element_badge_anchor*radius
	var extent: float = clampf(style.element_badge_radius,0,16)
	var tint: Color = style.element_colors.get(_element.id,_element.color)
	draw_circle(badge,extent+style.stroke_width(),style.ink,true,-1.0,true)
	draw_circle(badge,extent,tint,true,-1.0,true)
