class_name ItemTile
extends MenuTile
## Ô một vật phẩm: biểu tượng (chưa có hình thì hình thoi + chữ cái đầu) và số lượng ở góc.

const CATEGORY_NAMES: PackedStringArray = ["Vật liệu nâng cấp", "Chìa khóa", "Vật sưu tầm", "Dụng cụ"]

var item: ItemData
var count: int = 0


func setup(data: ItemData, amount: int) -> void:
	item = data
	count = amount
	queue_redraw()


func get_detail() -> DetailEntry:
	var entry := DetailEntry.new()
	entry.title = item.display_name
	var category := CATEGORY_NAMES[item.category] if item.category < CATEGORY_NAMES.size() else ""
	entry.subtitle = tr(category) if not item.owned_flag.is_empty() else tr("%s  ·  Đang có %d") % [tr(category), count]
	entry.art_texture = item.icon
	entry.add_section("", item.description)
	entry.lore = item.lore
	return entry


func _draw_content(rect: Rect2) -> void:
	if item == null:
		return
	if style.item_tile_box:
		draw_rect(rect, style.tile_fill)
		draw_rect(rect, style.tile_border, false, 1.0)
	# Có hình vẽ thì giữ màu gốc của hình; chưa có thì hình thoi màu chữ
	var tint := Color.WHITE if item.icon else (style.ink if has_focus() else style.dim)
	_draw_emblem(item.icon, rect.get_center(), rect.size.x * 0.78, tint, item.display_name)
	if item.owned_flag.is_empty() and count > 1:
		# Số lượng to ở góc dưới phải, viền tối để đọc được trên mọi hình
		var font := get_theme_default_font()
		var text := "x%d" % count
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, style.item_count_font)
		var at := rect.end - Vector2(text_size.x + 2.0, 4.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, style.item_count_font, 4, Color(0.0, 0.0, 0.0, 0.85))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, style.item_count_font, style.ink)
