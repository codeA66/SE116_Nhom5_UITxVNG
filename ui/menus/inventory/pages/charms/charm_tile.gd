class_name CharmTile
extends MenuTile
## Ô một bùa: biểu tượng, số ô khắc tốn (chấm dưới), dấu đang đeo.

const COST_DOT := 3.5
const COST_GAP := 10.0

var charm: CharmData
var equipped: bool = false


func setup(data: CharmData, is_equipped: bool) -> void:
	charm = data
	equipped = is_equipped
	queue_redraw()


func get_detail() -> DetailEntry:
	var entry := DetailEntry.new()
	entry.title = charm.display_name
	entry.subtitle = "Tốn %d ô khắc%s" % [charm.notch_cost, "  ·  Đang đeo" if equipped else ""]
	entry.art_texture = charm.icon
	entry.add_section("", charm.description)
	entry.lore = charm.lore
	if not GameState.can_change_charms():
		entry.add_section("", "Chỉ đổi bùa được khi đứng ở khu đổi bùa.", true)
		return entry
	var room := GameState.get_charm_notches() - GameState.get_used_notches()
	if not equipped and charm.notch_cost > room:
		entry.add_section("", "Không đủ ô khắc (còn %d)." % room, true)
	entry.hint = "Enter: tháo bùa" if equipped else "Enter: đeo bùa"
	return entry


func _draw_content(rect: Rect2) -> void:
	draw_rect(rect, style.tile_fill)
	draw_rect(rect, style.ink if equipped else style.tile_border, false, 1.4 if equipped else 1.0)
	var icon_center := rect.get_center() - Vector2(0.0, 6.0)
	_draw_emblem(charm.icon, icon_center, rect.size.x * 0.5, style.ink if equipped else style.dim, charm.display_name)
	var start := rect.get_center().x - COST_GAP * float(charm.notch_cost - 1) * 0.5
	for index in charm.notch_cost:
		draw_circle(Vector2(start + COST_GAP * index, rect.end.y - 10.0), COST_DOT, style.ink if equipped else style.faint)
