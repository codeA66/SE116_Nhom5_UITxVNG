class_name CharmTile
extends MenuTile
## Ô bùa của trang Bùa, ba kiểu:
## - COLLECTION: ô trong lưới bộ sưu tập. Chưa tìm thấy = bóng tối "?" (người chơi biết còn bao nhiêu bùa để tìm);
##   đã có = biểu tượng + hạt ô khắc tốn; đang đeo = mờ đi, có dấu đang đeo.
## - EQUIPPED: bùa trên hàng "đang đeo".
## - EMPTY_SLOT: ô trống trên hàng đang đeo (còn ô khắc).

enum Mode { COLLECTION, EQUIPPED, EMPTY_SLOT }

## Hạt ô khắc dưới ô: bán kính và khoảng cách (tính theo bề rộng ô)
const COST_DOT_RATIO := 0.04
const COST_GAP_RATIO := 0.12
const ICON_RATIO := 0.56
## Số nét đứt mỗi cạnh của ô trống
const DASHES_PER_SIDE := 4

var mode: Mode = Mode.COLLECTION
var charm: CharmData
var owned: bool = false
var equipped: bool = false


func setup(data: CharmData, tile_mode: Mode, is_owned: bool, is_equipped: bool) -> void:
	charm = data
	mode = tile_mode
	owned = is_owned
	equipped = is_equipped
	queue_redraw()


func get_detail() -> DetailEntry:
	var entry := DetailEntry.new()
	if mode == Mode.EMPTY_SLOT:
		entry.title = "Ô trống"
		entry.subtitle = "Còn %d ô khắc" % (GameState.get_charm_notches() - GameState.get_used_notches())
		entry.add_section("", "Chọn một bùa trong bộ sưu tập để đeo vào đây.")
		return entry
	if not owned:
		entry.title = "???"
		entry.subtitle = "Bùa chưa tìm thấy"
		entry.add_section("", "Một lá bùa còn nằm đâu đó trên đảo Foxy.")
		return entry
	entry.title = charm.display_name
	entry.subtitle = "Tốn %d ô khắc%s" % [charm.notch_cost, "  ·  Đang đeo" if equipped else ""]
	entry.art_texture = charm.icon
	entry.add_section("Tác dụng", charm.description)
	entry.lore = charm.lore
	if not GameState.can_change_charms():
		entry.add_section("", "Chỉ đổi bùa được khi đứng ở khu đổi bùa.", true)
		return entry
	var room := GameState.get_charm_notches() - GameState.get_used_notches()
	if not equipped and charm.notch_cost > room:
		entry.add_section("", "Không đủ ô khắc (còn %d, cần %d)." % [room, charm.notch_cost], true)
	entry.hint = "Enter: tháo bùa" if equipped else "Enter: đeo bùa"
	return entry


func _draw_content(rect: Rect2) -> void:
	match mode:
		Mode.EMPTY_SLOT:
			_draw_empty_slot(rect)
		_:
			if owned:
				_draw_owned(rect)
			else:
				_draw_unknown(rect)


func _draw_owned(rect: Rect2) -> void:
	var dim_in_grid := mode == Mode.COLLECTION and equipped
	draw_rect(rect, style.tile_fill)
	draw_rect(rect, style.ink if mode == Mode.EQUIPPED else style.tile_border, false, 1.4 if mode == Mode.EQUIPPED else 1.0)
	var icon_color := Color(1, 1, 1, 0.35 if dim_in_grid else 1.0) if charm.icon else (style.dim if dim_in_grid else style.ink)
	_draw_emblem(charm.icon, rect.get_center() - Vector2(0.0, rect.size.y * 0.06), rect.size.x * ICON_RATIO, icon_color, charm.display_name)
	_draw_cost(rect, style.faint if dim_in_grid else style.ink)
	if dim_in_grid:
		# Dấu "đang đeo": hạt kim cương ở góc trên phải
		var c := Vector2(rect.end.x - 10.0, rect.position.y + 10.0)
		var d := 4.5
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), style.ornament)


func _draw_unknown(rect: Rect2) -> void:
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(rect, Color(style.faint, 0.5), false, 1.0)
	_draw_centered_text("?", rect.get_center(), int(rect.size.y * 0.32), Color(style.faint, 0.8))


func _draw_empty_slot(rect: Rect2) -> void:
	var inner := rect.grow(-4.0)
	# Khung nét đứt: ô chờ được đeo bùa
	var corners := [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		for dash in DASHES_PER_SIDE:
			var t0 := float(dash) / float(DASHES_PER_SIDE)
			var t1 := t0 + 0.5 / float(DASHES_PER_SIDE)
			draw_line(a.lerp(b, t0), a.lerp(b, t1), Color(style.faint, 0.7), 1.2, true)
	_draw_centered_text("+", rect.get_center(), int(rect.size.y * 0.3), Color(style.faint, 0.7))


func _draw_cost(rect: Rect2, color: Color) -> void:
	var radius := rect.size.x * COST_DOT_RATIO
	var gap := rect.size.x * COST_GAP_RATIO
	var start := rect.get_center().x - gap * float(charm.notch_cost - 1) * 0.5
	for index in charm.notch_cost:
		draw_circle(Vector2(start + gap * index, rect.end.y - radius * 2.6), radius, color)
