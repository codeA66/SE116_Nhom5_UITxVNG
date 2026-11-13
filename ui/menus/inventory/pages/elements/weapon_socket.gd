class_name WeaponSocket
extends MenuTile
## Ô một vũ khí: biểu tượng lớn, tên, tên tổ hợp đang ghép, ổ khảm tròn bên phải.
## Thả nguyên tố vào để ghép (đang ở vũ khí khác thì chuyển sang); kéo ra để chuyển / tháo; chuột phải để tháo nhanh.

const SOCKET_RADIUS := 26.0
const ICON_SIZE := 64.0
const DASH_SEGMENTS := 16

var slot: WeaponData.Slot = WeaponData.Slot.SWORD
var weapon: WeaponData
var element: ElementData
var fusion: FusionData


func setup(slot_id: WeaponData.Slot, data: WeaponData, fused: ElementData, combo: FusionData) -> void:
	slot = slot_id
	weapon = data
	element = fused
	fusion = combo
	queue_redraw()


func get_detail() -> DetailEntry:
	var entry := DetailEntry.new()
	if weapon == null:
		entry.title = "???"
		entry.add_section("", "Chưa có vũ khí ở ô này.")
		return entry
	entry.title = weapon.display_name
	entry.art_texture = weapon.icon
	entry.add_section("", weapon.description)
	if fusion:
		entry.subtitle = tr("Đang ghép: %s") % tr(element.display_name)
		entry.accent = element.color
		entry.add_section(fusion.display_name, fusion.description)
		entry.hint = "Enter hoặc chuột phải: tháo  ·  kéo nguyên tố ra để chuyển"
	elif element:
		entry.subtitle = tr("Đang ghép: %s") % tr(element.display_name)
		entry.add_section("", "Tổ hợp này chưa có hiệu ứng.", true)
	else:
		entry.subtitle = "Ổ khảm trống"
		entry.hint = "Thả một nguyên tố vào ổ khảm để ghép"
	return entry


func _get_drag_data(_at_position: Vector2) -> Variant:
	if element == null:
		return null
	set_drag_preview(ElementCard.make_drag_preview(element))
	return {"element": element.id, "from_slot": slot}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return weapon != null and data is Dictionary and data.has("element")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	GameState.fuse(data["element"], slot)


func _socket_center() -> Vector2:
	return Vector2(size.x - SOCKET_RADIUS - 22.0, size.y * 0.5)


func _draw_content(rect: Rect2) -> void:
	draw_rect(rect, style.tile_fill)
	draw_rect(rect, style.tile_border, false, 1.0)
	if weapon == null:
		_draw_centered_text("???", rect.get_center(), style.body_font, style.faint)
		return
	var icon_center := Vector2(22.0 + ICON_SIZE * 0.5, rect.get_center().y)
	_draw_emblem(weapon.icon, icon_center, ICON_SIZE, style.ink, weapon.display_name)
	var font := get_theme_default_font()
	var text_x := icon_center.x + ICON_SIZE * 0.5 + 16.0
	draw_string(font, Vector2(text_x, rect.get_center().y - 4.0), tr(weapon.display_name), HORIZONTAL_ALIGNMENT_LEFT, -1, style.body_font + 4, style.ink)
	var combo_text: String = tr(fusion.display_name) if fusion else tr("Chưa ghép" if element == null else element.display_name)
	draw_string(font, Vector2(text_x, rect.get_center().y + 20.0), combo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, style.heading_font, element.color if element else style.faint)
	var socket := _socket_center()
	draw_circle(socket, SOCKET_RADIUS + 4.0, Color(0.0, 0.0, 0.0, 0.55))
	if element:
		draw_circle(socket, SOCKET_RADIUS + 8.0, Color(element.color, 0.12))
		draw_arc(socket, SOCKET_RADIUS, 0.0, TAU, 40, element.color, 1.8, true)
		_draw_emblem(element.icon, socket, SOCKET_RADIUS * 1.2, element.color, element.display_name)
		return
	# Ổ trống: vòng nét đứt
	for index in DASH_SEGMENTS:
		if index % 2 == 0:
			var a := TAU * float(index) / DASH_SEGMENTS
			draw_arc(socket, SOCKET_RADIUS, a, a + TAU / DASH_SEGMENTS, 4, style.faint, 1.4, true)
