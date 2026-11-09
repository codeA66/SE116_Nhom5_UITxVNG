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
	entry.subtitle = category if not item.owned_flag.is_empty() else "%s  ·  Đang có %d" % [category, count]
	entry.art_texture = item.icon
	entry.add_section("", item.description)
	entry.lore = item.lore
	if item is QuickItemData:
		var using := is_selected_item()
		entry.add_section("Sử dụng", "Đang dùng: giữ T để nhắm, thả T để đặt." if using else "Chưa dùng.")
		entry.hint = "Enter: bỏ chọn" if using else "Enter: chọn sử dụng (phím T)"
	return entry


## Vật phẩm của ô này đang được chọn dùng bằng phím T
func is_selected_item() -> bool:
	return item is QuickItemData and GameState.get_selected_item() == item


func _draw_content(rect: Rect2) -> void:
	draw_rect(rect, style.tile_fill)
	draw_rect(rect, style.tile_border, false, 1.0)
	# Có hình vẽ thì giữ màu gốc của hình; chưa có thì hình thoi màu chữ
	_draw_emblem(item.icon, rect.get_center(), rect.size.x * 0.6, Color.WHITE if item.icon else style.ink, item.display_name)
	if item.owned_flag.is_empty() and count > 1:
		var font := get_theme_default_font()
		var text := "x%d" % count
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, style.key_font)
		draw_string(font, rect.end - Vector2(text_size.x + 6.0, 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, style.key_font, style.ink)
	if is_selected_item():
		# Dấu "đang dùng": chữ T ở góc trên phải
		_draw_centered_text("T", rect.position + Vector2(rect.size.x - 12.0, 13.0), style.key_font, style.ink)
