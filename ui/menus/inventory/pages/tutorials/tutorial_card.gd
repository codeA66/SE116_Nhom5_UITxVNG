class_name TutorialCard
extends MenuTile
## Thẻ dọc trong danh sách Sổ Hướng Dẫn: kế thừa MenuTile để nhận toàn bộ hiệu ứng focus/chuột/bàn phím.

var tutorial: TutorialData


func setup(data: TutorialData) -> void:
	tutorial = data
	queue_redraw()


func get_detail() -> DetailEntry:
	return tutorial.create_detail_entry() if tutorial else null


func _draw_content(rect: Rect2) -> void:
	if tutorial == null or style == null:
		return
	
	var is_active := has_focus()
	# Nền thẻ
	var bg_color := Color(style.ink, 0.12) if is_active else Color(0.0, 0.0, 0.0, 0.45)
	draw_rect(rect, bg_color)
	# Đường viền mỏng
	var border_color := style.ornament if is_active else Color(style.ornament, 0.2)
	draw_rect(rect, border_color, false, 1.0)
	
	# Icon / Biểu tượng bên trái
	var icon_center := Vector2(rect.position.x + 28.0, rect.get_center().y)
	var icon_color := style.ink if is_active else style.dim
	_draw_emblem(tutorial.icon, icon_center, 26.0, icon_color, tutorial.title)
	
	# Chữ tiêu đề & phân loại
	var font := get_theme_default_font()
	var title_size := 15
	var cat_size := 11
	var text_x := rect.position.x + 54.0
	var text_max_w := rect.size.x - 64.0
	
	var title_color := style.ink if is_active else style.dim
	var cat_color := style.ornament if is_active else style.faint
	
	# Vẽ Title
	draw_string(font, Vector2(text_x, rect.position.y + 24.0), tr(tutorial.title), HORIZONTAL_ALIGNMENT_LEFT, text_max_w, title_size, title_color)
	# Vẽ Phân loại
	draw_string(font, Vector2(text_x, rect.position.y + 42.0), tutorial.category.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, text_max_w, cat_size, cat_color)
