@tool
class_name KeyGlyph
extends Control
## Hình một phím bấm (khung bo góc + chữ phím) nằm giữa câu hướng dẫn, thay cho chữ "Nhấn E".
## Tự giãn theo độ dài chữ phím (E, Space, Chuột trái...). Chỉ vẽ lại khi đổi chữ / màu.

@export var text: String = "E":
	set(value):
		text = value
		_refresh()
@export_range(8, 96, 1) var font_size: int = 20:
	set(value):
		font_size = value
		_refresh()
@export var text_color: Color = Color(0.95, 0.95, 0.92):
	set(value):
		text_color = value
		queue_redraw()
@export var fill_color: Color = Color(0.06, 0.06, 0.07):
	set(value):
		fill_color = value
		_refresh()
@export var border_color: Color = Color(0.9, 0.9, 0.86, 0.9):
	set(value):
		border_color = value
		_refresh()
## Khoảng trống quanh chữ (px): ngang, dọc
@export var padding: Vector2 = Vector2(10.0, 4.0):
	set(value):
		padding = value
		_refresh()
@export_range(0.0, 32.0, 0.5) var corner_radius: float = 5.0:
	set(value):
		corner_radius = value
		_refresh()
@export_range(0.5, 6.0, 0.5) var border_width: float = 1.5:
	set(value):
		border_width = value
		_refresh()

var _box: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _draw() -> void:
	if _box == null:
		return
	draw_style_box(_box, Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := Vector2((size.x - text_size.x) * 0.5, (size.y - text_size.y) * 0.5 + font.get_ascent(font_size))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func _refresh() -> void:
	if _box == null:
		_box = StyleBoxFlat.new()
	_box.bg_color = fill_color
	_box.border_color = border_color
	_box.set_border_width_all(roundi(border_width))
	_box.set_corner_radius_all(roundi(corner_radius))
	_box.anti_aliasing = true
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	# Phím 1 ký tự vẫn vuông vức, không bị hẹp hơn cao
	var height := text_size.y + padding.y * 2.0
	custom_minimum_size = Vector2(maxf(text_size.x + padding.x * 2.0, height), height)
	queue_redraw()
