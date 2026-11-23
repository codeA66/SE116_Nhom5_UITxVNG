class_name ElementCard
extends MenuTile
## Thẻ đứng của một nguyên tố đã mở: huy hiệu lớn màu nguyên tố có quầng sáng, tên kỹ năng cấp hiện tại, chấm cấp.
## Không có hộp nền như ô bùa (bật lại bằng style.element_card_box). Chỉ để xem, không có thao tác.
## Chi tiết chỉ nói về cấp đang có: không lộ tên / mô tả cấp sau.

## Huy hiệu nằm ở phần trên thẻ (tỉ lệ chiều cao thẻ tính tới tâm)
const EMBLEM_Y_RATIO := 0.36
## Khoảng cách giữa hai chấm cấp, tính theo cỡ chấm
const PIP_GAP_SCALE := 2.6

var element: ElementData
var level: int = 0
var max_level: int = 1


func setup(data: ElementData) -> void:
	element = data
	var ability := data.ability
	level = GameState.get_ability_level(ability) if ability else 0
	max_level = ability.get_max_level() if ability else 1
	queue_redraw()


func get_detail() -> DetailEntry:
	var entry := DetailEntry.new()
	var ability := element.ability
	entry.title = ability.get_level_name(level)
	entry.subtitle = tr("Nguyên tố %s  ·  Cấp %d") % [tr(element.display_name), level]
	entry.accent = element.color
	entry.art_ability = ability
	entry.art_texture = element.icon
	entry.level = level
	entry.max_level = max_level
	entry.add_section("", ability.get_level_description(level))
	return entry


func _draw_content(rect: Rect2) -> void:
	if element == null:
		return
	if style.element_card_box:
		draw_rect(rect, style.tile_fill)
		draw_rect(rect, style.tile_border, false, 1.0)
	var radius := style.element_emblem_radius
	var center := Vector2(rect.get_center().x, rect.position.y + rect.size.y * EMBLEM_Y_RATIO)
	var active := has_focus()
	# Quầng sáng màu nguyên tố: đậm hơn khi đang chọn
	draw_circle(center, radius * 1.32, Color(element.color, 0.16 if active else 0.08))
	draw_circle(center, radius, Color(0.02, 0.025, 0.03, 0.85))
	draw_arc(center, radius, 0.0, TAU, 64, Color(element.color, 1.0 if active else 0.75), 2.0 if active else 1.4, true)
	_draw_emblem(element.icon, center, radius * 1.1, element.color, element.display_name)
	_draw_level_burst(center, radius)
	var name_y := center.y + radius * 1.32 + style.body_font + 6.0
	_draw_centered_text(tr(element.ability.get_level_name(level)) if element.ability else tr(element.display_name),
		Vector2(rect.get_center().x, name_y), style.body_font, style.ink if active else style.dim, rect.size.x)
	_draw_level_pips(Vector2(rect.get_center().x, name_y + style.level_gem_size * 3.4))


## Chấm cấp: đã có = màu nguyên tố, cấp đang dùng có quầng sáng, chưa có = viên tối
func _draw_level_pips(center: Vector2) -> void:
	var gap := style.level_gem_size * PIP_GAP_SCALE
	var start := center.x - gap * float(max_level - 1) * 0.5
	for index in max_level:
		var state := LevelGem.GemState.CURRENT if index == level - 1 else (LevelGem.GemState.OWNED if index < level else LevelGem.GemState.LOCKED)
		LevelGem.draw_gem(self, Vector2(start + gap * index, center.y), style.level_gem_size, state, element.color, style.faint)


## Vừa lên cấp: vòng sáng nở ra từ huy hiệu (đi kèm lớp sáng chung của MenuTile)
func _draw_level_burst(center: Vector2, radius: float) -> void:
	if _flash <= 0.0:
		return
	var grow := (1.0 - _flash) * radius
	draw_arc(center, radius + 4.0 + grow, 0.0, TAU, 48, Color(element.color, _flash), 2.5, true)
	draw_circle(center, radius, Color(element.color, 0.25 * _flash))
