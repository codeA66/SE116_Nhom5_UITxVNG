class_name WeaponTile
extends MenuTile
## Ô một vũ khí đã nhặt: huy hiệu tròn (hình vũ khí, chưa có hình thì chữ cái đầu), tên bên dưới.
## Vũ khí đang trang bị: vòng màu nhấn + chữ "Đang trang bị". Chi tiết có chỉ số (WeaponData.get_stats) và phím trang bị.

const EQUIPPED_TEXT := "Đang trang bị"
## Huy hiệu nằm ở phần trên ô (tỉ lệ chiều cao ô tính tới tâm)
const EMBLEM_Y_RATIO := 0.4

var weapon: WeaponData
var equipped: bool = false
var group_title: String = ""


func setup(data: WeaponData, is_equipped: bool, title: String) -> void:
	weapon = data
	equipped = is_equipped
	group_title = title
	queue_redraw()


func get_detail() -> DetailEntry:
	var entry := DetailEntry.new()
	entry.title = weapon.display_name
	entry.subtitle = "%s  ·  %s" % [tr(group_title), tr(EQUIPPED_TEXT)] if equipped else tr(group_title)
	entry.art_texture = weapon.icon
	entry.accent = style.ink if style else Color.WHITE
	entry.add_section("", weapon.description)
	entry.stats = weapon.get_stats()
	if not equipped:
		entry.hint_key = PageTabs.key_name(&"ui_accept")
		entry.hint = tr("Trang bị")
	return entry


func _draw_content(rect: Rect2) -> void:
	if weapon == null:
		return
	var radius := style.weapon_emblem_radius
	var center := Vector2(rect.get_center().x, rect.position.y + rect.size.y * EMBLEM_Y_RATIO)
	var active := has_focus()
	var ring := style.accent if equipped else (style.ink if active else style.tile_border)
	draw_circle(center, radius, Color(0.02, 0.025, 0.03, 0.85))
	if equipped:
		draw_circle(center, radius * 1.25, Color(style.accent, 0.1))
	draw_arc(center, radius, 0.0, TAU, 64, ring, 2.0 if equipped or active else 1.2, true)
	_draw_emblem(weapon.icon, center, radius * 1.15, Color.WHITE if weapon.icon else (style.ink if active else style.dim), weapon.display_name)
	var name_y := center.y + radius + style.body_font + 8.0
	_draw_centered_text(_fit(tr(weapon.display_name), style.body_font, rect.size.x - 8.0), Vector2(rect.get_center().x, name_y), style.body_font,
		style.ink if active or equipped else style.dim, rect.size.x)
	if equipped:
		_draw_centered_text(tr(EQUIPPED_TEXT).to_upper(), Vector2(rect.get_center().x, name_y + style.key_font + 6.0),
			style.key_font - 2, style.accent, rect.size.x)


## Cắt tên dài cho vừa ô (thêm "…"): chỉ chạy khi vẽ lại ô, không chạy mỗi frame
func _fit(text: String, font_size: int, width: float) -> String:
	var font := get_theme_default_font()
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return text
	var cut := text.length()
	while cut > 1 and font.get_string_size(text.left(cut) + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		cut -= 1
	return text.left(cut) + "…"
