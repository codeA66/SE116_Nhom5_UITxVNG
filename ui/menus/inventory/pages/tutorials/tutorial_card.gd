class_name TutorialCard
extends MenuTile
## Thẻ dọc trong danh sách Sổ Hướng Dẫn: kế thừa MenuTile để nhận toàn bộ hiệu ứng focus/chuột/bàn phím.

var tutorial: TutorialData


func _init() -> void:
	zoom_on_focus = false


func setup(data: TutorialData) -> void:
	tutorial = data
	queue_redraw()


func get_detail() -> DetailEntry:
	return tutorial.create_detail_entry() if tutorial else null


func _draw_content(rect: Rect2) -> void:
	if tutorial == null or style == null:
		return
	var is_active := has_focus()
	# Không có nền: mục đang chọn chỉ có vạch màu nhấn bên trái và chữ sáng (phân loại đã nằm ở tiêu đề nhóm)
	if is_active:
		draw_rect(Rect2(rect.position, Vector2(style.tutorial_marker_width, rect.size.y)), style.accent)
	var icon_center := Vector2(rect.position.x + 30.0, rect.get_center().y)
	var color := style.ink if is_active else style.dim
	_draw_emblem(tutorial.icon, icon_center, 26.0, color, tutorial.title)
	var font := get_theme_default_font()
	var text_x := rect.position.x + 56.0
	var baseline := rect.get_center().y + font.get_ascent(style.body_font) * 0.35
	draw_string(font, Vector2(text_x, baseline), tr(tutorial.title), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 64.0, style.body_font - 2, color)


## Đang chọn chỉ có vạch bên trái: tắt ngoặc góc chung của MenuTile
func _draw_brackets(_rect: Rect2, _color: Color) -> void:
	pass
