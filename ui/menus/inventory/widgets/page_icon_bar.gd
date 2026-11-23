class_name PageIconBar
extends Control
## Hàng icon các trang ở đầu màn Tab (kiểu Death's Door): trang đang xem sáng màu nhấn, trang khác mờ.
## Bấm chuột vào icon thì xin đổi sang trang đó. Chỉ vẽ lại khi đổi trang (không có _process).
## Trang chưa có icon thì vẽ chữ cái đầu của tên trang trong vòng tròn.

## Bấm vào icon thứ index
signal page_requested(index: int)

var _style: InventoryStyle
var _icons: Array[Texture2D] = []
var _titles: PackedStringArray = PackedStringArray()
var _selected: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)


func configure(style: InventoryStyle) -> void:
	_style = style
	_update_size()


## icons[i] có thể null (trang chưa có icon). titles dùng để vẽ chữ thay thế và cho tooltip
func show_pages(icons: Array[Texture2D], titles: PackedStringArray, selected: int) -> void:
	_icons = icons
	_titles = titles
	_selected = selected
	tooltip_text = tr(titles[selected]) if selected >= 0 and selected < titles.size() else ""
	_update_size()
	queue_redraw()


func get_icon_count() -> int:
	return _icons.size()


func get_selected() -> int:
	return _selected


func _update_size() -> void:
	if _style == null:
		return
	var count := maxi(_icons.size(), 1)
	custom_minimum_size = Vector2(count * _style.page_icon_size + (count - 1) * _style.page_icon_gap, _style.page_icon_size)


func _icon_rect(index: int) -> Rect2:
	var total := _icons.size() * _style.page_icon_size + maxi(_icons.size() - 1, 0) * _style.page_icon_gap
	var start_x := (size.x - total) * 0.5
	return Rect2(Vector2(start_x + index * (_style.page_icon_size + _style.page_icon_gap), (size.y - _style.page_icon_size) * 0.5),
		Vector2.ONE * _style.page_icon_size)


func _draw() -> void:
	if _style == null:
		return
	var font := get_theme_default_font()
	for i in _icons.size():
		var rect := _icon_rect(i)
		var center := rect.get_center()
		var radius := rect.size.x * 0.5
		var active := i == _selected
		var tint: Color = _style.accent if active else _style.faint
		# Vòng tròn mảnh quanh mọi icon; trang đang xem có vòng màu nhấn đậm hơn và nền tối
		if active:
			draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.45))
		draw_arc(center, radius - 1.0, 0.0, TAU, 40, tint, 2.0 if active else 1.0, true)
		var icon := _icons[i]
		var inner := rect.grow(-rect.size.x * _style.page_icon_padding)
		if icon:
			draw_texture_rect(icon, inner, false, Color(1, 1, 1, 1.0 if active else 0.45))
		elif font and i < _titles.size():
			var letter := tr(_titles[i]).substr(0, 1).to_upper()
			var font_size := int(rect.size.y * 0.45)
			var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			draw_string(font, center + Vector2(-text_size.x * 0.5, text_size.y * 0.32), letter,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT or _style == null:
		return
	for i in _icons.size():
		if _icon_rect(i).has_point(click.position) and i != _selected:
			accept_event()
			page_requested.emit(i)
			return
